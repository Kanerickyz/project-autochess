class_name MapView
extends Control

signal node_selected(node_id: int)

const NODE_SIZE := Vector2(56, 56)
const FLOOR_SPACING := 72.0
const COLUMN_SPACING := 80.0
const PATH_WIDTH := 3.0

const _TYPE_COLORS := {
	MapNodeType.Type.START: Color(0.55, 0.85, 0.95),
	MapNodeType.Type.COMBAT: Color(0.75, 0.78, 0.82),
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

var _map_state: MapState
var _node_buttons: Dictionary = {}
var _scroll: ScrollContainer
var _content: Control
var _path_drawer: Control


func _ready() -> void:
	_build_layout()


func set_map_state(state: MapState) -> void:
	_map_state = state
	_rebuild_map()


func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	_node_buttons.clear()

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_content = Control.new()
	var view_w := maxf(360.0, size.x)
	_content.custom_minimum_size = Vector2(view_w, 800)
	_scroll.add_child(_content)

	_path_drawer = Control.new()
	_path_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_path_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_path_drawer)
	_path_drawer.draw.connect(_draw_paths)


func _rebuild_map() -> void:
	if _content == null:
		_build_layout()
	for button in _node_buttons.values():
		if is_instance_valid(button):
			button.queue_free()
	_node_buttons.clear()

	if _map_state == null:
		_path_drawer.queue_redraw()
		return

	var max_floor := 0
	for node in _map_state.nodes:
		max_floor = maxi(max_floor, node.get_floor())
	var view_w := maxf(360.0, size.x)
	_content.custom_minimum_size = Vector2(
		view_w,
		maxf(800.0, (max_floor + 2) * FLOOR_SPACING + 120.0),
	)

	for node in _map_state.nodes:
		var pos := _node_position(node, max_floor)
		var button := _create_node_button(node, pos)
		_content.add_child(button)
		_node_buttons[node.get_id()] = button

	_path_drawer.queue_redraw()
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_content.custom_minimum_size.y)


func _node_position(node: MapNodeRuntime, max_floor: int) -> Vector2:
	var y := (max_floor - node.get_floor()) * FLOOR_SPACING + 40.0
	var content_w := _content.custom_minimum_size.x if _content != null else 360.0
	var x := clampf(24.0 + node.get_column() * COLUMN_SPACING, 16.0, content_w - NODE_SIZE.x - 16.0)
	return Vector2(x, y)


func _create_node_button(node: MapNodeRuntime, pos: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NODE_SIZE
	button.position = pos
	button.toggle_mode = false
	button.focus_mode = Control.FOCUS_NONE
	var effective_type := (
		node.get_effective_type()
		if node.get_node_type() != MapNodeType.Type.MYSTERY
		else node.get_node_type()
	)
	var label := MapNodeType.display_name(effective_type)
	if node.completed:
		label = "✓"
	button.text = label
	button.disabled = not node.available
	var base_color: Color = _TYPE_COLORS.get(effective_type, Color.GRAY)
	if node.completed:
		base_color = base_color.darkened(0.35)
	elif not node.available:
		base_color = base_color.darkened(0.2)
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	button.pressed.connect(_on_node_pressed.bind(node.get_id()))
	return button


func _draw_paths() -> void:
	if _map_state == null:
		return
	var max_floor := 0
	for node in _map_state.nodes:
		max_floor = maxi(max_floor, node.get_floor())
	for node in _map_state.nodes:
		var from_pos := _node_position(node, max_floor) + NODE_SIZE * 0.5
		for outgoing_id in node.get_outgoing_ids():
			var target := _map_state.get_node(outgoing_id)
			if target == null:
				continue
			var to_pos := _node_position(target, max_floor) + NODE_SIZE * 0.5
			var color := Color(0.7, 0.75, 0.85, 0.8)
			if node.completed and target.available:
				color = Color(0.95, 0.85, 0.35, 0.95)
			elif node.completed:
				color = Color(0.55, 0.9, 0.65, 0.85)
			_path_drawer.draw_line(from_pos, to_pos, color, PATH_WIDTH, true)


func _on_node_pressed(node_id: int) -> void:
	node_selected.emit(node_id)
