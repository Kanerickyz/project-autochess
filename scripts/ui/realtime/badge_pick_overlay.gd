class_name BadgePickOverlay
extends Control
## 胜后徽章三选一：三栏大圆占位 + 名 + 条件短句；点选领取；可跳过。
## 禁止仅用三个系统 Button 文本条作为候选项。

signal badge_picked(index: int)
signal badge_skipped
signal badge_long_pressed(badge: BadgeData)

const CIRCLE_SIZE := 112.0
const LONG_PRESS_SEC := 0.45

var _title: Label
var _row: HBoxContainer
var _skip_btn: Button
var _info: PanelContainer
var _info_title: Label
var _info_body: RichTextLabel
var _slots: Array[Control] = []
var _press_index: int = -1
var _press_time: float = 0.0
var _long_fired: bool = false
var _shown_index: int = -1
var _candidates: Array[BadgeData] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	## 必须 anchors+offsets，否则代码新建 Control 尺寸常为 0，内容挤左上、Dim 不可见。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build()
	visible = false
	set_process(false)


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := VBoxContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_constant_override("separation", 18)
	center.add_child(panel)

	_title = Label.new()
	_title.text = "选择徽章（免费 · 可跳过）"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82, 1.0))
	panel.add_child(_title)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_row)

	_slots.clear()
	for i in BadgeSession.OFFER_COUNT:
		var slot := _make_candidate_slot(i)
		_row.add_child(slot)
		_slots.append(slot)

	_skip_btn = Button.new()
	_skip_btn.text = "跳过"
	_skip_btn.custom_minimum_size = Vector2(120, 40)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.pressed.connect(func() -> void: badge_skipped.emit())
	var skip_wrap := CenterContainer.new()
	skip_wrap.add_child(_skip_btn)
	panel.add_child(skip_wrap)

	## 长按说明卡叠在三选一之上（持有条可能为空且在 Dim 之下）。
	_info = PanelContainer.new()
	_info.name = "PickInfoCard"
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.z_index = 30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.92, 0.79, 0.98)
	style.set_content_margin_all(10.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_info.add_theme_stylebox_override("panel", style)
	_info.custom_minimum_size = Vector2(240, 0)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)
	_info.add_child(info_box)
	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 15)
	_info_title.add_theme_color_override("font_color", Color(0.13, 0.10, 0.08, 1.0))
	info_box.add_child(_info_title)
	_info_body = RichTextLabel.new()
	_info_body.bbcode_enabled = false
	_info_body.fit_content = true
	_info_body.scroll_active = false
	_info_body.custom_minimum_size = Vector2(220, 0)
	_info_body.add_theme_font_size_override("normal_font_size", 12)
	_info_body.add_theme_color_override("default_color", Color(0.28, 0.24, 0.18, 1.0))
	info_box.add_child(_info_body)
	add_child(_info)


func _make_candidate_slot(index: int) -> Control:
	var col := VBoxContainer.new()
	col.name = "BadgeSlot%d" % index
	col.custom_minimum_size = Vector2(CIRCLE_SIZE + 24.0, CIRCLE_SIZE + 72.0)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_STOP
	col.gui_input.connect(_on_slot_gui_input.bind(index))

	var circle := BadgeCircleDraw.new()
	circle.name = "Circle"
	circle.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(circle)

	var name_l := Label.new()
	name_l.name = "Name"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(CIRCLE_SIZE + 16.0, 0)
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", Color(0.98, 0.95, 0.88, 1.0))
	col.add_child(name_l)

	var cond_l := Label.new()
	cond_l.name = "Cond"
	cond_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cond_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cond_l.custom_minimum_size = Vector2(CIRCLE_SIZE + 16.0, 0)
	cond_l.add_theme_font_size_override("font_size", 12)
	cond_l.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	col.add_child(cond_l)
	return col


func show_offers(candidates: Array[BadgeData]) -> void:
	## 再次钉死全屏，避免父节点晚布局后仍为 0 尺寸。
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_candidates = candidates.duplicate()
	var shown := 0
	for i in _slots.size():
		var slot: Control = _slots[i]
		var badge: BadgeData = candidates[i] if i < candidates.size() else null
		_bind_slot(slot, badge)
		slot.visible = badge != null
		if badge != null:
			shown += 1
	if _title != null:
		if shown <= 0:
			_title.text = "暂无可选徽章（可跳过）"
		else:
			_title.text = "选择徽章（免费 · 可跳过）"
	visible = true
	move_to_front()


func hide_offers() -> void:
	visible = false
	_press_index = -1
	set_process(false)
	hide_info()


func show_info_for(badge: BadgeData, index: int = -1) -> void:
	if badge == null or _info == null:
		return
	_info_title.text = badge.display_name
	_info_body.text = "%s\n%s" % [badge.get_condition_label(), badge.effect_text]
	_info.reset_size()
	var mins := _info.get_combined_minimum_size()
	_info.position = Vector2((size.x - mins.x) * 0.5, size.y * 0.62)
	_info.visible = true
	if index >= 0:
		_shown_index = index


func hide_info() -> void:
	if _info != null:
		_info.visible = false
	_shown_index = -1


func _bind_slot(slot: Control, badge: BadgeData) -> void:
	var circle := slot.get_node_or_null("Circle") as BadgeCircleDraw
	var name_l := slot.get_node_or_null("Name") as Label
	var cond_l := slot.get_node_or_null("Cond") as Label
	if circle != null:
		circle.set_badge_visual(badge)
	if name_l != null:
		name_l.text = badge.display_name if badge != null else ""
	if cond_l != null:
		cond_l.text = badge.get_condition_label() if badge != null else ""


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_press(index)
		else:
			_end_press(index)
	elif event is InputEventScreenDrag:
		_track_motion()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_press(index)
		else:
			_end_press(index)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _press_index < 0:
			return
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		_track_motion()


func _begin_press(index: int) -> void:
	_press_index = index
	_press_time = 0.0
	_long_fired = false
	set_process(true)


func _end_press(_index: int) -> void:
	## 滑动后可能换到别的槽；松手以当前 _press_index 为准。
	if _press_index < 0:
		return
	set_process(false)
	var pick_index := _press_index
	_press_index = -1
	if _long_fired:
		## 与单位介绍卡一致：长按看说明后松手收卡，不领取。
		hide_info()
		return
	if pick_index >= 0 and pick_index < _candidates.size() and _candidates[pick_index] != null:
		badge_picked.emit(pick_index)


func _track_motion() -> void:
	if _press_index < 0 or not _long_fired:
		return
	var hit := _slot_index_at_global(get_global_mouse_position())
	if hit < 0 or hit == _shown_index:
		return
	if hit >= _candidates.size() or _candidates[hit] == null:
		return
	_press_index = hit
	show_info_for(_candidates[hit], hit)
	badge_long_pressed.emit(_candidates[hit])


func _slot_index_at_global(global_pt: Vector2) -> int:
	for i in _slots.size():
		var slot: Control = _slots[i]
		if slot == null or not slot.visible:
			continue
		if slot.get_global_rect().has_point(global_pt):
			return i
	return -1


func _process(delta: float) -> void:
	if _press_index < 0:
		set_process(false)
		return
	_press_time += delta
	if not _long_fired and _press_time >= LONG_PRESS_SEC:
		_long_fired = true
		var badge: BadgeData = (
			_candidates[_press_index] if _press_index < _candidates.size() else null
		)
		if badge != null:
			show_info_for(badge, _press_index)
			badge_long_pressed.emit(badge)
