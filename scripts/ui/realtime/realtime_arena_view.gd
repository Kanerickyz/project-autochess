class_name RealtimeArenaView
extends Control
## 实时战场占位绘制：棋盘格、半场色调、中线、投放高亮/虚影、单位剪影、血条、部署弧、投射物与溅射圈。
## 只读 RealtimeCombatSim 状态，不参与逻辑。剪影可大于碰撞圆（脚小身大）。

signal board_pressed(tile_pos: Vector2)
signal card_dropped(entry_id: int, tile_pos: Vector2)

const DRAG_KEY := "rt_entry_id"
const NO_CELL := Vector2i(-1, -1)
const GRASS_A := Color(0.58, 0.74, 0.46)
const GRASS_B := Color(0.55, 0.71, 0.43)
const PLAYER_TINT := Color(0.25, 0.45, 0.95, 0.10)
const ENEMY_TINT := Color(0.95, 0.25, 0.22, 0.10)
const GRID_LINE := Color(0.0, 0.0, 0.0, 0.05)
const MIDLINE := Color(1.0, 1.0, 1.0, 0.75)
const DEPLOY_HIGHLIGHT := Color(0.45, 0.75, 1.0, 0.18)
const PLAYER_COLOR := Color(0.22, 0.47, 0.92)
const ENEMY_COLOR := Color(0.88, 0.24, 0.22)
const BORDER := Color(0.12, 0.18, 0.10, 0.9)
const ATTACK_FLASH_SECONDS := 0.12
const HIT_FLASH_SECONDS := 0.10
const FX_SECONDS := 0.35
const ELLIPSE_SEGMENTS := 28

var board_size: Vector2i = Vector2i(18, 32)
var sim: RealtimeCombatSim
## Array[Dictionary]：{position, radius, visual_half_width?, visual_half_height?, label}
var enemy_previews: Array = []
## 已选中手牌时为 true：高亮我方半场并显示悬停虚影
var placement_active: bool = false
var ghost_radius: float = 0.7
var ghost_visual_half_width: float = 0.0
var ghost_visual_half_height: float = 0.0
var ghost_label: String = ""

var _hover_cell: Vector2i = NO_CELL
var _drag_active: bool = false
var _drag_radius: float = 0.7
var _drag_visual_half_width: float = 0.0
var _drag_visual_half_height: float = 0.0
var _drag_label: String = ""
var _fx: Array = []
var _fx_clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_fx_clock += delta
	if not _fx.is_empty():
		var alive: Array = []
		for fx in _fx:
			if _fx_clock - float(fx["t0"]) < FX_SECONDS:
				alive.append(fx)
		_fx = alive
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_active = false
		_hover_cell = NO_CELL
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover_cell = NO_CELL


# --- 公开接口 ---


func get_cell_px() -> float:
	if board_size.x <= 0 or board_size.y <= 0:
		return 1.0
	return maxf(1.0, minf(size.x / board_size.x, size.y / board_size.y))


func get_board_rect() -> Rect2:
	var px := get_cell_px()
	var board_px := Vector2(board_size) * px
	return Rect2((size - board_px) * 0.5, board_px)


func local_to_tile(local_pos: Vector2) -> Vector2:
	var rect := get_board_rect()
	return (local_pos - rect.position) / get_cell_px()


func tile_to_local(tile_pos: Vector2) -> Vector2:
	return get_board_rect().position + tile_pos * get_cell_px()


