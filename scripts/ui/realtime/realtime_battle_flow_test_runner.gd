extends SceneTree
## Headless：实时战斗控制器的准备/开战/结算规则 + RunGameController 的节点编排（胜、负、重开、占位节点）。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const RUN_SCENE := "res://scenes/main/run_game.tscn"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_battle_controller_rules()
	await _test_run_orchestration()
	if _failures == 0:
		print("RealtimeBattleFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("RealtimeBattleFlowTest: FAIL %s" % label)


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

	_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "controller: start_encounter enters PREPARE")
	_expect(battle.get_board_size() == Vector2i(18, 32), "controller: board is 18x32")
	var hand := battle.get_hand()
	_expect(hand.size() == deck.get_draw_count(), "controller: hand size equals draw_count")
	_expect(not battle.get_pending_enemy_positions().is_empty(), "controller: enemy previews exist before combat")
	_expect(not battle.try_start_combat(), "controller: cannot start with 0 player units")

	var size := battle.get_board_size()
	var mid := BoardHalf.midline_row(size.y)
	var first_id := hand[0].entry_id
	_expect(not battle.try_deploy(first_id, Vector2i(5, 2)).is_empty(), "controller: enemy half rejected")
	_expect(not battle.try_deploy(first_id, Vector2i(-1, size.y - 2)).is_empty(), "controller: out of board rejected")
	_expect(battle.try_deploy(first_id, Vector2i(3, size.y - 3)).is_empty(), "controller: player half accepted")
	_expect(battle.is_entry_on_field(first_id), "controller: deployed entry is on field")
	_expect(not battle.try_deploy(first_id, Vector2i(6, size.y - 3)).is_empty(), "controller: same card twice rejected")
	_expect(not battle.try_deploy(hand[1].entry_id, Vector2i(3, size.y - 3)).is_empty(), "controller: occupied cell rejected")

	_expect(battle.try_recall_at(Vector2(3.5, size.y - 2.5)), "controller: recall in PREPARE")
	_expect(not battle.is_entry_on_field(first_id), "controller: recalled entry leaves field")
	_expect(battle.try_deploy(first_id, Vector2i(3, size.y - 3)).is_empty(), "controller: recalled card can redeploy")

	_expect(battle.try_start_combat(), "controller: start with 1 unit")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.COMBAT, "controller: phase COMBAT")
	var sim := battle.get_sim()
	_expect(sim.has_started(), "controller: sim marked started on start_combat")
	_expect(sim.count_alive(UnitInstance.Team.ENEMY) > 0, "controller: enemies spawned on start")
	_expect(not battle.try_recall_at(Vector2(3.5, size.y - 2.5)), "controller: no recall during COMBAT")
	_expect(battle.try_deploy(hand[1].entry_id, Vector2i(8, mid + 4)).is_empty(), "controller: cycle reinforce in COMBAT")
	var late := sim.find_unit_by_deck_entry(hand[1].entry_id)
	_expect(late != null and late.is_deploying(), "controller: reinforcement waits deploy_time")

	for entry in hand:
		if not battle.is_entry_on_field(entry.entry_id):
			battle.try_deploy(entry.entry_id, Vector2i(randi_range(1, size.x - 2), randi_range(mid + 3, size.y - 2)))
	_expect(battle.get_player_unit_count() <= battle.get_max_board_units(), "controller: population cap respected")

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


