class_name BoardScene3D
extends Node3D

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)
signal unit_hover_changed(unit: UnitInstance)
signal grid_cell_hover_changed(cell: Vector2i)

const CELL_SCRIPT := preload("res://scripts/ui/board_3d/board_cell_3d.gd")
const UNIT_SCRIPT := preload("res://scripts/ui/board_3d/unit_display_3d.gd")

const PREVIEW_MODULATE := Color(1.0, 1.0, 1.0, 0.55)
const CARD_HEIGHT_RATIO := 1.12

@export var board_theme_config: BoardThemeConfig = preload("res://resources/ui/default_board_theme.tres")

var board_transition_active: bool = false
var cell_size: int = 64

var _grid: BoardGrid
var _camera: Camera3D
var _vfx_layer: Node2D
var _tile_root: Node3D
var _unit_root: Node3D
var _preview_root: Node3D
var _cells: Dictionary = {}
var _unit_nodes: Dictionary = {}
var _cell_home_positions: Dictionary = {}
var _preview_nodes: Array[Node3D] = []
var _preview_units_by_cell: Dictionary = {}
var _tile_size: float = 1.0
var _pixel_cell_size: int = 64
var _combat_spawn_duration: float = -1.0
var _character_phase: UnitCardDisplay.CharacterPhase = UnitCardDisplay.CharacterPhase.PREPARE
var _acting_unit_ids: Dictionary = {}
var _combat_view_active: bool = false
var _attack_highlight_cells: Dictionary = {}
var _range_preview_cells: Dictionary = {}
var _placement_mode_active: bool = false
var _prepare_drag_active: bool = false
var _drag_hover_cell: Vector2i = Vector2i(-1, -1)
var _drag_hover_valid: bool = false
var _hovered_unit: UnitInstance
var _hovered_grid_cell: Vector2i = Vector2i(-1, -1)
var _board_transition_tween: Tween


func setup(
	grid: BoardGrid,
	camera: Camera3D,
	vfx_layer: Node2D,
	pixel_cell_size: int,
) -> void:
	BoardTheme.set_config(board_theme_config)
	_grid = grid
	_camera = camera
	_vfx_layer = vfx_layer
	_pixel_cell_size = pixel_cell_size
	cell_size = pixel_cell_size
	_tile_size = maxf(0.8, float(pixel_cell_size) / 64.0)
	_rebuild_board()


func get_board_center_3d() -> Vector3:
	if _grid == null:
		return Vector3.ZERO
	var bounds := get_board_bounds_3d()
	return bounds.position + bounds.size * 0.5


func get_board_bounds_3d() -> AABB:
	if _grid == null:
		return AABB()
	var size := _grid.get_size()
	var tile_h := BoardCell3D.get_tile_height(_tile_size)
	return AABB(
		Vector3.ZERO,
		Vector3(size.x * _tile_size, tile_h, size.y * _tile_size),
	)


func get_tile_size() -> float:
	return _tile_size


func get_ortho_size() -> float:
	if _grid == null:
		return 10.0
	var size := _grid.get_size()
	var board_extent := maxf(size.x, size.y) * _tile_size
	return board_extent * 0.62


func get_board_screen_rect() -> Rect2:
	if _grid == null or _camera == null:
		return Rect2()
	var bounds := get_board_bounds_3d()
	var corners: Array[Vector3] = [
		bounds.position,
		bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
		bounds.position + Vector3(0.0, 0.0, bounds.size.z),
		bounds.position + Vector3(bounds.size.x, 0.0, bounds.size.z),
	]
	var min_v := Vector2(INF, INF)
	var max_v := Vector2(-INF, -INF)
	for corner in corners:
		var screen := project_world_to_screen(corner)
		min_v.x = minf(min_v.x, screen.x)
		min_v.y = minf(min_v.y, screen.y)
		max_v.x = maxf(max_v.x, screen.x)
		max_v.y = maxf(max_v.y, screen.y)
	return Rect2(min_v, max_v - min_v)


func get_board_pixel_size() -> Vector2:
	return get_board_screen_rect().size


