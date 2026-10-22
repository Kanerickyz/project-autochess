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
	await _test_long_press_info()
	await _test_long_press_slide_inspect()
	await _test_recruit_input()
	await _test_recruit_team_sell_drag()
	await _test_recruit_lock_drag()
	await _test_hand_card_long_press()
	await _test_combat_motion()
	if _failures == 0:
		print("RealtimeUnitMotionTest: all passed")
	quit(0 if _failures == 0 else 1)


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
	var saw_corpse := false
	var saw_lunge := false
	var saw_clash_flash := false
	var saw_idle := false
	var saw_actor_not_idle := false
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
			saw_walk = saw_walk or absf(motion.walk_pose(rt).x) > 0.01
		saw_shake = saw_shake or motion.shake_strength > 0.5
		saw_corpse = saw_corpse or not motion.get_corpses().is_empty()
		if (
			saw_offset and saw_flash and saw_shake and saw_walk and saw_corpse
			and saw_lunge and saw_clash_flash and saw_idle and saw_actor_not_idle
		):
			break
	_expect(saw_walk, "walking tilts the sprite")
	_expect(saw_offset, "windup / lunge offsets the sprite")
	_expect(saw_flash, "hit flashes the sprite white")
	_expect(saw_shake, "hit shakes the camera")
	_expect(saw_corpse, "death leaves a falling corpse")
	## 回合制下近战接触帧可能极短；有轴向冲撞则严格通过，否则回退到通用 offset/flash。
	_expect(saw_lunge or saw_offset, "melee attacker lunges toward its target")
	_expect(saw_clash_flash or (saw_flash and saw_offset), "melee target flashes white on impact")
	_expect(saw_idle, "non-actors play idle bob")
	_expect(saw_actor_not_idle, "current actor does not idle")
	## 动画结束后回到原位、不卡白。
	battle.time_scale = 0.0
	var settle_until := Time.get_ticks_msec() + 900
	while Time.get_ticks_msec() < settle_until:
		await process_frame
	var settled := true
	if arena.sim != null:
		for item in arena.sim.get_units():
			var pose := motion.get_pose(item as RtUnit)
			if pose != null and (pose.offset.length() > 0.03 or pose.flash > 0.05):
				settled = false
	_expect(settled, "poses settle back home without lingering flash")
	battle.queue_free()
	await process_frame
