class_name ShopOrEventChoicePanel
extends Control
## 战后商店或事件二选一（主模式线性远征）。
## 布局对齐 RunEndOverlay：全屏遮罩 + CenterContainer 居中面板。

signal choice_made(choice: StringName)

const CHOICE_SHOP := &"shop"
const CHOICE_EVENT := &"event"

var _shop_btn: Button
var _event_btn: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_full_rect()
	_build_ui()


func _apply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.04, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dim.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(420, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.12, 0.96)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "战后选择"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var tip := Label.new()
	tip.text = "选择商店或事件，完成后进入主题招募。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	_shop_btn = Button.new()
	_shop_btn.text = "商店"
	_shop_btn.custom_minimum_size = Vector2(160, 48)
	_shop_btn.pressed.connect(_on_shop)
	row.add_child(_shop_btn)

	_event_btn = Button.new()
	_event_btn.text = "事件"
	_event_btn.custom_minimum_size = Vector2(160, 48)
	_event_btn.pressed.connect(_on_event)
	row.add_child(_event_btn)


func show_choice() -> void:
	_apply_full_rect()
	visible = true
	move_to_front()
	if _shop_btn != null:
		_shop_btn.grab_focus()


func hide_choice() -> void:
	visible = false


func _on_shop() -> void:
	hide_choice()
	choice_made.emit(CHOICE_SHOP)


func _on_event() -> void:
	hide_choice()
	choice_made.emit(CHOICE_EVENT)
