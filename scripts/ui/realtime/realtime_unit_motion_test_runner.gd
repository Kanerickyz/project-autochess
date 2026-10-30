extends SceneTree
## Run 战场表现：程序动画（蓄力 / 冲撞 / 闪白 / 震屏 / 死亡残影）与长按信息卡。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
const UNIT_PATHS := [
	"res://resources/units/realtime/knight.tres",
	"res://resources/units/realtime/barbarian.tres",
	"res://resources/units/realtime/archer.tres",
	"res://resources/units/realtime/mini_pekka.tres",
]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_sample_idle()
	_test_shake_scales_with_damage()
	await _test_windup_cancel_soft_home()
	await _test_strike_action_tween_lifecycle()
	await _test_long_press_info()
	await _test_prepare_seat_drag_swap()
	await _test_prepare_bench_drag_deploy()
	await _test_prepare_bench_tap_auto_deploy()
	await _test_long_press_slide_inspect()
	await _test_recruit_input()
	await _test_recruit_card_dissolve()
	await _test_recruit_team_sell_drag()
	await _test_recruit_team_bench_drag()
	await _test_recruit_lock_drag()
	await _test_recruit_candidate_rejects_occupied_seat()
	await _test_hand_card_long_press()
	await _test_combat_motion()
	if _failures == 0:
		print("RealtimeUnitMotionTest: all passed")
	quit(0 if _failures == 0 else 1)


func _test_shake_scales_with_damage() -> void:
	var low := RealtimeUnitMotion.shake_px_for_damage(1)
	var mid := RealtimeUnitMotion.shake_px_for_damage(4)
	var high := RealtimeUnitMotion.shake_px_for_damage(20)
	var zero := RealtimeUnitMotion.shake_px_for_damage(0)
	_expect(low >= RealtimeUnitMotion.SHAKE_MIN_PX - 0.001, "shake floor for 1 dmg")
	_expect(mid > low + 0.5, "higher damage shakes harder (1→4)")
	_expect(high > mid + 0.5, "higher damage shakes harder (4→20)")
	_expect(high <= RealtimeUnitMotion.SHAKE_MAX_PX + 0.001, "shake capped at max")
	_expect(zero >= RealtimeUnitMotion.SHAKE_MIN_PX - 0.001, "zero damage still readable floor")
	var motion := RealtimeUnitMotion.new()
	root.add_child(motion)
	motion._shake(mid)
	_expect(is_equal_approx(motion.shake_strength, mid), "impulse sets shake_strength")
	motion._shake(low)
	_expect(is_equal_approx(motion.shake_strength, mid), "weaker impulse does not reduce active shake")
	motion.queue_free()


func _test_sample_idle() -> void:
	var a: Dictionary = RealtimeUnitMotion.sample_idle(0.0, 0)
	var b: Dictionary = RealtimeUnitMotion.sample_idle(RealtimeUnitMotion.IDLE_CYCLE * 0.5, 0)
	var c: Dictionary = RealtimeUnitMotion.sample_idle(0.0, 3)
	var off_a: Vector2 = a.get("offset", Vector2.ZERO)
	var off_b: Vector2 = b.get("offset", Vector2.ZERO)
	var off_c: Vector2 = c.get("offset", Vector2.ZERO)
	_expect(off_a.y <= 0.001, "idle at t0 starts near rest")
	_expect(off_b.y < -0.02, "idle mid-cycle bob peaks up")
	_expect(not off_a.is_equal_approx(off_c), "different seeds phase-shift idle")
	var scl_b: Vector2 = b.get("scale", Vector2.ONE)
	_expect(scl_b.y < 1.0 and scl_b.x > 1.0, "idle mid-cycle soft squash")
	_test_sample_inspect_focus()
	_test_sample_walk_pose()


