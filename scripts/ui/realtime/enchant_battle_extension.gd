class_name EnchantBattleExtension
extends RefCounted
## 附魔阶段 UI 与 Arena 同步；由 RealtimeBattleController 持有并调用。


var _battle: RealtimeBattleController
var _session: EnchantSession
var _hud: Control
var _title: Label
var _slot_a: Label
var _slot_b: Label
var _preview: Label
var _pick_list: ItemList
var _btn_to_a: Button
var _btn_to_b: Button
var _btn_fuse: Button
var _btn_skip: Button
var _btn_done: Button


func setup(battle: RealtimeBattleController) -> void:
	_battle = battle
	_ensure_hud()


func set_session(session: EnchantSession) -> void:
	_session = session
	if _session != null and not _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.connect(_on_session_changed)


func clear_session() -> void:
	if _session != null and _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.disconnect(_on_session_changed)
	_session = null


func get_hud() -> Control:
	_ensure_hud()
	return _hud


func show_hud() -> void:
	_ensure_hud()
	_hud.visible = true
	_refresh()


func hide_hud() -> void:
	if _hud != null:
		_hud.visible = false


func sync_arena(arena: RealtimeArenaView, deck: DeckState, slots: PrepareSlotBoard) -> void:
	if arena == null or deck == null or slots == null:
		return
	arena.clear_recruit_mode()
	arena.enchant_active = true
	arena.enchant_forge_previews = _build_forge_previews()
	arena.prepare_slots = slots
	arena.enemy_slots = null
	arena.enemy_previews = []
	arena.sim = null
	arena.placement_active = false
	_rebuild_team_slots(slots, deck)
	arena.queue_redraw()


func clear_arena(arena: RealtimeArenaView) -> void:
	if arena == null:
		return
	arena.clear_enchant_mode()


func rebuild_team_slots(slots: PrepareSlotBoard, deck: DeckState) -> void:
	_rebuild_team_slots(slots, deck)


func _build_forge_previews() -> Array:
	var out: Array = []
	if _session == null:
		return out
	var board_size := Vector2i(5, 8)
	if _battle != null:
		board_size = _battle.get_board_size()
	var mid := BoardHalf.midline_row(board_size.y)
	var y := clampi(mid - 2, 0, mid - 1)
	var xs := [1, 2, 3]
	var labels := ["时机 A", "效果 B", "产出 C"]
	var ids := [_session.slot_a_entry_id, _session.slot_b_entry_id, -1]
	for i in 3:
		var entry: DeckEntry = null
		if i < 2 and ids[i] >= 0 and _session.deck != null:
			entry = _session.deck.get_entry(ids[i])
		elif i == 2 and _session.can_fuse():
			var preview := _session.preview_ability()
			if preview != null:
				entry = DeckEntry.new()
				entry.unit = EnchantFusionService.FUSED_UNIT
				entry.runtime_main_ability = preview
		out.append({
			"cell": Vector2i(xs[i], y),
			"label": labels[i],
			"entry": entry,
		})
	return out


func _rebuild_team_slots(slots: PrepareSlotBoard, deck: DeckState) -> void:
	var seat_rows := DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := DeckConfig.DEFAULT_SEAT_COLS
	if deck != null:
		var config := deck.get_config()
		if config != null:
			seat_rows = config.get_seat_rows()
			seat_cols = config.get_seat_cols()
	var board_size := Vector2i(5, 8)
	if _battle != null:
		board_size = _battle.get_board_size()
	slots.configure_grid(seat_rows, seat_cols, board_size, false, false)
	for entry in deck.get_entries():
		if entry == null:
			continue
		var seat_i := entry.seat_index
		if seat_i < 0 or seat_i >= slots.slot_count:
			seat_i = deck.find_first_empty_seat()
			if seat_i >= 0:
				deck.assign_seat(entry.entry_id, seat_i)
		if seat_i >= 0 and seat_i < slots.slot_count:
			slots.try_assign_with_seq(seat_i, entry, entry.seat_assign_seq)