func tile_to_cell(tile_pos: Vector2) -> Vector2i:
	var cell := Vector2i(floori(tile_pos.x), floori(tile_pos.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= board_size.x or cell.y >= board_size.y:
		return NO_CELL
	return cell


func add_splash_fx(center: Vector2, radius: float) -> void:
	_fx.append({"kind": "splash", "center": center, "radius": radius, "t0": _fx_clock})


func add_death_fx(center: Vector2, radius: float, is_player: bool) -> void:
	_fx.append({"kind": "death", "center": center, "radius": radius, "t0": _fx_clock, "player": is_player})


func clear_fx() -> void:
	_fx.clear()


# --- 输入 ---


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_cell = tile_to_cell(local_to_tile((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			board_pressed.emit(local_to_tile(mb.position))
			accept_event()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has(DRAG_KEY):
		return false
	var dict := data as Dictionary
	_drag_active = true
	_drag_radius = float(dict.get("radius", 0.7))
	_drag_visual_half_width = float(dict.get("visual_half_width", 0.0))
	_drag_visual_half_height = float(dict.get("visual_half_height", 0.0))
	_drag_label = String(dict.get("label", ""))
	_hover_cell = tile_to_cell(local_to_tile(at_position))
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_drag_active = false
	var dict := data as Dictionary
	card_dropped.emit(int(dict[DRAG_KEY]), local_to_tile(at_position))


# --- 绘制 ---


func _draw() -> void:
	var rect := get_board_rect()
	var px := get_cell_px()
	var mid := BoardHalf.midline_row(board_size.y)
	draw_rect(rect.grow(2.0), BORDER)
	for y in board_size.y:
		for x in board_size.x:
			var cell_rect := Rect2(rect.position + Vector2(x, y) * px, Vector2(px, px))
			draw_rect(cell_rect, GRASS_A if (x + y) % 2 == 0 else GRASS_B)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, mid * px)), ENEMY_TINT)
	draw_rect(
		Rect2(rect.position + Vector2(0, mid * px), Vector2(rect.size.x, (board_size.y - mid) * px)),
		PLAYER_TINT,
	)
	for x in range(1, board_size.x):
		var lx := rect.position.x + x * px
		draw_line(Vector2(lx, rect.position.y), Vector2(lx, rect.end.y), GRID_LINE, 1.0)
	for y in range(1, board_size.y):
		var ly := rect.position.y + y * px
		draw_line(Vector2(rect.position.x, ly), Vector2(rect.end.x, ly), GRID_LINE, 1.0)

	var showing_placement := placement_active or _drag_active
	if showing_placement:
		draw_rect(
			Rect2(rect.position + Vector2(0, mid * px), Vector2(rect.size.x, (board_size.y - mid) * px)),
			DEPLOY_HIGHLIGHT,
		)
	var mid_y := rect.position.y + mid * px
	draw_line(Vector2(rect.position.x, mid_y), Vector2(rect.end.x, mid_y), MIDLINE, 2.0)

	for preview in enemy_previews:
		var body_r := float(preview["radius"])
		var vwx := float(preview.get("visual_half_width", 0.0))
		var vhy := float(preview.get("visual_half_height", 0.0))
		_draw_body(
			preview["position"], body_r, vwx, vhy, ENEMY_COLOR, 0.35, String(preview["label"]), px, false,
		)

	if sim != null:
		_draw_units(px)
		_draw_projectiles(px)
	_draw_fx(px)
	if showing_placement and _hover_cell != NO_CELL:
		_draw_ghost(px, mid)


func _draw_units(px: float) -> void:
	var now := sim.elapsed_seconds
	var started := sim.has_started()
	for item in sim.get_units():
		var rt := item as RtUnit
		var base := PLAYER_COLOR if rt.is_player() else ENEMY_COLOR
		var alpha := 1.0
		if started and rt.is_deploying():
			alpha = 0.55
		if now - rt.last_attack_time < ATTACK_FLASH_SECONDS:
			base = base.lightened(0.45)
		if now - rt.last_hit_time < HIT_FLASH_SECONDS:
			base = base.lerp(Color.WHITE, 0.5)
		var vwx := rt.get_visual_half_width()
		var vhy := rt.get_visual_half_height()
		_draw_body(rt.position, rt.get_radius(), vwx, vhy, base, alpha, rt.get_display_name(), px, true)
		var center := tile_to_local(rt.position)
		var silhouette_r_px := maxf(vwx, vhy) * px
		if started and rt.is_deploying():
			var ratio := rt.get_deploy_ratio()
			draw_arc(center, silhouette_r_px + 3.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color(1, 1, 1, 0.9), 2.0)
		_draw_hp_bar(center, silhouette_r_px, rt.get_hp_ratio(), rt.is_player())


func _draw_body(
	tile_pos: Vector2,
	body_radius: float,
	visual_half_width: float,
	visual_half_height: float,
	color: Color,
	alpha: float,
	label: String,
	px: float,
	show_foot: bool,
) -> void:
	var center := tile_to_local(tile_pos)
	var rx := maxf(3.0, _resolve_visual_half(visual_half_width, body_radius, 1.3) * px)
	var ry := maxf(3.0, _resolve_visual_half(visual_half_height, body_radius, 1.6) * px)
	var fill := Color(color, alpha)
	_draw_ellipse_filled(center, rx, ry, fill)
	_draw_ellipse_outline(center, rx, ry, Color(0, 0, 0, 0.45 * alpha), 1.5)
	if show_foot:
		var foot_r := maxf(2.0, body_radius * px)
		draw_arc(center, foot_r, 0.0, TAU, 20, Color(0, 0, 0, 0.35 * alpha), 1.25)
	if label.is_empty():
		return
	var font := get_theme_default_font()
	## 剪影上标最多两字，便于认出「盾兵 / 链枷」等 Content 兵种名。
	var max_chars := 2 if minf(rx, ry) >= 10.0 else 1
	var font_size := clampi(int(minf(rx, ry) * (0.85 if max_chars > 1 else 1.1)), 8, 22)
	var glyph := label.substr(0, mini(max_chars, label.length()))
	var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - font.get_descent(font_size) * 0.25)
	draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))


