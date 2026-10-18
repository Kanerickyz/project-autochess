class_name MapView
extends Control

signal node_selected(node_id: int)

const NODE_SIZE := Vector2(64, 64)
const FLOOR_SPACING := 108.0
const SIDE_MARGIN := 20.0
const TOP_PAD := 36.0
const PATH_WIDTH := 3.5
const PATH_SEGMENTS := 10

const _TYPE_COLORS := {
	MapNodeType.Type.START: Color(0.55, 0.85, 0.95),
	MapNodeType.Type.COMBAT: Color(0.78, 0.80, 0.84),
	MapNodeType.Type.ELITE: Color(0.95, 0.72, 0.35),
	MapNodeType.Type.SHOP: Color(0.45, 0.85, 0.55),
	MapNodeType.Type.REST: Color(0.55, 0.65, 0.95),
	MapNodeType.Type.EVENT: Color(0.85, 0.65, 0.95),
	MapNodeType.Type.TREASURE: Color(0.95, 0.85, 0.35),
	MapNodeType.Type.MYSTERY: Color(0.7, 0.7, 0.85),
	MapNodeType.Type.SACRIFICE: Color(0.75, 0.25, 0.35),
	MapNodeType.Type.BOSS: Color(0.95, 0.35, 0.35),
	MapNodeType.Type.ENCHANT: Color(0.45, 0.75, 0.95),
}

## 短标签，避免方块内挤字。
const _TYPE_SHORT := {
	MapNodeType.Type.START: "起点",
	MapNodeType.Type.COMBAT: "战斗",
	MapNodeType.Type.ELITE: "精英",
	MapNodeType.Type.SHOP: "商店",
	MapNodeType.Type.REST: "休息",
	MapNodeType.Type.EVENT: "事件",
	MapNodeType.Type.TREASURE: "宝箱",
	MapNodeType.Type.MYSTERY: "?",
	MapNodeType.Type.SACRIFICE: "献祭",
	MapNodeType.Type.BOSS: "Boss",
	MapNodeType.Type.ENCHANT: "附魔",
}

var _map_state: MapState
var _node_buttons: Dictionary = {}
## node_id -> 布局后的左上角坐标（避免窄屏 column*spacing 被 clamp 叠在一起）。
var _layout_positions: Dictionary = {}
var _scroll: ScrollContainer
var _content: Control
var _path_drawer: Control
## 手指/鼠标拖动浏览：超过阈值后滚动，并吞掉节点点击。
var _pan_tracking := false
var _pan_dragging := false
var _pan_last_y := 0.0
var _pan_press_node_id := -1
const PAN_DRAG_THRESHOLD_PX := 10.0


func _ready() -> void:
	_build_layout()
	resized.connect(_on_resized)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	## 空白区（未点到节点按钮）也可拖动滚动。
	_handle_pan_input(event, -1)


func set_map_state(state: MapState) -> void:
	_map_state = state
	_rebuild_map()


func _on_resized() -> void:
	if _map_state != null:
		_rebuild_map()


func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	_node_buttons.clear()
	_layout_positions.clear()

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	## 竖向始终显示可滚；拖动由本视图处理，不依赖必须点滑块。
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.gui_input.connect(_on_scroll_gui_input)
	add_child(_scroll)

	_content = Control.new()
	var view_w := _view_width()
	_content.custom_minimum_size = Vector2(view_w, 800)
	_content.mouse_filter = Control.MOUSE_FILTER_STOP
	_content.gui_input.connect(_on_content_gui_input)
	_scroll.add_child(_content)

	_path_drawer = Control.new()
	_path_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_path_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_path_drawer)
	_path_drawer.draw.connect(_draw_paths)


func _view_width() -> float:
	return maxf(320.0, size.x)


func _rebuild_map() -> void:
	if _content == null:
		_build_layout()
	for button in _node_buttons.values():
		if is_instance_valid(button):
			button.queue_free()
	_node_buttons.clear()
	_layout_positions.clear()

	if _map_state == null:
		_path_drawer.queue_redraw()
		return

	var max_floor := 0
	for node in _map_state.nodes:
		max_floor = maxi(max_floor, node.get_floor())
	var view_w := _view_width()
	_content.custom_minimum_size = Vector2(
		view_w,
		maxf(800.0, (max_floor + 2) * FLOOR_SPACING + TOP_PAD + NODE_SIZE.y + 48.0),
	)
	_recompute_layout(max_floor, view_w)

	for node in _map_state.nodes:
		var pos: Vector2 = _layout_positions.get(node.get_id(), Vector2.ZERO)
		var button := _create_node_button(node, pos)
		_content.add_child(button)
		_node_buttons[node.get_id()] = button

	_path_drawer.queue_redraw()
	await get_tree().process_frame
	_scroll_to_focus_node(max_floor)


