extends SceneTree
## Headless：实时战斗抽打弃 / 直接开战 / 结算（对齐 Features/PLAYER.md）。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_battle_controller_rules()
	if _failures == 0:
		print("RealtimeBattleFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("RealtimeBattleFlowTest: FAIL %s" % label)


func _clear_hand_cooldowns(battle: RealtimeBattleController) -> void:
	battle._card_flow.enter_hand_cooldown = 0.0
	battle._card_flow.tick(30.0)


func _fill_command(battle: RealtimeBattleController) -> void:
	battle._command.reset(battle._command.get_max())


func _test_battle_controller_rules() -> void:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	deck.reset_from_config()
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 4242
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, load(LEVEL_PATH) as LevelData)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	_clear_hand_cooldowns(battle)
	_fill_command(battle)

	_expect(battle.get_phase() == RealtimeBattleController.Phase.COMBAT, "controller: start_encounter enters COMBAT")
	_expect(battle.get_board_size() == Vector2i(18, 32), "controller: board is 18x32")
	_expect(battle.get_command_current() >= 5.0, "controller: command starts at or above open value")
	var hand := battle.get_hand()
	_expect(hand.size() == deck.get_hand_width(), "controller: hand size equals hand_width")
	var sim := battle.get_sim()
	_expect(sim != null and sim.has_started(), "controller: sim started on encounter enter")
	_expect(sim.count_alive(UnitInstance.Team.ENEMY) > 0, "controller: enemies spawned on enter")
	_expect(battle.try_start_combat(), "controller: already in combat")

	var size := battle.get_board_size()
	var mid := BoardHalf.midline_row(size.y)
	var first_id := hand[0].entry_id
	var first_cost := hand[0].get_command_cost()
	battle._command.reset(0.0)
	_expect(not battle.try_deploy(first_id, Vector2i(3, size.y - 3)).is_empty(), "controller: deploy rejected when command empty")
	_fill_command(battle)
	_expect(not battle.try_deploy(first_id, Vector2i(5, 2)).is_empty(), "controller: enemy half rejected")
	_expect(battle.try_deploy(first_id, Vector2i(3, size.y - 3)).is_empty(), "controller: player half accepted")
	_expect(battle.get_command_current() <= battle.get_command_max() - float(first_cost) + 0.001, "controller: command spent on deploy")
	_expect(battle.is_entry_on_field(first_id), "controller: deployed entry is on field")
	_expect(not battle._card_flow.is_in_hand(first_id), "controller: played card left hand")
	_expect(not battle.try_recall_at(Vector2(3.5, size.y - 2.5)), "controller: no prepare recall")

	_clear_hand_cooldowns(battle)
	_fill_command(battle)
	hand = battle.get_hand()
	_expect(not hand.is_empty(), "controller: hand refilled after play")
	if not hand.is_empty():
		var reinforce_id := hand[0].entry_id
		_expect(battle.try_deploy(reinforce_id, Vector2i(8, mid + 4)).is_empty(), "controller: reinforce in COMBAT")
		var late := sim.find_unit_by_deck_entry(reinforce_id)
		_expect(late != null and not late.is_deploying(), "controller: reinforcement has no deploy_time")

	var gold_before := economy.gold
	for rt in sim.get_units():
		if not rt.is_player():
			rt.unit.current_hp = 0
	sim.advance_fixed_step()
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RESULT, "controller: RESULT after enemies wiped")
	_expect(sim.did_player_win(), "controller: player won")
	_expect(economy.gold > gold_before, "controller: wave gold granted on win")

	var completed: Array = []
	battle.encounter_completed.connect(func(won: bool) -> void: completed.append(won))
	battle.continue_after_result()
	_expect(completed == [true], "controller: encounter_completed(true) emitted on continue")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "controller: IDLE after continue")
	_expect(battle.get_sim() == null, "controller: sim released after continue")
	await process_frame
	_expect(battle.find_child("RealtimeCombatEventBus", false, false) == null, "controller: bus freed after continue")

	battle.queue_free()
	await process_frame
