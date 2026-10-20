class_name EnchantBattleExtension
extends RefCounted
## 附魔阶段：Arena 拖拽 + 底栏三钮（融合 / 跳过 / 继续）。


var _battle: RealtimeBattleController
var _session: EnchantSession
var _hud: Control
var _btn_fuse: Button
var _btn_skip: Button
var _btn_continue: Button
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


func _build_forge_previews() -> Array:
	var out: Array = []
	if _session == null:
		return out
	var board_size := Vector2i(5, 8)
	if _battle != null:
		board_size = _battle.get_board_size()
	var slot_cells := EnchantLayout.forge_slot_cells(board_size)
	var labels := ["时机 A", "效果 B", "产出 C"]
	var ids := [_session.slot_a_entry_id, _session.slot_b_entry_id, -1]
	for i in mini(3, slot_cells.size()):
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
			"cell": slot_cells[i],
			"label": labels[i],
			"entry": entry,
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
	_hud = HBoxContainer.new()
	_hud.name = "EnchantHud"
	_hud.visible = false
	_hud.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_child(_hud)
	_btn_fuse = Button.new()
	_btn_fuse.text = "融合"
	_btn_fuse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_fuse.pressed.connect(_on_fuse)
	_hud.add_child(_btn_fuse)
	_btn_skip = Button.new()
	_btn_skip.text = "跳过"
	_btn_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_skip.pressed.connect(_on_skip)
	_hud.add_child(_btn_skip)
	_btn_continue = Button.new()
	_btn_continue.text = "继续"
	_btn_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_continue.pressed.connect(_on_continue)
	_hud.add_child(_btn_continue)


func _refresh() -> void:
	if _session == null:
		return
	_btn_fuse.disabled = not _session.can_fuse()
	_btn_skip.disabled = _session.fused_this_visit
	_btn_continue.disabled = not _session.fused_this_visit
	if _battle != null and _battle.get_arena() != null:
		var arena := _battle.get_arena()
		arena.enchant_forge_previews = _build_forge_previews()
		if _expanded_team and _session.deck != null:
			arena.enchant_team_max_scroll_rows = EnchantLayout.expanded_team_max_scroll_rows(
				arena.board_size,
				_session.deck.size(),
			)
		arena.queue_redraw()


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


func _on_continue() -> void:
	if _session != null:
		_session.finish_after_fuse()


func _on_session_changed() -> void:
	_refresh()
