class_name MainMenuParallaxBackground
extends Control
## 主菜单动态背景：双色深色正方形棋盘格 Shader，自右上向左下漂移 + 轻微指针视差（Tween 平滑）。

const BACKGROUND_SHADER := preload("res://assets/ui/main_menu/main_menu_background.gdshader")

const PARALLAX_STRENGTH := 18.0
## 较原 0.038 加快 20%。
const SCROLL_SPEED := 0.0456
const SCROLL_RAMP_DURATION := 1.05
const PARALLAX_TWEEN_DURATION := 0.32
const PARALLAX_RETARGET_DISTANCE := 1.25
## 棋盘绕屏幕中心旋转（弧度），减轻正对屏幕的方正感。
const GRID_ROTATION_RAD := -0.22

const _SCROLL_DIR := Vector2(-0.70710678118, 0.70710678118)

var _bg: ColorRect
var _material: ShaderMaterial
var _scroll_offset := Vector2.ZERO
var _scroll_speed_current := 0.0
var _parallax_display := Vector2.ZERO
var _parallax_tween_goal := Vector2.ZERO
var _scroll_ramp_tween: Tween
var _parallax_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layers()
	_update_viewport_aspect()
	resized.connect(_update_viewport_aspect)
	_start_scroll_ramp()


func _exit_tree() -> void:
	_kill_tweens()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_viewport_aspect()


func _build_layers() -> void:
	_material = ShaderMaterial.new()
	_material.shader = BACKGROUND_SHADER
	_material.set_shader_parameter("grid_rotation", GRID_ROTATION_RAD)

	_bg = ColorRect.new()
	_bg.name = "ShaderBackground"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = Color(0.07, 0.08, 0.11)
	_bg.material = _material
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)


func _start_scroll_ramp() -> void:
	_scroll_speed_current = 0.0
	if _scroll_ramp_tween != null and _scroll_ramp_tween.is_valid():
		_scroll_ramp_tween.kill()
	_scroll_ramp_tween = create_tween()
	_scroll_ramp_tween.tween_property(self, "_scroll_speed_current", SCROLL_SPEED, SCROLL_RAMP_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_viewport_aspect() -> void:
	if _material == null:
		return
	var size := get_viewport_rect().size
	if size.y <= 1.0:
		return
	_material.set_shader_parameter("viewport_aspect", size.x / size.y)


func _process(delta: float) -> void:
	if _material == null:
		return
	_scroll_offset += _SCROLL_DIR * _scroll_speed_current * delta
	_material.set_shader_parameter("scroll_offset", _scroll_offset)

	var parallax_target := _pointer_parallax_offset() * PARALLAX_STRENGTH
	if parallax_target.distance_to(_parallax_tween_goal) >= PARALLAX_RETARGET_DISTANCE:
		_parallax_tween_goal = parallax_target
		if _parallax_tween != null and _parallax_tween.is_valid():
			_parallax_tween.kill()
		_parallax_tween = create_tween()
		_parallax_tween.tween_property(self, "_parallax_display", parallax_target, PARALLAX_TWEEN_DURATION)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_material.set_shader_parameter("pointer_offset", _parallax_display)


func _pointer_parallax_offset() -> Vector2:
	var vp := get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return Vector2.ZERO
	var pos := get_viewport().get_mouse_position()
	return (pos / vp) * 2.0 - Vector2.ONE


func _kill_tweens() -> void:
	if _scroll_ramp_tween != null and _scroll_ramp_tween.is_valid():
		_scroll_ramp_tween.kill()
	if _parallax_tween != null and _parallax_tween.is_valid():
		_parallax_tween.kill()
