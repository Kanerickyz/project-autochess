class_name RunGameController
extends Node

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const DEFAULT_RUN_MAP := preload("res://resources/runs/act1_map.tres")
const DEFAULT_DECK_CONFIG := preload("res://resources/deck/realtime_starter_deck.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")
const DEFAULT_RECRUIT_CONFIG := preload("res://resources/recruit/default_recruit_config.tres")
const RELIC_OFFER_SCENE := preload("res://scenes/ui/event/relic_offer_screen.tscn")
## 无尽招募品阶软顶：避免进度比卡死，但实际层号可超过。
const ENDLESS_RECRUIT_SOFT_FLOOR_COUNT := 30

@export var map_config_override: RunMapConfig

@onready var _battle_root: Control = %BattleRoot
@onready var _map_screen: MapScreen = %MapScreen
@onready var _placeholder_screen: PlaceholderNodeScreen = %PlaceholderNodeScreen
@onready var _run_end_overlay: RunEndOverlay = %RunEndOverlay
@onready var _run_stats_overlay: RunStatsOverlay = %RunStatsOverlay
@onready var _relic_offer_screen: RelicOfferScreen = %RelicOfferScreen

var run_controller: RunController = RunController.new()
var deck_state: DeckState = DeckState.new()
var run_economy: RunEconomy = RunEconomy.new()
var relic_bag: ExpeditionRelicBag = ExpeditionRelicBag.new()
var recruit_config: RecruitConfig = DEFAULT_RECRUIT_CONFIG
var map_shop_config: MapShopConfig = MapShopConfig.load_or_default()
var _battle: RealtimeBattleController
var _recruit_session: RecruitSession = RecruitSession.new()
var _map_shop_service: MapShopService = MapShopService.new()
var _relic_offer_service: ExpeditionRelicOfferService = ExpeditionRelicOfferService.new()
var _rng := RandomNumberGenerator.new()
var _recruit_busy: bool = false
var _enchant_busy: bool = false
var _map_shop_busy: bool = false
var _event_relic_busy: bool = false
## 时机 A：点开始后、见地图前先开局招募；期间抑制 MAP→_show_map。
var _opening_recruit_pending: bool = false
var _suppress_map_show: bool = false
## 主模式线性：战后店|事二选一尚未完成（完成后进主题招募，再 complete）。
var _linear_post_battle_pending: bool = false
var _shop_or_event_panel: ShopOrEventChoicePanel
var _relic_stage_choice: RelicStageChoice
var _run_stat_ledger: RunStatLedger = RunStatLedger.new()
var _pending_end_victory: bool = false
var _pending_end_snapshot: RunStatsSnapshot
var _pending_map_hint: String = ""


func _ready() -> void:
	_rng.randomize()
	deck_state.configure(DEFAULT_DECK_CONFIG)
	run_economy.configure(DEFAULT_ECONOMY)
	_ensure_relic_offer_screen()
	var offer_rng := RandomNumberGenerator.new()
	offer_rng.seed = _rng.randi()
	_relic_offer_service.configure(null, offer_rng)

	_battle = BATTLE_SCENE.instantiate() as RealtimeBattleController
	if _battle == null:
		push_error("RunGameController: battle scene is not RealtimeBattleController")
		return
	_battle_root.add_child(_battle)
	_ensure_shop_or_event_panel()
	_ensure_relic_stage_choice()
	if recruit_config != null:
		_battle.half_exit_seconds = recruit_config.half_exit_seconds
		_battle.recruit_enter_seconds = recruit_config.panel_enter_seconds
	_battle.set_run_stat_ledger(_run_stat_ledger)
	_battle.set_relic_bag(relic_bag)
	_battle.encounter_completed.connect(_on_encounter_completed)
	_battle.final_trial_floors_recorded.connect(_on_final_trial_floors_recorded)
	_battle.recruit_finished.connect(_on_recruit_finished)
	_battle.enchant_finished.connect(_on_enchant_finished)
	_battle.map_shop_finished.connect(_on_map_shop_finished)

	var map_cfg: RunMapConfig = map_config_override if map_config_override != null else DEFAULT_RUN_MAP
	run_controller.configure(map_cfg, _rng.randi())
	run_controller.phase_changed.connect(_on_run_phase_changed)
	run_controller.map_updated.connect(_on_map_updated)

	_map_screen.node_selected.connect(_on_map_node_selected)
	_placeholder_screen.continue_pressed.connect(_on_placeholder_continue)
	if _relic_offer_screen != null and not _relic_offer_screen.finished.is_connected(_on_relic_offer_finished):
		_relic_offer_screen.finished.connect(_on_relic_offer_finished)
	_run_end_overlay.action_pressed.connect(_on_run_end_action)
	_run_stats_overlay.continue_pressed.connect(_on_run_stats_continue)

	await _start_new_run()


