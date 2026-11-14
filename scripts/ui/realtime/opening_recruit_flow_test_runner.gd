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
	config.seat_rows = 4
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
	var recruit_cfg := (load(RECRUIT_PATH) as RecruitConfig).duplicate(true) as RecruitConfig
	recruit_cfg.phase_seconds = 0.0
	session.configure(recruit_cfg, deck, economy, rng)
	session.require_nonempty_roster = true
	session.begin(0.0)

	await battle.enter_recruit(session, 0.0)
	await process_frame

	var arena := battle.get_arena()
	_expect(is_equal_approx(arena.ally_half_slide_y, 0.0), "opening recruit: ally half slide reset")
	_expect(is_equal_approx(arena.enemy_half_slide_y, 0.0), "opening recruit: enemy half slide reset")
	var dock := battle.get_node_or_null("Layout/Dock") as Control
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RECRUIT, "phase RECRUIT")
	_expect(dock != null and dock.visible, "dock visible during opening recruit")
	## 招募底栏按 RecruitHud 自然高度收缩，不再锁准备手牌等效高。
	_expect(is_equal_approx(dock.custom_minimum_size.y, 0.0), "dock min height not locked to prepare hand")
	var hud := dock.find_child("RecruitHud", true, false)
	_expect(hud != null and (hud as CanvasItem).visible, "RecruitHud in Dock visible")
	_expect(dock.find_child("RecruitGoldRow", true, false) == null, "RecruitHud omits duplicate gold row")

	## 招募三段栈：team 4×5 → gap → bench → gap → cand → action（招募区内紧凑，可虚拟行）。
	var seat_rows := 4
	var expected_team_max_y := seat_rows - 1
	var expected_bench_y := seat_rows + 1
	var expected_cand_y := seat_rows + 3
	var expected_action_y := seat_rows + 4
	_expect(not arena.recruit_candidates.is_empty(), "candidates present")
	_expect(arena.recruit_candidates.size() == RecruitSession.CANDIDATE_COUNT, "candidate row has 5 slots")
	if arena.recruit_team_slots != null:
		_expect(arena.recruit_team_slots.seat_rows == 4, "recruit team 4 rows")
		_expect(arena.recruit_team_slots.seat_cols == 5, "recruit team 5 cols")
		_expect(arena.recruit_team_slots.slot_count == 20, "recruit team 20 seats")
		_expect(arena.recruit_team_slots.get_cell(0) == Vector2i(0, 0), "recruit team front-left at y0")
		_expect(arena.recruit_team_slots.get_cell(15) == Vector2i(0, 3), "recruit team back-left at y3")
		_expect(expected_team_max_y == 3, "team max y == 3")
	if not arena.recruit_candidates.is_empty():
		var cell: Vector2i = arena.recruit_candidates[0].get("cell", Vector2i(-1, -1))
		_expect(cell.y == expected_cand_y, "candidate y == seat_rows+3")
		## 一行五格：x 互不重叠（5 宽棋盘 gap=0 → x=0..4）。
		var xs: Dictionary = {}
		var same_y := true
		for info in arena.recruit_candidates:
			var c: Vector2i = info.get("cell", Vector2i(-1, -1))
			xs[c.x] = true
			if c.y != expected_cand_y:
				same_y = false
		_expect(same_y, "all candidates share one row")
		_expect(xs.size() == arena.recruit_candidates.size(), "candidate cells unique x in one row")

	_expect(not arena.recruit_items.is_empty(), "item row present")
	if not arena.recruit_items.is_empty():
		var item0: Vector2i = arena.recruit_items[0].get("cell", Vector2i(-1, -1))
		_expect(item0.y == expected_action_y, "item row y == cand+1")
		_expect(item0.y - expected_cand_y == 1, "candidate/item row delta == 1")
		for info in arena.recruit_items:
			var ic: Vector2i = info.get("cell", Vector2i(-1, -1))
			_expect(ic.y == expected_action_y, "all items share action row")
	_expect(arena.recruit_sell_cell.y == expected_action_y, "sell same row as items")
	if arena.bench_slots != null and arena.bench_slots.slot_count > 0:
		_expect(arena.bench_slots.get_cell(0).y == expected_bench_y, "bench between team and candidates")
	_expect(arena.recruit_lock_cell.y == expected_action_y, "lock same row as items")
	_expect(arena.recruit_sell_cell != arena.recruit_lock_cell, "sell/lock not overlapping")
	_expect(arena.recruit_sell_cell.y == expected_cand_y + 1, "sell on action row")

	## 道具 / 锁定 / 卖出均可长按 inspect（同 is_item 信息卡路径）。
	if not arena.recruit_items.is_empty():
		var offer0: Dictionary = arena.recruit_items[0]
		var offer_cell: Vector2i = offer0.get("cell", Vector2i(-1, -1))
		if offer0.get("item") != null and offer_cell.x >= 0:
			var offer_center := (
				arena.tile_to_local(Vector2(offer_cell) + Vector2(0.5, 0.5))
				+ Vector2(0.0, arena.ally_half_slide_y)
			)
			var offer_info := arena.inspect_at(offer_center)
			_expect(
				not offer_info.is_empty() and bool(offer_info.get("is_item", false)),
				"recruit item inspectable as item",
			)
	if arena.recruit_lock_cell.x >= 0:
		var lock_center := (
			arena.tile_to_local(Vector2(arena.recruit_lock_cell) + Vector2(0.5, 0.5))
			+ Vector2(0.0, arena.ally_half_slide_y)
		)
		var lock_info := arena.inspect_at(lock_center)
		_expect(
			not lock_info.is_empty()
			and bool(lock_info.get("is_item", false))
			and String(lock_info.get("inspect_key", "")) == "recruit_lock",
			"recruit lock inspectable",
		)
	if arena.recruit_sell_cell.x >= 0:
		var sell_center := (
			arena.tile_to_local(Vector2(arena.recruit_sell_cell) + Vector2(0.5, 0.5))
			+ Vector2(0.0, arena.ally_half_slide_y)
		)
		var sell_info := arena.inspect_at(sell_center)
		_expect(
			not sell_info.is_empty()
			and bool(sell_info.get("is_item", false))
			and String(sell_info.get("inspect_key", "")) == "recruit_sell",
			"recruit sell inspectable",
		)

	## 上区队伍块：占满前 seat_rows 行；行序与我半场一致（前排在上）。
	_expect(arena.recruit_team_slots != null, "team slots board exists")
	var team_max_y := -1
	if arena.recruit_team_slots != null and arena.recruit_team_slots.slot_count >= 1:
		var team_front := arena.recruit_team_slots.get_cell(0)
		var team_back := arena.recruit_team_slots.get_cell(5)
		_expect(team_front.y == 0, "team front on first row")
		_expect(team_front.y < team_back.y, "recruit front row above back (ally row order)")
		for si in arena.recruit_team_slots.slot_count:
			team_max_y = maxi(team_max_y, arena.recruit_team_slots.get_cell(si).y)
		_expect(team_max_y == expected_team_max_y, "team_max_y == seat_rows-1")

	## 招募备战：bench.y == team_max+2；两侧空档；中心介于队伍与候选之间。
	_expect(arena.bench_visible and arena.bench_slots != null, "recruit bench visible")
	if arena.bench_slots != null and arena.bench_slots.slot_count > 0:
		var bench_y := arena.bench_slots.get_cell(0).y
		_expect(bench_y == expected_bench_y, "recruit bench y == seat_rows+1")
		_expect(team_max_y + 1 == expected_bench_y - 1, "gap1 between team and bench")
		_expect(bench_y == team_max_y + 2, "bench.y == team_max_y + 2")
		_expect(expected_cand_y == bench_y + 2, "cand.y == bench.y + 2")
		_expect(expected_action_y == expected_cand_y + 1, "action.y == cand.y + 1")
		_expect(bench_y != expected_cand_y, "bench.y != candidate.y")
		var bench_center := arena.bench_slot_center_local(0)
		var hit_i := arena.find_bench_slot_at_local(bench_center)
		_expect(hit_i == 0, "recruit bench hit-test maps center to slot 0")
		if team_max_y >= 0 and not arena.recruit_candidates.is_empty():
			var cand_cell0: Vector2i = arena.recruit_candidates[0].get("cell", Vector2i.ZERO)
			var team_bottom := arena.tile_to_local(Vector2(2.5, float(team_max_y) + 0.5))
			var cand_center := arena.tile_to_local(Vector2(cand_cell0) + Vector2(0.5, 0.5))
			_expect(
				bench_center.y > team_bottom.y and bench_center.y < cand_center.y,
				"recruit bench center y between team and candidates"
			)
			## 候选人中心不得被备战命中抢占（点买通路）。
			_expect(
				arena.find_bench_slot_at_local(cand_center) < 0,
				"candidate center does not hit bench slot"
			)

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
	var recruit_cfg2 := (load(RECRUIT_PATH) as RecruitConfig).duplicate(true) as RecruitConfig
	recruit_cfg2.phase_seconds = 0.0
	session.configure(recruit_cfg2, deck, economy, rng)
	session.require_nonempty_roster = false
	session.begin(0.2)
	await battle.enter_recruit(session, 0.0)
	await process_frame

	var dock := battle.get_node_or_null("Layout/Dock") as Control
	_expect(dock != null and dock.visible, "dock visible in post-win-style recruit")
	_expect(
		is_equal_approx(dock.custom_minimum_size.y, 0.0),
		"dock min height not locked to prepare hand"
	)
	## Dock 收缩后 Arena 应收得更多垂直空间（不再强锁与准备同高）。
	_expect(arena.size.y + 1.0 >= prepare_h, "arena height >= prepare after recruit dock shrink")

	battle.queue_free()
	await process_frame
