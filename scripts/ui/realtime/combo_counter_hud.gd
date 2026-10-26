class_name ComboCounterHud
extends Control
## 战场右上角连击数字（1–15）；素材为 256×256 裁切图。

const TEXTURE_PATH := "res://assets/sprites/combat/combo/combo_%02d.png"
const DISPLAY_PX := 88.0
const PUNCH_IN_SECONDS := 0.085
const SETTLE_SECONDS := 0.14
const FLASH_SECONDS := 0.16
const WOBBLE_SECONDS := 0.13
const HIDE_SECONDS := 0.1
const PEAK_SCALE_MIN := 1.26
const PEAK_SCALE_MAX := 1.42
const START_SCALE := 0.38

var _textures: Array[Texture2D] = []
var _icon: TextureRect
var _impact_tween: Tween
var _last_combo_shown: int = 0


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
	_play_impact(combo)
	_last_combo_shown = combo


func _hide_combo() -> void:
	_kill_impact_tween()
	if not visible:
		_last_combo_shown = 0
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * 0.65, HIDE_SECONDS)
	tween.parallel().tween_property(self, "modulate:a", 0.0, HIDE_SECONDS)
	tween.chain().tween_callback(_finish_hide)


func _finish_hide() -> void:
	visible = false
	scale = Vector2.ONE
	modulate = Color.WHITE
	rotation_degrees = 0.0
	_last_combo_shown = 0


func _preload_textures() -> void:
	_textures.clear()
	for i in range(1, 16):
		var path := TEXTURE_PATH % i
		var tex := load(path) as Texture2D
		if tex != null:
			_textures.append(tex)


func _kill_impact_tween() -> void:
	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	_impact_tween = null


func _peak_scale_for_combo(combo: int) -> float:
	var t := float(mini(maxi(combo, 1), 15) - 1) / 14.0
	return lerpf(PEAK_SCALE_MIN, PEAK_SCALE_MAX, t)


func _play_impact(combo: int) -> void:
	_kill_impact_tween()
	modulate = Color.WHITE
	rotation_degrees = 0.0
	scale = Vector2.ONE * START_SCALE
	var peak := _peak_scale_for_combo(combo)
	var wobble_sign := 1.0 if combo % 2 == 0 else -1.0

	_impact_tween = create_tween()
	_impact_tween.set_parallel(true)
	var punch := _impact_tween.tween_property(self, "scale", Vector2.ONE * peak, PUNCH_IN_SECONDS)
	punch.set_trans(Tween.TRANS_BACK)
	punch.set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(self, "modulate", Color.WHITE, FLASH_SECONDS).from(
		Color(1.65, 1.08, 0.72, 1.0)
	)
	_impact_tween.tween_property(self, "rotation_degrees", 0.0, WOBBLE_SECONDS).from(
		9.0 * wobble_sign
	)

	var settle := _impact_tween.chain().tween_property(self, "scale", Vector2.ONE, SETTLE_SECONDS)
	settle.set_trans(Tween.TRANS_ELASTIC)
	settle.set_ease(Tween.EASE_OUT)