func grid_to_world_3d(cell: Vector2i) -> Vector3:
	var surface_y := BoardCell3D.get_tile_height(_tile_size)
	return Vector3(
		cell.x * _tile_size + _tile_size * 0.5,
		surface_y,
		cell.y * _tile_size + _tile_size * 0.5,
	)


func grid_to_world(cell: Vector2i) -> Vector2:
	return project_world_to_screen(grid_to_world_3d(cell))


func grid_to_world_plane(cell: Vector2i) -> Vector2:
	var world_3d := grid_to_world_3d(cell)
	return Vector2(world_3d.x, world_3d.z)


func grid_to_unit_position(cell: Vector2i) -> Vector2:
	return grid_to_world_plane(cell)


func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / _tile_size)),
		int(floor(world_pos.z / _tile_size)),
	)


func project_world_to_screen(world_pos: Vector3) -> Vector2:
	if _camera == null:
		return Vector2(world_pos.x, world_pos.z)
	return _camera.unproject_position(world_pos)


func get_cell_at_viewport_pos(viewport_pos: Vector2) -> Vector2i:
	var hit := _raycast_board_plane(viewport_pos)
	if hit == Vector3.INF:
		return Vector2i(-1, -1)
	var cell := world_to_grid(hit)
	if _grid == null or not _grid.in_bounds(cell):
		return Vector2i(-1, -1)
	return cell


func get_player_unit_at_viewport_pos(viewport_pos: Vector2) -> UnitInstance:
	var cell := get_cell_at_viewport_pos(viewport_pos)
	if cell == Vector2i(-1, -1):
		return null
	var unit := get_unit_at_cell(cell)
	if unit == null or unit.team != UnitInstance.Team.PLAYER:
		return null
	return unit


func get_hovered_grid_cell() -> Vector2i:
	return _hovered_grid_cell


func refresh() -> void:
	if not board_transition_active:
		_restore_board_cells_home()
	sync_units()
	if not board_transition_active:
		_set_unit_nodes_visible(true)
	_update_unit_hover()
	_apply_cell_highlights()
	if _hovered_unit != null:
		unit_hover_changed.emit(_hovered_unit)


func set_placement_mode(active: bool, grid: BoardGrid = null) -> void:
	if grid != null:
		_grid = grid
	_placement_mode_active = active
	_apply_cell_highlights()


func set_prepare_drag_mode(active: bool) -> void:
	_prepare_drag_active = active
	if not active:
		_drag_hover_cell = Vector2i(-1, -1)
		_drag_hover_valid = false
	_apply_cell_highlights()


func set_drag_hover_cell(cell: Vector2i, valid: bool) -> void:
	if _drag_hover_cell == cell and _drag_hover_valid == valid:
		return
	_drag_hover_cell = cell
	_drag_hover_valid = valid
	_apply_cell_highlights()


func set_board_unit_drag_visual(unit: UnitInstance, dragging: bool) -> void:
	if unit == null:
		return
	var node := get_unit_node(unit.instance_id) as UnitDisplay3D
	if node != null:
		node.set_dragging(dragging)


func clear_all_unit_drag_visuals() -> void:
	for instance_id in _unit_nodes:
		var node: UnitDisplay3D = _unit_nodes[instance_id]
		if node != null:
			node.set_dragging(false)
			node.restore_opacity_modulate()


func set_range_preview_cells(cells: Array[Vector2i]) -> void:
	_range_preview_cells.clear()
	for cell in cells:
		_range_preview_cells[cell] = true
	_apply_cell_highlights()


func clear_range_preview_cells() -> void:
	if _range_preview_cells.is_empty():
		return
	_range_preview_cells.clear()
	_apply_cell_highlights()


func prepare_board_reveal_hidden() -> void:
	if _cells.is_empty():
		return
	var rise_offset := _tile_size * CombatAnimationConfig.BOARD_CELL_RISE_OFFSET
	for cell_node in _ordered_cells():
		var home: Vector3 = _cell_home_positions.get(cell_node.cell, cell_node.position)
		_apply_cell_hidden_state(cell_node, home, rise_offset)
	_set_unit_nodes_visible(false)


