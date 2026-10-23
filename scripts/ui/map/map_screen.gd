class_name MapScreen
extends Control

signal node_selected(node_id: int)

const FADE_SECONDS := 0.28

@onready var _map_view: MapView = %MapView
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _world_bg: TextureRect = %WorldBackground
@onready var _scrim: ColorRect = %Scrim

var _fade_tween: Tween


func _ready() -> void:
	_map_view.node_selected.connect(_on_node_selected)
	modulate.a = 1.0


func show_map(run_controller: RunController, hint_override: String = "") -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _world_bg != null:
		_world_bg.visible = true
	if _scrim != null:
		_scrim.visible = true
	if run_controller != null and run_controller.map_config != null:
		_title_label.text = run_controller.map_config.act_display_name
	else:
		_title_label.text = "远征地图"
	_hint_label.text = (
		hint_override if not hint_override.is_empty() else "选择一条路径前进"
	)
	if run_controller != null:
		_map_view.set_map_state(run_controller.get_map_state())
	_fade_to(1.0, true)


func hide_map() -> void:
	## 立刻关交互；淡出后真正 invisible，减轻「黑屏跳转」感。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_to(0.0, false)


func refresh_map(run_controller: RunController) -> void:
	if run_controller != null:
		_map_view.set_map_state(run_controller.get_map_state())


func _fade_to(target_alpha: float, keep_visible_when_done: bool) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if keep_visible_when_done:
		visible = true
	_fade_tween = create_tween()
	_fade_tween.set_parallel(false)
	_fade_tween.tween_property(self, "modulate:a", target_alpha, FADE_SECONDS).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	if not keep_visible_when_done:
		_fade_tween.tween_callback(func() -> void:
			visible = false
			modulate.a = 1.0
		)


func _on_node_selected(node_id: int) -> void:
	node_selected.emit(node_id)
