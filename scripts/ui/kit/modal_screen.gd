class_name ModalScreen
extends Control
## 重流程浮层（事件全文、败北结算、设置）：近全屏；必须有明确退出。
## 样式复用 KitPopupPanel + COLOR_DIM；内容由调用方塞进 ContentHost。
##
## 用法：
##   var modal := ModalScreen.new()
##   add_child(modal)
##   modal.set_title("设置")
##   modal.content_host.add_child(my_settings_ui)
##   modal.closed.connect(_on_closed)
##   modal.open()

signal closed

@export var dismiss_on_dim: bool = false
@export var show_close_button: bool = true

var dim: ColorRect
var panel: PanelContainer
var title_label: Label
var content_host: MarginContainer
var close_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_if_needed()


func _build_if_needed() -> void:
	if dim != null:
		return
	UiKit.apply_shell_theme(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = UiKit.COLOR_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = UiKit.make_popup_panel()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(520, 360)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)

	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 22)
	header.add_child(title_label)

	close_button = UiKit.make_icon_button("×")
	close_button.visible = show_close_button
	close_button.pressed.connect(close)
	header.add_child(close_button)

	content_host = MarginContainer.new()
	content_host.name = "ContentHost"
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(content_host)


func set_title(text: String) -> void:
	_build_if_needed()
	title_label.text = text


func open() -> void:
	_build_if_needed()
	close_button.visible = show_close_button
	visible = true
	move_to_front()
	if play_motion_safe():
		UiMotion.tween_panel_show(panel, true)


func close() -> void:
	visible = false
	closed.emit()


func play_motion_safe() -> bool:
	return panel != null and is_inside_tree()


func _on_dim_gui_input(event: InputEvent) -> void:
	if not dismiss_on_dim:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()
			accept_event()