func play_board_reveal() -> void:
	if _cells.is_empty():
		return
	board_transition_active = true
	_kill_board_transition_tween()
	prepare_board_reveal_hidden()
	var ordered := _ordered_cells()
	ordered.shuffle()
	var rise_offset := _tile_size * CombatAnimationConfig.BOARD_CELL_RISE_OFFSET
	var base_delay := CombatAnimationConfig.BOARD_CELL_REVEAL_DELAY
	var jitter_max := CombatAnimationConfig.BOARD_CELL_REVEAL_JITTER
	_board_transition_tween = create_tween()
	_board_transition_tween.set_parallel(true)
	for cell_node in ordered:
		var home: Vector3 = _cell_home_positions.get(cell_node.cell, cell_node.position)
		var delay := base_delay + randf() * jitter_max
		_append_cell_reveal_tween(_board_transition_tween, cell_node, home, rise_offset, delay)
	await _board_transition_tween.finished
	_board_transition_tween = null
	board_transition_active = false
	_set_unit_nodes_visible(true)


func play_board_hide() -> void:
	if _cells.is_empty():
		return
	board_transition_active = true
	_set_unit_nodes_visible(false)
	clear_enemy_preview()
	_kill_board_transition_tween()
	var ordered := _ordered_cells()
	ordered.shuffle()
	var rise_offset := _tile_size * CombatAnimationConfig.BOARD_CELL_RISE_OFFSET
	var base_delay := CombatAnimationConfig.BOARD_CELL_REVEAL_DELAY
	var jitter_max := CombatAnimationConfig.BOARD_CELL_REVEAL_JITTER
	_board_transition_tween = create_tween()
	_board_transition_tween.set_parallel(true)
	for cell_node in ordered:
		var home: Vector3 = _cell_home_positions.get(cell_node.cell, cell_node.position)
		var delay := base_delay + randf() * jitter_max
		_append_cell_hide_tween(_board_transition_tween, cell_node, home, rise_offset, delay)
	await _board_transition_tween.finished
	_board_transition_tween = null
	board_transition_active = false
	_set_unit_nodes_visible(true)


func set_enemy_preview(placements: Array) -> void:
	clear_enemy_preview()
	if _grid == null or placements.is_empty():
		return
	_ensure_preview_root()
	for placement in placements:
		if typeof(placement) != TYPE_DICTIONARY:
			continue
		var cell: Vector2i = placement.get("cell", Vector2i(-1, -1))
		var unit_data: UnitData = placement.get("unit")
		if unit_data == null or cell == Vector2i(-1, -1) or not _grid.in_bounds(cell):
			continue
		var preview_unit := UnitInstance.from_unit_data(
			unit_data,
			cell,
			UnitInstance.Team.ENEMY,
		)
		var unit_node := UNIT_SCRIPT.new() as UnitDisplay3D
		unit_node.name = "Preview_%s" % cell
		unit_node.configure(_tile_size, _pixel_cell_size)
		unit_node.update_home_position_3d(grid_to_world_3d(cell))
		unit_node.bind_unit(preview_unit)
		unit_node.set_preview_mode(true)
		unit_node.set_character_phase(_character_phase)
		_preview_root.add_child(unit_node)
		_preview_nodes.append(unit_node)
		_preview_units_by_cell[cell] = preview_unit


func clear_enemy_preview() -> void:
	for node in _preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_preview_nodes.clear()
	_preview_units_by_cell.clear()


func sync_units() -> void:
	if _grid == null:
		return
	var seen: Dictionary = {}
	for unit in _grid.get_all_units():
		var unit_inst: UnitInstance = unit as UnitInstance
		seen[unit_inst.instance_id] = true
		_grid.sync_unit_grid_pos(unit_inst)
		var cell := _grid.find_cell_of(unit_inst)
		if cell == Vector2i(-1, -1):
			cell = unit_inst.grid_pos
		var unit_node := ensure_unit_node(unit_inst) as UnitDisplay3D
		unit_node.configure(_tile_size, _pixel_cell_size)
		var world_3d := grid_to_world_3d(cell)
		unit_node.update_home_position_3d(world_3d)
		unit_node.bind_unit(unit_inst)
		unit_node.set_character_phase(_character_phase)
		_update_unit_depth(unit_node, cell)

	var to_remove: Array[int] = []
	for instance_id in _unit_nodes:
		if not seen.has(instance_id):
			to_remove.append(instance_id)
	for instance_id in to_remove:
		remove_unit_node(instance_id)
	if _hovered_unit != null and not _unit_nodes.has(_hovered_unit.instance_id):
		_clear_unit_hover()
	sync_cell_effects()