func _ensure_relic_offer_screen() -> void:
	if _relic_offer_screen != null:
		return
	## 场景未挂节点时运行时补挂，避免旧场景阻断。
	var ui := get_node_or_null("UI") as CanvasLayer
	if ui == null:
		return
	_relic_offer_screen = RELIC_OFFER_SCENE.instantiate() as RelicOfferScreen
	_relic_offer_screen.name = "RelicOfferScreen"
	_relic_offer_screen.unique_name_in_owner = true
	ui.add_child(_relic_offer_screen)


func _ensure_shop_or_event_panel() -> void:
	if _shop_or_event_panel != null:
		_shop_or_event_panel.bind_battle(_battle)
		return
	_shop_or_event_panel = ShopOrEventChoicePanel.new()
	_shop_or_event_panel.choice_made.connect(_on_shop_or_event_chosen)
	_shop_or_event_panel.bind_battle(_battle)


func _ensure_relic_stage_choice() -> void:
	if _relic_stage_choice == null:
		_relic_stage_choice = RelicStageChoice.new()
		_relic_stage_choice.finished.connect(_on_relic_offer_finished)
	_relic_stage_choice.bind_battle(_battle)


func _is_endless() -> bool:
	return run_controller != null and run_controller.is_endless()


func _is_linear_main() -> bool:
	return run_controller != null and run_controller.is_linear_main()


func _start_new_run() -> void:
	_run_stat_ledger.reset()
	deck_state.set_run_stat_ledger(_run_stat_ledger)
	_pending_end_victory = false
	_pending_end_snapshot = null
	_linear_post_battle_pending = false
	deck_state.reset_from_config()
	run_economy.reset()
	relic_bag.clear()
	_recruit_session.clear_persisted_locks()
	_recruit_session.clear_party_bark_flags()
	_recruit_session.clear_taken_copies()
	_battle.reset_final_trial_state()
	_battle.setup(deck_state, run_economy, run_controller.get_board_defaults())
	_battle.set_relic_bag(relic_bag)
	if run_controller.map_config != null:
		_battle.set_map_floor_count(_recruit_map_floor_count())
		_battle.set_forward_tier_unlock(_is_endless())
		if run_controller.map_config.spawn_budget_override != null:
			_battle.set_spawn_budget_config(run_controller.map_config.spawn_budget_override)
		else:
			_battle.set_spawn_budget_config(null)
	_battle.reset_tier_unlock_announcements()
	_hide_encounter_ui()
	## 主模式线性：全程旁路地图选路。
	_suppress_map_show = true
	_opening_recruit_pending = true
	run_controller.start_run()
	run_controller.run_state.mark_run_started()
	await _open_opening_recruit()


func _show_map() -> void:
	if _suppress_map_show or _is_linear_main():
		return
	_hide_encounter_ui()
	## 地图与关卡共用竞技场背景：战斗层保留在下方作世界底图，地图半透明罩上。
	_battle_root.visible = true
	if _battle != null:
		_battle.exit_recruit()
		_battle.exit_map_shop()
		_battle.exit_enchant()
		_battle.set_world_backdrop_mode(true)
	var hint := _pending_map_hint
	_pending_map_hint = ""
	_map_screen.show_map(run_controller, hint)


