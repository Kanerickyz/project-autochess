class_name BadgeCircleDraw
extends Control
## 徽章圆形占位绘制（三选一 / 持有条复用）。

var _color: Color = Color(0.55, 0.62, 0.78, 1.0)
var _label: String = ""
var _dimmed: bool = false


func set_badge_visual(badge: BadgeData, dimmed: bool = false) -> void:
	_dimmed = dimmed
	if badge == null:
		_color = Color(0.25, 0.28, 0.32, 1.0)
		_label = ""
	else:
		_color = badge.accent_color
		var name := badge.display_name.strip_edges()
		_label = name.substr(0, 1) if not name.is_empty() else "?"
	queue_redraw()


func _draw() -> void:
	var r := mini(size.x, size.y) * 0.5
	var center := size * 0.5
	var fill := _color
	if _dimmed:
		fill = fill.darkened(0.35)
		fill.a = 0.55
	draw_circle(center, r, fill)
	draw_arc(center, r * 0.92, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 2.0, true)
	if _label.is_empty():
		return
	var font := ThemeDB.fallback_font
	var font_size := maxi(14, int(r * 0.55))
	var text_size := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(
		center.x - text_size.x * 0.5,
		center.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5,
	)
	draw_string(
		font,
		baseline,
		_label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0.98, 0.96, 0.9, 0.95 if not _dimmed else 0.6),
	)