func sync_cell_effects() -> void:
	if _grid == null:
		return
	var burning: Dictionary = {}
	if _grid.cell_effects != null:
		for cell in _grid.cell_effects.get_cells_with_effects():
			burning[cell] = true
	for key in _cells:
		var cell: Vector2i = key as Vector2i
		var board_cell: BoardCell3D = _cells[key]
		if board_cell != null:
			board_cell.set_burning(burning.has(cell))


func sync_combat_step_units(animate_new_spawns: bool = false) -> Array[Tween]:
	var tweens: Array[Tween] = []
	if _grid == null:
		return tweens
	for unit in _grid.get_all_units():
		var unit_inst: UnitInstance = unit as UnitInstance
		if unit_inst == null:
			continue
		_grid.sync_unit_grid_pos(unit_inst)
		var cell := _grid.find_cell_of(unit_inst)
		if cell == Vector2i(-1, -1):
			continue
		var was_missing := not _has_valid_unit_node(unit_inst.instance_id)
		var unit_node := ensure_unit_node(unit_inst) as UnitDisplay3D
		unit_node.configure(_tile_size, _pixel_cell_size)
		unit_node.bind_unit(unit_inst)
		var world_3d := grid_to_world_3d(cell)
		if was_missing or not unit_inst.is_alive():
			unit_node.update_home_position_3d(world_3d)
		_update_unit_depth(unit_node, cell)
		if was_missing and animate_new_spawns:
			var spawn_duration := _combat_spawn_duration
			if spawn_duration < 0.0:
				spawn_duration = CombatAnimationConfig.DUR_SPAWN
			tweens.append(unit_node.play_spawn_pop(spawn_duration))
		if was_missing and _character_phase == UnitCardDisplay.CharacterPhase.COMBAT:
			unit_node.set_character_phase(UnitCardDisplay.CharacterPhase.COMBAT)
	return tweens


func set_combat_spawn_duration(duration: float) -> void:
	_combat_spawn_duration = duration


func set_character_phase(phase: UnitCardDisplay.CharacterPhase) -> void:
	_character_phase = phase
	_apply_character_phase_to_all_nodes()


func play_body_reveal(duration: float = -1.0) -> Array[Tween]:
	_character_phase = UnitCardDisplay.CharacterPhase.COMBAT
	var tweens: Array[Tween] = []
	for instance_id in _unit_nodes:
		var node: UnitDisplay3D = _unit_nodes[instance_id]
		if node == null:
			continue
		var tween := node.play_body_reveal(duration)
		if tween != null:
			tweens.append(tween)
	for preview_node in _preview_nodes:
		if preview_node is UnitDisplay3D:
			var tween := (preview_node as UnitDisplay3D).play_body_reveal(duration)
			if tween != null:
				tweens.append(tween)
	return tweens


func play_body_hide(duration: float = -1.0) -> Array[Tween]:
	var tweens: Array[Tween] = []
	for instance_id in _unit_nodes:
		var node: UnitDisplay3D = _unit_nodes[instance_id]
		if node == null:
			continue
		var tween := node.play_body_hide(duration)
		if tween != null:
			tweens.append(tween)
	for preview_node in _preview_nodes:
		if preview_node is UnitDisplay3D:
			var tween := (preview_node as UnitDisplay3D).play_body_hide(duration)
			if tween != null:
				tweens.append(tween)
	return tweens


func set_combat_animations_paused(paused: bool) -> void:
	for node in _unit_nodes.values():
		if node is UnitDisplay3D:
			node.set_tween_paused(paused)


func set_acting_units(units: Array) -> void:
	_acting_unit_ids.clear()
	for unit in units:
		var inst := unit as UnitInstance
		if inst != null:
			_acting_unit_ids[inst.instance_id] = true
	_apply_unit_visual_states()


func clear_acting_units() -> void:
	_acting_unit_ids.clear()
	clear_attack_highlight_cells()
	_apply_unit_visual_states()


