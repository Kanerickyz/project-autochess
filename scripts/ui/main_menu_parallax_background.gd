class_name MainMenuParallaxBackground
extends Control
## 主菜单营地远景视差（远/中分层 + 指针视差 + 慢速漂移）。中层待美术分层资源替换。

const BACKGROUND_TEXTURE := preload("res://assets/ui/main_menu/menu_background.jpg")

## 指针归一化位移 (-1..1) 乘数（像素）。
const PARALLAX_FAR_STRENGTH := 14.0
const PARALLAX_MID_STRENGTH := 28.0
const DRIFT_FAR_AMPLITUDE := Vector2(6.0, 4.0)
const DRIFT_MID_AMPLITUDE := Vector2(10.0, 7.0)
const DRIFT_FAR_SPEED := 0.22
const DRIFT_MID_SPEED := 0.31
const OVERSCAN_SCALE := 1.08

var _layer_root: Control
var _far: TextureRect
var _mid: TextureRect
var _vignette: ColorRect
var _drift_time: float = 0.0
var _base_far: Vector2
var _base_mid: Vector2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layers()


func _build_layers() -> void:
	_layer_root = Control.new()
	_layer_root.name = "LayerRoot"
	_layer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer_root)

	_far = _make_layer("Far", BACKGROUND_TEXTURE, Color(1.0, 1.0, 1.0, 1.0))
	_mid = _make_layer("Mid", BACKGROUND_TEXTURE, Color(1.05, 0.92, 0.78, 0.35))
	_layer_root.add_child(_far)
	_layer_root.add_child(_mid)

	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.02, 0.04, 0.08, 0.42)
	add_child(_vignette)

	_base_far = _far.position
	_base_mid = _mid.position


func _make_layer(layer_name: String, tex: Texture2D, tint: Color) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture = tex
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.modulate = tint
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := (OVERSCAN_SCALE - 1.0) * 0.5
	layer.anchor_left = -margin
	layer.anchor_top = -margin
	layer.anchor_right = 1.0 + margin
	layer.anchor_bottom = 1.0 + margin
	return layer


func _process(delta: float) -> void:
	if _far == null or _mid == null:
		return
	_drift_time += delta
	var drift_far := Vector2(
		sin(_drift_time * DRIFT_FAR_SPEED),
		cos(_drift_time * DRIFT_FAR_SPEED * 0.85),
	) * DRIFT_FAR_AMPLITUDE
	var drift_mid := Vector2(
		cos(_drift_time * DRIFT_MID_SPEED * 0.9),
		sin(_drift_time * DRIFT_MID_SPEED),
	) * DRIFT_MID_AMPLITUDE
	var parallax := _pointer_parallax_offset()
	_far.position = _base_far + drift_far + parallax * PARALLAX_FAR_STRENGTH
	_mid.position = _base_mid + drift_mid - parallax * PARALLAX_MID_STRENGTH


func _pointer_parallax_offset() -> Vector2:
	var vp := get_viewport_rect().size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return Vector2.ZERO
	var pos := get_viewport().get_mouse_position()
	# 触屏无悬停时仍用鼠标位（Godot 触摸会同步 mouse position）
	return (pos / vp) * 2.0 - Vector2.ONE
