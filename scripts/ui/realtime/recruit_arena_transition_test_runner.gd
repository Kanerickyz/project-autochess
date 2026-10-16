extends SceneTree
## Headless：胜后半场退场 → 同屏招募滑入；草地/边框固定；场上队伍与 3 候选人。
## half_exit / enter 均 0，避免 Tween 挂死。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
const RECRUIT_PATH := "res://resources/recruit/default_recruit_config.tres"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_recruit_arena_transition()
	if _failures == 0:
		print("RecruitArenaTransitionTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("RecruitArenaTransitionTest: FAIL %s" % label)


func _seed_test_deck(deck: DeckState) -> void:
	## 勿假设 starter 开局有人；空队时自行注入。
	deck.reset_from_config()
	if deck.size() > 0:
		return
	for path in [
		"res://resources/units/realtime/knight.tres",
		"res://resources/units/realtime/archer.tres",
		"res://resources/units/realtime/barbarian.tres",
		"res://resources/units/realtime/goblin.tres",
	]:
		var unit := load(path) as UnitData
		if unit != null:
			deck.add_entry(unit)


func _test_recruit_arena_transition() -> void:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	_seed_test_deck(deck)
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	economy.grant(20)
	var level := load(LEVEL_PATH) as LevelData
	var recruit_config := load(RECRUIT_PATH) as RecruitConfig
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 7777
	battle.half_exit_seconds = 0.0
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, level)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)

	var arena := battle.get_arena()
	_expect(arena != null, "arena exists")
	_expect(not arena.recruit_active, "recruit inactive at prepare")
	await process_frame
	var prepare_arena_h := arena.size.y
	var prepare_dock := battle.get_node_or_null("Layout/Dock") as Control
	_expect(prepare_dock != null and prepare_dock.visible, "dock visible in prepare")

	## 持久占位自动入座后开战清敌 → RESULT
	var slots := battle.get_slot_board()
	_expect(slots.occupied_count() >= 1, "prepare loads persistent seats")
	_expect(battle.try_start_combat(), "start combat")
	var sim := battle.get_sim()
	_expect(sim != null, "sim started")
	for rt in sim.get_units():
		if not rt.is_player():
			rt.unit.current_hp = 0
	sim.advance_fixed_step()
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RESULT, "RESULT after wipe")

	var completed: Array = []
	battle.encounter_completed.connect(func(won: bool) -> void: completed.append(won))
	battle.continue_after_result()
	_expect(completed == [true], "encounter_completed(true)")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "IDLE after continue")
	## half_exit=0 胜场：半场应已置于屏外，供招募滑入衔接
	_expect(absf(arena.enemy_half_slide_y) > 1.0, "enemy half parked offscreen after win continue")
	_expect(absf(arena.ally_half_slide_y) > 1.0, "ally half parked offscreen after win continue")

	var session := RecruitSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	session.configure(recruit_config, deck, economy, rng)
	session.begin(0.2)
	_expect(session.get_candidates().size() == RecruitSession.CANDIDATE_COUNT, "3 candidates rolled")

	await battle.enter_recruit(session, 0.0)
	await process_frame
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RECRUIT, "phase RECRUIT")
	_expect(arena.recruit_active, "arena recruit_active")
	_expect(is_equal_approx(arena.enemy_half_slide_y, 0.0), "enemy half slid in to 0")
	_expect(is_equal_approx(arena.ally_half_slide_y, 0.0), "ally half slid in to 0")
	_expect(arena.recruit_team_slots != null, "team slots set")
	_expect(arena.recruit_team_slots.occupied_count() == deck.size(), "team units on upper half")
	_expect(arena.recruit_candidates.size() == RecruitSession.CANDIDATE_COUNT, "3 candidate cells")
	var alive_cands := 0
	for info in arena.recruit_candidates:
		if info is Dictionary and info.get("unit") != null:
			alive_cands += 1
	_expect(alive_cands == RecruitSession.CANDIDATE_COUNT, "3 candidate unit bodies")
	## 招募时 Dock 保持占位，Arena 高度不膨胀。
	var recruit_dock := battle.get_node_or_null("Layout/Dock") as Control
	_expect(recruit_dock != null and recruit_dock.visible, "dock stays visible in recruit")
	_expect(recruit_dock.find_child("RecruitHud", true, false) != null, "RecruitHud parented under Dock")
	if prepare_arena_h > 1.0:
		_expect(
			absf(arena.size.y - prepare_arena_h) <= 2.0,
			"arena height matches prepare (no dock collapse)"
		)
	## 候选人行相对我半场垂直居中（与 PrepareSlotBoard._centered_row_ys 一致）。
	var expected_ys := PrepareSlotBoard._centered_row_ys(battle.get_board_size().y, 1, 1, 1, false)
	var cand0: Dictionary = arena.recruit_candidates[0] if arena.recruit_candidates.size() > 0 else {}
	var cand_cell: Vector2i = cand0.get("cell", Vector2i(-1, -1))
	_expect(
		not expected_ys.is_empty() and cand_cell.y == expected_ys[0],
		"candidate row vertically centered in ally half"
	)

	## 规则：刷新 / 重置仍可用
	var gold_before := economy.gold
	_expect(session.can_refresh(), "can refresh")
	_expect(session.try_refresh(), "refresh ok")
	_expect(economy.gold < gold_before, "refresh spent gold")
	session.reset()
	_expect(economy.gold == gold_before, "reset restored gold")

	## 完成退出
	var finished: Array = []
	battle.recruit_finished.connect(func(kept: bool) -> void: finished.append(kept))
	session.finish()
	battle.exit_recruit()
	## exit_recruit 不自动 emit；按钮路径会 emit。此处直接测 exit 清理。
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "IDLE after exit_recruit")
	_expect(not arena.recruit_active, "recruit cleared")
	_expect(is_equal_approx(arena.enemy_half_slide_y, 0.0), "slide reset after exit")

	## 再进一轮：finish 按钮路径
	session.begin(0.5)
	await battle.enter_recruit(session, 0.0)
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RECRUIT, "re-enter RECRUIT")
	## 模拟完成按钮：走 controller 内部 finish
	battle._on_recruit_finish_pressed()
	_expect(finished == [true], "recruit_finished(true) from finish button")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "IDLE after finish button")

	battle.queue_free()
	await process_frame
