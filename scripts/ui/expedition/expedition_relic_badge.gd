class_name ExpeditionRelicBadge
extends Control
## 远征行囊单槽圆形徽章：空槽空心描边；占用按 Tier 着色 + 显示名首字。

signal pressed(slot_index: int, relic: ExpeditionRelicData)

const DEFAULT_DIAMETER := 32.0

## Tier 1/2/3 填充色（无 icon 纹理时的可读占位）。
const TIER_FILL := {
	1: Color(0.42, 0.48, 0.55, 1.0),
	2: Color(0.38, 0.55, 0.72, 1.0),
	3: Color(0.78, 0.58, 0.22, 1.0),
}

var slot_index: int = 0
var relic: ExpeditionRelicData = null
var diameter: float = DEFAULT_DIAMETER


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_apply_min_size()
	tooltip_text = ""
	queue_redraw()


func configure(index: int, relic_data: ExpeditionRelicData, badge_diameter: float = DEFAULT_DIAMETER) -> void:
	slot_index = index
	relic = relic_data
	diameter = maxf(22.0, badge_diameter)
	_apply_min_size()
	if relic != null and not relic.display_name.is_empty():
		tooltip_text = relic.display_name
	else:
		tooltip_text = "空槽"
	queue_redraw()


func is_occupied() -> bool:
	return relic != null


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


func _gui_input(event: InputEvent) -> void:
	if relic == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(slot_index, relic)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			pressed.emit(slot_index, relic)
			accept_event()


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