func _hide_encounter_ui() -> void:
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	if _relic_offer_screen != null:
		_relic_offer_screen.hide_offers()
	if _relic_stage_choice != null:
		_relic_stage_choice.hide_offers()
	if _shop_or_event_panel != null:
		_shop_or_event_panel.hide_choice()
	if run_controller.phase != RunController.RunPhase.RUN_COMPLETE \
			and run_controller.phase != RunController.RunPhase.RUN_DEFEAT:
		_run_end_overlay.hide_overlay()
		_run_stats_overlay.hide_overlay()


func _on_map_node_selected(node_id: int) -> void:
	var node := run_controller.enter_node(node_id)
	if node == null:
		return
	_map_screen.hide_map()
	var node_type := run_controller.get_pending_node_type()
	if node_type == MapNodeType.Type.START:
		run_controller.complete_encounter()
		return
	if MapNodeType.is_combat(node_type):
		var encounter := node.get_encounter()
		if encounter == null:
			push_warning("RunGameController: combat node missing encounter")
			run_controller.complete_encounter()
			return
		_battle_root.visible = true
		if _battle != null:
			_battle.set_world_backdrop_mode(false)
			## 无尽软顶随当前战斗层放开，避免品阶/抽阵仍按开局 30 卡死观感。
			if _is_endless():
				_battle.set_map_floor_count(maxi(ENDLESS_RECRUIT_SOFT_FLOOR_COUNT, node.get_floor()))
		var floor_index := node.get_floor()
		_battle.start_encounter(
			encounter,
			run_controller.get_encounter_tier_index(),
			floor_index,
			int(node_type),
		)
		return
	## 主模式线性层表无商店/事件/附魔节点；无尽地图店仍走此路径。
	if node_type == MapNodeType.Type.SHOP:
		run_controller.register_shop_visit()
		await _open_map_shop()
		return
	if node_type == MapNodeType.Type.ENCHANT:
		## 主循环不接入附魔；误进则直接完成。
		if _is_linear_main():
			run_controller.complete_encounter()
			return
		await _open_enchant()
		return
	if node_type == MapNodeType.Type.EVENT:
		await _open_event_relic_offer()
		return
	## 非战斗节点仍留世界底图，占位 UI 叠在上面。
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(true)
	_placeholder_screen.show_placeholder(node_type)


func _enter_next_linear_combat() -> void:
	if not _is_linear_main():
		return
	var next_node := LinearRunProgress.find_next_combat_node(run_controller.get_map_state())
	if next_node == null:
		push_warning("RunGameController: no next linear combat node")
		return
	_on_map_node_selected(next_node.get_id())


func _on_placeholder_continue() -> void:
	_grant_pending_node_floor_gold()
	_placeholder_screen.hide_placeholder()
	run_controller.complete_encounter()


func _on_final_trial_floors_recorded(floors: int) -> void:
	if run_controller != null and run_controller.run_state != null:
		run_controller.run_state.final_trial_floors_cleared = maxi(0, floors)


func _on_encounter_completed(won: bool) -> void:
	if not won:
		var snap := _build_stats_snapshot(false)
		_battle_root.visible = false
		if _battle != null:
			_battle.exit_recruit()
		run_controller.fail_run()
		_present_run_end_result(snap)
		return

	var node := run_controller.get_pending_node()
	var encounter := node.get_encounter() if node != null else null
	if encounter != null and encounter.bonus_gold > 0:
		run_economy.grant(encounter.bonus_gold)

	var node_type := run_controller.get_pending_node_type()
	## Boss 胜：直接通关，不进店/事/招。
	if node_type == MapNodeType.Type.BOSS:
		_battle_root.visible = false
		if _battle != null:
			_battle.exit_recruit()
		run_controller.complete_encounter()
		return

	## 主模式线性：普通/精英胜 → 店|事二选一 → 主题招募 → 下一层。
	if _is_linear_main():
		_linear_post_battle_pending = true
		await _open_shop_or_event_choice()
		return

	## 无尽：胜后直接主题招募（无店|事二选一）。
	if not _recruit_session.should_offer_recruit(node_type, true):
		_battle_root.visible = false
		if _battle != null:
			_battle.exit_recruit()
		run_controller.complete_encounter()
		return

	await _open_recruit()


