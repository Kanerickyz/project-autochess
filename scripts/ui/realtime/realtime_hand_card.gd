class_name RealtimeHandCard
extends Control
## 实时战斗手牌卡片（色块占位）：点击选中，按住拖到战场投放。

signal card_pressed(entry_id: int)

const ARENA_DRAG_KEY := RealtimeArenaView.DRAG_KEY

var entry: DeckEntry
var available: bool = true:
	set(value):
		if available != value:
			available = value
			queue_redraw()
var status_text: String = "":
	set(value):
		if status_text != value:
			status_text = value
			queue_redraw()
var selected: bool = false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()

var _box := StyleBoxFlat.new()


class DragGhost:
	extends Control

	var radius_px: float = 14.0
	var color: Color = RealtimeArenaView.PLAYER_COLOR
	var glyph: String = ""

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius_px, Color(color, 0.7))
		var font := get_theme_default_font()
		var font_size := clampi(int(radius_px * 1.1), 10, 22)
		var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(
			font, Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.4), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE,
		)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(64, 88)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(p_entry: DeckEntry) -> void:
	entry = p_entry
	tooltip_text = p_entry.get_display_name() if p_entry != null else ""
	queue_redraw()


func get_entry_id() -> int:
	return entry.entry_id if entry != null else -1


static func color_for_unit(unit_id: String) -> Color:
	var hue := float(absi(hash(unit_id)) % 360) / 360.0
	return Color.from_hsv(hue, 0.45, 0.72)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and entry != null:
			card_pressed.emit(entry.entry_id)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if entry == null or not available:
		return null
	var stats := entry.unit.stats if entry.unit != null else null
	var radius := stats.body_radius if stats != null else 0.4
	var ghost := DragGhost.new()
	ghost.radius_px = maxf(10.0, radius * 22.0)
	ghost.glyph = entry.get_display_name().substr(0, 1)
	set_drag_preview(ghost)
	return {ARENA_DRAG_KEY: entry.entry_id, "radius": radius, "label": entry.get_display_name()}


func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var unit_id := entry.get_unit_id() if entry != null else ""
	var base := color_for_unit(unit_id)
	if not available:
		base = Color(0.35, 0.35, 0.38)
	var box := _box
	box.bg_color = base
	box.set_corner_radius_all(6)
	box.set_border_width_all(3 if selected else 1)
	box.border_color = Color(1.0, 0.92, 0.4) if selected else Color(0, 0, 0, 0.5)
	draw_style_box(box, rect)
	if entry == null:
		return
	var font := get_theme_default_font()
	var text_color := Color.WHITE if available else Color(0.75, 0.75, 0.75)
	draw_string(
		font, Vector2(rect.position.x, rect.position.y + 20), entry.get_display_name(),
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, text_color,
	)
	var stats := entry.unit.stats if entry.unit != null else null
	if stats != null:
		var hp := stats.max_hp + entry.bonus_max_hp
		var atk := stats.attack + entry.bonus_attack
		draw_string(
			font, Vector2(rect.position.x, rect.position.y + 44), "血 %d" % hp,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, text_color,
		)
		draw_string(
			font, Vector2(rect.position.x, rect.position.y + 60), "攻 %d" % atk,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, text_color,
		)
	if not status_text.is_empty():
		var tag := Rect2(rect.position + Vector2(4, rect.size.y - 22), Vector2(rect.size.x - 8, 18))
		draw_rect(tag, Color(0, 0, 0, 0.55))
		draw_string(
			font, Vector2(tag.position.x, tag.position.y + 14), status_text,
			HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 11, Color(1.0, 0.9, 0.6),
		)
