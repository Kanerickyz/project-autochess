class_name DayPickCard
extends Control
## 暗场三选一里的一张纸片卡：立绘 + 名称 + 攻/血/金角标 + 短说明。
## 外层由容器排版；动画只动内层 _body（位移/缩放/透明），不与容器抢位置。

signal tapped(card: DayPickCard)
signal long_pressed(card: DayPickCard)

const LONG_PRESS_SECONDS := 0.45
const TAP_MOVE_TOLERANCE := 14.0
const NAME_COLOR := Color(0.96, 0.97, 1.0, 1.0)
const TAG_COLOR := Color(0.85, 1.0, 0.78, 0.92)
const DESC_COLOR := Color(0.88, 0.9, 0.95, 0.86)
const SOLD_COLOR := Color(1.0, 0.86, 0.45, 1.0)
const DISABLED_COLOR := Color(1.0, 0.62, 0.55, 0.95)
const PAPER_BG := Color(0.13, 0.16, 0.14, 0.88)
const PAPER_BORDER := Color(0.85, 1.0, 0.78, 0.35)
const SELECT_BORDER := Color(1.0, 0.92, 0.55, 1.0)

var index: int = -1
var option: Dictionary = {}

var _body: Control
var _panel: Panel
var _style: StyleBoxFlat
var _art: TextureRect
var _shadow: Panel
var _name: Label
var _tag: Label
var _desc: Label
var _status: Label
var _badges: HBoxContainer
var _press_active: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _long_fired: bool = false
var _hover_tween: Tween
var _selected: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_build()


func _build() -> void:
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style = StyleBoxFlat.new()
	_style.bg_color = PAPER_BG
	_style.set_corner_radius_all(10)
	_style.set_border_width_all(2)
	_style.border_color = PAPER_BORDER
	_style.shadow_color = Color(0, 0, 0, 0.45)
	_style.shadow_size = 6
	_style.shadow_offset = Vector2(0, 3)
	_panel.add_theme_stylebox_override("panel", _style)
	_body.add_child(_panel)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 6
	col.offset_right = -6
	col.offset_top = 6
	col.offset_bottom = -6
	col.add_theme_constant_override("separation", 3)
	_body.add_child(col)

	var art_holder := Control.new()
	art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_holder.custom_minimum_size = Vector2(0, 86)
	art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(art_holder)
	_shadow = Panel.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.35)
	shadow_style.set_corner_radius_all(40)
	_shadow.add_theme_stylebox_override("panel", shadow_style)
	_shadow.anchor_left = 0.2
	_shadow.anchor_right = 0.8
	_shadow.anchor_top = 0.86
	_shadow.anchor_bottom = 0.98
	art_holder.add_child(_shadow)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_holder.add_child(_art)

	_name = _make_label(14, NAME_COLOR)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.clip_text = true
	col.add_child(_name)

	_badges = HBoxContainer.new()
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.alignment = BoxContainer.ALIGNMENT_CENTER
	_badges.add_theme_constant_override("separation", 6)
	col.add_child(_badges)

	_tag = _make_label(11, TAG_COLOR)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_tag)

	_desc = _make_label(11, DESC_COLOR)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.max_lines_visible = 3
	col.add_child(_desc)

	_status = _make_label(13, SOLD_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	col.add_child(_status)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 3)
	return l


func get_body() -> Control:
	return _body


func setup(p_index: int, p_option: Dictionary) -> void:
	index = p_index
	option = p_option
	_art.texture = p_option.get("texture") as Texture2D
	_shadow.visible = _art.texture != null
	_name.text = String(p_option.get("title", ""))
	_tag.text = String(p_option.get("tag", ""))
	_tag.visible = not _tag.text.is_empty()
	_desc.text = String(p_option.get("desc", ""))
	_desc.visible = not _desc.text.is_empty()
	_rebuild_badges()
	refresh_state()


func _rebuild_badges() -> void:
	for c in _badges.get_children():
		c.queue_free()
	var atk := int(option.get("attack", -1))
	var hp := int(option.get("hp", -1))
	var cost := int(option.get("cost", -1))
	if atk >= 0:
		_badges.add_child(_make_badge(RealtimeArenaView.STAT_ATTACK_TEX, atk))
	if hp >= 0:
		_badges.add_child(_make_badge(RealtimeArenaView.STAT_HP_TEX, hp))
	if cost >= 0:
		_badges.add_child(_make_badge(RealtimeArenaView.STAT_GOLD_TEX, cost))
	_badges.visible = _badges.get_child_count() > 0


func _make_badge(tex: Texture2D, value: int) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 1)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = tex
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var l := _make_label(13, NAME_COLOR)
	l.text = str(value)
	row.add_child(l)
	return row


func is_disabled() -> bool:
	return bool(option.get("disabled", false)) or bool(option.get("sold", false))


func set_sold(sold: bool, text: String = "已购入") -> void:
	option["sold"] = sold
	if sold:
		option["status_text"] = text
	refresh_state()


func set_selected(selected: bool) -> void:
	_selected = selected
	refresh_state()


func refresh_state() -> void:
	var sold := bool(option.get("sold", false))
	var disabled := bool(option.get("disabled", false))
	var status_text := String(option.get("status_text", ""))
	if sold:
		_status.text = status_text if not status_text.is_empty() else "已购入"
		_status.add_theme_color_override("font_color", SOLD_COLOR)
	elif disabled:
		_status.text = String(option.get("disabled_reason", "不可选"))
		_status.add_theme_color_override("font_color", DISABLED_COLOR)
	_status.visible = sold or disabled
	_style.border_color = SELECT_BORDER if _selected else PAPER_BORDER
	_style.set_border_width_all(3 if _selected else 2)
	_art.modulate = Color(1, 1, 1, 0.45) if (sold or disabled) else Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _body != null:
		_body.pivot_offset = size * 0.5


func _process(delta: float) -> void:
	if not _press_active or _long_fired:
		return
	_press_time += delta
	if _press_time >= LONG_PRESS_SECONDS:
		_long_fired = true
		_press_active = false
		_tween_hover(1.0)
		long_pressed.emit(self)


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pressed = mb.pressed
		released = not mb.pressed
		pos = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		pressed = st.pressed
		released = not st.pressed
		pos = st.position
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _press_active and event.position.distance_to(_press_pos) > TAP_MOVE_TOLERANCE:
			_press_active = false
			_tween_hover(1.0)
		return
	else:
		return
	if pressed:
		_press_active = true
		_long_fired = false
		_press_time = 0.0
		_press_pos = pos
		_tween_hover(0.94)
		accept_event()
	elif released:
		var was_tap := _press_active and not _long_fired
		_press_active = false
		_tween_hover(1.0)
		if was_tap:
			tapped.emit(self)
		accept_event()


func _tween_hover(target: float) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_body, "scale", Vector2.ONE * target, 0.09)