func _open_shop_or_event_choice() -> void:
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	_ensure_shop_or_event_panel()
	if _shop_or_event_panel != null:
		_shop_or_event_panel.show_choice()
	else:
		## 无面板时默认进商店。
		await _open_map_shop_for_linear_choice()


func _on_shop_or_event_chosen(choice: StringName) -> void:
	if not _linear_post_battle_pending:
		return
	if choice == ShopOrEventChoicePanel.CHOICE_EVENT:
		await _open_event_relic_offer_for_linear_choice()
	else:
		await _open_map_shop_for_linear_choice()


## 开局招募：与胜后同一套 Arena enter_recruit；进度第 0 层；须 ≥1 已入座才能完成。
func _open_opening_recruit() -> void:
	if _recruit_busy:
		return
	_recruit_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()

	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.randi()
	_recruit_session.configure(recruit_config, deck_state, run_economy, rng, relic_bag)
	_recruit_session.require_nonempty_roster = true
	## 招募不按主题/羁绊锁池：在已解锁品阶全池随机（开局第 0 层尺 → 仅 T1）。
	_recruit_session.theme_commitment_required = false
	_recruit_session.forward_tier_unlock = _is_endless()
	## 开局：第 0 层尺 → 仅 T1。
	_recruit_session.begin(0.0, 0, _recruit_map_floor_count())
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_recruit(_recruit_session, enter_s)


## 胜后留在 BattleRoot：半场退场后同屏滑入队伍/候选人（Arena 主路径，非暗色卡片面板）。
func _open_enchant() -> void:
	if _enchant_busy:
		return
	_enchant_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_enchant(enter_s)


func _on_enchant_finished(_did_fuse: bool) -> void:
	_enchant_busy = false
	run_controller.complete_encounter()


## 事件 / 商店离开：与战斗胜场同公式（第 n 层 → n+3 金）+ 圣物 bonus_floor_gold。
func _grant_pending_node_floor_gold() -> int:
	if run_controller == null or run_economy == null:
		return 0
	var node_type := run_controller.get_pending_node_type()
	if not MapNodeType.grants_node_completion_gold(node_type):
		return 0
	var node := run_controller.get_pending_node()
	if node == null:
		return 0
	var bonus := ExpeditionRelicEffectService.sum_bonus_floor_gold(relic_bag)
	var amount := run_economy.grant_floor_gold(node.get_floor(), bonus)
	if amount > 0:
		_pending_map_hint = "节点完成  +%d 金" % amount
	return amount


## 事件节点：远征圣物三选一（可跳过）；完成后发层金并回地图。
func _open_event_relic_offer() -> void:
	if _event_relic_busy:
		return
	_event_relic_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	_ensure_relic_stage_choice()
	var node := run_controller.get_pending_node()
	var floor_i := node.get_floor() if node != null else 1
	var offer_rng := RandomNumberGenerator.new()
	offer_rng.seed = _rng.randi()
	## 每次进事件重读池：balance-designer 资源到位后无需重开进程。
	_relic_offer_service.configure(ExpeditionRelicOfferService.load_pool_or_stub(), offer_rng)
	var offers := _relic_offer_service.roll_offers(floor_i, relic_bag, 3)
	if _relic_stage_choice != null:
		_relic_stage_choice.show_offers(offers, relic_bag)
	else:
		_event_relic_busy = false
		_grant_pending_node_floor_gold()
		run_controller.complete_encounter()


## 线性战后「事件」支：不发节点层金（战斗已发）、不 complete，结束后进招募。
func _open_event_relic_offer_for_linear_choice() -> void:
	if _event_relic_busy:
		return
	_event_relic_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	_ensure_relic_stage_choice()
	var floor_i := _recruit_map_floor()
	var offer_rng := RandomNumberGenerator.new()
	offer_rng.seed = _rng.randi()
	_relic_offer_service.configure(ExpeditionRelicOfferService.load_pool_or_stub(), offer_rng)
	var offers := _relic_offer_service.roll_offers(floor_i, relic_bag, 3)
	if _relic_stage_choice != null:
		_relic_stage_choice.show_offers(offers, relic_bag)
	else:
		_event_relic_busy = false
		await _open_recruit()