func set_combat_view_active(active: bool) -> void:
	if _combat_view_active == active:
		return
	_combat_view_active = active
	_apply_unit_visual_states()


func set_attack_highlight_cells(cells: Array[Vector2i]) -> void:
	_attack_highlight_cells.clear()
	for cell in cells:
		_attack_highlight_cells[cell] = true
	_apply_cell_highlights()


func clear_attack_highlight_cells() -> void:
	if _attack_highlight_cells.is_empty():
		return
	_attack_highlight_cells.clear()
	_apply_cell_highlights()


func get_logic_cell(unit: UnitInstance) -> Vector2i:
	if unit == null:
		return Vector2i.ZERO
	if _grid != null:
		_grid.sync_unit_grid_pos(unit)
		var cell := _grid.find_cell_of(unit)
		if cell != Vector2i(-1, -1):
			return cell
	return unit.grid_pos


func remove_grid_unit(unit: UnitInstance) -> void:
	if _grid == null or unit == null:
		return
	_grid.remove_unit(unit)


func get_grid() -> BoardGrid:
	return _grid


func get_unit_at_cell(cell: Vector2i) -> UnitInstance:
	if cell == Vector2i(-1, -1) or _grid == null:
		return null
	if not _grid.in_bounds(cell):
		return null
	var unit: UnitInstance = _grid.get_unit(cell)
	if unit is UnitInstance and unit.is_alive():
		return unit
	if _preview_units_by_cell.has(cell):
		return _preview_units_by_cell[cell] as UnitInstance
	return null


func get_unit_node(instance_id: int) -> Node:
	return _unit_nodes.get(instance_id)


func ensure_unit_node(unit: UnitInstance) -> Node:
	if unit == null:
		return null
	if _has_valid_unit_node(unit.instance_id):
		return _unit_nodes[unit.instance_id]
	if _unit_nodes.has(unit.instance_id):
		_unit_nodes.erase(unit.instance_id)
	var cell := get_logic_cell(unit)
	var unit_node := UNIT_SCRIPT.new() as UnitDisplay3D
	unit_node.name = "Unit_%d" % unit.instance_id
	unit_node.configure(_tile_size, _pixel_cell_size)
	unit_node.set_vfx_context(_vfx_layer, project_world_to_screen)
	unit_node.update_home_position_3d(grid_to_world_3d(cell))
	unit_node.bind_unit(unit)
	unit_node.set_character_phase(_character_phase)
	_unit_root.add_child(unit_node)
	_unit_nodes[unit.instance_id] = unit_node
	_update_unit_depth(unit_node, cell)
	_apply_unit_visual_states()
	return unit_node


func remove_unit_node(instance_id: int) -> void:
	if not _unit_nodes.has(instance_id):
		return
	var node: Node = _unit_nodes[instance_id]
	if is_instance_valid(node):
		node.queue_free()
	_unit_nodes.erase(instance_id)


func get_unit_global_anchor(unit: UnitInstance) -> Vector2:
	if unit == null:
		return Vector2.ZERO
	var node := get_unit_node(unit.instance_id) as UnitDisplay3D
	if node != null:
		return project_world_to_screen(node.get_billboard_top_global())
	if _grid != null:
		var cell := _grid.find_cell_of(unit)
		if cell != Vector2i(-1, -1):
			var icon_h := _tile_size * CARD_HEIGHT_RATIO
			return project_world_to_screen(
				grid_to_world_3d(cell) + Vector3(0.0, icon_h, 0.0),
			)
	return Vector2.ZERO


func animate_unit_move(
	unit: UnitInstance,
	from_cell: Vector2i,
	to_cell: Vector2i,
	duration: float,
) -> Tween:
	if unit == null or from_cell == to_cell:
		return null
	var unit_node := ensure_unit_node(unit) as UnitDisplay3D
	var from_world := grid_to_world_plane(from_cell)
	var to_world := grid_to_world_plane(to_cell)
	unit_node.update_home_position(from_world)
	var use_slide := unit.uses_sliding_move_presentation()
	if use_slide and unit_node.has_method("play_slide_charge_to"):
		return unit_node.play_slide_charge_to(to_world, duration)
	if unit_node.has_method("play_move_to"):
		return unit_node.play_move_to(to_world, duration)
	var tween: Tween = create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var flat := from_world.lerp(to_world, t)
			unit_node.update_home_position(flat),
		0.0,
		1.0,
		duration,
	)
	return tween


