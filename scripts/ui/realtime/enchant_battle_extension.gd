class_name EnchantBattleExtension
extends RefCounted
## 附魔阶段：Arena 拖拽 + 底栏（重置 / 随机 / 融合 / 跳过 / 继续）。


var _battle: RealtimeBattleController
var _session: EnchantSession
var _hud: Control
var _stats_label: Label
var _btn_reset: Button
var _btn_random: Button
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
		elif i == 2:
			entry = _session.build_preview_fused_entry()
		out.append({
			"cell": slot_cells[i],
			"label": labels[i],
			"entry": entry,
		})
	return out


func _entry_on_forge(entry_id: int) -> bool:
	if _session == null or entry_id < 0:
		return false
	return entry_id == _session.slot_a_entry_id or entry_id == _session.slot_b_entry_id


func _rebuild_team_slots(slots: PrepareSlotBoard, deck: DeckState) -> void:
	var board_size := Vector2i(5, 8)
	if _battle != null:
		board_size = _battle.get_board_size()
	if _expanded_team:
		var cells := EnchantLayout.build_expanded_team_cells(board_size, deck.size())
		slots.configure_custom_cells(cells)
		var i := 0
		for entry in deck.get_entries():
			if entry == null or _entry_on_forge(entry.entry_id):
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
		if entry == null or _entry_on_forge(entry.entry_id):
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
	_btn_reset = Button.new()
	_btn_reset.text = "重置"
	_btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_reset.pressed.connect(_on_reset)
	row.add_child(_btn_reset)
	_btn_random = Button.new()
	_btn_random.text = "随机"
	_btn_random.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_random.pressed.connect(_on_random)
	row.add_child(_btn_random)
	_btn_fuse = Button.new()
	_btn_fuse.text = "融合"
	_btn_fuse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_fuse.pressed.connect(_on_fuse)
	row.add_child(_btn_fuse)
	_btn_skip = Button.new()
	_btn_skip.text = "跳过"
	_btn_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_skip.pressed.connect(_on_skip)
	row.add_child(_btn_skip)
	_btn_continue = Button.new()
	_btn_continue.text = "继续"
	_btn_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_continue.pressed.connect(_on_continue)
	row.add_child(_btn_continue)


func _refresh() -> void:
	if _session == null:
		return
	_btn_fuse.disabled = not _session.can_fuse()
	_btn_reset.disabled = _session.fused_this_visit
	## 随机仅试验场：满池滚列表时快速试配方。
	if _btn_random != null:
		_btn_random.visible = _expanded_team
		_btn_random.disabled = (
			_session.fused_this_visit
			or _session.get_material_entry_ids().size() < 2
		)
	_btn_skip.disabled = _session.fused_this_visit
	_btn_continue.disabled = not _session.fused_this_visit
	_stats_label.text = _format_stats_line()
	if _battle != null and _battle.get_arena() != null:
		var arena := _battle.get_arena()
		arena.enchant_forge_previews = _build_forge_previews()
		if _expanded_team and _session.deck != null:
			arena.enchant_team_max_scroll_rows = EnchantLayout.expanded_team_max_scroll_rows(
				arena.board_size,
				_session.deck.size(),
			)
		arena.queue_redraw()


func _format_stats_line() -> String:
	if _session == null:
		return ""
	var rate := _session.get_success_percent()
	if not _session.can_fuse():
		return "放入 A/B 后可融合 · 成功率 %.0f%%" % rate
	return "成功率 %.0f%% · 点融合检定（失败失去 A/B）" % rate


func _on_reset() -> void:
	if _session == null:
		return
	_session.reset_forge()
	if _battle != null:
		_battle.on_enchant_forge_changed()
	_refresh()


func _on_random() -> void:
	if _session == null or not _expanded_team:
		return
	if not _session.randomize_ab_slots():
		if _battle != null:
			_battle.flash_hint("可用原料不足两人")
		return
	if _battle != null:
		_battle.on_enchant_forge_changed()
	_refresh()


func _on_fuse() -> void:
	if _session == null:
		return
	var result := _session.try_fuse()
	if not result.get("ok", false):
		_battle.flash_hint("无法融合")
		return
	if result.get("success", false):
		_battle.flash_hint("熔合成功")
	else:
		_battle.flash_hint("熔合失败")
	_refresh()
	if _battle != null:
		_battle.on_enchant_forge_changed()


func _on_skip() -> void:
	if _session != null:
		_session.skip()


func _on_continue() -> void:
	if _session != null:
		_session.finish_after_fuse()


func _on_session_changed() -> void:
	_refresh()
	if _battle != null and _session != null and _session.is_active:
		_battle.on_enchant_forge_changed()