func _ensure_hud() -> void:
	if _hud != null or _battle == null:
		return
	var dock := _battle.get_dock()
	if dock == null:
		return
	_hud = VBoxContainer.new()
	_hud.name = "EnchantHud"
	_hud.visible = false
	dock.add_child(_hud)
	_title = Label.new()
	_title.text = "附魔"
	_hud.add_child(_title)
	_slot_a = Label.new()
	_slot_a.text = "时机格 A：空"
	_hud.add_child(_slot_a)
	_slot_b = Label.new()
	_slot_b.text = "效果格 B：空"
	_hud.add_child(_slot_b)
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.text = ""
	_hud.add_child(_preview)
	_pick_list = ItemList.new()
	_pick_list.custom_minimum_size = Vector2(0, 120)
	_hud.add_child(_pick_list)
	var row := HBoxContainer.new()
	_hud.add_child(row)
	_btn_to_a = Button.new()
	_btn_to_a.text = "放入 A"
	_btn_to_a.pressed.connect(_on_put_a)
	row.add_child(_btn_to_a)
	_btn_to_b = Button.new()
	_btn_to_b.text = "放入 B"
	_btn_to_b.pressed.connect(_on_put_b)
	row.add_child(_btn_to_b)
	var row2 := HBoxContainer.new()
	_hud.add_child(row2)
	_btn_fuse = Button.new()
	_btn_fuse.text = "融合"
	_btn_fuse.pressed.connect(_on_fuse)
	row2.add_child(_btn_fuse)
	_btn_skip = Button.new()
	_btn_skip.text = "跳过"
	_btn_skip.pressed.connect(_on_skip)
	row2.add_child(_btn_skip)
	_btn_done = Button.new()
	_btn_done.text = "继续"
	_btn_done.pressed.connect(_on_done)
	row2.add_child(_btn_done)


func _refresh() -> void:
	_refresh_pick_list()
	if _session == null:
		return
	_slot_a.text = "时机格 A：%s" % _entry_label(_session.slot_a_entry_id)
	_slot_b.text = "效果格 B：%s" % _entry_label(_session.slot_b_entry_id)
	var preview_ab := _session.preview_ability()
	if preview_ab != null:
		_preview.text = UnitInfoText.get_ability_description(preview_ab, 1)
	else:
		_preview.text = ""
	_btn_fuse.disabled = not _session.can_fuse()
	_btn_done.disabled = not _session.fused_this_visit
	if _battle != null and _battle.get_arena() != null:
		_battle.get_arena().enchant_forge_previews = _build_forge_previews()
		_battle.get_arena().queue_redraw()


func _refresh_pick_list() -> void:
	if _pick_list == null or _session == null or _session.deck == null:
		return
	_pick_list.clear()
	for entry_id in _session.get_material_entry_ids():
		var entry := _session.deck.get_entry(entry_id)
		if entry == null:
			continue
		var stars := ""
		if entry.get_star_display_level() > 0:
			stars = " %d★" % entry.level
		_pick_list.add_item("%s%s" % [entry.get_display_name(), stars], null, false)


func _entry_label(entry_id: int) -> String:
	if _session == null or _session.deck == null or entry_id < 0:
		return "空"
	var entry := _session.deck.get_entry(entry_id)
	if entry == null:
		return "空"
	return entry.get_display_name()


func _selected_entry_id() -> int:
	if _pick_list == null or _session == null:
		return -1
	var idx := _pick_list.get_selected_items()
	if idx.is_empty():
		return -1
	var entry_ids := _session.get_material_entry_ids()
	var list_idx: int = idx[0]
	if list_idx < 0 or list_idx >= entry_ids.size():
		return -1
	return entry_ids[list_idx]


func _on_put_a() -> void:
	if _session == null:
		return
	_session.set_slot(&"a", _selected_entry_id())


func _on_put_b() -> void:
	if _session == null:
		return
	_session.set_slot(&"b", _selected_entry_id())


func _on_fuse() -> void:
	if _session == null:
		return
	var result := _session.try_fuse()
	if not result.get("ok", false):
		_battle.flash_hint("无法融合")
		return
	_battle.flash_hint("熔合成功")
	_refresh()
	if _battle != null:
		_battle.on_enchant_fused()


func _on_skip() -> void:
	if _session != null:
		_session.skip()


func _on_done() -> void:
	if _session != null:
		_session.finish_after_fuse()


func _on_session_changed() -> void:
	_refresh()