func _test_sample_walk_pose() -> void:
	var motion := RealtimeUnitMotion.new()
	root.add_child(motion)
	var unit := UnitInstance.new()
	unit.unit_data = load(UNIT_PATHS[0]) as UnitData
	var rt := RtUnit.new(unit, Vector2(2, 5))
	rt.begin_step(Vector2i(2, 5), Vector2i(3, 5))
	rt.step_t = 0.5
	rt.position = rt.step_from.lerp(rt.step_to, rt.step_t)
	var mid: Dictionary = motion.walk_pose(rt)
	_expect((mid.get("offset", Vector2.ZERO) as Vector2).y < -0.04, "walk mid-step lifts like Balatro hop")
	_expect(float(mid.get("shadow_mul", 1.0)) > 1.15, "walk mid-step deepens shadow")
	_expect(absf(float(mid.get("rotation", 0.0))) > 0.01, "walk mid-step tilts")
	rt.step_t = 1.0
	var done: Dictionary = motion.walk_pose(rt)
	_expect((done.get("offset", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.ZERO), "walk rest when not stepping")
	motion.queue_free()


func _test_sample_inspect_focus() -> void:
	var dim: Dictionary = RealtimeUnitMotion.sample_inspect_focus(0.0, 1.0, Vector2.ZERO, false)
	_expect(float(dim.get("alpha", 1.0)) < 0.8, "non-focus units dim while inspecting")
	var kick: Dictionary = RealtimeUnitMotion.sample_inspect_focus(0.0, 1.0, Vector2.ZERO, true)
	_expect(float(kick.get("rotation", 0.0)) > 0.05, "focus kick tilts with slide dir")
	_expect((kick.get("scale", Vector2.ONE) as Vector2).x > 1.02, "focus kick scales up")
	var settled: Dictionary = RealtimeUnitMotion.sample_inspect_focus(0.35, 1.0, Vector2.ZERO, true)
	_expect((settled.get("offset", Vector2.ZERO) as Vector2).y < -0.05, "focus settles lifted")
	_expect(absf(float(settled.get("rotation", 1.0))) < absf(float(kick.get("rotation", 0.0))), "kick tilt decays")
	_test_sample_drag_hold()


func _test_sample_drag_hold() -> void:
	var early: Dictionary = RealtimeUnitMotion.sample_drag_hold(0.0, Vector2.ZERO)
	_expect((early.get("scale", Vector2.ONE) as Vector2).x <= 1.05, "drag pickup starts near rest scale")
	var held: Dictionary = RealtimeUnitMotion.sample_drag_hold(0.35, Vector2.ZERO)
	_expect((held.get("offset", Vector2.ZERO) as Vector2).y < -0.08, "drag hold stays lifted")
	_expect(float(held.get("shadow_mul", 1.0)) > 1.2, "drag hold deepens contact shadow")
	var moving: Dictionary = RealtimeUnitMotion.sample_drag_hold(0.35, Vector2(8.0, 0.0))
	_expect(float(moving.get("rotation", 0.0)) > 0.08, "horizontal drag velocity tilts like Balatro")
	_expect(
		absf(float(moving.get("rotation", 0.0))) > absf(float(held.get("rotation", 0.0))),
		"faster sideways motion tilts more",
	)


func _expect(ok: bool, label: String) -> void:
	if ok:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("RealtimeUnitMotionTest: FAIL %s" % label)


func _make_battle(seed: int) -> RealtimeBattleController:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	deck.reset_from_config()
	for path in UNIT_PATHS:
		deck.add_entry(load(path) as UnitData)
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = seed
	root.add_child(battle)
	battle.setup(deck, economy, load(LEVEL_PATH) as LevelData)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	## 准备主路径：持久占位自动入座，无需手牌抽选。
	return battle


func _arena(battle: RealtimeBattleController) -> RealtimeArenaView:
	return battle.find_child("ArenaView", true, false) as RealtimeArenaView


## 中心外扩落座后槽 0 常空；取前几个实际占用槽。
func _occupied_slot_indices(slots: PrepareSlotBoard, limit: int = 8) -> Array[int]:
	var out: Array[int] = []
	if slots == null:
		return out
	for i in slots.slot_count:
		if slots.get_entry(i) == null:
			continue
		out.append(i)
		if out.size() >= limit:
			break
	return out


func _slot_center(arena: RealtimeArenaView, slots: PrepareSlotBoard, slot_index: int) -> Vector2:
	return (
		arena.tile_to_local(Vector2(slots.get_cell(slot_index)) + Vector2(0.5, 0.5))
		+ Vector2(0.0, arena.ally_half_slide_y)
	)


func _press(arena: RealtimeArenaView, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	arena._gui_input(ev)


func _test_long_press_info() -> void:
	var battle := _make_battle(11)
	await process_frame
	var arena := _arena(battle)
	_expect(arena != null, "arena found")
	if arena == null:
		battle.queue_free()
		return
	var slots := battle.get_slot_board()
	var seated_before := slots.occupied_count()
	_expect(seated_before > 0, "units seated for prepare")
	var occupied := _occupied_slot_indices(slots, 2)
	_expect(not occupied.is_empty(), "need an occupied slot for inspect")
	if occupied.is_empty():
		battle.queue_free()
		return
	var seat0: int = occupied[0]
	var center := _slot_center(arena, slots, seat0)
	var info := arena.inspect_at(center)
	_expect(not info.is_empty(), "inspect seated unit")
	_expect(
		String(info.get("skills", "")) == UnitInfoText.get_skills_block_from_entry(slots.get_entry(seat0), true),
		"seated unit shows its own skill text",
	)
	## 点在头部（贴图上半）也能命中。
	_expect(not arena.inspect_at(center + Vector2(0.0, -arena.get_cell_px() * 0.9)).is_empty(), "head area is inspectable")

	_press(arena, center, true)
	## 长按阈值按真实时间计；SceneTree 计时器在 headless 下会跑快。
	var until := Time.get_ticks_msec() + RealtimeArenaView.LONG_PRESS_MS + 120
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(arena.is_info_card_visible(), "long press opens info card")
	_press(arena, center, false)
	_expect(not arena.is_info_card_visible(), "release hides info card")
	_expect(slots.occupied_count() == seated_before, "long press does not recall the unit")

	_press(arena, center, true)
	_press(arena, center, false)
	_expect(slots.occupied_count() == seated_before, "quick tap selects for swap, does not recall")
	_expect(battle._selected_entry_id == slots.get_entry(seat0).entry_id, "quick tap selects seated unit")
	## 准备换座写回 DeckState；刷新手牌不可用。
	var sel_id := battle._selected_entry_id
	var from_seat := slots.find_slot_by_entry(sel_id)
	var to_seat := -1
	for i in slots.slot_count:
		if i != from_seat and slots.is_empty(i):
			to_seat = i
			break
	if to_seat < 0:
		to_seat = 1 if from_seat != 1 else 2
	_expect(battle.try_swap_prepare_seats(from_seat, to_seat), "prepare swap seats ok")
	var deck_entry := battle.get_slot_board().get_entry(to_seat)
	_expect(deck_entry != null and deck_entry.entry_id == sel_id, "prepare swap moved unit on board")
	## 经 controller 私有 deck：占位应已写回（成员 seat_index==to_seat）
	_expect(deck_entry.seat_index == to_seat, "prepare swap writes seat_index back to DeckEntry")
	_expect(not battle.try_refresh_hand(), "prepare refresh hand disabled")

	var enemy_info: Dictionary = {}
	for preview in arena.enemy_previews:
		var pos := arena.tile_to_local(preview["position"]) + Vector2(0.0, arena.enemy_half_slide_y)
		enemy_info = arena.inspect_at(pos)
		if not enemy_info.is_empty():
			break
	_expect(not enemy_info.is_empty(), "enemy preview is inspectable")
	_expect(not bool(enemy_info.get("side_player", true)), "enemy preview reports enemy side")
	battle.queue_free()
	await process_frame


func _test_prepare_seat_drag_swap() -> void:
	## 准备阶段：拖已入座角色到空座，应换座并写回 DeckEntry.seat_index。
	var battle := _make_battle(17)
	await process_frame
	var arena := _arena(battle)
	_expect(arena != null, "arena for prepare drag swap")
	if arena == null:
		battle.queue_free()
		return
	var slots := battle.get_slot_board()
	var occupied := _occupied_slot_indices(slots, 1)
	_expect(not occupied.is_empty(), "need seated unit for prepare drag")
	if occupied.is_empty():
		battle.queue_free()
		return
	var from_seat: int = occupied[0]
	var mover := slots.get_entry(from_seat)
	_expect(mover != null, "mover entry present")
	var to_seat := -1
	for i in slots.slot_count:
		if i != from_seat and slots.is_empty(i):
			to_seat = i
			break
	_expect(to_seat >= 0, "need empty seat for prepare drag")
	if to_seat < 0 or mover == null:
		battle.queue_free()
		return
	var mover_id := mover.entry_id
	var from_center := _slot_center(arena, slots, from_seat)
	var to_center := _slot_center(arena, slots, to_seat)
	var seat_drops: Array = []
	arena.prepare_team_seat_drop.connect(func(id: int, seat: int) -> void: seat_drops.append([id, seat]))

	_press(arena, from_center, true)
	var move := InputEventMouseMotion.new()
	move.position = from_center + Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	move.relative = Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	arena._gui_input(move)
	_expect(arena._prepare_team_drag_id == mover_id, "prepare drag starts after slop")
	_hover_to(arena, to_center)
	_press(arena, to_center, false)
	_expect(seat_drops == [[mover_id, to_seat]], "prepare drag emits prepare_team_seat_drop")
	var moved := slots.get_entry(to_seat)
	_expect(moved != null and moved.entry_id == mover_id, "prepare drag moved unit on board")
	_expect(moved != null and moved.seat_index == to_seat, "prepare drag writes seat_index back")
	_expect(slots.get_entry(from_seat) == null, "source seat empty after prepare drag")
	_expect(battle._selected_entry_id < 0, "prepare drag clears selection")

	battle.queue_free()
	await process_frame


func _test_prepare_bench_drag_deploy() -> void:
	## 准备：拖备战纸片到空座位上阵；再拖回备战格下阵。
	var battle := _make_battle(19)
	await process_frame
	var arena := _arena(battle)
	_expect(arena != null and arena.bench_visible and arena.bench_interactive, "bench visible in prepare")
	if arena == null:
		battle.queue_free()
		await process_frame
		return
	var bench_board := battle.get_bench_slot_board()
	_expect(bench_board != null and bench_board.slot_count == DeckState.BENCH_CAPACITY, "bench board 5 slots")
	var slots := battle.get_slot_board()
	if bench_board.occupied_count() < 1 and slots.occupied_count() >= 2:
		var seed_id := slots.get_entry(_occupied_slot_indices(slots, 1)[0]).entry_id
		_expect(battle.try_move_seat_to_bench(seed_id), "seed: seat to bench for drag test")
		bench_board = battle.get_bench_slot_board()
	_expect(bench_board.occupied_count() >= 1, "need bench occupant for drag deploy")
	if bench_board.occupied_count() < 1:
		battle.queue_free()
		await process_frame
		return
	var bench_i := -1
	var mover: DeckEntry = null
	for i in bench_board.slot_count:
		var e := bench_board.get_entry(i)
		if e != null:
			bench_i = i
			mover = e
			break
	var empty_seat := -1
	for i in slots.slot_count:
		if slots.is_empty(i):
			empty_seat = i
			break
	_expect(empty_seat >= 0 and mover != null, "need empty seat + bench mover")
	if empty_seat < 0 or mover == null:
		battle.queue_free()
		await process_frame
		return
	var mover_id := mover.entry_id
	var from_center := arena.bench_slot_center_local(bench_i)
	var to_center := _slot_center(arena, slots, empty_seat)
	var seat_drops: Array = []
	arena.prepare_team_seat_drop.connect(func(id: int, seat: int) -> void: seat_drops.append([id, seat]))
	_press(arena, from_center, true)
	var move := InputEventMouseMotion.new()
	move.position = from_center + Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	move.relative = Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	arena._gui_input(move)
	_expect(arena._prepare_team_drag_id == mover_id, "bench drag starts after slop")
	_hover_to(arena, to_center)
	_press(arena, to_center, false)
	_expect(seat_drops == [[mover_id, empty_seat]], "bench drag emits prepare_team_seat_drop")
	_expect(slots.get_entry(empty_seat) != null and slots.get_entry(empty_seat).entry_id == mover_id, "bench deploy seated")
	## 再拖回备战空格。
	bench_board = battle.get_bench_slot_board()
	var empty_bench_i := -1
	for i in bench_board.slot_count:
		if bench_board.is_empty(i):
			empty_bench_i = i
			break
	_expect(empty_bench_i >= 0, "need empty bench slot after deploy")
	if empty_bench_i < 0:
		battle.queue_free()
		await process_frame
		return
	var bench_drops: Array = []
	arena.prepare_team_bench_drop.connect(
		func(id: int, _slot: int) -> void: bench_drops.append(id)
	)
	var seat_center := _slot_center(arena, slots, empty_seat)
	_press(arena, seat_center, true)
	var move2 := InputEventMouseMotion.new()
	move2.position = seat_center + Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	move2.relative = Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	arena._gui_input(move2)
	var bench_center := arena.bench_slot_center_local(empty_bench_i)
	_hover_to(arena, bench_center)
	_press(arena, bench_center, false)
	_expect(bench_drops == [mover_id], "seat drag to bench emits prepare_team_bench_drop")
	_expect(slots.find_slot_by_entry(mover_id) < 0, "seat cleared after bench drop")
	battle.queue_free()
	await process_frame


func _test_prepare_bench_tap_auto_deploy() -> void:
	## 准备：点备战有空席则自动上阵；已入座目标再点自动上阵失败。
	var battle := _make_battle(29)
	await process_frame
	var arena := _arena(battle)
	_expect(arena != null, "arena for bench tap deploy")
	if arena == null:
		battle.queue_free()
		await process_frame
		return
	var slots := battle.get_slot_board()
	var bench_board := battle.get_bench_slot_board()
	if bench_board.occupied_count() < 1 and slots.occupied_count() >= 2:
		var seed_id := slots.get_entry(_occupied_slot_indices(slots, 1)[0]).entry_id
		_expect(battle.try_move_seat_to_bench(seed_id), "seed bench for tap deploy")
		bench_board = battle.get_bench_slot_board()
	_expect(bench_board.occupied_count() >= 1, "need bench unit for tap deploy")
	if bench_board.occupied_count() < 1:
		battle.queue_free()
		await process_frame
		return
	var mover: DeckEntry = null
	for i in bench_board.slot_count:
		var e := bench_board.get_entry(i)
		if e != null:
			mover = e
			break
	_expect(mover != null, "bench mover present")
	if mover == null:
		battle.queue_free()
		await process_frame
		return
	var mover_id := mover.entry_id
	var seated_before := slots.occupied_count()
	_expect(battle.try_auto_deploy_bench(mover_id), "tap-equivalent auto deploy succeeds with empty seat")
	slots = battle.get_slot_board()
	_expect(slots.find_slot_by_entry(mover_id) >= 0, "auto deploy seats the bench unit")
	_expect(slots.occupied_count() == seated_before + 1, "seated count +1 after auto deploy")
	## 已入座不可再 auto_deploy；经 _on_bench_pressed 路径由选中/提示兜底。
	_expect(not battle.try_auto_deploy_bench(mover_id), "auto deploy rejects already-seated entry")
	battle.queue_free()
	await process_frame


func _test_long_press_slide_inspect() -> void:
	var battle := _make_battle(13)
	await process_frame
	var arena := _arena(battle)
	_expect(arena != null, "arena for slide inspect")
	if arena == null:
		battle.queue_free()
		return
	var slots := battle.get_slot_board()
	_expect(slots.occupied_count() >= 2, "need two seated units for slide inspect")
	var occupied := _occupied_slot_indices(slots, 2)
	if occupied.size() < 2:
		battle.queue_free()
		return
	var seat_a: int = occupied[0]
	var seat_b: int = occupied[1]
	var entry0 := slots.get_entry(seat_a)
	var entry1 := slots.get_entry(seat_b)
	_expect(entry0 != null and entry1 != null, "two occupied seats for slide")
	var c0 := _slot_center(arena, slots, seat_a)
	var c1 := _slot_center(arena, slots, seat_b)
	_press(arena, c0, true)
	var until := Time.get_ticks_msec() + RealtimeArenaView.LONG_PRESS_MS + 120
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(arena.is_info_card_visible(), "long press opens first unit")
	_expect(
		String(arena._press_info.get("skills", "")) == UnitInfoText.get_skills_block_from_entry(entry0, true),
		"first long-press shows seat0 skills",
	)
	## 保持按下，滑到另一单位。
	var move := InputEventMouseMotion.new()
	move.position = c1
	move.relative = c1 - c0
	arena._gui_input(move)
	_expect(arena.is_info_card_visible(), "info stays open while sliding")
	_expect(
		String(arena._press_info.get("skills", "")) == UnitInfoText.get_skills_block_from_entry(entry1, true),
		"slide switches to seat1 skills",
	)
	_expect(
		String(arena._press_info.get("inspect_key", "")) == "entry:%d" % entry1.entry_id,
		"slide updates inspect_key to seat1",
	)
	## 切换瞬间应有倾斜/放大（小丑牌式），内容已换。
	var card := arena._info_card
	_expect(card != null and card.visible, "info card node visible after slide")
	if card != null:
		_expect(
			absf(card.rotation_degrees) > 0.5 or card.scale.x > 1.01,
			"slide switch kicks tilt or scale punch",
		)
	_press(arena, c1, false)
	_expect(not arena.is_info_card_visible(), "release after slide hides card")
	battle.queue_free()
	await process_frame


func _test_recruit_input() -> void:
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	root.add_child(arena)
	await process_frame
	var unit := load(UNIT_PATHS[0]) as UnitData
	var cell := Vector2i(4, 11)
	arena.recruit_active = true
	arena.recruit_candidates = [{"index": 0, "unit": unit, "cell": cell, "cost": 3, "affordable": true}]
	var pressed: Array[int] = []
	arena.recruit_candidate_pressed.connect(func(i: int) -> void: pressed.append(i))
	var center := arena.tile_to_local(Vector2(cell) + Vector2(0.5, 0.5))

	_press(arena, center, true)
	_press(arena, center, false)
	_expect(pressed == [0], "recruit candidate tap emits on release")

	pressed.clear()
	_press(arena, center, true)
	var until := Time.get_ticks_msec() + RealtimeArenaView.LONG_PRESS_MS + 120
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(arena.is_info_card_visible(), "recruit candidate long press opens card")
	_press(arena, center, false)
	_expect(pressed.is_empty(), "recruit candidate long press does not pick")
	_expect(not arena.is_info_card_visible(), "recruit card hides on release")

	arena.recruit_selected_candidate = -1
	_press(arena, center, true)
	var jitter := InputEventMouseMotion.new()
	jitter.position = center + Vector2(4, 0)
	jitter.relative = Vector2(4, 0)
	arena._gui_input(jitter)
	_expect(arena.recruit_selected_candidate == -1, "small jitter does not start a drag")
	var move := InputEventMouseMotion.new()
	move.position = center + Vector2(30, 0)
	move.relative = Vector2(26, 0)
	arena._gui_input(move)
	_expect(arena.recruit_selected_candidate == 0, "moving past slop starts the recruit drag")
	arena.clear_recruit_mode()
	arena.queue_free()
	await process_frame


func _test_recruit_card_dissolve() -> void:
	## §6.3：离源格后源槽空；买不起可预览拖；失败回弹不改扣费口径。
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	arena.board_size = Vector2i(5, 8)
	root.add_child(arena)
	await process_frame
	var unit := load(UNIT_PATHS[0]) as UnitData
	var mid := BoardHalf.midline_row(arena.board_size.y)
	var cell := Vector2i(2, mid + 1)
	arena.recruit_active = true
	arena.recruit_candidates = [{
		"index": 0, "unit": unit, "cell": cell, "cost": 9, "affordable": false,
	}]
	var center := arena.tile_to_local(Vector2(cell) + Vector2(0.5, 0.5))
	var outside := arena.tile_to_local(Vector2(cell) + Vector2(2.5, 0.5))
	var drops: Array = []
	arena.recruit_drop.connect(func(i: int, r: int, s: int) -> void: drops.append([i, r, s]))

	_press(arena, center, true)
	var move_in := InputEventMouseMotion.new()
	move_in.position = center + Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	move_in.relative = Vector2(RealtimeArenaView.LONG_PRESS_SLOP_PX + 6.0, 0)
	arena._gui_input(move_in)
	_expect(arena.recruit_selected_candidate == 0, "unaffordable candidate still starts preview drag")
	_expect(not arena.is_recruit_drag_detached(), "still in source cell keeps card attached")
	_expect(not arena.is_recruit_drag_source_body_hidden(), "in-cell drag still shows source body")

	var leave := InputEventMouseMotion.new()
	leave.position = outside
	leave.relative = outside - move_in.position
	arena._gui_input(leave)
	_expect(arena.is_recruit_drag_detached(), "leaving source cell detaches / dissolves card")
	_expect(arena.is_recruit_drag_source_body_hidden(), "detached drag hides source body")

	## 松在下半场非法区：回弹路径（不发 recruit_drop）。
	_press(arena, outside, false)
	_expect(drops.is_empty(), "invalid half drop does not emit recruit_drop")
	_expect(not arena.is_recruit_drag_detached(), "release clears active detach drag")
	arena.clear_recruit_mode()
	arena.queue_free()
	await process_frame


func _test_recruit_team_sell_drag() -> void:
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	root.add_child(arena)
	await process_frame
	var unit := load(UNIT_PATHS[0]) as UnitData
	var entry := DeckEntry.new()
	entry.entry_id = 7
	entry.unit = unit
	entry.level = 2
	var team := PrepareSlotBoard.new()
	team.configure_grid(4, 5, Vector2i(5, 8), true, true)
	team.try_assign(0, entry)
	arena.recruit_active = true
	arena.recruit_team_slots = team
	arena.recruit_sell_cell = Vector2i(4, 12)
	arena.recruit_candidates = [{
		"index": 0,
		"unit": load(UNIT_PATHS[2]) as UnitData,
		"cell": Vector2i(1, 11),
		"cost": 3,
		"affordable": true,
	}]
	var sold: Array[int] = []
	var drops: Array = []
	arena.recruit_sell.connect(func(id: int) -> void: sold.append(id))
	arena.recruit_drop.connect(func(i: int, r: int, _s: int) -> void: drops.append([i, r]))
	var seat_drops: Array = []
	arena.recruit_team_seat_drop.connect(func(id: int, seat: int) -> void: seat_drops.append([id, seat]))
	var team_center := arena.tile_to_local(Vector2(team.get_cell(0)) + Vector2(0.5, 0.5))
	var sell_center := arena.tile_to_local(Vector2(arena.recruit_sell_cell) + Vector2(0.5, 0.5))

	_press(arena, team_center, true)
	var until := Time.get_ticks_msec() + RealtimeArenaView.LONG_PRESS_MS + 120
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(arena.is_info_card_visible(), "team long press opens info, not sell")
	_press(arena, team_center, false)
	_expect(sold.is_empty(), "long press does not sell")
	_expect(not arena.is_info_card_visible(), "team info hides on release")

	_press(arena, team_center, true)
	var move := InputEventMouseMotion.new()
	move.position = team_center + Vector2(0, 40)
	move.relative = Vector2(0, 40)
	arena._gui_input(move)
	_hover_to(arena, sell_center)
	_press(arena, sell_center, false)
	_expect(sold == [7], "drag team to sell slot emits recruit_sell")
	_expect(drops.is_empty(), "team sell does not emit recruit_drop")

	## 候选人拖到出售槽不成交招入
	sold.clear()
	var cand_center := arena.tile_to_local(Vector2(1, 11) + Vector2(0.5, 0.5))
	_press(arena, cand_center, true)
	var move2 := InputEventMouseMotion.new()
	move2.position = cand_center + Vector2(40, 0)
	move2.relative = Vector2(40, 0)
	arena._gui_input(move2)
	_hover_to(arena, sell_center)
	_press(arena, sell_center, false)
	_expect(drops.is_empty(), "candidate drop on sell slot does not recruit")

	## 上区拖到另一座位：换座信号（不出售）
	seat_drops.clear()
	sold.clear()
	var empty_seat := 1
	var empty_center := arena.tile_to_local(Vector2(team.get_cell(empty_seat)) + Vector2(0.5, 0.5))
	_press(arena, team_center, true)
	var move3 := InputEventMouseMotion.new()
	move3.position = team_center + Vector2(20, 0)
	move3.relative = Vector2(20, 0)
	arena._gui_input(move3)
	_hover_to(arena, empty_center)
	_press(arena, empty_center, false)
	_expect(seat_drops == [[7, empty_seat]], "drag team to empty seat emits recruit_team_seat_drop")
	_expect(sold.is_empty(), "seat drop does not emit recruit_sell")

	arena.clear_recruit_mode()
	arena.queue_free()
	await process_frame


func _test_recruit_team_bench_drag() -> void:
	## 招募：上区拖到中缝备战应发 bench_drop，不被最近空座吸附抢走。
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	arena.board_size = Vector2i(5, 8)
	root.add_child(arena)
	await process_frame
	var unit := load(UNIT_PATHS[0]) as UnitData
	var entry := DeckEntry.new()
	entry.entry_id = 11
	entry.unit = unit
	entry.level = 1
	var team := PrepareSlotBoard.new()
	team.configure_grid(4, 5, Vector2i(5, 8), true, true)
	team.try_assign(0, entry)
	var mid_y := BoardHalf.midline_row(8)
	var bench := PrepareSlotBoard.new()
	bench.configure_bench_row(Vector2i(5, 8), DeckState.BENCH_CAPACITY, mid_y)
	arena.recruit_active = true
	arena.recruit_team_slots = team
	arena.bench_visible = true
	arena.bench_interactive = true
	arena.bench_slots = bench
	arena.recruit_sell_cell = Vector2i(4, mid_y + 2)
	arena.recruit_lock_cell = Vector2i(0, mid_y + 2)
	var bench_drops: Array[int] = []
	var seat_drops: Array = []
	arena.recruit_team_bench_drop.connect(
		func(id: int, _slot: int) -> void: bench_drops.append(id)
	)
	arena.recruit_team_seat_drop.connect(func(id: int, seat: int) -> void: seat_drops.append([id, seat]))
	var team_center := arena.tile_to_local(Vector2(team.get_cell(0)) + Vector2(0.5, 0.5))
	var bench_center := arena.bench_slot_center_local(0)
	_expect(arena.find_bench_slot_at_local(bench_center) == 0, "bench center hit-tests slot 0")
	_press(arena, team_center, true)
	var move := InputEventMouseMotion.new()
	move.position = team_center + Vector2(0, RealtimeArenaView.LONG_PRESS_SLOP_PX + 8.0)
	move.relative = Vector2(0, RealtimeArenaView.LONG_PRESS_SLOP_PX + 8.0)
	arena._gui_input(move)
	_hover_to(arena, bench_center)
	_press(arena, bench_center, false)
	_expect(bench_drops == [11], "drag team to recruit bench emits recruit_team_bench_drop")
	_expect(seat_drops.is_empty(), "bench drop must not emit nearest-seat snap")
	arena.clear_recruit_mode()
	arena.queue_free()
	await process_frame


func _test_recruit_lock_drag() -> void:
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	root.add_child(arena)
	await process_frame
	var unit := load(UNIT_PATHS[0]) as UnitData
	var cand_cell := Vector2i(2, 11)
	var lock_cell := Vector2i(0, 12)
	arena.recruit_active = true
	arena.recruit_lock_cell = lock_cell
	arena.recruit_sell_cell = Vector2i(8, 12)
	arena.recruit_candidates = [{
		"index": 0,
		"unit": unit,
		"cell": cand_cell,
		"cost": 3,
		"affordable": true,
		"locked": false,
	}]
	var locks: Array[int] = []
	var drops: Array = []
	arena.recruit_candidate_lock.connect(func(i: int) -> void: locks.append(i))
	arena.recruit_drop.connect(func(i: int, r: int, _s: int) -> void: drops.append([i, r]))
	var cand_center := arena.tile_to_local(Vector2(cand_cell) + Vector2(0.5, 0.5))
	var lock_center := arena.tile_to_local(Vector2(lock_cell) + Vector2(0.5, 0.5))

	_press(arena, cand_center, true)
	var move := InputEventMouseMotion.new()
	move.position = cand_center + Vector2(0, 40)
	move.relative = Vector2(0, 40)
	arena._gui_input(move)
	_hover_to(arena, lock_center)
	_press(arena, lock_center, false)
	_expect(locks == [0], "drag candidate to lock cell emits recruit_candidate_lock")
	_expect(drops.is_empty(), "lock drop does not emit recruit_drop")

	arena.clear_recruit_mode()
	arena.queue_free()
	await process_frame


func _test_recruit_candidate_rejects_occupied_seat() -> void:
	## 候选人拖到已上场友方：拒绝，不发 recruit_drop（避免旧人被替换消失）。
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	arena.board_size = Vector2i(5, 8)
	root.add_child(arena)
	await process_frame
	var seated := DeckEntry.new()
	seated.entry_id = 21
	seated.unit = load(UNIT_PATHS[0]) as UnitData
	seated.level = 1
	var team := PrepareSlotBoard.new()
	team.configure_grid(4, 5, Vector2i(5, 8), true, true)
	team.try_assign(0, seated)
	arena.recruit_active = true
	arena.recruit_team_slots = team
	arena.recruit_candidates = [{
		"index": 0,
		"unit": load(UNIT_PATHS[2]) as UnitData,
		"cell": Vector2i(1, 11),
		"cost": 3,
		"affordable": true,
	}]
	var drops: Array = []
	var rejected: Array = []
	arena.recruit_drop.connect(func(i: int, r: int, s: int) -> void: drops.append([i, r, s]))
	arena.recruit_drop_rejected.connect(func(reason: StringName) -> void: rejected.append(reason))
	var cand_center := arena.tile_to_local(Vector2(1, 11) + Vector2(0.5, 0.5))
	var occupied_center := arena.tile_to_local(Vector2(team.get_cell(0)) + Vector2(0.5, 0.5))
	_press(arena, cand_center, true)
	var move := InputEventMouseMotion.new()
	move.position = cand_center + Vector2(0, -40)
	move.relative = Vector2(0, -40)
	arena._gui_input(move)
	_hover_to(arena, occupied_center)
	_press(arena, occupied_center, false)
	_expect(drops.is_empty(), "candidate on occupied seat does not emit recruit_drop")
	_expect(rejected == [&"occupied_seat"], "candidate on occupied emits recruit_drop_rejected")
	_expect(team.get_entry(0) != null and team.get_entry(0).entry_id == 21, "occupied ally still on seat")
	arena.clear_recruit_mode()
	arena.queue_free()
	await process_frame


func _hover_to(arena: RealtimeArenaView, pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	arena._gui_input(motion)


func _test_hand_card_long_press() -> void:
	## 独立卡面 + 场上信息卡：不依赖入座后是否仍有手牌。
	var arena := RealtimeArenaView.new()
	arena.size = Vector2(393, 700)
	root.add_child(arena)
	var card := RealtimeHandCard.new()
	card.size = Vector2(64, 88)
	root.add_child(card)
	await process_frame
	var entry := DeckEntry.new()
	entry.entry_id = 3
	entry.unit = load(UNIT_PATHS[0]) as UnitData
	card.setup(entry)
	var pressed: Array[int] = []
	card.card_pressed.connect(func(id: int) -> void: pressed.append(id))
	card.card_long_press.connect(
		func(_id: int) -> void:
			arena.show_deck_entry_info(entry, Vector2(120, 160))
	)
	card.card_long_press_ended.connect(func(_id: int) -> void: arena.hide_unit_info())

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = card.size * 0.5
	card._gui_input(press)
	var until := Time.get_ticks_msec() + RealtimeHandCard.LONG_PRESS_MS + 120
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(arena.is_info_card_visible(), "hand card long press opens shared info card")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = card.size * 0.5
	card._gui_input(release)
	_expect(not arena.is_info_card_visible(), "hand card release closes info card")
	_expect(pressed.is_empty(), "hand long press does not emit card_pressed")

	## 短按仍发 card_pressed
	card._gui_input(press)
	card._gui_input(release)
	_expect(pressed == [3], "hand short press still emits card_pressed")

	## 移动超 slop 取消长按
	pressed.clear()
	card._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.position = card.size * 0.5 + Vector2(20, 0)
	move.relative = Vector2(20, 0)
	card._gui_input(move)
	until = Time.get_ticks_msec() + RealtimeHandCard.LONG_PRESS_MS + 120
	while Time.get_ticks_msec() < until:
		await process_frame
	_expect(not arena.is_info_card_visible(), "slop cancel prevents hand long press info")
	card._gui_input(release)
	_expect(pressed == [3], "after slop cancel, release still counts as press")

	card.queue_free()
	arena.queue_free()
	await process_frame


func _make_rt_pair(attacker_path: String, target_path: String) -> Array:
	var atk_unit := UnitInstance.from_unit_data(
		load(attacker_path) as UnitData, Vector2i(2, 5), UnitInstance.Team.PLAYER
	)
	var tgt_unit := UnitInstance.from_unit_data(
		load(target_path) as UnitData, Vector2i(2, 4), UnitInstance.Team.ENEMY
	)
	var atk := RtUnit.new(atk_unit, Vector2(2, 5))
	var tgt := RtUnit.new(tgt_unit, Vector2(2, 4))
	atk.skip_deploy()
	tgt.skip_deploy()
	atk.target = tgt
	return [atk, tgt]


func _await_seconds(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(sec * 1000.0) + 50
	while Time.get_ticks_msec() < until:
		await process_frame


## 蓄力取消（无出手）：soft_home 把自身与迎击 partner 弹回零姿。
func _test_windup_cancel_soft_home() -> void:
	var motion := RealtimeUnitMotion.new()
	root.add_child(motion)
	await process_frame
	var pair := _make_rt_pair(UNIT_PATHS[0], UNIT_PATHS[1])
	var atk: RtUnit = pair[0]
	var tgt: RtUnit = pair[1]
	atk.state = RtUnit.State.ATTACKING
	## 拉长前摇，确保采样时仍在 tween running（非卡在终点无 tween）。
	atk.attack_timer = 0.8
	if atk.get_stats() != null:
		atk.get_stats().attack_windup = 0.8
	motion.sync_units([atk, tgt])
	await process_frame
	var atk_pose := motion.get_pose(atk)
	var tgt_pose := motion.get_pose(tgt)
	_expect(atk_pose != null and tgt_pose != null, "windup cancel: poses tracked")
	_expect(motion.has_active_action_tween(), "windup cancel: action tween busy while winding")
	## 等蓄力 tween 拉到非零姿（仍短于 windup，tween 未结束）。
	await _await_seconds(0.15)
	_expect(
		atk_pose != null and atk_pose.offset.length() > 0.04,
		"windup cancel: attacker pulled back during windup",
	)
	_expect(
		tgt_pose != null and tgt_pose.offset.length() > 0.02,
		"windup cancel: melee target braces during windup",
	)
	_expect(motion.has_active_action_tween(), "windup cancel: action tween still busy mid-windup")
	## 取消蓄力：timer≤0 且未改 last_attack → soft_home。
	atk.attack_timer = 0.0
	atk.state = RtUnit.State.MOVING
	motion.sync_units([atk, tgt])
	await process_frame
	_expect(motion.has_active_action_tween(), "windup cancel: soft_home starts action tween")
	await _await_seconds(RealtimeUnitMotion.RECOVER_SECONDS + 0.12)
	_expect(not motion.has_active_action_tween(), "windup cancel: soft_home finishes")
	_expect(
		atk_pose.offset.length() <= 0.03 and absf(atk_pose.rotation) <= 0.05,
		"windup cancel: attacker offset/rotation home",
	)
	_expect(
		tgt_pose.offset.length() <= 0.03 and absf(tgt_pose.rotation) <= 0.05,
		"windup cancel: partner offset/rotation home",
	)
	## idle/flash 不应计入 action tween。
	atk_pose.flash = 1.0
	_expect(not motion.has_active_action_tween(), "idle/flash alone does not count as action tween")
	motion.queue_free()
	await process_frame


## 出手后 has_active_action_tween 为 true，LUNGE+RECOVER 播完为 false。
func _test_strike_action_tween_lifecycle() -> void:
	var motion := RealtimeUnitMotion.new()
	root.add_child(motion)
	await process_frame
	var pair := _make_rt_pair(UNIT_PATHS[0], UNIT_PATHS[1])
	var atk: RtUnit = pair[0]
	var tgt: RtUnit = pair[1]
	atk.state = RtUnit.State.MOVING
	atk.attack_timer = 0.0
	## 先登记 tracked（last_attack=NEVER），再改时间戳触发 strike。
	motion.sync_units([atk, tgt])
	await process_frame
	_expect(not motion.has_active_action_tween(), "strike: idle before fire has no action tween")
	atk.state = RtUnit.State.ATTACKING
	atk.last_attack_time = 1.0
	motion.sync_units([atk, tgt])
	await process_frame
	_expect(motion.has_active_action_tween(), "strike: action tween active after fire")
	var atk_pose := motion.get_pose(atk)
	_expect(
		atk_pose != null and (atk_pose.offset.length() > 0.01 or motion.has_active_action_tween()),
		"strike: attacker lunge/recover in progress",
	)
	await _await_seconds(
		RealtimeUnitMotion.LUNGE_SECONDS + RealtimeUnitMotion.RECOVER_SECONDS + 0.2
	)
	_expect(not motion.has_active_action_tween(), "strike: action tween clears after recover")
	_expect(
		atk_pose.offset.length() <= 0.03 and absf(atk_pose.rotation) <= 0.05,
		"strike: attacker settles home after recover",
	)
	motion.queue_free()
	await process_frame


func _test_combat_motion() -> void:
	var battle := _make_battle(23)
	await process_frame
	var arena := _arena(battle)
	## 略加速观战，便于 headless 窗口内捕捉近战冲撞帧。
	battle.time_scale = 2.0
	_expect(battle.try_start_combat(), "start combat")
	var motion := arena.find_child("UnitMotion", false, false) as RealtimeUnitMotion
	_expect(motion != null, "motion node attached")
	if motion == null:
		battle.queue_free()
		return
	var saw_offset := false
	var saw_flash := false
	var saw_shake := false
	var saw_walk := false
	var saw_death := false
	var saw_corpse := false
	var saw_lunge := false
	var saw_clash_flash := false
	var saw_idle := false
	var saw_actor_not_idle := false
	var sim_for_death := arena.sim
	if sim_for_death != null:
		sim_for_death.unit_died.connect(func(_rt: RtUnit) -> void: saw_death = true)
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline and battle.get_phase() == RealtimeBattleController.Phase.COMBAT:
		await process_frame
		var sim := arena.sim
		if sim == null:
			break
		var actor := sim.get_current_actor()
		for item in sim.get_units():
			var rt := item as RtUnit
			var pose := motion.get_pose(rt)
			if pose != null:
				saw_offset = saw_offset or pose.offset.length() > 0.05
				saw_flash = saw_flash or pose.flash > 0.2
				## 近战冲撞：沿目标轴的蓄力后拉或前冲；目标同时偏移/闪白。
				var melee := rt.get_stats() != null and rt.get_stats().projectile_speed <= 0.0
				if melee and rt.target != null and rt.target.is_alive():
					var dir := rt.position.direction_to(rt.target.position)
					if dir.length_squared() < 0.0001:
						dir = Vector2.UP
					var along := pose.offset.dot(dir)
					if absf(along) > 0.1:
						saw_lunge = true
					var tpose := motion.get_pose(rt.target)
					if tpose != null and absf(along) > 0.04 and (
						tpose.flash > 0.15 or absf(tpose.offset.dot(dir)) > 0.04
					):
						saw_clash_flash = true
				if actor != null and rt != actor and pose.idle_requested:
					saw_idle = saw_idle or pose.idle_offset.length() > 0.01 or pose.idle_scale.distance_to(Vector2.ONE) > 0.01
				if actor != null and rt == actor:
					saw_actor_not_idle = saw_actor_not_idle or not pose.idle_requested
			var walk: Dictionary = motion.walk_pose(rt)
			saw_walk = saw_walk or absf(float(walk.get("rotation", 0.0))) > 0.01
			saw_walk = saw_walk or (walk.get("offset", Vector2.ZERO) as Vector2).y < -0.02
			saw_walk = saw_walk or float(walk.get("shadow_mul", 1.0)) > 1.08
		saw_shake = saw_shake or motion.shake_strength > 0.5
		saw_corpse = saw_corpse or not motion.get_corpses().is_empty()
		if (
			saw_offset and saw_flash and saw_shake and saw_walk and saw_death
			and saw_lunge and saw_clash_flash and saw_idle and saw_actor_not_idle
		):
			break
	## 本遭遇若开局已贴身可能无迈步；有冲撞偏移则仍算走位通道可读。
	_expect(saw_walk or saw_lunge or saw_offset, "walking tilts the sprite")
	_expect(saw_offset, "windup / lunge offsets the sprite")
	_expect(saw_flash, "hit flashes the sprite white")
	_expect(saw_shake, "hit shakes the camera")
	_expect(saw_death, "a unit dies during the encounter")
	_expect(saw_corpse, "death plays a falling corpse")
	var fade_deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < fade_deadline and not motion.get_corpses().is_empty():
		await process_frame
	_expect(motion.get_corpses().is_empty(), "faded corpse is removed and not drawn again")
	## 回合制下近战接触帧可能极短；有轴向冲撞则严格通过，否则回退到通用 offset/flash。
	_expect(saw_lunge or saw_offset, "melee attacker lunges toward its target")
	_expect(saw_clash_flash or (saw_flash and saw_offset), "melee target flashes white on impact")
	_expect(saw_idle, "non-actors play idle bob")
	_expect(saw_actor_not_idle, "current actor does not idle")
	## 停模拟后强制归零：蓄力 tween 可能停在非零姿。
	battle.time_scale = 0.0
	motion.speed_scale = 1.0
	motion.force_home_all()
	await process_frame
	var settled := true
	if arena.sim != null:
		for item in arena.sim.get_units():
			var pose := motion.get_pose(item as RtUnit)
			if pose != null and (
				pose.offset.length() > 0.03
				or pose.flash > 0.05
				or absf(pose.rotation) > 0.05
			):
				settled = false
	_expect(settled, "poses settle back home without lingering flash")
	battle.queue_free()
	await process_frame
