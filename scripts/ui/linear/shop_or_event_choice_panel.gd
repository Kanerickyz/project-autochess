class_name ShopOrEventChoicePanel
extends Control
## 战后商店或事件二选一（主模式线性远征）。
## 样式走 UiKit / GamePopup，禁止私建 StyleBoxFlat。

signal choice_made(choice: StringName)

const CHOICE_SHOP := &"shop"
const CHOICE_EVENT := &"event"

var _popup: GamePopup


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_full_rect()
	_ensure_popup()


func _apply_full_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _ensure_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		return
	_popup = UiKit.instantiate_popup()
	_popup.name = "ChoicePopup"
	## 必须二选一，点遮罩不关闭。
	_popup.dismiss_on_dim = false
	_popup.configure(
		"战后选择",
		"选择商店或事件，完成后进入主题招募。",
		"商店",
		"事件",
	)
	_popup.primary_pressed.connect(_on_shop)
	_popup.secondary_pressed.connect(_on_event)
	add_child(_popup)


func show_choice() -> void:
	_apply_full_rect()
	_ensure_popup()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()
	if _popup != null:
		_popup.open()


func hide_choice() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.close(false)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_shop() -> void:
	hide_choice()
	choice_made.emit(CHOICE_SHOP)


func _on_event() -> void:
	hide_choice()
	choice_made.emit(CHOICE_EVENT)