func spawn_teleport_afterimage(world_pos: Vector2, duration: float) -> void:
	if _vfx_layer == null:
		return
	TeleportAfterimage.spawn(
		_vfx_layer,
		world_pos,
		_pixel_cell_size,
		CombatAnimationConfig.TELEPORT_TINT,
		duration,
	)


func pulse_cell_teleport(cell: Vector2i, duration: float) -> void:
	pulse_cells_impact([cell], CombatAnimationConfig.TELEPORT_TINT, duration)


func spawn_melee_clash_spark(world_pos: Vector2, duration: float) -> void:
	if _vfx_layer == null:
		return
	MeleeClashSpark.spawn(
		_vfx_layer,
		world_pos,
		_pixel_cell_size,
		CombatAnimationConfig.MELEE_CLASH_SPARK_TINT,
		duration,
	)


func spawn_crit_hit_spark(world_pos: Vector2, duration: float) -> void:
	if _vfx_layer == null:
		return
	MeleeClashSpark.spawn(
		_vfx_layer,
		world_pos,
		_pixel_cell_size,
		CombatAnimationConfig.CRIT_HIT_SPARK_TINT,
		duration,
	)


func spawn_death_spark(world_pos: Vector2, team: UnitInstance.Team, duration: float) -> void:
	if _vfx_layer == null:
		return
	MeleeClashSpark.spawn(
		_vfx_layer,
		world_pos,
		_pixel_cell_size,
		CombatAnimationConfig.death_spark_tint(team),
		duration,
	)


func pulse_cell_death(cell: Vector2i, team: UnitInstance.Team, duration: float) -> void:
	pulse_cells_impact(
		[cell],
		CombatAnimationConfig.death_cell_tint(team),
		duration,
	)


func pulse_cells_impact(cells: Array[Vector2i], tint: Color, duration: float) -> void:
	for cell in cells:
		if not _cells.has(cell):
			continue
		var cell_node := _cells[cell] as BoardCell3D
		if cell_node != null:
			cell_node.play_impact_pulse(tint, duration)


func _ready() -> void:
	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	if not visible or board_transition_active or _grid == null:
		if _hovered_unit != null:
			_clear_unit_hover()
		if _hovered_grid_cell != Vector2i(-1, -1):
			_hovered_grid_cell = Vector2i(-1, -1)
			_apply_cell_highlights()
		return
	if _prepare_drag_active:
		return
	_update_cell_hover()
	_update_unit_hover()


func _unhandled_input(event: InputEvent) -> void:
	if board_transition_active or _grid == null or not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		var cell := get_cell_at_viewport_pos(mb.position)
		if cell == Vector2i(-1, -1):
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var unit := _grid.get_unit(cell)
			if unit != null and unit.team == UnitInstance.Team.PLAYER:
				return
			cell_clicked.emit(cell)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cell_right_clicked.emit(cell)
			get_viewport().set_input_as_handled()


func _rebuild_board() -> void:
	for child in get_children():
		child.queue_free()
	_cells.clear()
	_unit_nodes.clear()
	_cell_home_positions.clear()
	_hovered_grid_cell = Vector2i(-1, -1)
	_placement_mode_active = false

	_tile_root = Node3D.new()
	_tile_root.name = "TileRoot"
	add_child(_tile_root)

	_unit_root = Node3D.new()
	_unit_root.name = "UnitRoot"
	add_child(_unit_root)

	_preview_root = Node3D.new()
	_preview_root.name = "PreviewRoot"
	add_child(_preview_root)

	if _grid == null:
		return

	var size := _grid.get_size()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var cell_node := CELL_SCRIPT.new() as BoardCell3D
			cell_node.name = "Cell_%d_%d" % [x, y]
			cell_node.position = Vector3(x * _tile_size, 0.0, y * _tile_size)
			var has_terrain := _grid.has_terrain()
			var terrain := _grid.get_terrain(cell) if has_terrain else TerrainType.Type.GRASS
			var board_h := _grid.get_size().y if _grid != null else -1
			cell_node.setup(
				cell,
				_grid.is_blocked(cell),
				_tile_size,
				terrain,
				has_terrain,
				board_h,
			)
			_tile_root.add_child(cell_node)
			_cells[cell] = cell_node
			_cell_home_positions[cell] = cell_node.position
	_apply_cell_highlights()


