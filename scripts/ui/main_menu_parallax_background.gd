class_name MainMenuParallaxBackground
extends Control
## 主菜单动态背景：双色深色正方形棋盘格 Shader，自右上向左下缓慢漂移 + 轻微指针视差。

const BACKGROUND_SHADER := preload("res://assets/ui/main_menu/main_menu_background.gdshader")

const PARALLAX_STRENGTH := 18.0

var _bg: ColorRect
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layers()
	_update_viewport_aspect()
	resized.connect(_update_viewport_aspect)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_viewport_aspect()


func _build_layers() -> void:
	_material = ShaderMaterial.new()
	_material.shader = BACKGROUND_SHADER

	_bg = ColorRect.new()
	_bg.name = "ShaderBackground"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = Color(0.07, 0.08, 0.11)
	_bg.material = _material
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)


func _update_viewport_aspect() -> void:
	if _material == null:
		return
	var size := get_viewport_rect().size
	if size.y <= 1.0:
		return
	_material.set_shader_parameter("viewport_aspect", size.x / size.y)


func _process(_delta: float) -> void:
	if _material == null:
		return
	var parallax := _pointer_parallax_offset() * PARALLAX_STRENGTH
	_material.set_shader_parameter("pointer_offset", parallax)


func _pointer_parallax_offset() -> Vector2:
	var vp := get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return Vector2.ZERO
	var pos := get_viewport().get_mouse_position()
	return (pos / vp) * 2.0 - Vector2.ONE
