class_name ExpeditionRelicBadge
extends Control
## 远征行囊单槽圆形徽章：空槽空心描边；占用按 Tier 着色 + 显示名首字。
## 长按占用槽 → 统一 RealtimeUnitInfoCard 详情（与场上单位一致）。

signal pressed(slot_index: int, relic: ExpeditionRelicData)
signal long_press(slot_index: int, relic: ExpeditionRelicData)
signal long_press_ended(slot_index: int, relic: ExpeditionRelicData)

const DEFAULT_DIAMETER := 32.0
const LONG_PRESS_MS := 380
const LONG_PRESS_SLOP_PX := 10.0

## Tier 1/2/3 填充色（无 icon 纹理时的可读占位）。
const TIER_FILL := {
	1: Color(0.42, 0.48, 0.55, 1.0),
	2: Color(0.38, 0.55, 0.72, 1.0),
	3: Color(0.78, 0.58, 0.22, 1.0),
}

var slot_index: int = 0
var relic: ExpeditionRelicData = null
var diameter: float = DEFAULT_DIAMETER

var _pressing: bool = false
var _press_ms: int = -1
var _press_pos := Vector2.ZERO
var _info_shown: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	_apply_min_size()
	tooltip_text = ""
	queue_redraw()


func configure(index: int, relic_data: ExpeditionRelicData, badge_diameter: float = DEFAULT_DIAMETER) -> void:
	slot_index = index
	relic = relic_data
	diameter = maxf(22.0, badge_diameter)
	_apply_min_size()
	if relic != null and not relic.display_name.is_empty():
		tooltip_text = "%s（长按查看）" % relic.display_name
	else:
		tooltip_text = "空槽"
	_reset_press_state()
	queue_redraw()


func is_occupied() -> bool:
	return relic != null


func is_info_long_press_active() -> bool:
	return _info_shown


func glyph_text() -> String:
	if relic == null or relic.display_name.is_empty():
		return ""
	var name := relic.display_name.strip_edges()
	if name.length() <= 1:
		return name
	## 中文取 1 字；拉丁短名可取 2。
	var first := name.substr(0, 1)
	if first.unicode_at(0) < 128 and name.length() >= 2:
		return name.substr(0, 2).to_upper()
	return first


func _apply_min_size() -> void:
	custom_minimum_size = Vector2(diameter, diameter)


func _process(_delta: float) -> void:
	if relic == null:
		_reset_press_state()
		return
	if _press_ms >= 0 and not _info_shown and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		_info_shown = true
		_press_ms = -1
		long_press.emit(slot_index, relic)


func _gui_input(event: InputEvent) -> void:
	if relic == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_press_ms = Time.get_ticks_msec()
			_press_pos = mb.position
			_info_shown = false
			set_process(true)
			accept_event()
		elif _pressing:
			var shown := _info_shown
			var r := relic
			var idx := slot_index
			_reset_press_state()
			if shown:
				long_press_ended.emit(idx, r)
			else:
				## 短按仍发 pressed（不弹旧 Popup）；详情只走长按信息卡。
				pressed.emit(idx, r)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var motion := event as InputEventMouseMotion
		if _press_ms >= 0 and not _info_shown and motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
			_press_ms = -1
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pressing = true
			_press_ms = Time.get_ticks_msec()
			_press_pos = touch.position
			_info_shown = false
			set_process(true)
			accept_event()
		elif _pressing:
			var shown_t := _info_shown
			var r_t := relic
			var idx_t := slot_index
			_reset_press_state()
			if shown_t:
				long_press_ended.emit(idx_t, r_t)
			else:
				pressed.emit(idx_t, r_t)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree() and _info_shown and relic != null:
			long_press_ended.emit(slot_index, relic)
		if not is_visible_in_tree():
			_reset_press_state()


func _reset_press_state() -> void:
	_pressing = false
	_press_ms = -1
	_info_shown = false
	set_process(false)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	if r < 4.0:
		return
	var center := size * 0.5
	var outline := Color(0.08, 0.07, 0.05, 0.85)
	if relic == null:
		var empty_stroke := Color(0.72, 0.66, 0.52, 0.75)
		draw_arc(center, r - 1.5, 0.0, TAU, 36, empty_stroke, 2.0, true)
		draw_arc(center, r - 1.5, 0.0, TAU, 36, outline, 1.0, true)
		return
	var tier := clampi(relic.tier, 1, 3)
	var fill: Color = TIER_FILL.get(tier, TIER_FILL[1]) as Color
	draw_circle(center, r - 1.0, fill)
	draw_arc(center, r - 1.0, 0.0, TAU, 36, outline, 1.25, true)
	var glyph := glyph_text()
	if glyph.is_empty():
		return
	var font := ThemeDB.fallback_font
	var font_size := maxi(10, int(r * 0.85))
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(
		center.x - text_size.x * 0.5,
		center.y + text_size.y * 0.28,
	)
	draw_string(font, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.98, 0.96, 0.9, 1.0))
