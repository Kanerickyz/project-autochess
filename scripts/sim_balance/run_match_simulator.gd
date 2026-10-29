class_name RunMatchSimulator
extends RefCounted

const DEFAULT_RUN_MAP := preload("res://resources/runs/act1_map.tres")
const DEFAULT_DECK_CONFIG := preload("res://resources/deck/realtime_starter_deck.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")
const DEFAULT_RECRUIT_CONFIG := preload("res://resources/recruit/default_recruit_config.tres")
const DEFAULT_AI_PROFILE := preload("res://resources/sim_balance/default_ai_profile.tres")

var map_config: RunMapConfig
var deck_config: DeckConfig
var economy_config: EconomyConfig
var recruit_config: RecruitConfig
var ai_profile: SimAIProfile
var spawn_budget: SpawnBudgetConfig

var _ai: RefCounted
var bandit_checkpoint: SimBanditCheckpoint
var bandit_learning: bool = false
var _recruit_session: RecruitSession = RecruitSession.new()
var _recruit_shop: RecruitShopService = RecruitShopService.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func configure(
	p_map: RunMapConfig = null,
	p_deck: DeckConfig = null,
	p_economy: EconomyConfig = null,
	p_recruit: RecruitConfig = null,
	p_profile: SimAIProfile = null,
	p_budget: SpawnBudgetConfig = null,
	p_checkpoint: SimBanditCheckpoint = null,
	p_bandit_learning: bool = false,
) -> void:
	map_config = p_map if p_map != null else DEFAULT_RUN_MAP
	deck_config = p_deck if p_deck != null else DEFAULT_DECK_CONFIG
	economy_config = p_economy if p_economy != null else DEFAULT_ECONOMY
	recruit_config = p_recruit if p_recruit != null else DEFAULT_RECRUIT_CONFIG
	ai_profile = p_profile if p_profile != null else DEFAULT_AI_PROFILE
	spawn_budget = p_budget if p_budget != null else SpawnBudgetConfig.load_or_default()
	bandit_checkpoint = p_checkpoint
	bandit_learning = p_bandit_learning
	_ai = _build_ai(ai_profile, p_checkpoint, p_bandit_learning)


func _build_ai(
	p_profile: SimAIProfile,
	p_checkpoint: SimBanditCheckpoint,
	p_learning: bool,
) -> RefCounted:
	if p_checkpoint != null:
		var table := SimBanditTable.new()
		p_checkpoint.apply_to(table)
		var mode := p_checkpoint.reward_mode
		if mode.is_empty():
			mode = BanditRunAI.REWARD_V1
		return BanditRunAI.new(p_profile, table, p_learning, mode)
	return HeuristicRunAI.new(p_profile)


func simulate_run(seed: int) -> Dictionary:
	var run_controller := RunController.new()
	run_controller.configure(map_config, seed)
	var deck := DeckState.new()
	deck.configure(deck_config)
	deck.set_rng(_rng)
	var economy := RunEconomy.new()
	economy.configure(economy_config)
	economy.reset()
	_rng.seed = seed + 991
	deck.set_rng(_rng)

	_recruit_session.clear_persisted_locks()
	_recruit_session.clear_taken_copies()
	_recruit_shop.configure(RecruitShopConfig.load_or_default(), economy)

	run_controller.start_run()
	run_controller.run_state.mark_run_started()
	if _ai is BanditRunAI:
		(_ai as BanditRunAI).begin_run()

	var encounters: Array = []
	_run_opening_recruit(run_controller, deck, economy)

	var guard := 0
	while guard < 512:
		guard += 1
		match run_controller.phase:
			RunController.RunPhase.RUN_COMPLETE:
				break
			RunController.RunPhase.RUN_DEFEAT:
				break
			RunController.RunPhase.MAP:
				var node: MapNodeRuntime = _ai.pick_map_node(run_controller)
				if node == null:
					run_controller.fail_run()
					break
				run_controller.enter_node(node.get_id())
			RunController.RunPhase.ENCOUNTER:
				var done := _resolve_encounter(run_controller, deck, economy, encounters)
				if not done:
					break
			_:
				break

	var record := _build_run_record(seed, run_controller, encounters)
	_notify_run_finished(record, run_controller)
	return record


func _run_opening_recruit(run_controller: RunController, deck: DeckState, economy: RunEconomy) -> void:
	_rng.seed = run_controller.run_state.rng_seed + 17
	_recruit_session.configure(recruit_config, deck, economy, _rng)
	_recruit_session.require_nonempty_roster = true
	_recruit_session.forward_tier_unlock = run_controller.is_endless()
	var floors := _map_floor_count(run_controller)
	_recruit_session.begin(0.0, 1, floors)
	_ai.run_opening_recruit(_recruit_session, _recruit_shop)


