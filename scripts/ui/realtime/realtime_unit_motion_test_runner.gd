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
	await _test_long_press_info()
	await _test_combat_motion()
	if _failures == 0:
		print("RealtimeUnitMotionTest: all passed")
	quit(0 if _failures == 0 else 1)


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
	var slots := battle.get_slot_board()
	var i := 0
	for entry in battle.get_hand():
		if i >= battle.get_deploy_cap():
			break
		battle.try_assign_to_slot(entry.entry_id, slots.get_cell(i))
		i += 1
	return battle


func _arena(battle: RealtimeBattleController) -> RealtimeArenaView:
	return battle.find_child("ArenaView", true, false) as RealtimeArenaView


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
	var center := arena.tile_to_local(Vector2(slots.get_cell(0)) + Vector2(0.5, 0.5)) + Vector2(0.0, arena.ally_half_slide_y)
	var info := arena.inspect_at(center)
	_expect(not info.is_empty(), "inspect seated unit")
	_expect(
		String(info.get("skills", "")) == UnitInfoText.get_skills_block_from_entry(slots.get_entry(0)),
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
	_expect(slots.occupied_count() == seated_before - 1, "quick tap still recalls the unit")

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


func _test_combat_motion() -> void:
	var battle := _make_battle(23)
	await process_frame
	var arena := _arena(battle)
	battle.time_scale = 4.0
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
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and battle.get_phase() == RealtimeBattleController.Phase.COMBAT:
		await process_frame
		var sim := arena.sim
		if sim == null:
			break
		for item in sim.get_units():
			var rt := item as RtUnit
			var pose := motion.get_pose(rt)
			if pose != null:
				saw_offset = saw_offset or pose.offset.length() > 0.05
				saw_flash = saw_flash or pose.flash > 0.2
			saw_walk = saw_walk or absf(motion.walk_pose(rt).x) > 0.01
		saw_shake = saw_shake or motion.shake_strength > 0.5
		saw_corpse = saw_corpse or not motion.get_corpses().is_empty()
		if saw_offset and saw_flash and saw_shake and saw_walk and saw_corpse:
			break
	_expect(saw_walk, "walking tilts the sprite")
	_expect(saw_offset, "windup / lunge offsets the sprite")
	_expect(saw_flash, "hit flashes the sprite white")
	_expect(saw_shake, "hit shakes the camera")
	_expect(saw_corpse, "death leaves a falling corpse")
	battle.queue_free()
	await process_frame