## 按层均分水平位置：同层 1/2/3 个节点均匀铺开，不再用原始 column 乘间距（窄屏会 clamp 重叠）。
func _recompute_layout(max_floor: int, content_w: float) -> void:
	_layout_positions.clear()
	var by_floor: Dictionary = {}
	for node in _map_state.nodes:
		var floor_index := node.get_floor()
		if not by_floor.has(floor_index):
			var empty: Array[MapNodeRuntime] = []
			by_floor[floor_index] = empty
		(by_floor[floor_index] as Array).append(node)

	var usable := maxf(80.0, content_w - SIDE_MARGIN * 2.0 - NODE_SIZE.x)
	for floor_index in by_floor.keys():
		var nodes: Array = by_floor[floor_index]
		nodes.sort_custom(func(a: MapNodeRuntime, b: MapNodeRuntime) -> bool:
			if a.get_column() != b.get_column():
				return a.get_column() < b.get_column()
			return a.get_id() < b.get_id()
		)
		var count := nodes.size()
		var y := (max_floor - int(floor_index)) * FLOOR_SPACING + TOP_PAD
		for i in count:
			var t := 0.5 if count <= 1 else float(i) / float(count - 1)
			var x := SIDE_MARGIN + t * usable
			_layout_positions[(nodes[i] as MapNodeRuntime).get_id()] = Vector2(x, y)


func _scroll_to_focus_node(max_floor: int) -> void:
	if _scroll == null or _content == null or _map_state == null:
		return
	var focus_y := _resolve_focus_content_y(max_floor)
	var viewport_h := _scroll.size.y
	if viewport_h <= 1.0:
		viewport_h = size.y
	var max_scroll := maxi(0, int(_content.custom_minimum_size.y - viewport_h))
	var target := int(focus_y + NODE_SIZE.y * 0.5 - viewport_h * 0.5)
	_scroll.scroll_vertical = clampi(target, 0, max_scroll)


func _resolve_focus_content_y(max_floor: int) -> float:
	if _map_state.current_node_id >= 0:
		var current := _map_state.get_node(_map_state.current_node_id)
		if current != null:
			return _node_position(current, max_floor).y
	var available := _map_state.get_available_nodes()
	if not available.is_empty():
		var sum_y := 0.0
		for node in available:
			sum_y += _node_position(node, max_floor).y
		return sum_y / float(available.size())
	return _content.custom_minimum_size.y


func _node_position(node: MapNodeRuntime, max_floor: int) -> Vector2:
	if _layout_positions.has(node.get_id()):
		return _layout_positions[node.get_id()]
	## 布局尚未计算时的回退（不应在正常绘制路径使用）。
	var y := (max_floor - node.get_floor()) * FLOOR_SPACING + TOP_PAD
	var content_w := _content.custom_minimum_size.x if _content != null else 360.0
	var usable := maxf(80.0, content_w - SIDE_MARGIN * 2.0 - NODE_SIZE.x)
	var x := SIDE_MARGIN + 0.5 * usable
	return Vector2(x, y)


func _create_node_button(node: MapNodeRuntime, pos: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.size = NODE_SIZE
	button.position = pos
	button.toggle_mode = false
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	var effective_type := (
		node.get_effective_type()
		if node.get_node_type() != MapNodeType.Type.MYSTERY
		else node.get_node_type()
	)
	var label: String = String(_TYPE_SHORT.get(effective_type, MapNodeType.display_name(effective_type)))
	if node.completed:
		label = "✓"
	button.text = label
	## 不用 disabled：禁用控件不收指针，无法从该格开始拖地图。
	button.disabled = false
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if node.available and not node.completed else Control.CURSOR_ARROW
	)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.12, 0.12, 0.14, 0.85))
	button.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.55))
	button.add_theme_constant_override("outline_size", 2)
	var base_color: Color = _TYPE_COLORS.get(effective_type, Color.GRAY)
	if node.completed:
		base_color = base_color.darkened(0.4)
	elif not node.available:
		base_color = base_color.darkened(0.28).lerp(Color(0.2, 0.22, 0.28), 0.35)
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = Color(0.05, 0.06, 0.08, 0.75)
	if node.available and not node.completed:
		style.border_color = Color(1.0, 0.92, 0.55, 0.95)
		style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	## 不用 pressed：拖动浏览时要区分「点击选节点」与「滑动地图」。
	button.gui_input.connect(_on_node_button_gui_input.bind(node.get_id()))
	return button


