class_name GamePopup
extends Control
## 轻量 Popup（二选一 / 轻确认）。
## - 半透明遮罩（UiKit.COLOR_DIM）
## - 主按钮右/下、次按钮左/上
## - `dismiss_on_dim` 控制点遮罩是否关闭（毁灭性确认可关）
##
## 用法：
##   var popup := UiKit.instantiate_popup()
##   add_child(popup)
##   popup.configure("战后选择", "选择商店或事件", "商店", "事件")
##   popup.primary_pressed.connect(_on_shop)
##   popup.secondary_pressed.connect(_on_event)
##   popup.open()

signal primary_pressed
signal secondary_pressed
signal dismissed

@export var dismiss_on_dim: bool = true
@export var play_motion: bool = true

@onready var _dim: ColorRect = %Dim
@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _button_row: HBoxContainer = %ButtonRow
@onready var _secondary_button: Button = %SecondaryButton
@onready var _primary_button: Button = %PrimaryButton
@onready var _content_slot: MarginContainer = %ContentSlot

var _active_tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_full_rect()
	UiKit.apply_shell_theme(self)
	if _panel != null:
		UiKit.apply_variation(_panel, UiKit.VAR_POPUP_PANEL)
	if _dim != null:
		_dim.color = UiKit.COLOR_DIM
		_dim.gui_input.connect(_on_dim_gui_input)
	if _primary_button != null:
		UiKit.apply_variation(_primary_button, UiKit.VAR_PRIMARY)
		_primary_button.custom_minimum_size = UiKit.BUTTON_MIN_PRIMARY
		_primary_button.pressed.connect(_on_primary)
	if _secondary_button != null:
		UiKit.apply_variation(_secondary_button, UiKit.VAR_SECONDARY)
		_secondary_button.custom_minimum_size = UiKit.BUTTON_MIN_SECONDARY
		_secondary_button.pressed.connect(_on_secondary)
	_ensure_button_order()


## title/body 文案；primary 在右，secondary 在左。空 secondary 则隐藏次按钮。
func configure(
	title: String,
	body: String = "",
	primary_text: String = "确定",
	secondary_text: String = "取消",
) -> void:
	_resolve_nodes()
	if _title_label != null:
		_title_label.text = title
		_title_label.visible = not title.is_empty()
	if _body_label != null:
		_body_label.text = body
		_body_label.visible = not body.is_empty()
	if _primary_button != null:
		_primary_button.text = primary_text
		_primary_button.visible = not primary_text.is_empty()
	if _secondary_button != null:
		_secondary_button.text = secondary_text
		_secondary_button.visible = not secondary_text.is_empty()
	_ensure_button_order()


## 可选：往 ContentSlot 塞自定义内容（列表、图标等）。
func set_custom_content(node: Control) -> void:
	if _content_slot == null or node == null:
		return
	for child in _content_slot.get_children():
		child.queue_free()
	_content_slot.add_child(node)
	_content_slot.visible = true


func open() -> void:
	_apply_full_rect()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()
	if play_motion and _panel != null:
		_kill_tween()
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.96, 0.96)
		_panel.pivot_offset = _panel.size * 0.5
		_active_tween = create_tween()
		_active_tween.set_parallel(true)
		_active_tween.set_ease(Tween.EASE_OUT)
		_active_tween.set_trans(Tween.TRANS_CUBIC)
		_active_tween.tween_property(_panel, "modulate:a", 1.0, UiMotion.PANEL_FADE_SEC)
		_active_tween.tween_property(_panel, "scale", Vector2.ONE, UiMotion.PANEL_FADE_SEC)
	if _primary_button != null and _primary_button.visible:
		_primary_button.grab_focus()


func close(emit_dismissed: bool = true) -> void:
	_kill_tween()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if emit_dismissed:
		dismissed.emit()


func get_primary_button() -> Button:
	_resolve_nodes()
	return _primary_button


func get_secondary_button() -> Button:
	_resolve_nodes()
	return _secondary_button


func get_panel() -> PanelContainer:
	_resolve_nodes()
	return _panel


func _resolve_nodes() -> void:
	if _dim == null:
		_dim = get_node_or_null("%Dim") as ColorRect
	if _panel == null:
		_panel = get_node_or_null("%Panel") as PanelContainer
	if _title_label == null:
		_title_label = get_node_or_null("%TitleLabel") as Label
	if _body_label == null:
		_body_label = get_node_or_null("%BodyLabel") as Label
	if _button_row == null:
		_button_row = get_node_or_null("%ButtonRow") as HBoxContainer
	if _secondary_button == null:
		_secondary_button = get_node_or_null("%SecondaryButton") as Button
	if _primary_button == null:
		_primary_button = get_node_or_null("%PrimaryButton") as Button
	if _content_slot == null:
		_content_slot = get_node_or_null("%ContentSlot") as MarginContainer


## 契约：横向时次左主右；若改为竖排则次上主下。
func _ensure_button_order() -> void:
	_resolve_nodes()
	if _button_row == null or _primary_button == null or _secondary_button == null:
		return
	var secondary_i := _secondary_button.get_index()
	var primary_i := _primary_button.get_index()
	if secondary_i > primary_i:
		_button_row.move_child(_secondary_button, primary_i)


func _apply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _on_dim_gui_input(event: InputEvent) -> void:
	if not dismiss_on_dim:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close(true)
			accept_event()


func _on_primary() -> void:
	primary_pressed.emit()


func _on_secondary() -> void:
	secondary_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not dismiss_on_dim:
		return
	if event.is_action_pressed("ui_cancel"):
		close(true)
		get_viewport().set_input_as_handled()


func _kill_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