func _apply_cell_highlights() -> void:
	for key in _cells:
		var cell_node: BoardCell3D = _cells[key]
		if cell_node == null:
			continue
		cell_node.set_highlight(_resolve_cell_highlight(cell_node.cell))


func _resolve_cell_highlight(cell: Vector2i) -> BoardTheme.CellHighlight:
	if _prepare_drag_active and cell == _drag_hover_cell:
		return (
			BoardTheme.CellHighlight.HOVER_PLACEABLE
			if _drag_hover_valid
			else BoardTheme.CellHighlight.INVALID
		)
	if _attack_highlight_cells.has(cell):
		return BoardTheme.CellHighlight.ATTACK
	if _range_preview_cells.has(cell):
		return BoardTheme.CellHighlight.ATTACK_RANGE
	var hovered := cell == _hovered_grid_cell
	var placeable := _is_placeable_cell(cell)
	if hovered and placeable:
		return BoardTheme.CellHighlight.HOVER_PLACEABLE
	if hovered:
		return BoardTheme.CellHighlight.HOVER
	if placeable:
		return BoardTheme.CellHighlight.PLACEABLE
	return BoardTheme.CellHighlight.NONE


func _is_placeable_cell(cell: Vector2i) -> bool:
	if _grid == null or not _placement_mode_active:
		return false
	if not _grid.in_bounds(cell) or _grid.is_blocked(cell):
		return false
	if _grid.get_unit(cell) != null:
		return false
	return BoardHalf.is_player_deploy_cell(cell, _grid.get_size().y)


func _apply_unit_visual_states() -> void:
	for instance_id in _unit_nodes:
		var node: UnitDisplay3D = _unit_nodes[instance_id]
		var hovered: bool = (
			_hovered_unit != null
			and int(instance_id) == _hovered_unit.instance_id
		)
		var acting: bool = _acting_unit_ids.has(instance_id)
		node.set_acting(acting)
		node.set_hovered(hovered)
		var unit := node.get_bound_unit()
		var alive := unit != null and unit.is_alive()
		var should_idle := (
			_combat_view_active
			and _character_phase == UnitCardDisplay.CharacterPhase.COMBAT
			and not acting
			and alive
		)
		node.set_head_idle(should_idle)


func _apply_character_phase_to_all_nodes() -> void:
	for instance_id in _unit_nodes:
		var node: UnitDisplay3D = _unit_nodes[instance_id]
		if node != null:
			node.set_character_phase(_character_phase)
	for preview_node in _preview_nodes:
		if preview_node is UnitDisplay3D:
			(preview_node as UnitDisplay3D).set_character_phase(_character_phase)


func _update_unit_depth(unit_node: UnitDisplay3D, cell: Vector2i) -> void:
	if unit_node == null:
		return
	var surface_y := BoardCell3D.get_tile_height(_tile_size)
	unit_node.position.y = surface_y + float(cell.x + cell.y) * 0.001


func _has_valid_unit_node(instance_id: int) -> bool:
	if not _unit_nodes.has(instance_id):
		return false
	var node: Variant = _unit_nodes[instance_id]
	return node != null and is_instance_valid(node)


func _raycast_board_plane(viewport_pos: Vector2) -> Vector3:
	if _camera == null:
		return Vector3.INF
	var origin := _camera.project_ray_origin(viewport_pos)
	var direction := _camera.project_ray_normal(viewport_pos)
	var plane_y := BoardCell3D.get_tile_height(_tile_size)
	var plane := Plane(Vector3.UP, plane_y)
	var hit: Variant = plane.intersects_ray(origin, direction)
	if hit == null:
		return Vector3.INF
	return hit as Vector3


func _update_cell_hover() -> void:
	if _grid == null:
		return
	var cell := _get_grid_cell_under_mouse()
	if cell == _hovered_grid_cell:
		return
	_hovered_grid_cell = cell
	_apply_cell_highlights()
	grid_cell_hover_changed.emit(cell)


