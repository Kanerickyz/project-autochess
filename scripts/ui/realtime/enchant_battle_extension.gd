class_name EnchantBattleExtension
extends RefCounted
## 附魔神龛：选人 + 词条；底栏确认 / 跳过。


var _battle: RealtimeBattleController
var _session: EnchantSession
var _hud: Control
var _stats_label: Label
var _btn_confirm: Button
var _btn_skip: Button
var _expanded_team: bool = false


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


func set_expanded_team(enabled: bool) -> void:
	_expanded_team = enabled


func is_expanded_team() -> bool:
	return _expanded_team


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
	arena.enchant_forge_previews = _build_trait_previews()
	arena.prepare_slots = slots
	arena.enemy_slots = null
	arena.enemy_previews = []
	arena.sim = null
	arena.placement_active = false
	_rebuild_team_slots(slots, deck)
	if _expanded_team:
		arena.enchant_team_scroll_enabled = true
		arena.enchant_team_max_scroll_rows = EnchantLayout.expanded_team_max_scroll_rows(
			arena.board_size,
			deck.size(),
		)
	else:
		arena.enchant_team_scroll_enabled = false
		arena.enchant_team_max_scroll_rows = 0.0
		arena.enchant_team_scroll_rows = 0.0
	arena.queue_redraw()


func clear_arena(arena: RealtimeArenaView) -> void:
	if arena == null:
		return
	arena.clear_enchant_mode()


func rebuild_team_slots(slots: PrepareSlotBoard, deck: DeckState) -> void:
	_rebuild_team_slots(slots, deck)


func _build_trait_previews() -> Array:
	var out: Array = []
	if _session == null:
		return out
	var board_size := Vector2i(5, 8)
	if _battle != null:
		board_size = _battle.get_board_size()
	var slot_cells := EnchantLayout.forge_slot_cells(board_size)
	for i in mini(EnchantTraitCatalog.OFFER_COUNT, slot_cells.size()):
		var label := "—"
		if i < _session.trait_offers.size():
			var row: Dictionary = _session.trait_offers[i]
			label = str(row.get("name", "?"))
		var selected := _session.selected_trait_index == i
		if selected:
			label = "✓ " + label
		out.append({
			"cell": slot_cells[i],
			"label": label,
			"entry": null,
			"trait_index": i,
		})
	return out


func _rebuild_team_slots(slots: PrepareSlotBoard, deck: DeckState) -> void:
	var board_size := Vector2i(5, 8)
	if _battle != null:
		board_size = _battle.get_board_size()
	if _expanded_team:
		var cells := EnchantLayout.build_expanded_team_cells(board_size, deck.size())
		slots.configure_custom_cells(cells)
		var i := 0
		for entry in deck.get_entries():
			if entry == null:
				continue
			if i < slots.slot_count:
				slots.try_assign_with_seq(i, entry, entry.seat_assign_seq)
				i += 1
		return
	var seat_rows := DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := DeckConfig.DEFAULT_SEAT_COLS
	if deck != null:
		var config := deck.get_config()
		if config != null:
			seat_rows = config.get_seat_rows()
			seat_cols = config.get_seat_cols()
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
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hud.add_child(_stats_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud.add_child(row)
	_btn_confirm = Button.new()
	_btn_confirm.text = "确认附魔"
	_btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_confirm.pressed.connect(_on_confirm)
	row.add_child(_btn_confirm)
	_btn_skip = Button.new()
	_btn_skip.text = "跳过"
	_btn_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_skip.pressed.connect(_on_skip)
	row.add_child(_btn_skip)


func _refresh() -> void:
	if _session == null:
		return
	_btn_confirm.disabled = not _session.can_confirm()
	_btn_skip.disabled = _session.confirmed_this_visit
	_stats_label.text = _format_stats_line()
	if _battle != null and _battle.get_arena() != null:
		var arena := _battle.get_arena()
		arena.enchant_forge_previews = _build_trait_previews()
		if _expanded_team and _session.deck != null:
			arena.enchant_team_max_scroll_rows = EnchantLayout.expanded_team_max_scroll_rows(
				arena.board_size,
				_session.deck.size(),
			)
		arena.queue_redraw()


func _format_stats_line() -> String:
	if _session == null:
		return ""
	if _session.confirmed_this_visit:
		return "已附魔 · 点确认附魔后结束（或等待自动）"
	var parts: PackedStringArray = []
	parts.append("上：点词条 · 下：点队员")
	if _session.selected_trait_index >= 0:
		parts.append("已选词条")
	if _session.selected_entry_id >= 0:
		parts.append("已选队员")
	return " · ".join(parts)


func _on_confirm() -> void:
	if _session == null:
		return
	if not _session.confirmed_this_visit:
		var result := _session.try_confirm()
		if not result.get("ok", false):
			if _battle != null:
				_battle.flash_hint("请选择队员与词条")
			return
		if _battle != null:
			_battle.flash_hint("附魔已写入")
	_session.finish_after_confirm()
	_refresh()


func _on_skip() -> void:
	if _session != null:
		_session.skip()


func _on_session_changed() -> void:
	_refresh()
	if _battle != null and _session != null and _session.is_active:
		_battle.on_enchant_forge_changed()