func _test_run_orchestration() -> void:
	var run_game := (load(RUN_SCENE) as PackedScene).instantiate() as RunGameController
	root.add_child(run_game)
	await process_frame
	var rc := run_game.run_controller
	var battle := run_game.find_children("*", "RealtimeBattleController", true, false)[0] as RealtimeBattleController
	var map_screen := run_game.get_node("%MapScreen") as MapScreen
	var placeholder := run_game.get_node("%PlaceholderNodeScreen") as PlaceholderNodeScreen
	var overlay := run_game.get_node("%RunEndOverlay") as RunEndOverlay
	var start_gold := run_game.run_economy.gold
	var start_deck_size := run_game.deck_state.size()

	_expect(rc.phase == RunController.RunPhase.MAP, "run: starts on MAP")
	for node in rc.get_map_state().nodes:
		var t := node.get_node_type()
		_expect(t in [
			MapNodeType.Type.START, MapNodeType.Type.COMBAT, MapNodeType.Type.ELITE, MapNodeType.Type.BOSS,
			MapNodeType.Type.SHOP, MapNodeType.Type.EVENT, MapNodeType.Type.ENCHANT,
		], "run: node %d type %s is v1" % [node.get_id(), MapNodeType.Type.keys()[t]])

	var saw_placeholder := false
	var won_combats := 0
	var guard := 0
	while rc.phase == RunController.RunPhase.MAP and (won_combats < 2 or not saw_placeholder) and guard < 20:
		guard += 1
		var available := rc.get_available_nodes()
		if available.is_empty():
			break
		var node: MapNodeRuntime = available[0]
		if not saw_placeholder:
			for candidate in available:
				if not candidate.is_combat_node() and candidate.get_node_type() != MapNodeType.Type.START:
					node = candidate
		var depth_before := rc.run_state.run_depth
		map_screen.node_selected.emit(node.get_id())
		await process_frame
		var t := rc.get_pending_node_type() if rc.get_pending_node() != null else node.get_effective_type()
		if MapNodeType.is_combat(t):
			_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "run: combat node opens realtime battle")
			_win_current_battle(battle)
			battle.continue_after_result()
			await process_frame
			won_combats += 1
			_expect(rc.phase == RunController.RunPhase.MAP, "run: won combat returns to MAP")
		elif rc.get_pending_node() != null:
			_expect(placeholder.visible, "run: non-combat node shows placeholder")
			saw_placeholder = true
			placeholder.continue_pressed.emit()
			await process_frame
			_expect(rc.phase == RunController.RunPhase.MAP, "run: placeholder continue returns to MAP")
		_expect(rc.run_state.run_depth >= depth_before, "run: depth does not regress")
	_expect(won_combats >= 1, "run: at least one combat won (got %d)" % won_combats)
	if not saw_placeholder:
		print("  NOTE run: first path had no non-combat node; placeholder covered by type check only")

	var lost := false
	guard = 0
	while rc.phase == RunController.RunPhase.MAP and not lost and guard < 20:
		guard += 1
		var available := rc.get_available_nodes()
		if available.is_empty():
			break
		var target: MapNodeRuntime = available[0]
		for candidate in available:
			if candidate.is_combat_node():
				target = candidate
		map_screen.node_selected.emit(target.get_id())
		await process_frame
		if battle.get_phase() == RealtimeBattleController.Phase.PREPARE:
			_lose_current_battle(battle)
			battle.continue_after_result()
			await process_frame
			lost = true
		elif placeholder.visible:
			placeholder.continue_pressed.emit()
			await process_frame
	_expect(lost, "run: reached a combat to lose")
	_expect(rc.phase == RunController.RunPhase.RUN_DEFEAT, "run: defeat ends run")
	_expect(overlay.visible, "run: defeat overlay visible")

	run_game.run_economy.grant(999)
	overlay.action_pressed.emit(&"restart")
	await process_frame
	_expect(rc.phase == RunController.RunPhase.MAP, "run: restart returns to MAP")
	_expect(run_game.run_economy.gold == start_gold, "run: restart resets gold")
	_expect(run_game.deck_state.size() == start_deck_size, "run: restart resets deck")
	_expect(rc.run_state.run_depth == 0 or rc.run_state.completed_encounter_count == 0, "run: restart resets progress")

	run_game.queue_free()
	await process_frame


func _deploy_first(battle: RealtimeBattleController) -> void:
	var size := battle.get_board_size()
	battle.try_deploy(battle.get_hand()[0].entry_id, Vector2i(size.x / 2, size.y - 3))
	battle.try_start_combat()


func _win_current_battle(battle: RealtimeBattleController) -> void:
	_deploy_first(battle)
	var sim := battle.get_sim()
	for rt in sim.get_units():
		if not rt.is_player():
			rt.unit.current_hp = 0
	sim.advance_fixed_step()
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RESULT, "run: battle resolved (win)")


func _lose_current_battle(battle: RealtimeBattleController) -> void:
	_deploy_first(battle)
	var sim := battle.get_sim()
	for rt in sim.get_units():
		if rt.is_player():
			rt.unit.current_hp = 0
	sim.advance_fixed_step()
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RESULT, "run: battle resolved (loss)")
