extends SceneTree
## Headless：开局空队招募门槛、候选人半场垂直居中、招募期 Dock 占位（Arena 不膨胀）。
## half_exit / enter 均 0。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const RECRUIT_PATH := "res://resources/recruit/default_recruit_config.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
const KNIGHT := "res://resources/units/realtime/knight.tres"
const ARCHER := "res://resources/units/realtime/archer.tres"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_empty_starter_deck_and_session_gate()
	await _test_opening_enter_recruit_ui()
	await _test_arena_height_prepare_vs_recruit()
	if _failures == 0:
		print("OpeningRecruitFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("OpeningRecruitFlowTest: FAIL %s" % label)


func _make_empty_deck_config() -> DeckConfig:
	var config := DeckConfig.new()
	config.starting_units = []
	config.starting_unit = null
	config.starting_count = 0
	config.max_size = 20
	config.seat_rows = 2
	config.seat_cols = 5
	return config


func _test_empty_starter_deck_and_session_gate() -> void:
	var deck := DeckState.new()
	deck.configure(_make_empty_deck_config())
	deck.reset_from_config()
	_expect(deck.size() == 0, "empty starter: deck.size()==0")

	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	_expect(economy.gold == 6, "economy starting_gold from config is 6")

	var session := RecruitSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	session.configure(load(RECRUIT_PATH) as RecruitConfig, deck, economy, rng)
	session.require_nonempty_roster = true
	session.begin(0.0)
	_expect(not session.can_skip(), "opening: can_skip false")
	_expect(not session.can_finish(), "opening: can_finish false while empty")
	_expect(session.get_candidates().size() == RecruitSession.CANDIDATE_COUNT, "opening: 3 candidates")


func _test_opening_enter_recruit_ui() -> void:
	var deck := DeckState.new()
	deck.configure(_make_empty_deck_config())
	deck.reset_from_config()
	_expect(deck.size() == 0, "ui: start with empty deck")

	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	economy.grant(20)

	var level := load(LEVEL_PATH) as LevelData
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 2026
	battle.half_exit_seconds = 0.0
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, level)

	var session := RecruitSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	session.configure(load(RECRUIT_PATH) as RecruitConfig, deck, economy, rng)
	session.require_nonempty_roster = true
	session.begin(0.0)

	await battle.enter_recruit(session, 0.0)
	await process_frame

	var arena := battle.get_arena()
	var dock := battle.get_node_or_null("Layout/Dock") as Control
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RECRUIT, "phase RECRUIT")
	_expect(dock != null and dock.visible, "dock visible during opening recruit")
	_expect(dock.custom_minimum_size.y >= 190.0, "dock min height == prepare-equivalent")
	var hud := dock.find_child("RecruitHud", true, false)
	_expect(hud != null and (hud as CanvasItem).visible, "RecruitHud in Dock visible")

	var expected_ys := PrepareSlotBoard._centered_row_ys(battle.get_board_size().y, 1, 1, 1, false)
	_expect(not arena.recruit_candidates.is_empty(), "candidates present")
	if not arena.recruit_candidates.is_empty():
		var cell: Vector2i = arena.recruit_candidates[0].get("cell", Vector2i(-1, -1))
		_expect(cell.y == expected_ys[0], "candidate y == ally-half vertical center")

	## 上半场队伍块：敌半场 2×5 垂直居中（空队仍配置几何）。
	_expect(arena.recruit_team_slots != null, "team slots board exists")
	if arena.recruit_team_slots != null and arena.recruit_team_slots.slot_count >= 1:
		var team_front := arena.recruit_team_slots.get_cell(0)
		var mid := BoardHalf.midline_row(battle.get_board_size().y)
		_expect(team_front.y < mid, "team block on enemy half")
		var team_ys := PrepareSlotBoard._centered_row_ys(
			battle.get_board_size().y, 2, 2, 3, true
		)
		_expect(team_front.y == team_ys[0], "team front row enemy-half vertical center")

	var finished: Array = []
	battle.recruit_finished.connect(func(kept: bool) -> void: finished.append(kept))
	battle._on_recruit_finish_pressed()
	_expect(finished.is_empty(), "finish blocked while empty")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RECRUIT, "still RECRUIT")

	var buy := session.try_recruit(0)
	_expect(buy.get("ok", false), "recruit one unit ok")
	_expect(deck.size() >= 1, "deck size >=1 after recruit")
	battle._on_recruit_finish_pressed()
	_expect(finished == [true], "finish ok after roster>=1")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "IDLE after finish")

	battle.queue_free()
	await process_frame


func _test_arena_height_prepare_vs_recruit() -> void:
	var deck := DeckState.new()
	deck.configure(_make_empty_deck_config())
	deck.add_entry(load(KNIGHT) as UnitData)
	deck.add_entry(load(ARCHER) as UnitData)

	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	economy.grant(20)

	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 88
	battle.half_exit_seconds = 0.0
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, load(LEVEL_PATH) as LevelData)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	await process_frame

	var arena := battle.get_arena()
	var prepare_h := arena.size.y
	_expect(prepare_h > 1.0, "prepare arena has height")

	var session := RecruitSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	session.configure(load(RECRUIT_PATH) as RecruitConfig, deck, economy, rng)
	session.require_nonempty_roster = false
	session.begin(0.2)
	await battle.enter_recruit(session, 0.0)
	await process_frame

	var dock := battle.get_node_or_null("Layout/Dock") as Control
	_expect(dock != null and dock.visible, "dock visible in post-win-style recruit")
	_expect(absf(arena.size.y - prepare_h) <= 2.0, "arena height matches prepare")

	battle.queue_free()
	await process_frame