func _on_relic_offer_finished(_took: bool) -> void:
	if not _event_relic_busy:
		return
	_event_relic_busy = false
	if _linear_post_battle_pending:
		await _open_recruit()
		return
	_grant_pending_node_floor_gold()
	run_controller.complete_encounter()


## 地图商店：Arena 主路径（上队伍 / 下货架），与招募同屏半场；结束回地图。
func _open_map_shop() -> void:
	if _map_shop_busy:
		return
	_map_shop_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	var shop_rng := RandomNumberGenerator.new()
	shop_rng.seed = _rng.randi()
	var config := map_shop_config if map_shop_config != null else MapShopConfig.load_or_default()
	_map_shop_service.configure(config, run_economy, deck_state, shop_rng, relic_bag)
	_map_shop_service.open_shop()
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_map_shop(_map_shop_service, enter_s)


func _open_map_shop_for_linear_choice() -> void:
	run_controller.register_shop_visit()
	await _open_map_shop()


func _on_map_shop_finished() -> void:
	_map_shop_service.close_shop()
	_map_shop_busy = false
	if _linear_post_battle_pending:
		await _open_recruit()
		return
	_grant_pending_node_floor_gold()
	run_controller.complete_encounter()


func _open_recruit() -> void:
	if _recruit_busy:
		return
	_recruit_busy = true
	_opening_recruit_pending = false
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()

	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.randi()
	_recruit_session.configure(recruit_config, deck_state, run_economy, rng, relic_bag)
	_recruit_session.require_nonempty_roster = false
	## 胜后招募同样不按主题/羁绊过滤；品阶仍随层号解锁。
	_recruit_session.theme_commitment_required = false
	_recruit_session.forward_tier_unlock = _is_endless()
	_recruit_session.begin(
		_recruit_progress_ratio(),
		_recruit_map_floor(),
		_recruit_map_floor_count(),
	)
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_recruit(_recruit_session, enter_s)


func _recruit_progress_ratio() -> float:
	var floors := _recruit_map_floor_count()
	var depth := run_controller.run_state.completed_encounter_count
	return clampf(float(depth) / float(floors), 0.0, 1.0)


## 胜后招募品阶：用本场遭遇地图层（T2 自第 4 层；T3 自倒数 6 层 / 无尽单向）。
func _recruit_map_floor() -> int:
	if _battle != null:
		return maxi(0, _battle.get_floor_index())
	return 1


func _recruit_map_floor_count() -> int:
	## 无尽：软顶 max(30, currentF)，品阶靠 forward_tier_unlock 随 F 放开。
	if _is_endless():
		var current_f := _recruit_map_floor()
		return maxi(ENDLESS_RECRUIT_SOFT_FLOOR_COUNT, current_f)
	if run_controller != null:
		return run_controller.get_recruit_floor_count()
	if _battle != null:
		return maxi(1, _battle.get_map_floor_count())
	return TierUnlock.DEFAULT_FLOOR_COUNT


func _on_recruit_finished(_kept: bool) -> void:
	_recruit_busy = false
	if _opening_recruit_pending:
		_opening_recruit_pending = false
		## 开局招完：主模式直接进第 1 层；无尽仍进地图。
		if _is_linear_main():
			_suppress_map_show = true
			_enter_next_linear_combat()
			return
		_suppress_map_show = false
		_show_map()
		return
	## 线性战后招：离开后再层号 +1（complete）并进下一层。
	if _linear_post_battle_pending and _is_linear_main():
		_linear_post_battle_pending = false
		_battle_root.visible = false
		run_controller.complete_encounter()
		if run_controller.phase == RunController.RunPhase.RUN_COMPLETE:
			return
		_enter_next_linear_combat()
		return
	_battle_root.visible = false
	run_controller.complete_encounter()


