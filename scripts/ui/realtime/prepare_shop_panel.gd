class_name PrepareShopPanel
extends VBoxContainer
## 准备商店功能 UI：上行角色 5 槽、下行道具；点击购买；道具可拖拽。

signal character_pressed(slot_index: int)
signal item_pressed(slot_index: int)
signal item_drag_started(slot_index: int)

const ITEM_DRAG_KEY := "rt_prepare_item_slot"

var _char_row: HBoxContainer
var _item_row: HBoxContainer
var _title: Label
var _hint: Label
var _char_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _pending_item_slot: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 4)
	_title = Label.new()
	_title.text = "准备商店"
	_title.add_theme_font_size_override("font_size", 12)
	add_child(_title)
	_char_row = HBoxContainer.new()
	_char_row.add_theme_constant_override("separation", 4)
	_char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_char_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_char_row)
	_item_row = HBoxContainer.new()
	_item_row.add_theme_constant_override("separation", 4)
	_item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_item_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_item_row)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.modulate = Color(1.0, 0.85, 0.55)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	custom_minimum_size.y = 96


func set_pending_item_slot(slot_index: int) -> void:
	_pending_item_slot = slot_index
	_refresh_pending_visual()


func get_pending_item_slot() -> int:
	return _pending_item_slot


func clear_pending_item() -> void:
	_pending_item_slot = -1
	_refresh_pending_visual()


func set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text


func bind_offers(
	characters: Array,
	items: Array,
	gold: int,
	roster_full: bool,
	service: PrepareShopService,
) -> void:
	_ensure_char_buttons(characters.size())
	_ensure_item_buttons(items.size())
	for i in _char_buttons.size():
		var btn := _char_buttons[i]
		var unit: UnitData = characters[i] if i < characters.size() else null
		if unit == null:
			btn.text = "空"
			btn.disabled = true
			btn.modulate = Color(0.55, 0.55, 0.55)
			continue
		var cost := service.get_character_cost(unit) if service != null else unit.cost
		var name := unit.display_name if not unit.display_name.is_empty() else unit.id
		btn.text = "%s\n%d金" % [name, cost]
		var afford := gold >= cost and not roster_full
		btn.disabled = not afford
		btn.modulate = Color.WHITE if afford else Color(0.7, 0.45, 0.45)
	for i in _item_buttons.size():
		var btn2 := _item_buttons[i]
		var item: PrepareItemData = items[i] if i < items.size() else null
		if item == null:
			btn2.text = "空"
			btn2.disabled = true
			btn2.modulate = Color(0.55, 0.55, 0.55)
			btn2.set_meta("item_slot", i)
			continue
		var cost2 := service.get_item_cost(item) if service != null else item.cost
		btn2.text = "%s\n%d金" % [item.get_display_name(), cost2]
		var afford2 := gold >= cost2
		btn2.disabled = not afford2
		btn2.modulate = Color.WHITE if afford2 else Color(0.7, 0.45, 0.45)
		btn2.set_meta("item_slot", i)
	_refresh_pending_visual()


func _ensure_char_buttons(count: int) -> void:
	while _char_buttons.size() < count:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 44)
		btn.clip_text = true
		var idx := _char_buttons.size()
		btn.pressed.connect(_on_char_pressed.bind(idx))
		_char_row.add_child(btn)
		_char_buttons.append(btn)
	for i in _char_buttons.size():
		_char_buttons[i].visible = i < count


func _ensure_item_buttons(count: int) -> void:
	while _item_buttons.size() < count:
		var btn := _PrepareItemButton.new()
		btn.custom_minimum_size = Vector2(88, 44)
		btn.clip_text = true
		var idx := _item_buttons.size()
		btn.slot_index = idx
		btn.pressed.connect(_on_item_pressed.bind(idx))
		btn.drag_begun.connect(_on_item_drag.bind(idx))
		_item_row.add_child(btn)
		_item_buttons.append(btn)
	for i in _item_buttons.size():
		_item_buttons[i].visible = i < count


func _on_char_pressed(index: int) -> void:
	character_pressed.emit(index)


func _on_item_pressed(index: int) -> void:
	item_pressed.emit(index)


func _on_item_drag(index: int) -> void:
	item_drag_started.emit(index)


func _refresh_pending_visual() -> void:
	for i in _item_buttons.size():
		var btn := _item_buttons[i]
		if not btn.visible or btn.disabled:
			continue
		if i == _pending_item_slot:
			btn.modulate = Color(1.0, 0.92, 0.45)
		elif btn.modulate.is_equal_approx(Color(1.0, 0.92, 0.45)):
			btn.modulate = Color.WHITE


## 可拖拽的道具按钮（药水拖到己方座位）。
class _PrepareItemButton:
	extends Button

	signal drag_begun(slot_index: int)

	var slot_index: int = -1

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if disabled:
			return null
		var preview := Label.new()
		preview.text = text.replace("\n", " ")
		preview.modulate = Color(1, 1, 1, 0.9)
		set_drag_preview(preview)
		drag_begun.emit(slot_index)
		return {
			PrepareShopPanel.ITEM_DRAG_KEY: slot_index,
			"label": text,
		}
