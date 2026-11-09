class_name PhaseGridBackground
extends Control
## 全屏动态正方形棋盘格背景（主菜单同款 Shader）：漂移 + 可选指针视差；双色可按阶段切换。

const BACKGROUND_SHADER := preload("res://assets/ui/main_menu/main_menu_background.gdshader")

const PARALLAX_STRENGTH := 18.0
const SCROLL_SPEED := 0.25
const SCROLL_RAMP_DURATION := 1.05
const PARALLAX_TWEEN_DURATION := 0.32
const PARALLAX_RETARGET_DISTANCE := 1.25
const PALETTE_TWEEN_DURATION := 0.45
## 棋盘绕屏幕中心旋转（弧度），减轻正对屏幕的方正感。
const GRID_ROTATION_RAD := -0.22

const _SCROLL_DIR := Vector2(-0.70710678118, 0.70710678118)

@export var enable_pointer_parallax: bool = true
@export var initial_theme: PhaseGridPalettes.ThemeId = PhaseGridPalettes.ThemeId.MENU

var _bg: ColorRect
var _material: ShaderMaterial
var _scroll_offset := Vector2.ZERO
var _scroll_speed_current := 0.0
var _parallax_display := Vector2.ZERO
var _parallax_tween_goal := Vector2.ZERO
var _scroll_ramp_tween: Tween
var _parallax_tween: Tween
var _palette_tween: Tween
var _color_a := Color(0.07, 0.08, 0.11)
var _color_b := Color(0.13, 0.11, 0.15)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layers()
	var pal := PhaseGridPalettes.colors_for(initial_theme)
	_apply_palette_immediate(pal["a"] as Color, pal["b"] as Color)
	_update_viewport_aspect()
	resized.connect(_update_viewport_aspect)
	_start_scroll_ramp()


func _exit_tree() -> void:
	_kill_tweens()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_viewport_aspect()


func set_theme_id(theme_id: PhaseGridPalettes.ThemeId, animate: bool = true) -> void:
	var pal := PhaseGridPalettes.colors_for(theme_id)
	set_palette(pal["a"] as Color, pal["b"] as Color, animate)


func set_palette(color_a: Color, color_b: Color, animate: bool = true) -> void:
	if _material == null:
		_color_a = color_a
		_color_b = color_b
		return
	if not animate:
		_apply_palette_immediate(color_a, color_b)
		return
	if _palette_tween != null and _palette_tween.is_valid():
		_palette_tween.kill()
	var from_a := _color_a
	var from_b := _color_b
	_palette_tween = create_tween()
	_palette_tween.set_parallel(true)
	_palette_tween.tween_method(
		func(t: float) -> void:
			_apply_palette_immediate(from_a.lerp(color_a, t), from_b.lerp(color_b, t)),
		0.0,
		1.0,
		PALETTE_TWEEN_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_layers() -> void:
	_material = ShaderMaterial.new()
	_material.shader = BACKGROUND_SHADER
	_material.set_shader_parameter("grid_rotation", GRID_ROTATION_RAD)

	_bg = ColorRect.new()
	_bg.name = "ShaderBackground"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = _color_a
	_bg.material = _material
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)


func _apply_palette_immediate(color_a: Color, color_b: Color) -> void:
	_color_a = color_a
	_color_b = color_b
	if _bg != null:
		_bg.color = color_a
	if _material == null:
		return
	_material.set_shader_parameter("color_dark_a", Vector3(color_a.r, color_a.g, color_a.b))
	_material.set_shader_parameter("color_dark_b", Vector3(color_b.r, color_b.g, color_b.b))


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

	if not enable_pointer_parallax:
		_material.set_shader_parameter("pointer_offset", Vector2.ZERO)
		return

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
	if _palette_tween != null and _palette_tween.is_valid():
		_palette_tween.kill()