func _resolve_visual_half(explicit: float, body_radius: float, fallback_mul: float) -> float:
	if explicit > 0.0:
		return explicit
	return maxf(0.05, body_radius * fallback_mul)


func _draw_ellipse_filled(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var a := TAU * float(i) / float(ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS + 1:
		var a := TAU * float(i) / float(ELLIPSE_SEGMENTS)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, width, true)


func _draw_hp_bar(center: Vector2, r_px: float, ratio: float, is_player: bool) -> void:
	var width := maxf(14.0, r_px * 2.2)
	var bar := Rect2(center + Vector2(-width * 0.5, -r_px - 7.0), Vector2(width, 4.0))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var fill_color := Color(0.35, 0.8, 1.0) if is_player else Color(1.0, 0.4, 0.35)
	draw_rect(Rect2(bar.position, Vector2(width * ratio, bar.size.y)), fill_color)


func _draw_projectiles(px: float) -> void:
	for item in sim.get_projectiles():
		var proj := item as RtProjectile
		var color := Color(0.85, 0.95, 1.0) if proj.is_player_owned() else Color(1.0, 0.85, 0.6)
		draw_circle(tile_to_local(proj.position), maxf(2.5, 0.12 * px), color)


func _draw_fx(px: float) -> void:
	for fx in _fx:
		var t := clampf((_fx_clock - float(fx["t0"])) / FX_SECONDS, 0.0, 1.0)
		var center := tile_to_local(fx["center"])
		var r_px := float(fx["radius"]) * px
		if fx["kind"] == "splash":
			draw_circle(center, r_px, Color(1.0, 0.9, 0.5, 0.35 * (1.0 - t)))
			draw_arc(center, r_px, 0.0, TAU, 32, Color(1.0, 0.85, 0.4, 0.8 * (1.0 - t)), 2.0)
		else:
			var color := PLAYER_COLOR if bool(fx["player"]) else ENEMY_COLOR
			draw_arc(center, r_px * (1.0 + t), 0.0, TAU, 24, Color(color, 0.8 * (1.0 - t)), 2.0)


func _draw_ghost(px: float, mid: int) -> void:
	var cell := _hover_cell
	var center_tile := Vector2(cell) + Vector2(0.5, 0.5)
	var radius := _drag_radius if _drag_active else ghost_radius
	var vwx := _drag_visual_half_width if _drag_active else ghost_visual_half_width
	var vhy := _drag_visual_half_height if _drag_active else ghost_visual_half_height
	var label := _drag_label if _drag_active else ghost_label
	var cell_rect := Rect2(get_board_rect().position + Vector2(cell) * px, Vector2(px, px))
	if cell.y < mid:
		draw_rect(cell_rect, Color(1.0, 0.2, 0.2, 0.35))
		var center := tile_to_local(center_tile)
		var d := px * 0.3
		draw_line(center - Vector2(d, d), center + Vector2(d, d), Color(1, 1, 1, 0.9), 2.0)
		draw_line(center + Vector2(-d, d), center + Vector2(d, -d), Color(1, 1, 1, 0.9), 2.0)
		return
	draw_rect(cell_rect, Color(1, 1, 1, 0.25))
	_draw_body(center_tile, radius, vwx, vhy, PLAYER_COLOR, 0.45, label, px, true)
