class_name ComboCounterHud
extends Control
## 战场右上角连击数字（1–15）；素材为 256×256 裁切图。

const TEXTURE_PATH := "res://assets/sprites/combat/combo/combo_%02d.png"
const DISPLAY_PX := 88.0
const POP_SCALE := 1.18
const POP_IN_SECONDS := 0.1
const POP_OUT_SECONDS := 0.14

var _textures: Array[Texture2D] = []
var _icon: TextureRect
var _pop_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = -DISPLAY_PX - 12.0
	offset_top = 12.0
	offset_right = -12.0
	offset_bottom = DISPLAY_PX + 12.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	_preload_textures()
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_icon)
	visible = false
	pivot_offset = size * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func set_combo_count(combo: int) -> void:
	if combo <= 0:
		_hide_combo()
		return
	var idx := mini(combo, 15) - 1
	if idx < 0 or idx >= _textures.size():
		return
	_icon.texture = _textures[idx]
	if not visible:
		visible = true
		scale = Vector2.ONE
	_play_pop()


func _hide_combo() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	visible = false
	scale = Vector2.ONE


func _preload_textures() -> void:
	_textures.clear()
	for i in range(1, 16):
		var path := TEXTURE_PATH % i
		var tex := load(path) as Texture2D
		if tex != null:
			_textures.append(tex)


func _play_pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = create_tween()
	_pop_tween.set_trans(Tween.TRANS_BACK)
	_pop_tween.set_ease(Tween.EASE_OUT)
	scale = Vector2.ONE * POP_SCALE
	_pop_tween.tween_property(self, "scale", Vector2.ONE, POP_OUT_SECONDS).from_current()
