class_name EquipmentDetailPanel
extends Control
## 角色装备详情：槽位空/实格、缩略图、合计护甲、卸载；旁列队伍暂存可挂装。
## 最小可用 Control 弹层（轻量验收）。

signal closed
signal unequip_requested(entry_id: int, slot_index: int)
signal equip_from_stash_requested(stash_index: int, entry_id: int)

var _entry_id: int = -1
var _readonly: bool = false
var _deck: DeckState = null

var _root: PanelContainer
var _title: Label
var _stats: Label
var _armor_label: Label
var _slots_row: HBoxContainer
var _stash_row: HBoxContainer
var _hint: Label
var _close_btn: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(420, 320)
	_root.position = Vector2(-210, -160)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.2, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(0.75, 0.7, 0.45, 0.9)
	style.set_content_margin_all(12)
	_root.add_theme_stylebox_override("panel", style)
	add_child(_root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_root.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 18)
	head.add_child(_title)
	_close_btn = Button.new()
	_close_btn.text = "关闭"
	_close_btn.pressed.connect(hide_panel)
	head.add_child(_close_btn)

	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 13)
	col.add_child(_stats)

	_armor_label = Label.new()
	_armor_label.add_theme_font_size_override("font_size", 13)
	_armor_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	col.add_child(_armor_label)

	var slots_title := Label.new()
	slots_title.text = "装备槽"
	slots_title.add_theme_font_size_override("font_size", 12)
	col.add_child(slots_title)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	col.add_child(_slots_row)

	var stash_title := Label.new()
	stash_title.text = "队伍装备暂存"
	stash_title.add_theme_font_size_override("font_size", 12)
	col.add_child(stash_title)
	_stash_row = HBoxContainer.new()
	_stash_row.add_theme_constant_override("separation", 6)
	col.add_child(_stash_row)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	col.add_child(_hint)


func show_for_entry(deck: DeckState, entry_id: int, readonly: bool = false) -> void:
	_deck = deck
	_entry_id = entry_id
	_readonly = readonly
	_refresh()
	visible = true
	move_to_front()


func hide_panel() -> void:
	visible = false
	_entry_id = -1
	closed.emit()


func is_open() -> bool:
	return visible


func get_entry_id() -> int:
	return _entry_id


func set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


func refresh() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_clear_row(_slots_row)
	_clear_row(_stash_row)
	if _deck == null:
		return
	var entry := _deck.get_entry(_entry_id)
	if entry == null:
		_title.text = "角色已离开"
		_stats.text = ""
		_armor_label.text = ""
		_hint.text = ""
		return
	var stars := entry.get_star_display_level()
	var star_txt := ""
	if stars > 0:
		star_txt = " · %d★" % stars
	_title.text = "%s%s" % [entry.get_display_name(), star_txt]
	var atk := DeckUpgradeService.get_display_attack(entry)
	var hp := DeckUpgradeService.get_display_max_hp(entry)
	var bond := ""
	if entry.unit != null:
		bond = UnitData.theme_bond_label(entry.unit.theme_bond)
	_stats.text = "攻 %d · 生命 %d%s" % [atk, hp, (" · " + bond) if not bond.is_empty() else ""]
	var armor := entry.get_armor_block()
	var armor_max := entry.equipment_armor_max
	if armor_max <= 0:
		armor_max = armor
	if armor_max > 0:
		_armor_label.text = "合计护甲 %d / %d" % [armor, armor_max]
	else:
		_armor_label.text = "合计护甲 0（无装备）"

	var slot_cap := entry.get_equipment_slot_count()
	for i in slot_cap:
		_slots_row.add_child(_make_slot_cell(entry, i))
	if slot_cap <= 0:
		var none := Label.new()
		none.text = "本角色 0 槽，无法挂装"
		_slots_row.add_child(none)

	var stash := _deck.get_equipment_stash()
	var cap := _deck.get_equipment_stash_capacity()
	for i in stash.size():
		_stash_row.add_child(_make_stash_cell(i, stash[i], entry))
	var empty_slots := maxi(0, cap - stash.size())
	for _j in mini(empty_slots, 4):
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(56, 56)
		var es := StyleBoxFlat.new()
		es.bg_color = Color(0.18, 0.2, 0.24, 0.8)
		es.set_border_width_all(1)
		es.border_color = Color(0.35, 0.38, 0.42)
		empty.add_theme_stylebox_override("panel", es)
		var el := Label.new()
		el.text = "空"
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(el)
		_stash_row.add_child(empty)
	if _readonly:
		_hint.text = "开战只读：不可卸载 / 挂装"
	else:
		_hint.text = "卸载进暂存；点暂存件挂到本角色空槽"


func _make_slot_cell(entry: DeckEntry, index: int) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(96, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.24, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.55, 0.65)
	cell.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(col)
	var eq := entry.get_equipment_at(index)
	if eq == null:
		var empty := Label.new()
		empty.text = "空槽"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(empty)
		return cell
	var icon := eq.get_icon()
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(tr)
	var name_l := Label.new()
	name_l.text = eq.get_display_name()
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 11)
	col.add_child(name_l)
	var detail_l := Label.new()
	if eq.is_ability_kind():
		detail_l.text = "技能"
	else:
		detail_l.text = "甲 %d" % eq.get_armor_block()
	detail_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_l.add_theme_font_size_override("font_size", 11)
	col.add_child(detail_l)
	if not _readonly:
		var btn := Button.new()
		btn.text = "卸载"
		btn.add_theme_font_size_override("font_size", 11)
		var slot_i := index
		btn.pressed.connect(func() -> void: unequip_requested.emit(_entry_id, slot_i))
		col.add_child(btn)
	return cell


func _make_stash_cell(stash_index: int, eq: EquipmentData, entry: DeckEntry) -> Control:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(72, 72)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.18, 0.14, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.7, 0.6, 0.35)
	cell.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(col)
	if eq == null:
		var empty := Label.new()
		empty.text = "?"
		col.add_child(empty)
		return cell
	var icon := eq.get_icon()
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(tr)
	var name_l := Label.new()
	name_l.text = eq.get_display_name()
	name_l.add_theme_font_size_override("font_size", 10)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	if not _readonly and entry != null and entry.has_empty_equipment_slot():
		var btn := Button.new()
		btn.text = "挂上"
		btn.add_theme_font_size_override("font_size", 10)
		var si := stash_index
		btn.pressed.connect(func() -> void: equip_from_stash_requested.emit(si, _entry_id))
		col.add_child(btn)
	elif _readonly:
		pass
	else:
		var full := Label.new()
		full.text = "目标满槽"
		full.add_theme_font_size_override("font_size", 10)
		col.add_child(full)
	return cell


func _clear_row(row: HBoxContainer) -> void:
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			hide_panel()
