extends SceneTree
## 沙盒切片最小加载：剪贴板编解码 + 相关场景 instantiate。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_clipboard()
	failed += await _test_scenes()
	print("sandbox_slice_smoke failed=%d" % failed)
	quit(1 if failed else 0)


func _test_clipboard() -> int:
	var failed := 0
	var e1 := DeckEntry.new()
	e1.unit = load("res://resources/units/realtime/knight.tres") as UnitData
	e1.entry_id = 0
	e1.level = 2
	e1.seat_index = 3
	e1.bonus_attack = 1
	e1.seat_assign_seq = 1
	var entries: Array[DeckEntry] = [e1]
	var text := BattleLayoutClipboard.encode_roster(entries, 5)
	var parsed := BattleLayoutClipboard.parse(text)
	if not parsed.ok:
		push_error("roster parse fail: %s" % parsed.error)
		failed += 1
	var enemy_rows: Array = [{"unit_id": "enemy_skeleton", "seat": 1, "level": 1}]
	var layout := BattleLayoutClipboard.encode_layout(entries, 5, enemy_rows, 42, "combat")
	var p2 := BattleLayoutClipboard.parse(layout)
	if not p2.ok or p2.payload == null or not p2.payload.has_enemies():
		push_error("layout parse fail")
		failed += 1
	var bad := BattleLayoutClipboard.parse("garbage")
	if bad.ok:
		push_error("bad text should fail")
		failed += 1
	if parsed.ok and parsed.payload != null:
		var built := BattleLayoutClipboard.build_deck_entries(parsed.payload)
		if built.is_empty():
			push_error("build_deck_entries empty")
			failed += 1
	return failed


func _test_scenes() -> int:
	var failed := 0
	for path in [
		"res://scenes/main/main_menu.tscn",
		"res://scenes/main/combat_sandbox.tscn",
		"res://scenes/ui/run/run_stats_overlay.tscn",
		"res://scenes/combat/realtime/realtime_battle.tscn",
	]:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("missing %s" % path)
			failed += 1
			continue
		var node := packed.instantiate()
		if node == null:
			push_error("instantiate fail %s" % path)
			failed += 1
			continue
		root.add_child(node)
		await process_frame
		await process_frame
		node.queue_free()
		await process_frame
	return failed
