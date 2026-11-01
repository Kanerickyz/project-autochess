class_name VictoryBoostFocusUxTest
extends RefCounted
## 胜后强化 UX 烟测：暗场居中阵列、无确认钮、短按落盘发完成信号。

const ARCHER := preload("res://resources/units/realtime/archer.tres")
const KNIGHT := preload("res://resources/units/realtime/knight.tres")
const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"


static func run_all(tree: SceneTree) -> bool:
	var passed := true
	passed = await _test_controller_short_press_flow(tree) and passed
	if passed:
		print("VictoryBoostFocusUxTest: all passed")
	else:
		push_error("VictoryBoostFocusUxTest: failures detected")
	return passed


static func _make_deck() -> DeckState:
	var deck := DeckState.new()
	var deck_config := DeckConfig.new()
	deck_config.max_size = 8
	deck_config.seat_rows = 4
	deck_config.seat_cols = 5
	deck_config.max_board_units = 5
	deck.configure(deck_config)
	var a := deck.add_entry(ARCHER as UnitData)
	var b := deck.add_entry(KNIGHT as UnitData)
	if a != null:
		deck.assign_seat(a.entry_id, 0)
	if b != null:
		deck.try_place_on_bench(b.entry_id, 0)
	return deck


static func _test_controller_short_press_flow(tree: SceneTree) -> bool:
	var deck := _make_deck()
	if deck.get_seated_count() < 1 or deck.get_bench_count() < 1:
		push_error("victory_boost_ux: need seated+bench roster")
		return false
	var economy := RunEconomy.new()
	economy.configure(EconomyConfig.new())
	economy.reset()
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	if battle == null:
		push_error("victory_boost_ux: battle scene missing")
		return false
	battle.rng_seed = 7
	battle.half_exit_seconds = 0.0
	battle.recruit_enter_seconds = 0.0
	battle.victory_boost_confirm_hold_seconds = 0.0
	tree.root.add_child(battle)
	await tree.process_frame
	## 无 level 也可进强化：只绑 deck。
	battle.setup(deck, economy, null)
	await tree.process_frame

	var session := VictoryBoostSession.new()
	session.configure(deck, 1, 15, false)
	session.begin()
	var finished_applied := {"v": null}
	battle.victory_boost_finished.connect(func(applied: bool) -> void:
		finished_applied["v"] = applied
	)
	await battle.enter_victory_boost(session, 0.0)
	await tree.process_frame

	if battle.get_phase() != RealtimeBattleController.Phase.VICTORY_BOOST:
		push_error("victory_boost_ux: phase not VICTORY_BOOST")
		battle.queue_free()
		return false
	var arena: RealtimeArenaView = battle.find_child("ArenaView", true, false) as RealtimeArenaView
	if arena == null:
		push_error("victory_boost_ux: ArenaView not found")
		battle.queue_free()
		return false
	if not arena.victory_boost_active:
		push_error("victory_boost_ux: arena not in boost mode")
		battle.queue_free()
		return false
	if arena.victory_boost_focus_roster.size() < 2:
		push_error("victory_boost_ux: focus roster missing seated+bench")
		battle.queue_free()
		return false
	if arena.victory_boost_dim_alpha < 0.99 or arena.victory_boost_focus_t < 0.99:
		push_error("victory_boost_ux: enter(0) should snap dim/focus")
		battle.queue_free()
		return false
	var has_bench_label := false
	for item in arena.victory_boost_focus_roster:
		if item is Dictionary and bool((item as Dictionary).get("is_bench", false)):
			has_bench_label = true
			break
	if not has_bench_label:
		push_error("victory_boost_ux: bench member missing is_bench flag")
		battle.queue_free()
		return false
	## 无「确认强化」按钮。
	var confirm := battle.find_child("确认强化", true, false)
	if confirm != null and (confirm as CanvasItem).visible:
		push_error("victory_boost_ux: confirm button still visible")
		battle.queue_free()
		return false
	var skip_found := false
	for n in battle.find_children("*", "Button", true, false):
		var btn := n as Button
		if btn != null and btn.visible and String(btn.text).contains("跳过强化"):
			skip_found = true
			break
	if not skip_found:
		push_error("victory_boost_ux: skip button missing")
		battle.queue_free()
		return false

	var seated := deck.get_entries()[0] as DeckEntry
	var atk0 := seated.bonus_attack
	battle._on_victory_boost_unit_pressed(seated.entry_id)
	## 短按路径含 await；给几帧消化。
	for _i in 8:
		await tree.process_frame
	if seated.bonus_attack != atk0 + 1:
		push_error("victory_boost_ux: short press did not write bonus")
		battle.queue_free()
		return false
	if finished_applied["v"] != true:
		push_error("victory_boost_ux: finished(true) not emitted")
		battle.queue_free()
		return false

	battle.queue_free()
	await tree.process_frame
	return true