func _on_run_phase_changed(new_phase: RunController.RunPhase) -> void:
	match new_phase:
		RunController.RunPhase.MAP:
			if _is_linear_main():
				## 线性主模式不展示尖塔选路。
				return
			_show_map()
		RunController.RunPhase.RUN_COMPLETE:
			_battle_root.visible = false
			_map_screen.hide_map()
			if _battle != null:
				_battle.exit_recruit()
			_present_run_end_result(_build_stats_snapshot(true))
		RunController.RunPhase.RUN_DEFEAT:
			_battle_root.visible = false
			_map_screen.hide_map()
			if _battle != null:
				_battle.exit_recruit()


func _on_map_updated() -> void:
	if _is_linear_main():
		return
	if run_controller.phase == RunController.RunPhase.MAP and not _suppress_map_show:
		_map_screen.refresh_map(run_controller)


## 结局宣告「继续」→ 远征统计；统计「继续」→ 再来一局/回主菜单。
func _on_run_stats_continue() -> void:
	_run_stats_overlay.hide_overlay()
	var reached := 0
	var endless := false
	if _pending_end_snapshot != null:
		reached = _pending_end_snapshot.reached_floor
		endless = _pending_end_snapshot.endless_mode
	_run_end_overlay.show_choices(_pending_end_victory, reached, endless)


func _present_run_end_result(snapshot: RunStatsSnapshot) -> void:
	_pending_end_snapshot = snapshot
	_pending_end_victory = snapshot != null and snapshot.victory
	_run_stats_overlay.hide_overlay()
	var reached := snapshot.reached_floor if snapshot != null else 0
	var endless := snapshot.endless_mode if snapshot != null else false
	_run_end_overlay.show_result_intro(_pending_end_victory, reached, endless)


func _present_run_end_stats(snapshot: RunStatsSnapshot) -> void:
	_run_end_overlay.hide_overlay()
	if snapshot != null:
		RunMatchHistoryStore.append_snapshot(snapshot)
	_run_stats_overlay.show_snapshot(snapshot)


func _build_stats_snapshot(victory: bool) -> RunStatsSnapshot:
	var snap := RunStatsSnapshot.new()
	snap.victory = victory
	var rs := run_controller.run_state
	snap.encounters_won = rs.completed_encounter_count
	snap.shop_visits = rs.shop_visit_count
	snap.combat_seconds = rs.get_run_elapsed_real_seconds()
	snap.gold = run_economy.gold
	snap.endless_mode = _is_endless()
	snap.final_trial_floors_cleared = rs.final_trial_floors_cleared
	## 败局：优先用正打着的战斗层；否则用已胜场+1；通关不记层深成绩。
	if not victory:
		var pending := run_controller.get_pending_node()
		if pending != null and MapNodeType.is_combat(pending.get_effective_type()):
			snap.reached_floor = maxi(1, pending.get_floor())
		elif _battle != null and _battle.get_floor_index() > 0:
			snap.reached_floor = _battle.get_floor_index()
		else:
			snap.reached_floor = maxi(1, rs.completed_encounter_count + 1)
	else:
		snap.reached_floor = 0
	snap.roster.assign(deck_state.get_entries())
	## 拷贝账本：历程数字已是值拷贝；战斗合计也须与活账本脱钩（再开局 reset 不影响已展示快照）。
	snap.ledger = (
		_run_stat_ledger.duplicate_ledger()
		if _run_stat_ledger != null
		else RunStatLedger.new()
	)
	snap.highest_attack_entries = RunStatsSnapshot.pick_highest_attack(snap.roster)
	snap.highest_max_hp_entries = RunStatsSnapshot.pick_highest_max_hp(snap.roster)
	snap.highest_combat_atk_hp_entries.assign(snap.ledger.peak_combat_entries)
	return snap


func _on_run_end_action(action: StringName) -> void:
	if action == &"continue":
		_run_end_overlay.hide_overlay()
		_present_run_end_stats(_pending_end_snapshot)
		return
	_run_end_overlay.hide_overlay()
	_run_stats_overlay.hide_overlay()
	_pending_end_snapshot = null
	if action == &"menu":
		await SceneTransition.change_scene_to_file("res://scenes/main/main_menu.tscn")
		return
	_start_new_run()
