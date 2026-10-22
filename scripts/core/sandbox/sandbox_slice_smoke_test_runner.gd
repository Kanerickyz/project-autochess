extends SceneTree
## 沙盒切片最小加载：剪贴板编解码 + 相关场景 instantiate。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_clipboard()
	failed += await _test_paste_apply()
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



func _test_paste_apply() -> int:
	var failed := 0
	var packed := load("res://scenes/combat/realtime/realtime_battle.tscn") as PackedScene
	var battle := packed.instantiate() as RealtimeBattleController
	root.add_child(battle)
	await process_frame
	## 与沙盒入口一致：空队进准备，再粘贴布局。
	var deck := DeckState.new()
	deck.configure(load("res://resources/deck/realtime_starter_deck.tres") as DeckConfig)
	battle.setup(deck, RunEconomy.new(), load("res://resources/levels/board_act1.tres") as LevelData)
	battle.set_combat_sandbox_mode(true)
	battle.enter_combat_sandbox(0)
	await process_frame
	if battle.get_phase() != RealtimeBattleController.Phase.PREPARE:
		push_error("paste_apply: not PREPARE after empty enter")
		failed += 1
	var e1 := DeckEntry.new()
	e1.unit = load("res://resources/units/realtime/wardrum.tres") as UnitData
	e1.entry_id = 0
	e1.level = 1
	e1.seat_index = 0
	e1.seat_assign_seq = 1
	var entries: Array[DeckEntry] = [e1]
	var text := BattleLayoutClipboard.encode_layout(
		entries, 5, [{"unit_id": "enemy_archer", "seat": 0, "level": 1}], 7, "combat"
	)
	var err := battle.apply_layout_clipboard_text(text, false)
	if not err.is_empty():
		push_error("paste_apply: %s" % err)
		failed += 1
	elif battle.get_slot_board().occupied_count() < 1:
		push_error("paste_apply: no ally seats after paste")
		failed += 1
	elif battle._enemy_spawns.is_empty():
		push_error("paste_apply: no enemies after paste")
		failed += 1
	## 点「粘贴布局」必须创建自定义弹层（含「应用」按钮，不依赖系统剪贴板）。
	battle.paste_layout_from_clipboard()
	await process_frame
	var dlg := battle.get_node_or_null("PasteLayoutDialog") as Control
	if dlg == null or not dlg.visible:
		push_error("paste_apply: dialog missing or hidden")
		failed += 1
	elif dlg.find_child("PasteApplyButton", true, false) == null:
		push_error("paste_apply: Apply button missing")
		failed += 1
	battle.queue_free()
	await process_frame
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