func _update_unit_hover() -> void:
	var unit := _get_unit_under_mouse()
	if unit == _hovered_unit:
		return
	if unit == null:
		_clear_unit_hover()
		return
	_hovered_unit = unit
	_hovered_cell_from_unit(unit)
	_apply_unit_visual_states()
	unit_hover_changed.emit(unit)


func _hovered_cell_from_unit(unit: UnitInstance) -> void:
	if _grid == null or unit == null:
		return
	var cell := _grid.find_cell_of(unit)
	if cell == Vector2i(-1, -1):
		cell = unit.grid_pos
	if cell != Vector2i(-1, -1):
		_hovered_grid_cell = cell


func _clear_unit_hover() -> void:
	_hovered_unit = null
	_apply_unit_visual_states()
	unit_hover_changed.emit(null)


func _get_unit_under_mouse() -> UnitInstance:
	return get_unit_at_cell(_get_grid_cell_under_mouse())


func _get_grid_cell_under_mouse() -> Vector2i:
	var hit := _raycast_board_plane(get_viewport().get_mouse_position())
	if hit == Vector3.INF:
		return Vector2i(-1, -1)
	var cell := world_to_grid(hit)
	if _grid == null or not _grid.in_bounds(cell):
		return Vector2i(-1, -1)
	return cell


func _ordered_cells() -> Array[BoardCell3D]:
	var result: Array[BoardCell3D] = []
	if _grid == null:
		return result
	var size := _grid.get_size()
	for y in size.y:
		for x in size.x:
			var grid_cell := Vector2i(x, y)
			if _cells.has(grid_cell):
				result.append(_cells[grid_cell] as BoardCell3D)
	return result


func _restore_board_cells_home() -> void:
	for cell_node in _ordered_cells():
		var home: Vector3 = _cell_home_positions.get(cell_node.cell, cell_node.position)
		cell_node.position = home
		cell_node.scale = Vector3.ONE


func _apply_cell_hidden_state(cell_node: BoardCell3D, home: Vector3, rise_offset: float) -> void:
	cell_node.position = home + Vector3(0.0, -rise_offset, 0.0)
	cell_node.scale = Vector3.ONE * CombatAnimationConfig.BOARD_CELL_REVEAL_SCALE


func _append_cell_reveal_tween(
	master: Tween,
	cell_node: BoardCell3D,
	home: Vector3,
	rise_offset: float,
	delay: float,
) -> void:
	var hidden := home + Vector3(0.0, -rise_offset, 0.0)
	cell_node.position = hidden
	cell_node.scale = Vector3.ONE * CombatAnimationConfig.BOARD_CELL_REVEAL_SCALE
	master.tween_property(cell_node, "position", home, CombatAnimationConfig.BOARD_CELL_RISE_DUR)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	master.tween_property(cell_node, "scale", Vector3.ONE, CombatAnimationConfig.BOARD_CELL_RISE_DUR)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _append_cell_hide_tween(
	master: Tween,
	cell_node: BoardCell3D,
	home: Vector3,
	rise_offset: float,
	delay: float,
) -> void:
	var hidden := home + Vector3(0.0, -rise_offset, 0.0)
	master.tween_property(cell_node, "position", hidden, CombatAnimationConfig.BOARD_CELL_RISE_DUR)\
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	master.tween_property(
		cell_node,
		"scale",
		Vector3.ONE * CombatAnimationConfig.BOARD_CELL_REVEAL_SCALE,
		CombatAnimationConfig.BOARD_CELL_RISE_DUR,
	).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _kill_board_transition_tween() -> void:
	if _board_transition_tween != null and _board_transition_tween.is_valid():
		_board_transition_tween.kill()
	_board_transition_tween = null


func _set_unit_nodes_visible(show_units: bool) -> void:
	if _unit_root != null:
		_unit_root.visible = show_units


func _ensure_preview_root() -> void:
	if _preview_root != null and is_instance_valid(_preview_root):
		return
	_preview_root = Node3D.new()
	_preview_root.name = "PreviewRoot"
	add_child(_preview_root)
