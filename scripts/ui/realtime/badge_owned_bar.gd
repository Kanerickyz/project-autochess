class_name BadgeOwnedBar
extends Control
## 招募 / 准备 / 战斗底部持有徽章横排；长按弹出说明，滑动切换（对齐单位介绍卡）。
## 挂在 DockBox 内作为独立行，不叠在上一动/倍速/下一动按钮上。

signal badge_long_pressed(badge: BadgeData)

const ICON_SIZE := 36.0
const GAP := 8.0
const LONG_PRESS_SEC := 0.45
const ROW_HEIGHT := 44.0

var _row: HBoxContainer
var _info: PanelContainer
var _info_title: Label
var _info_body: RichTextLabel
var _badges: Array[BadgeData] = []
var _press_index: int = -1
var _press_time: float = 0.0
var _long_fired: bool = false
var _shown_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Dock 内流式布局：不要用屏幕底锚点（会盖住倍速等按钮）。
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_build()
	visible = false
	set_process(false)


func _build() -> void:
	_row = HBoxContainer.new()
	_row.name = "OwnedRow"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", int(GAP))
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

	_info = PanelContainer.new()
	_info.name = "BadgeInfoCard"
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.92, 0.79, 0.98)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_info.add_theme_stylebox_override("panel", style)
	_info.custom_minimum_size = Vector2(220, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_info.add_child(box)
	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 15)
	_info_title.add_theme_color_override("font_color", Color(0.13, 0.10, 0.08, 1.0))
	box.add_child(_info_title)
	_info_body = RichTextLabel.new()
	_info_body.bbcode_enabled = false
	_info_body.fit_content = true
	_info_body.scroll_active = false
	_info_body.custom_minimum_size = Vector2(200, 0)
	_info_body.add_theme_font_size_override("normal_font_size", 12)
	_info_body.add_theme_color_override("default_color", Color(0.28, 0.24, 0.18, 1.0))
	box.add_child(_info_body)
	add_child(_info)


func set_owned_badges(badges: Array[BadgeData]) -> void:
	_badges = badges.duplicate()
	for child in _row.get_children():
		child.queue_free()
	hide_info()
	if _badges.is_empty():
		visible = false
		custom_minimum_size = Vector2(0.0, 0.0)
		return
	visible = true
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	for i in _badges.size():
		var badge: BadgeData = _badges[i]
		var icon := BadgeCircleDraw.new()
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.set_badge_visual(badge)
		icon.gui_input.connect(_on_icon_gui_input.bind(i))
		_row.add_child(icon)


func hide_info() -> void:
	if _info != null:
		_info.visible = false
	_shown_index = -1


func show_info_for(badge: BadgeData, index: int = -1) -> void:
	if badge == null or _info == null:
		return
	## 三选一阶段持有可为空：仍须显示说明卡，不能因空列表把整条藏死。
	visible = true
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_info_title.text = badge.display_name
	_info_body.text = "%s\n%s" % [badge.get_condition_label(), badge.effect_text]
	_info.reset_size()
	## 本行上方居中（向 Arena 方向弹出，不挡 Dock 按钮）。
	_info.position = Vector2(
		(size.x - _info.get_combined_minimum_size().x) * 0.5,
		-(_info.get_combined_minimum_size().y + 12.0),
	)
	_info.visible = true
	if index >= 0:
		_shown_index = index
	badge_long_pressed.emit(badge)


func _on_icon_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_press(index)
		else:
			_end_press()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_track_motion(drag.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_press(index)
		else:
			_end_press()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _press_index < 0:
			return
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		_track_motion(mm.position)


func _begin_press(index: int) -> void:
	_press_index = index
	_press_time = 0.0
	_long_fired = false
	set_process(true)


func _end_press() -> void:
	set_process(false)
	_press_index = -1
	## 与单位介绍卡一致：松手收卡。
	hide_info()


func _track_motion(_local_pos: Vector2) -> void:
	if _press_index < 0 or not _long_fired:
		return
	var hit := _index_at_global(get_global_mouse_position())
	if hit < 0 or hit == _shown_index:
		return
	if hit >= _badges.size() or _badges[hit] == null:
		return
	_press_index = hit
	show_info_for(_badges[hit], hit)


func _index_at_global(global_pt: Vector2) -> int:
	if _row == null:
		return -1
	for i in _row.get_child_count():
		var child := _row.get_child(i) as Control
		if child == null or not child.visible:
			continue
		if child.get_global_rect().has_point(global_pt):
			return i
	return -1


func _process(delta: float) -> void:
	if _press_index < 0:
		set_process(false)
		return
	_press_time += delta
	if not _long_fired and _press_time >= LONG_PRESS_SEC:
		_long_fired = true
		if _press_index < _badges.size():
			show_info_for(_badges[_press_index], _press_index)
