extends SceneTree
## 观战录音机：下一动 +1 停住；上一动同种子重演与实战完成动数一致（不因 defer 分叉提前终局）。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += await _test_next_and_prev()
	print("combat_tape_rewind_test failed=%d" % failed)
	quit(1 if failed else 0)


func _await_settled(battle: RealtimeBattleController, max_frames: int = 1200) -> void:
	var g := 0
	while g < max_frames:
		await process_frame
		g += 1
		if battle._sim == null or battle._sim.is_finished():
			await process_frame
			return
		if (
			battle._tape_paused
			and not battle._tape_step_once
			and not battle._tape_boundary_pending
			and battle._arena != null
			and not battle._arena.has_active_combat_action_tween()
		):
			return


func _test_next_and_prev() -> int:
	var failed := 0
	var packed := load("res://scenes/combat/realtime/realtime_battle.tscn") as PackedScene
	var battle := packed.instantiate() as RealtimeBattleController
	root.add_child(battle)
	await process_frame
	var deck := DeckState.new()
	deck.configure(load("res://resources/deck/realtime_starter_deck.tres") as DeckConfig)
	deck.reset_from_config()
	while deck.size() > 0:
		deck.remove_entry(deck.get_entries()[0].entry_id)
	deck.add_entry(load("res://resources/units/realtime/relic_aegis.tres") as UnitData, 0, 0)
	deck.add_entry(load("res://resources/units/realtime/relic_aegis.tres") as UnitData, 0, 1)
	battle.setup(deck, RunEconomy.new(), load("res://resources/levels/board_act1.tres") as LevelData)
	battle.set_combat_sandbox_mode(true)
	battle.rng_seed = 11
	battle.enter_combat_sandbox(11)
	await process_frame
	var err := battle.apply_layout_clipboard_text(
		BattleLayoutClipboard.encode_layout(
			deck.get_entries(),
			5,
			[
				{"unit_id": "enemy_relic_aegis", "seat": 0, "level": 1},
				{"unit_id": "enemy_relic_aegis", "seat": 1, "level": 1},
			],
			11,
			"combat",
		),
		false,
	)
	if not err.is_empty():
		push_error("tape test layout: %s" % err)
		battle.queue_free()
		await process_frame
		return 1
	await process_frame
	battle._on_start_pressed()
	for _i in 90:
		await process_frame
		if battle.get_phase() == RealtimeBattleController.Phase.COMBAT:
			break
	if battle.get_phase() != RealtimeBattleController.Phase.COMBAT:
		push_error("tape test: not COMBAT")
		failed += 1
	battle._tape_paused = true
	battle._tape_step_once = false
	battle._tape_boundary_pending = false
	for n in 6:
		if battle._sim == null or battle._sim.is_finished():
			push_error("tape test: finished too early at next %d" % (n + 1))
			failed += 1
			break
		var before := battle._tape_completed_turns
		battle._on_tape_next_pressed()
		await _await_settled(battle)
		if battle._tape_completed_turns != before + 1:
			push_error(
				"tape next: expected %d got %d" % [before + 1, battle._tape_completed_turns]
			)
			failed += 1
		if not battle._tape_paused or battle._tape_step_once or battle._tape_boundary_pending:
			push_error("tape next: should settle paused with flags clear")
			failed += 1
	var at := battle._tape_completed_turns
	if at < 2:
		push_error("tape test: need >=2 turns for prev")
		failed += 1
	else:
		battle._on_tape_prev_pressed()
		await process_frame
		await process_frame
		if battle._tape_completed_turns != at - 1:
			push_error(
				"tape prev: expected %d got %d (sim=%d finished=%s)"
				% [
					at - 1,
					battle._tape_completed_turns,
					battle._sim.get_completed_actor_turns() if battle._sim else -1,
					str(battle._sim.is_finished() if battle._sim else true),
				]
			)
			failed += 1
		if battle._sim != null and battle._sim.is_finished():
			push_error("tape prev: rewind should not finish early vs live")
			failed += 1
		var mid := battle._tape_completed_turns
		battle._on_tape_next_pressed()
		await _await_settled(battle)
		if battle._tape_completed_turns != mid + 1:
			push_error(
				"tape next after prev: expected %d got %d"
				% [mid + 1, battle._tape_completed_turns]
			)
			failed += 1
	battle.queue_free()
	await process_frame
	return failed
