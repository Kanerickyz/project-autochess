extends SceneTree

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const HURT := preload("res://resources/abilities/hurt_gain_atk_small.tres")
const CRIT := preload("res://resources/abilities/crit_extra_damage_mid.tres")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_enchant_fuse_flow()
	await _test_enchant_sandbox_skip_no_map_signal()
	await _test_enchant_team_seat_swap()
	await _test_enchant_scroll_vs_drag_gesture()
	if _failures == 0:
		print("EnchantFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		push_error("EnchantFlowTest: FAIL %s" % label)


func _test_enchant_fuse_flow() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 10
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	var u1 := UnitData.new()
	u1.id = "mat_a"
	u1.display_name = "原料A"
	u1.stats = UnitStats.new()
	u1.stats.attack = 4
	u1.stats.max_hp = 6
	u1.ability = HURT
	var u2 := UnitData.new()
	u2.id = "mat_b"
	u2.display_name = "原料B"
	u2.stats = UnitStats.new()
	u2.stats.attack = 8
	u2.stats.max_hp = 4
	u2.ability = CRIT
	var e1 := deck.add_entry(u1)
	var e2 := deck.add_entry(u2)
	_expect(e1 != null and e2 != null, "materials added")

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)

	var finished: Array = []
	battle.enchant_finished.connect(func(did: bool) -> void: finished.append(did))

	await battle.enter_enchant(0.0)
	_expect(battle.get_phase() == RealtimeBattleController.Phase.ENCHANT, "phase ENCHANT")

	var session := battle.get_enchant_session()
	_expect(session != null, "session exists")
	session.set_slot(&"a", e1.entry_id)
	session.set_slot(&"b", e2.entry_id)
	session.set_test_unit_roll(0.0)
	var fuse := session.try_fuse()
	_expect(fuse.get("ok", false), "fuse ok")
	_expect(deck.size() == 1, "one member")
	_expect(deck.get_entries()[0].is_fused_enchant(), "fused product")

	session.finish_after_fuse()
	await _process_n_frames(2)
	_expect(finished == [true], "enchant_finished true")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "back idle")

	battle.queue_free()
	await process_frame


func _process_n_frames(n: int) -> void:
	for _i in n:
		await process_frame


func _test_enchant_sandbox_skip_no_map_signal() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 4
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	var u := UnitData.new()
	u.id = "solo"
	u.stats = UnitStats.new()
	u.ability = HURT
	deck.add_entry(u)

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)

	var finished: Array = []
	battle.enchant_finished.connect(func(did: bool) -> void: finished.append(did))

	await battle.enter_enchant(0.0, true)
	_expect(battle.is_enchant_sandbox_mode(), "sandbox flag")
	var session := battle.get_enchant_session()
	session.skip()
	await _process_n_frames(2)
	_expect(finished.is_empty(), "sandbox skip does not emit enchant_finished")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "idle after skip")

	battle.queue_free()
	await process_frame


func _test_enchant_team_seat_swap() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 5
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	for i in 3:
		var u := UnitData.new()
		u.id = "swap_%d" % i
		u.stats = UnitStats.new()
		u.stats.attack = 2 + i
		u.stats.max_hp = 4
		u.ability = HURT
		var e := deck.add_entry(u)
		deck.assign_seat(e.entry_id, i)
	_expect(deck.size() == 3, "three members")

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)
	await battle.enter_enchant(0.0)

	var mover := deck.get_entries()[0]
	var before := mover.seat_index
	battle.get_arena().enchant_team_seat_drop.emit(mover.entry_id, 2)
	await _process_n_frames(1)
	_expect(mover.seat_index == 2, "seat swapped via enchant drop")
	_expect(mover.seat_index != before, "seat changed")

	battle.queue_free()
	await process_frame


func _test_enchant_scroll_vs_drag_gesture() -> void:
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	arena.board_size = Vector2i(5, 8)
	root.add_child(arena)
	await process_frame
	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 24
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	for i in 12:
		var u := UnitData.new()
		u.id = "mem_%d" % i
		u.stats = UnitStats.new()
		u.ability = HURT
		deck.add_entry(u)
	var slots := PrepareSlotBoard.new()
	var cells := EnchantLayout.build_expanded_team_cells(arena.board_size, deck.size())
	slots.configure_custom_cells(cells)
	var idx := 0
	for entry in deck.get_entries():
		if entry != null and idx < slots.slot_count:
			slots.try_assign(idx, entry)
			idx += 1
	arena.enchant_active = true
	arena.enchant_team_scroll_enabled = true
	arena.enchant_team_max_scroll_rows = EnchantLayout.expanded_team_max_scroll_rows(
		arena.board_size,
		deck.size(),
	)
	arena.prepare_slots = slots
	arena.queue_redraw()
	await process_frame

	var seat0 := slots.get_cell(0)
	var center := arena.tile_to_local(Vector2(seat0) + Vector2(0.5, 0.5))
	_press_arena(arena, center, true)
	_expect(not arena._enchant_team_pan_active, "press on member does not start pan")
	_expect(arena._enchant_team_press_id >= 0, "member press tracked")

	var move_h := InputEventMouseMotion.new()
	move_h.position = center + Vector2(24, 2)
	move_h.relative = Vector2(24, 2)
	arena._gui_input(move_h)
	_expect(arena._enchant_team_drag_id >= 0, "horizontal slop starts team drag")
	_expect(not arena._enchant_team_pan_active, "horizontal move does not pan")
	_press_arena(arena, move_h.position, false)

	## 竖直上移（入炉方向）也必须开拖，不能被滚列表抢走。
	arena.enchant_team_scroll_rows = 0.0
	arena._enchant_team_drag_id = -1
	arena._enchant_team_press_id = -1
	_press_arena(arena, center, true)
	var move_v := InputEventMouseMotion.new()
	move_v.position = center + Vector2(2, -28)
	move_v.relative = Vector2(2, -28)
	arena._gui_input(move_v)
	_expect(arena._enchant_team_drag_id >= 0, "vertical up on member starts drag toward forge")
	_expect(not arena._enchant_team_pan_active, "vertical up on member does not pan")
	_press_arena(arena, move_v.position, false)

	## 队伍半场空白格按下才跟手滚（非队员）。
	arena._enchant_team_drag_id = -1
	arena._enchant_team_press_id = -1
	arena._enchant_team_pan_active = false
	var empty_center := Vector2.ZERO
	var found_empty := false
	var mid := BoardHalf.midline_row(arena.board_size.y)
	for y in range(mid, arena.board_size.y):
		for x in range(arena.board_size.x):
			var cell := Vector2i(x, y)
			if arena._find_enchant_team_entry_at(cell) >= 0:
				continue
			empty_center = arena.tile_to_local(Vector2(cell) + Vector2(0.5, 0.5))
			found_empty = true
			break
		if found_empty:
			break
	_expect(found_empty, "team half has empty cell for pan")
	if found_empty:
		_press_arena(arena, empty_center, true)
		_expect(arena._enchant_team_pan_active, "press empty team cell starts scroll pan")
		_expect(arena._enchant_team_press_id < 0, "empty cell press is not member press")
		_press_arena(arena, empty_center, false)

	arena.queue_free()
	await process_frame


func _press_arena(arena: RealtimeArenaView, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	arena._gui_input(ev)
