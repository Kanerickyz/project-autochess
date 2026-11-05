class_name ShopOrEventChoicePanel
extends Control
## 战后商店或事件二选一（主模式线性远征）。

signal choice_made(choice: StringName)

const CHOICE_SHOP := &"shop"
const CHOICE_EVENT := &"event"

var _panel: PanelContainer
var _shop_btn: Button
var _event_btn: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(420, 220)
	_panel.offset_left = -210
	_panel.offset_top = -110
	_panel.offset_right = 210
	_panel.offset_bottom = 110
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.12, 0.96)
	style.set_content_margin_all(16.0)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

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
	visible = true
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
