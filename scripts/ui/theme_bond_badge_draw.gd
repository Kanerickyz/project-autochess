class_name ThemeBondBadgeDraw
extends RefCounted
## 主题羁绊纸片/卡头徽：八主题稳定形+色；主实心、辅空心弱显。

enum Shape {
	CIRCLE,
	SQUARE,
	DIAMOND,
	TRIANGLE,
	HEXAGON,
	PENTAGON,
	STAR,
	CROSS,
}

const COLORS := {
	UnitTheme.GUARD: Color(0.29, 0.48, 0.72, 1.0),
	UnitTheme.KNIGHT_ORDER: Color(0.79, 0.64, 0.15, 1.0),
	UnitTheme.WARRIOR: Color(0.77, 0.24, 0.24, 1.0),
	UnitTheme.ARTISAN: Color(0.79, 0.47, 0.23, 1.0),
	UnitTheme.UNDEAD: Color(0.48, 0.42, 0.60, 1.0),
	UnitTheme.BAND: Color(0.18, 0.62, 0.56, 1.0),
	UnitTheme.ARCANE: Color(0.42, 0.36, 0.84, 1.0),
	UnitTheme.MERCENARY: Color(0.55, 0.45, 0.25, 1.0),
}

const SHAPES := {
	UnitTheme.GUARD: Shape.SQUARE,
	UnitTheme.KNIGHT_ORDER: Shape.DIAMOND,
	UnitTheme.WARRIOR: Shape.TRIANGLE,
	UnitTheme.ARTISAN: Shape.HEXAGON,
	UnitTheme.UNDEAD: Shape.CIRCLE,
	UnitTheme.BAND: Shape.STAR,
	UnitTheme.ARCANE: Shape.PENTAGON,
	UnitTheme.MERCENARY: Shape.CROSS,
}


static func color_for(theme_id: StringName) -> Color:
	if not UnitTheme.is_valid_id(theme_id):
		return Color(0.55, 0.55, 0.55, 1.0)
	return COLORS.get(theme_id, Color(0.55, 0.55, 0.55, 1.0)) as Color


static func shape_for(theme_id: StringName) -> Shape:
	if not UnitTheme.is_valid_id(theme_id):
		return Shape.CIRCLE
	return SHAPES.get(theme_id, Shape.CIRCLE) as Shape


## 单枚徽。filled=false 时画空心/弱显描边。
static func draw_badge(
	ci: CanvasItem,
	center: Vector2,
	theme_id: StringName,
	radius: float,
	alpha: float,
	filled: bool,
) -> void:
	if ci == null or not UnitTheme.is_valid_id(theme_id) or radius <= 0.5:
		return
	var a := clampf(alpha, 0.0, 1.0)
	if a <= 0.01:
		return
	var fill := color_for(theme_id)
	fill.a = a if filled else a * 0.22
	var stroke := color_for(theme_id)
	stroke.a = a if not filled else a * 0.95
	var outline := Color(0.05, 0.04, 0.03, a * 0.55)
	var line_w := maxf(1.25, radius * 0.22)
	match shape_for(theme_id):
		Shape.CIRCLE:
			if filled:
				ci.draw_circle(center, radius, fill)
			else:
				ci.draw_arc(center, radius, 0.0, TAU, 28, stroke, line_w)
			ci.draw_arc(center, radius, 0.0, TAU, 28, outline, 1.0)
		Shape.SQUARE:
			_draw_regular_polygon(ci, center, radius, 4, PI * 0.25, fill, stroke, outline, filled, line_w)
		Shape.DIAMOND:
			_draw_regular_polygon(ci, center, radius, 4, 0.0, fill, stroke, outline, filled, line_w)
		Shape.TRIANGLE:
			_draw_regular_polygon(ci, center, radius, 3, -PI * 0.5, fill, stroke, outline, filled, line_w)
		Shape.HEXAGON:
			_draw_regular_polygon(ci, center, radius, 6, 0.0, fill, stroke, outline, filled, line_w)
		Shape.PENTAGON:
			_draw_regular_polygon(ci, center, radius, 5, -PI * 0.5, fill, stroke, outline, filled, line_w)
		Shape.STAR:
			_draw_star(ci, center, radius, fill, stroke, outline, filled, line_w)
		Shape.CROSS:
			_draw_cross(ci, center, radius, fill, stroke, outline, filled, line_w)


## 主徽在 anchor；有辅则在主右侧更小且 filled=false。
static func draw_pair(
	ci: CanvasItem,
	anchor: Vector2,
	primary: StringName,
	secondary: StringName,
	primary_r: float,
	alpha: float,
) -> void:
	if not UnitTheme.is_valid_id(primary):
		return
	draw_badge(ci, anchor, primary, primary_r, alpha, true)
	if not UnitTheme.is_valid_id(secondary) or secondary == primary:
		return
	var sec_r := primary_r * 0.58
	var gap := maxf(2.0, primary_r * 0.28)
	var sec_center := anchor + Vector2(primary_r + sec_r + gap, 0.0)
	draw_badge(ci, sec_center, secondary, sec_r, alpha * 0.9, false)


static func _draw_regular_polygon(
	ci: CanvasItem,
	center: Vector2,
	radius: float,
	sides: int,
	rotation: float,
	fill: Color,
	stroke: Color,
	outline: Color,
	filled: bool,
	line_w: float,
) -> void:
	var pts := _regular_points(center, radius, sides, rotation)
	if filled:
		ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), stroke if not filled else outline, line_w if not filled else 1.0, true)
	if filled:
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.0, true)


static func _draw_star(
	ci: CanvasItem,
	center: Vector2,
	radius: float,
	fill: Color,
	stroke: Color,
	outline: Color,
	filled: bool,
	line_w: float,
) -> void:
	var outer := radius
	var inner := radius * 0.45
	var pts: PackedVector2Array = []
	for i in 10:
		var ang := -PI * 0.5 + float(i) * TAU / 10.0
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	if filled:
		ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), stroke if not filled else outline, line_w if not filled else 1.0, true)
	if filled:
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.0, true)


static func _draw_cross(
	ci: CanvasItem,
	center: Vector2,
	radius: float,
	fill: Color,
	stroke: Color,
	outline: Color,
	filled: bool,
	line_w: float,
) -> void:
	var arm := radius * 0.38
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(-arm, -radius),
		center + Vector2(arm, -radius),
		center + Vector2(arm, -arm),
		center + Vector2(radius, -arm),
		center + Vector2(radius, arm),
		center + Vector2(arm, arm),
		center + Vector2(arm, radius),
		center + Vector2(-arm, radius),
		center + Vector2(-arm, arm),
		center + Vector2(-radius, arm),
		center + Vector2(-radius, -arm),
		center + Vector2(-arm, -arm),
	])
	if filled:
		ci.draw_colored_polygon(pts, fill)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), stroke if not filled else outline, line_w if not filled else 1.0, true)
	if filled:
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.0, true)


static func _regular_points(
	center: Vector2, radius: float, sides: int, rotation: float
) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in sides:
		var ang := rotation + float(i) * TAU / float(sides)
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	return pts
