class_name MainMenuParallaxBackground
extends Control
## 主菜单动态背景：营地底图 + Shader 格纹自右上向左下持续漂移 + 轻微指针视差。

const BACKGROUND_TEXTURE := preload("res://assets/ui/main_menu/menu_background.jpg")
const BACKGROUND_SHADER := preload("res://assets/ui/main_menu/main_menu_background.gdshader")

const PARALLAX_STRENGTH := 22.0
const OVERSCAN_SCALE := 1.06

var _bg: TextureRect
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layers()


func _build_layers() -> void:
	_material = ShaderMaterial.new()
	_material.shader = BACKGROUND_SHADER
	_material.set_shader_parameter("bg_texture", BACKGROUND_TEXTURE)

	_bg = TextureRect.new()
	_bg.name = "ShaderBackground"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.texture = BACKGROUND_TEXTURE
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.material = _material
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := (OVERSCAN_SCALE - 1.0) * 0.5
	_bg.anchor_left = -margin
	_bg.anchor_top = -margin
	_bg.anchor_right = 1.0 + margin
	_bg.anchor_bottom = 1.0 + margin
	add_child(_bg)


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
