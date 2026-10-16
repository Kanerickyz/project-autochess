class_name RealtimeHandCard
extends Control
## 实时战斗手牌卡片（色块占位）：准备阶段点击选中，按住拖到角色槽；
## 长按约 0.4s 弹出与场上相同的信息卡（松手不触发选中/入座）。

signal card_pressed(entry_id: int)
signal card_long_press(entry_id: int)
signal card_long_press_ended(entry_id: int)

const ARENA_DRAG_KEY := RealtimeArenaView.DRAG_KEY
const LONG_PRESS_MS := RealtimeArenaView.LONG_PRESS_MS
const LONG_PRESS_SLOP_PX := RealtimeArenaView.LONG_PRESS_SLOP_PX

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
var _pressing := false
var _press_ms: int = -1
var _press_pos := Vector2.ZERO
var _info_shown := false
var _drag_started := false


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
	set_process(false)


func _process(_delta: float) -> void:
	if _press_ms >= 0 and not _info_shown and entry != null:
		if Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
			_info_shown = true
			_press_ms = -1
			card_long_press.emit(entry.entry_id)


func setup(p_entry: DeckEntry) -> void:
	entry = p_entry
	tooltip_text = p_entry.get_display_name() if p_entry != null else ""
	queue_redraw()


func get_entry_id() -> int:
	return entry.entry_id if entry != null else -1


func is_info_long_press_active() -> bool:
	return _info_shown


static func color_for_unit(unit_id: String) -> Color:
	var hue := float(absi(hash(unit_id)) % 360) / 360.0
	return Color.from_hsv(hue, 0.45, 0.72)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or entry == null:
			return
		if mb.pressed:
			_pressing = true
			_press_ms = Time.get_ticks_msec()
			_press_pos = mb.position
			_info_shown = false
			_drag_started = false
			set_process(true)
			accept_event()
		elif _pressing:
			var shown := _info_shown
			var dragged := _drag_started
			var entry_id := entry.entry_id
			_reset_press_state()
			if shown:
				card_long_press_ended.emit(entry_id)
			elif not dragged:
				card_pressed.emit(entry_id)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		var motion := event as InputEventMouseMotion
		if _press_ms >= 0 and not _info_shown and motion.position.distance_to(_press_pos) > LONG_PRESS_SLOP_PX:
			## 移动超 slop：取消长按，允许原生拖拽入座。
			_press_ms = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_started = false
		if _pressing and not _info_shown:
			_reset_press_state()
	elif what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree() and _info_shown and entry != null:
			card_long_press_ended.emit(entry.entry_id)
		if not is_visible_in_tree():
			_reset_press_state()


func _reset_press_state() -> void:
	_pressing = false
	_press_ms = -1
	_info_shown = false
	_drag_started = false
	set_process(false)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if entry == null or not available or _info_shown:
		return null
	## 进入拖拽：取消长按计时，松手不再当作点选。
	_press_ms = -1
	_drag_started = true
	var stats := entry.unit.stats if entry.unit != null else null
	var radius := stats.body_radius if stats != null else 0.7
	var vwx := stats.get_visual_half_width() if stats != null else radius * 1.3
	var vhy := stats.get_visual_half_height() if stats != null else radius * 1.6
	var ghost := DragGhost.new()
	ghost.radius_px = maxf(10.0, maxf(vwx, vhy) * 22.0)
	var full_name := entry.get_display_name()
	ghost.glyph = full_name.substr(0, mini(2, full_name.length()))
	set_drag_preview(ghost)
	return {
		ARENA_DRAG_KEY: entry.entry_id,
		"radius": radius,
		"visual_half_width": vwx,
		"visual_half_height": vhy,
		"label": entry.get_display_name(),
		"unit_id": entry.get_unit_id(),
	}


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
			font, Vector2(rect.position.x, rect.position.y + 42), "血%d 攻%d" % [hp, atk],
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 11, text_color,
		)
	if not status_text.is_empty():
		var tag := Rect2(rect.position + Vector2(4, rect.size.y - 22), Vector2(rect.size.x - 8, 18))
		draw_rect(tag, Color(0, 0, 0, 0.55))
		draw_string(
			font, Vector2(tag.position.x, tag.position.y + 14), status_text,
			HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 11, Color(1.0, 0.9, 0.6),
		)