func _resolve_encounter(
	run_controller: RunController,
	deck: DeckState,
	economy: RunEconomy,
	encounters: Array,
) -> bool:
	var node := run_controller.get_pending_node()
	if node == null:
		run_controller.complete_encounter()
		return true
	var node_type := node.get_effective_type()
	if node_type == MapNodeType.Type.START:
		run_controller.complete_encounter()
		return true
	if MapNodeType.is_combat(node_type):
		return _resolve_combat_encounter(run_controller, deck, economy, node, encounters)
	if node_type == MapNodeType.Type.SHOP:
		run_controller.register_shop_visit()
		economy.grant_floor_gold(node.get_floor())
		run_controller.complete_encounter()
		return true
	if MapNodeType.grants_node_completion_gold(node_type):
		economy.grant_floor_gold(node.get_floor())
	run_controller.complete_encounter()
	return true


func _resolve_combat_encounter(
	run_controller: RunController,
	deck: DeckState,
	economy: RunEconomy,
	node: MapNodeRuntime,
	encounters: Array,
) -> bool:
	var encounter := node.get_encounter()
	if encounter == null:
		run_controller.complete_encounter()
		return true
	var level := run_controller.get_board_defaults()
	if level == null:
		run_controller.fail_run()
		return false

	var board_size := encounter.get_board_size(level.get_board_size())
	_ai.ensure_combat_seating(deck, board_size)
	if deck.get_seated_count() <= 0:
		run_controller.fail_run()
		return false

	var tier := run_controller.get_encounter_tier_index()
	var floor := maxi(1, node.get_floor())
	_rng.seed = int(run_controller.run_state.rng_seed) ^ (node.get_id() * 7919 + tier * 101)
	var combat_rng_seed := _rng.randi()

	var combat := EncounterCombatDriver.run_encounter({
		"encounter": encounter,
		"level": level,
		"deck": deck,
		"economy": economy,
		"tier_index": tier,
		"floor_index": floor,
		"node_type": int(node.get_effective_type()),
		"rng_seed": combat_rng_seed,
		"map_floor_count": _map_floor_count(run_controller),
		"forward_tier_unlock": run_controller.is_endless(),
		"spawn_budget": spawn_budget,
	})
	var won := bool(combat.get("won", false))
	_notify_encounter_resolved(won)
	encounters.append({
		"floor": floor,
		"node_type": MapNodeType.display_name(node.get_effective_type()),
		"node_id": node.get_id(),
		"won": won,
		"encounter_id": encounter.id,
		"tier_index": tier,
	})

	if not won:
		run_controller.fail_run()
		return false

	if encounter.bonus_gold > 0:
		economy.grant(encounter.bonus_gold)
	economy.grant_floor_gold(floor)

	if _recruit_session.should_offer_recruit(node.get_effective_type(), true):
		_rng.seed = combat_rng_seed + 3
		_recruit_session.configure(recruit_config, deck, economy, _rng)
		_recruit_session.require_nonempty_roster = false
		_recruit_session.forward_tier_unlock = run_controller.is_endless()
		var progress := clampf(
			float(run_controller.run_state.completed_encounter_count) / float(_map_floor_count(run_controller)),
			0.0,
			1.0,
		)
		_recruit_session.begin(progress, floor, _map_floor_count(run_controller))
		_ai.run_post_combat_recruit(_recruit_session, _recruit_shop)

	run_controller.complete_encounter()
	return true


func _map_floor_count(run_controller: RunController) -> int:
	if run_controller.map_config != null:
		return maxi(1, run_controller.map_config.floor_count)
	return TierUnlock.DEFAULT_FLOOR_COUNT


func _build_run_record(seed: int, run_controller: RunController, encounters: Array) -> Dictionary:
	var outcome := "RUN_DEFEAT"
	if run_controller.phase == RunController.RunPhase.RUN_COMPLETE:
		outcome = "RUN_COMPLETE"
	var death_floor := 0
	if outcome == "RUN_DEFEAT":
		death_floor = maxi(0, run_controller.defeat_reached_floor)
	return {
		"seed": seed,
		"outcome": outcome,
		"death_floor": death_floor,
		"encounters_fought": encounters.size(),
		"encounters": encounters,
		"profile_id": _report_profile_id(),
	}


func _report_profile_id() -> String:
	if bandit_checkpoint != null and not bandit_checkpoint.policy_id.is_empty():
		return bandit_checkpoint.policy_id
	if ai_profile != null:
		return ai_profile.profile_id
	return "default"


func _notify_encounter_resolved(won: bool) -> void:
	if _ai is BanditRunAI:
		(_ai as BanditRunAI).on_encounter_resolved(won)


func _notify_run_finished(record: Dictionary, run_controller: RunController) -> void:
	if _ai is BanditRunAI:
		(_ai as BanditRunAI).on_run_finished(
			str(record.get("outcome", "")),
			int(record.get("death_floor", 0)),
			_map_floor_count(run_controller),
		)


func export_bandit_checkpoint() -> SimBanditCheckpoint:
	var out := bandit_checkpoint.duplicate_checkpoint() if bandit_checkpoint != null else SimBanditCheckpoint.new()
	if _ai is BanditRunAI:
		var ai := _ai as BanditRunAI
		out.capture_from(ai.bandit_table)
		out.reward_mode = ai.reward_mode
	return out


func get_bandit_update_count() -> int:
	if _ai is BanditRunAI:
		return (_ai as BanditRunAI).bandit_table.get_total_updates()
	return 0