func _draw_paths() -> void:
	if _map_state == null:
		return
	var max_floor := 0
	for node in _map_state.nodes:
		max_floor = maxi(max_floor, node.get_floor())
	## 先画暗线再画高亮，减少交叉时可读性崩坏。
	var dim_edges: Array[Dictionary] = []
	var lit_edges: Array[Dictionary] = []
	for node in _map_state.nodes:
		var from_pos := _node_position(node, max_floor) + NODE_SIZE * 0.5
		var out_ids := node.get_outgoing_ids()
		for edge_i in out_ids.size():
			var outgoing_id: int = out_ids[edge_i]
			var target := _map_state.get_node(outgoing_id)
			if target == null:
				continue
			var to_pos := _node_position(target, max_floor) + NODE_SIZE * 0.5
			var color := Color(0.78, 0.82, 0.9, 0.55)
			var lit := false
			if node.completed and target.available:
				color = Color(0.98, 0.88, 0.4, 0.98)
				lit = true
			elif node.completed:
				color = Color(0.55, 0.9, 0.65, 0.75)
				lit = true
			elif not node.available and not target.available:
				color = Color(0.55, 0.58, 0.65, 0.35)
			var entry := {
				"from": from_pos,
				"to": to_pos,
				"color": color,
				"bend": _edge_bend(from_pos, to_pos, edge_i, out_ids.size()),
			}
			if lit:
				lit_edges.append(entry)
			else:
				dim_edges.append(entry)
	for entry in dim_edges:
		_draw_bent_path(entry["from"], entry["to"], entry["color"], PATH_WIDTH, entry["bend"])
	for entry in lit_edges:
		_draw_bent_path(entry["from"], entry["to"], entry["color"], PATH_WIDTH + 0.5, entry["bend"])


## 同层多出边时左右微弯，减轻直线完全重合。
func _edge_bend(from_pos: Vector2, to_pos: Vector2, edge_i: int, edge_count: int) -> float:
	if edge_count <= 1:
		return (to_pos.x - from_pos.x) * 0.08
	var spread := (float(edge_i) - float(edge_count - 1) * 0.5) * 18.0
	return spread + (to_pos.x - from_pos.x) * 0.05


func _draw_bent_path(
	from_pos: Vector2,
	to_pos: Vector2,
	color: Color,
	width: float,
	bend: float,
) -> void:
	var mid := (from_pos + to_pos) * 0.5
	mid.x += bend
	var points := PackedVector2Array()
	for i in PATH_SEGMENTS + 1:
		var t := float(i) / float(PATH_SEGMENTS)
		var a := from_pos.lerp(mid, t)
		var b := mid.lerp(to_pos, t)
		points.append(a.lerp(b, t))
	_path_drawer.draw_polyline(points, color, width, true)


func _on_scroll_gui_input(event: InputEvent) -> void:
	_handle_pan_input(event, -1)


func _on_content_gui_input(event: InputEvent) -> void:
	_handle_pan_input(event, -1)


func _on_node_button_gui_input(event: InputEvent, node_id: int) -> void:
	_handle_pan_input(event, node_id)


func _handle_pan_input(event: InputEvent, node_id: int) -> void:
	if _scroll == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pan_tracking = true
			_pan_dragging = false
			_pan_last_y = mb.global_position.y
			_pan_press_node_id = node_id
			accept_event()
			return
		var was_dragging := _pan_dragging
		var press_id := _pan_press_node_id
		_pan_tracking = false
		_pan_dragging = false
		_pan_press_node_id = -1
		accept_event()
		## 未拖动且点在可用节点上 → 选中。
		if was_dragging or press_id < 0 or _map_state == null:
			return
		var node := _map_state.get_node(press_id)
		if node != null and node.available and not node.completed:
			node_selected.emit(press_id)
		return
	if event is InputEventMouseMotion and _pan_tracking:
		var motion := event as InputEventMouseMotion
		var y := motion.global_position.y
		if not _pan_dragging and absf(y - _pan_last_y) >= PAN_DRAG_THRESHOLD_PX:
			_pan_dragging = true
		if _pan_dragging:
			var delta := _pan_last_y - y
			_pan_last_y = y
			_scroll.scroll_vertical = clampi(
				_scroll.scroll_vertical + int(round(delta)),
				0,
				_max_scroll_vertical(),
			)
			accept_event()


func _max_scroll_vertical() -> int:
	if _scroll == null or _content == null:
		return 0
	var viewport_h := _scroll.size.y
	if viewport_h <= 1.0:
		viewport_h = size.y
	return maxi(0, int(_content.custom_minimum_size.y - viewport_h))
