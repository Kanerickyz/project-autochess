extends SceneTree
## Headless：主爬塔十五天日程——选指挥官 → 第 1 天 6 次招募 → 战 → 商店买入暂存 → 战 → 事件 → 战
## → 第 2 天招募可跳过；战败即失败。战斗本体不打，直接回调遭遇完成。

const RUN_SCENE := "res://scenes/main/run_game.tscn"
const WAIT_FRAMES := 2400

var _failures: int = 0
var _ctl: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(RUN_SCENE) as PackedScene
	_ctl = packed.instantiate() if packed != null else null
	if _ctl == null:
		push_error("DayLoopFlowTest: cannot instantiate run scene")
		quit(1)
		return
	root.add_child(_ctl)
	var overlay: DayPickOverlay = _ctl._day_overlay
	_expect(overlay != null, "overlay created")
	if overlay == null:
		quit(1)
		return
	overlay.anim_scale = 0.0
	_expect(not _ctl._battle.final_trial_enabled, "day loop: no final trial after boss")

	await _tap_option(0)
	_expect(_ctl.deck_state.get_commander_entry() != null, "commander present")
	_expect(_ctl.deck_state.get_commander_entry().get_equipment_slot_count() == 1, "commander 1 slot")

	for i in DayRunSchedule.FIRST_DAY_RECRUIT_PICKS:
		await _tap_option(i % DayRunSchedule.PICK_OPTION_COUNT)
	await _wait_step(DayRunSchedule.Step.COMBAT, 1)
	_expect(
		_ctl.deck_state.size() == 1 + DayRunSchedule.FIRST_DAY_RECRUIT_PICKS,
		"day 1: commander + 6 recruits (got %d)" % _ctl.deck_state.size()
	)
	_expect(not overlay.is_open(), "overlay closed before battle 1")

	_ctl._on_encounter_completed(true)
	await _wait_step(DayRunSchedule.Step.SHOP, 1)
	var gold_before: int = _ctl.run_economy.gold
	var stash_before: int = _ctl.deck_state.get_equipment_stash_count()
	await _tap_option(int(DayShopCatalog.Category.ARMORY))
	await _tap_option(0)
	await _frames(4)
	var bought: bool = _ctl.deck_state.get_equipment_stash_count() == stash_before + 1
	var broke: bool = _ctl.run_economy.gold == gold_before
	_expect(bought or broke, "shop: equipment into stash or rejected without charge")
	if bought:
		_expect(_ctl.run_economy.gold < gold_before, "shop: gold spent")
	await _tap_action(&"done")
	await _wait_step(DayRunSchedule.Step.COMBAT, 1)
	_expect(_ctl._day_schedule.get_battle_index() == 2, "battle 2 after shop")

	_ctl._on_encounter_completed(true)
	await _wait_step(DayRunSchedule.Step.EVENT, 1)
	await _frames(4)
	_ctl._placeholder_screen.continue_pressed.emit()
	await _wait_step(DayRunSchedule.Step.COMBAT, 1)
	_expect(_ctl._day_schedule.get_battle_index() == 3, "battle 3 after event")

	_ctl._on_encounter_completed(true)
	await _wait_step(DayRunSchedule.Step.RECRUIT, 2)
	_expect(_ctl._day_schedule.get_recruit_pick_count() == 1, "day 2: one pick")
	await _tap_action(&"skip")
	await _wait_step(DayRunSchedule.Step.COMBAT, 2)
	_expect(
		_ctl.deck_state.size() == 1 + DayRunSchedule.FIRST_DAY_RECRUIT_PICKS,
		"day 2 skip keeps roster"
	)

	_ctl._on_encounter_completed(false)
	await _frames(4)
	_expect(_ctl.run_controller.phase == RunController.RunPhase.RUN_DEFEAT, "loss = run defeat")

	if _failures == 0:
		print("DayLoopFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("DayLoopFlowTest: FAIL %s" % label)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _wait_input() -> bool:
	for _i in WAIT_FRAMES:
		var o: DayPickOverlay = _ctl._day_overlay
		if o.is_open() and not o._busy and o.resolved.get_connections().size() > 0:
			return true
		await process_frame
	return false


func _tap_option(index: int) -> void:
	var ok := await _wait_input()
	_expect(ok, "overlay waiting for option %d" % index)
	_ctl._day_overlay.resolved.emit({"kind": &"option", "index": index, "action": &""})
	await process_frame


func _tap_action(action: StringName) -> void:
	var ok := await _wait_input()
	_expect(ok, "overlay waiting for action %s" % action)
	_ctl._day_overlay.resolved.emit({"kind": &"action", "index": -1, "action": action})
	await process_frame


func _wait_step(step: DayRunSchedule.Step, day: int) -> void:
	for _i in WAIT_FRAMES:
		var s: DayRunSchedule = _ctl._day_schedule
		if s.get_day() == day and s.get_step() == step:
			await _frames(3)
			return
		await process_frame
	_expect(false, "reach day %d step %s" % [day, DayRunSchedule.step_label(step)])
