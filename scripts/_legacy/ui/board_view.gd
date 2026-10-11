class_name BoardView
## LEGACY — not on main gameplay path. See scripts/_legacy/README.md.
extends Node2D

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)
signal unit_hover_changed(unit: UnitInstance)
signal grid_cell_hover_changed(cell: Vector2i)

const CELL_SCENE := preload("res://scenes/ui/board_cell.tscn")
const UNIT_DISPLAY_SCENE := preload("res://scenes/units/unit_board_display.tscn")

const MIN_CELL_SIZE := BoardLayout.MIN_CELL_SIZE
const MAX_CELL_SIZE := BoardLayout.MAX_CELL_SIZE

@export var cell_size: int = 64
@export var board_theme_config: BoardThemeConfig = preload("res://resources/ui/default_board_theme.tres")

var _grid: BoardGrid
var _cells: Dictionary = {}
var _unit_nodes: Dictionary = {}
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _hovered_grid_cell: Vector2i = Vector2i(-1, -1)
var _hovered_unit: UnitInstance
var _presentation: CombatPresentation
var _combat_spawn_duration: float = -1.0
var _acting_unit_ids: Dictionary = {}
var _attack_highlight_cells: Dictionary = {}
var _range_preview_cells: Dictionary = {}
var _placement_mode_active: bool = false
var _prepare_drag_active: bool = false
var _drag_hover_cell: Vector2i = Vector2i(-1, -1)
var _drag_hover_valid: bool = false
var _board_frame: Line2D
var _preview_nodes: Array[Node2D] = []
var _preview_layer: Node2D
var _cell_home_positions: Dictionary = {}
var board_transition_active: bool = false
var _board_transition_tween: Tween

const PREVIEW_MODULATE := Color(1.0, 1.0, 1.0, 0.55)


func setup(grid: BoardGrid) -> void:
	BoardTheme.set_config(board_theme_config)
	_grid = grid
	cell_size = _calculate_cell_size(grid)
	_clear_board()
	_build_cells()
	_ensure_presentation()


func get_combat_presentation() -> CombatPresentation:
	return _ensure_presentation()


func set_combat_spawn_duration(duration: float) -> void:
	_combat_spawn_duration = duration


func set_skill_callout(callout: CombatSkillCallout) -> void:
	get_combat_presentation().set_skill_callout(callout)


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


func get_hovered_grid_cell() -> Vector2i:
	return _hovered_grid_cell


func get_unit_global_anchor(unit: UnitInstance) -> Vector2:
	if unit == null:
		return Vector2.ZERO
	var node := get_unit_node(unit.instance_id) as Node2D
	if node != null:
		return node.global_position + Vector2(0.0, -float(cell_size) * 0.6)
	if _grid != null:
		var cell := _grid.find_cell_of(unit)
		if cell != Vector2i(-1, -1):
			return to_global(grid_to_world(cell) + Vector2(0.0, -float(cell_size) * 0.6))
	return global_position


func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * cell_size + cell_size * 0.5,
		cell.y * cell_size + cell_size * 0.5,
	)


func grid_to_unit_position(cell: Vector2i) -> Vector2:
	return grid_to_world(cell)


func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / cell_size)),
		int(floor(world_pos.y / cell_size)),
	)


func get_board_pixel_size() -> Vector2:
	if _grid == null:
		return Vector2.ZERO
	var s := _grid.get_size()
	return Vector2(s.x * cell_size, s.y * cell_size)


func prepare_board_reveal_hidden() -> void:
	if _cells.is_empty():
		return
	var rise_offset := float(cell_size) * CombatAnimationConfig.BOARD_CELL_RISE_OFFSET
	for cell_node in _ordered_cells():
		var home: Vector2 = _cell_home_positions.get(cell_node.cell, cell_node.position)
		_apply_cell_hidden_state(cell_node, home, rise_offset)
	if _board_frame != null:
		_board_frame.modulate.a = 0.0
	_set_unit_nodes_visible(false)


func play_board_reveal() -> void:
	if _cells.is_empty():
		return
	board_transition_active = true
	_kill_board_transition_tween()
	prepare_board_reveal_hidden()
	var ordered := _ordered_cells()
	ordered.shuffle()
	var rise_offset := float(cell_size) * CombatAnimationConfig.BOARD_CELL_RISE_OFFSET
	var base_delay := CombatAnimationConfig.BOARD_CELL_REVEAL_DELAY
	var jitter_max := CombatAnimationConfig.BOARD_CELL_REVEAL_JITTER
	_board_transition_tween = create_tween()
	_board_transition_tween.set_parallel(true)
	for cell_node in ordered:
		var home: Vector2 = _cell_home_positions.get(cell_node.cell, cell_node.position)
		var delay := base_delay + randf() * jitter_max
		_append_cell_reveal_tween(_board_transition_tween, cell_node, home, rise_offset, delay)
	_tween_board_frame(_board_transition_tween, true, base_delay)
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
	var rise_offset := float(cell_size) * CombatAnimationConfig.BOARD_CELL_RISE_OFFSET
	var base_delay := CombatAnimationConfig.BOARD_CELL_REVEAL_DELAY
	var jitter_max := CombatAnimationConfig.BOARD_CELL_REVEAL_JITTER
	_board_transition_tween = create_tween()
	_board_transition_tween.set_parallel(true)
	for cell_node in ordered:
		var home: Vector2 = _cell_home_positions.get(cell_node.cell, cell_node.position)
		var delay := base_delay + randf() * jitter_max
		_append_cell_hide_tween(_board_transition_tween, cell_node, home, rise_offset, delay)
	_tween_board_frame(_board_transition_tween, false, base_delay)
	await _board_transition_tween.finished
	_board_transition_tween = null
	board_transition_active = false


func get_unit_at_cell(cell: Vector2i) -> UnitInstance:
	if _grid == null:
		return null
	return _grid.get_unit(cell)


func get_all_grid_units() -> Array:
	if _grid == null:
		return []
	return _grid.get_all_units()


func sync_missing_units(animate_spawn: bool = false) -> Array[Tween]:
	return sync_combat_step_units(animate_spawn)


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
		var unit_node := ensure_unit_node(unit_inst) as UnitBoardDisplay
		if unit_node.has_method("bind_unit"):
			unit_node.bind_unit(unit_inst)
		var should_snap := was_missing or not unit_inst.is_alive()
		if should_snap:
			var world_pos := grid_to_world(cell)
			unit_node.position = world_pos
			if unit_node.has_method("update_home_position"):
				unit_node.update_home_position(world_pos)
		if was_missing and animate_new_spawns:
			var spawn_duration := _combat_spawn_duration
			if spawn_duration < 0.0:
				spawn_duration = CombatAnimationConfig.DUR_SPAWN
			tweens.append(unit_node.play_spawn_pop(spawn_duration))
	return tweens


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


func refresh() -> void:
	sync_units()
	if visible and not board_transition_active:
		_set_unit_nodes_visible(true)
	_update_unit_hover()
	_apply_cell_highlights()
	if _hovered_unit != null:
		unit_hover_changed.emit(_hovered_unit)


func set_enemy_preview(placements: Array) -> void:
	clear_enemy_preview()
	if placements.is_empty():
		return
	_ensure_preview_layer()
	for item in placements:
		if item == null or not item is Dictionary:
			continue
		var unit_data: UnitData = item.get("unit")
		var cell: Vector2i = item.get("cell", Vector2i(-1, -1))
		if unit_data == null or cell == Vector2i(-1, -1):
			continue
		var preview_unit := UnitInstance.from_unit_data(
			unit_data,
			cell,
			UnitInstance.Team.ENEMY,
		)
		var unit_node: Node2D = UNIT_DISPLAY_SCENE.instantiate()
		unit_node.z_index = 2
		unit_node.modulate = PREVIEW_MODULATE
		unit_node.position = grid_to_world(cell)
		_preview_layer.add_child(unit_node)
		if unit_node.has_method("configure"):
			unit_node.configure(cell_size)
		if unit_node.has_method("bind_unit"):
			unit_node.bind_unit(preview_unit)
		_preview_nodes.append(unit_node)


func clear_enemy_preview() -> void:
	for node in _preview_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_preview_nodes.clear()


func _ensure_preview_layer() -> void:
	if _preview_layer != null and is_instance_valid(_preview_layer):
		return
	_preview_layer = Node2D.new()
	_preview_layer.name = "EnemyPreviewLayer"
	add_child(_preview_layer)


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


func get_cell_at_viewport_pos(viewport_pos: Vector2) -> Vector2i:
	if _grid == null:
		return Vector2i(-1, -1)
	var world := get_viewport().get_canvas_transform().affine_inverse() * viewport_pos
	var local := to_local(world)
	var board_size := get_board_pixel_size()
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	if local.x >= board_size.x or local.y >= board_size.y:
		return Vector2i(-1, -1)
	var cell := world_to_grid(local)
	if not _grid.in_bounds(cell):
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


func set_board_unit_drag_visual(unit: UnitInstance, dragging: bool) -> void:
	if unit == null:
		return
	var node := get_unit_node(unit.instance_id)
	if node == null:
		return
	if node.has_method("set_dragging"):
		node.set_dragging(dragging)
	elif node.has_method("restore_opacity_modulate"):
		if dragging:
			node.modulate = Color(1.0, 1.0, 1.0, 0.35)
		else:
			node.restore_opacity_modulate()
	else:
		node.modulate = Color(1.0, 1.0, 1.0, 0.35) if dragging else Color.WHITE


func clear_all_unit_drag_visuals() -> void:
	for instance_id in _unit_nodes:
		var node: Node = _unit_nodes[instance_id]
		if node == null:
			continue
		if node.has_method("set_dragging"):
			node.set_dragging(false)
		elif node.has_method("restore_opacity_modulate"):
			node.restore_opacity_modulate()
		else:
			node.modulate = Color.WHITE


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
		var unit_node := ensure_unit_node(unit_inst)
		unit_node.position = grid_to_world(cell)
		if unit_node.has_method("update_home_position"):
			unit_node.update_home_position(grid_to_world(cell))
		if unit_node.has_method("bind_unit"):
			unit_node.bind_unit(unit_inst)

	var to_remove: Array[int] = []
	for instance_id in _unit_nodes:
		if not seen.has(instance_id):
			to_remove.append(instance_id)
	for instance_id in to_remove:
		_remove_unit_node(instance_id)
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
		var board_cell: BoardCell = _cells[key]
		if board_cell != null and board_cell.has_method("set_burning"):
			board_cell.set_burning(burning.has(cell))


func get_unit_node(instance_id: int) -> Node2D:
	return _unit_nodes.get(instance_id)


func set_combat_animations_paused(paused: bool) -> void:
	for node in _unit_nodes.values():
		if node is UnitBoardDisplay:
			node.set_tween_paused(paused)


func ensure_unit_node(unit: UnitInstance) -> Node2D:
	if unit == null:
		return null
	if _has_valid_unit_node(unit.instance_id):
		return _unit_nodes[unit.instance_id]
	if _unit_nodes.has(unit.instance_id):
		_unit_nodes.erase(unit.instance_id)
	var cell := get_logic_cell(unit)
	var unit_node: Node2D = UNIT_DISPLAY_SCENE.instantiate()
	unit_node.z_index = 1
	unit_node.position = grid_to_world(cell)
	add_child(unit_node)
	if unit_node.has_method("configure"):
		unit_node.configure(cell_size)
	if unit_node.has_method("bind_unit"):
		unit_node.bind_unit(unit)
	_unit_nodes[unit.instance_id] = unit_node
	return unit_node


func remove_unit_node(instance_id: int) -> void:
	_remove_unit_node(instance_id)


func spawn_teleport_afterimage(world_pos: Vector2, duration: float) -> void:
	TeleportAfterimage.spawn(
		self,
		world_pos,
		cell_size,
		CombatAnimationConfig.TELEPORT_TINT,
		duration,
	)


func pulse_cell_teleport(cell: Vector2i, duration: float) -> void:
	pulse_cells_impact([cell], CombatAnimationConfig.TELEPORT_TINT, duration)


func spawn_melee_clash_spark(world_pos: Vector2, duration: float) -> void:
	MeleeClashSpark.spawn(
		self,
		world_pos,
		cell_size,
		CombatAnimationConfig.MELEE_CLASH_SPARK_TINT,
		duration,
	)


func spawn_crit_hit_spark(world_pos: Vector2, duration: float) -> void:
	MeleeClashSpark.spawn(
		self,
		world_pos,
		cell_size,
		CombatAnimationConfig.CRIT_HIT_SPARK_TINT,
		duration,
	)


func spawn_death_spark(world_pos: Vector2, team: UnitInstance.Team, duration: float) -> void:
	MeleeClashSpark.spawn(
		self,
		world_pos,
		cell_size,
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
		var cell_node := _cells[cell] as BoardCell
		if cell_node != null:
			cell_node.play_impact_pulse(tint, duration)


func animate_unit_move(
	unit: UnitInstance,
	from_cell: Vector2i,
	to_cell: Vector2i,
	duration: float,
) -> Tween:
	if unit == null or from_cell == to_cell:
		return null
	var unit_node := ensure_unit_node(unit)
	var from_world := grid_to_world(from_cell)
	var to_world := grid_to_world(to_cell)
	unit_node.position = from_world
	var use_slide := unit.uses_sliding_move_presentation()
	if use_slide and unit_node.has_method("play_slide_charge_to"):
		return unit_node.play_slide_charge_to(to_world, duration)
	if unit_node.has_method("play_move_to"):
		return unit_node.play_move_to(to_world, duration)
	var tween := create_tween()
	tween.tween_property(unit_node, "position", to_world, duration)
	return tween


func _process(_delta: float) -> void:
	if not visible:
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


func _calculate_cell_size(grid: BoardGrid) -> int:
	var size := grid.get_size()
	var available_w := BoardLayout.VIEWPORT_WIDTH - BoardLayout.PLAY_MARGIN_H
	var available_h := (
		BoardLayout.VIEWPORT_HEIGHT
		- BoardLayout.PLAY_MARGIN_TOP
		- BoardLayout.PLAY_MARGIN_BOTTOM
	)
	var from_w := available_w / maxi(1, size.x)
	var from_h := available_h / maxi(1, size.y)
	return clampi(mini(from_w, from_h), MIN_CELL_SIZE, MAX_CELL_SIZE)


func _ensure_presentation() -> CombatPresentation:
	if _presentation == null:
		_presentation = CombatPresentation.new()
		_presentation.name = "CombatPresentation"
		add_child(_presentation)
		_presentation.setup(self)
	return _presentation


func _clear_board() -> void:
	clear_enemy_preview()
	if _preview_layer != null and is_instance_valid(_preview_layer):
		_preview_layer.queue_free()
		_preview_layer = null
	for child in get_children():
		if child is CombatPresentation:
			continue
		remove_child(child)
		child.free()
	_cells.clear()
	_unit_nodes.clear()
	_cell_home_positions.clear()
	_hovered_grid_cell = Vector2i(-1, -1)
	_placement_mode_active = false
	_board_frame = null


func _build_cells() -> void:
	var size := _grid.get_size()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var cell_node: BoardCell = CELL_SCENE.instantiate()
			cell_node.position = Vector2(x * cell_size, y * cell_size)
			cell_node.setup(cell, _grid.is_blocked(cell), cell_size)
			cell_node.clicked.connect(_on_cell_clicked)
			cell_node.right_clicked.connect(_on_cell_right_clicked)
			_set_cell_collision(cell_node)
			add_child(cell_node)
			_cells[cell] = cell_node
			_cell_home_positions[cell] = cell_node.position
	_build_board_frame()
	_apply_cell_highlights()


func _build_board_frame() -> void:
	if _board_frame != null and is_instance_valid(_board_frame):
		_board_frame.queue_free()
	var board_size := get_board_pixel_size()
	var pad := BoardTheme.get_config().frame_padding
	_board_frame = Line2D.new()
	_board_frame.name = "BoardFrame"
	_board_frame.z_index = -1
	_board_frame.width = BoardTheme.get_config().frame_width
	_board_frame.default_color = BoardTheme.get_config().color_frame
	_board_frame.antialiased = true
	_board_frame.points = PackedVector2Array([
		Vector2(-pad, -pad),
		Vector2(board_size.x + pad, -pad),
		Vector2(board_size.x + pad, board_size.y + pad),
		Vector2(-pad, board_size.y + pad),
		Vector2(-pad, -pad),
	])
	add_child(_board_frame)
	move_child(_board_frame, 0)


func _set_cell_collision(cell_node: BoardCell) -> void:
	var shape_node := cell_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(cell_size, cell_size)
	shape_node.position = Vector2(cell_size * 0.5, cell_size * 0.5)
	shape_node.shape = rect


func _on_cell_clicked(cell: Vector2i) -> void:
	if board_transition_active:
		return
	if _grid != null:
		var unit := _grid.get_unit(cell)
		if unit != null and unit.team == UnitInstance.Team.PLAYER:
			return
	cell_clicked.emit(cell)


func _on_cell_right_clicked(cell: Vector2i) -> void:
	if board_transition_active:
		return
	cell_right_clicked.emit(cell)


func _ordered_cells() -> Array[BoardCell]:
	var result: Array[BoardCell] = []
	if _grid == null:
		return result
	var size := _grid.get_size()
	for y in size.y:
		for x in size.x:
			var grid_cell := Vector2i(x, y)
			if _cells.has(grid_cell):
				result.append(_cells[grid_cell] as BoardCell)
	return result


func _apply_cell_hidden_state(cell_node: BoardCell, home: Vector2, rise_offset: float) -> void:
	var start_scale := CombatAnimationConfig.BOARD_CELL_REVEAL_SCALE
	var half := float(cell_size) * 0.5
	var hidden := home + Vector2(0.0, rise_offset)
	var pivot := Vector2(1.0 - start_scale, 1.0 - start_scale) * half
	cell_node.position = hidden + pivot
	cell_node.modulate.a = 0.0
	cell_node.scale = Vector2.ONE * start_scale


func _kill_board_transition_tween() -> void:
	if _board_transition_tween != null and _board_transition_tween.is_valid():
		_board_transition_tween.kill()
	_board_transition_tween = null


func _append_cell_reveal_tween(
	master: Tween,
	cell_node: BoardCell,
	home: Vector2,
	rise_offset: float,
	delay: float,
) -> void:
	var hidden := home + Vector2(0.0, rise_offset)
	var start_scale := CombatAnimationConfig.BOARD_CELL_REVEAL_SCALE
	var duration := CombatAnimationConfig.BOARD_CELL_RISE_DUR
	var alpha_ratio := CombatAnimationConfig.BOARD_CELL_ALPHA_FADE_RATIO
	_apply_cell_hidden_state(cell_node, home, rise_offset)
	master.tween_method(
		func(t: float) -> void:
			var scale_v := lerpf(start_scale, 1.0, t)
			cell_node.scale = Vector2.ONE * scale_v
			var half := float(cell_size) * 0.5
			var pivot := Vector2(1.0 - scale_v, 1.0 - scale_v) * half
			cell_node.position = hidden.lerp(home, t) + pivot,
		0.0,
		1.0,
		duration,
	).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	master.tween_property(cell_node, "modulate:a", 1.0, duration * alpha_ratio)\
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _append_cell_hide_tween(
	master: Tween,
	cell_node: BoardCell,
	home: Vector2,
	rise_offset: float,
	delay: float,
) -> void:
	var hidden := home + Vector2(0.0, rise_offset)
	var end_scale := CombatAnimationConfig.BOARD_CELL_REVEAL_SCALE
	var half := float(cell_size) * 0.5
	var duration := CombatAnimationConfig.BOARD_CELL_RISE_DUR
	var alpha_ratio := CombatAnimationConfig.BOARD_CELL_ALPHA_FADE_RATIO
	master.tween_method(
		func(t: float) -> void:
			var scale_v := lerpf(1.0, end_scale, t)
			cell_node.scale = Vector2.ONE * scale_v
			var pivot := Vector2(1.0 - scale_v, 1.0 - scale_v) * half
			cell_node.position = home.lerp(hidden, t) + pivot,
		0.0,
		1.0,
		duration,
	).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	master.tween_property(cell_node, "modulate:a", 0.0, duration * alpha_ratio)\
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _tween_board_frame(master: Tween, reveal: bool, base_delay: float) -> void:
	if _board_frame == null:
		return
	if reveal:
		_board_frame.modulate.a = 0.0
		master.tween_property(
			_board_frame,
			"modulate:a",
			1.0,
			CombatAnimationConfig.BOARD_FRAME_FADE_DUR,
		).set_delay(base_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		master.tween_property(
			_board_frame,
			"modulate:a",
			0.0,
			CombatAnimationConfig.BOARD_FRAME_FADE_DUR,
		).set_delay(base_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_unit_nodes_visible(visible: bool) -> void:
	for node in _unit_nodes.values():
		if is_instance_valid(node):
			(node as Node2D).visible = visible


func _remove_unit_node(instance_id: int) -> void:
	if not _unit_nodes.has(instance_id):
		return
	var node: Node = _unit_nodes[instance_id]
	if is_instance_valid(node):
		node.queue_free()
	_unit_nodes.erase(instance_id)


func _has_valid_unit_node(instance_id: int) -> bool:
	if not _unit_nodes.has(instance_id):
		return false
	var node: Variant = _unit_nodes[instance_id]
	return node != null and is_instance_valid(node)


func _update_unit_hover() -> void:
	if _grid == null:
		return
	var unit: UnitInstance = _get_unit_under_mouse()
	if unit == _hovered_unit:
		return
	_hovered_unit = unit
	_hovered_cell = unit.grid_pos if unit != null else Vector2i(-1, -1)
	_apply_hover_visuals()
	unit_hover_changed.emit(unit)


func _get_unit_under_mouse() -> UnitInstance:
	var local := get_local_mouse_position()
	var board_size := get_board_pixel_size()
	if local.x < 0.0 or local.y < 0.0:
		return null
	if local.x >= board_size.x or local.y >= board_size.y:
		return null
	var cell := world_to_grid(local)
	if not _grid.in_bounds(cell):
		return null
	var unit: UnitInstance = _grid.get_unit(cell)
	if unit is UnitInstance and not (unit as UnitInstance).is_alive():
		return null
	return unit as UnitInstance


func _apply_hover_visuals() -> void:
	_apply_unit_visual_states()


func _apply_unit_visual_states() -> void:
	for instance_id in _unit_nodes:
		var node: Node2D = _unit_nodes[instance_id]
		var hovered: bool = (
			_hovered_unit != null
			and int(instance_id) == _hovered_unit.instance_id
		)
		var acting: bool = _acting_unit_ids.has(instance_id)
		if node.has_method("set_acting"):
			node.set_acting(acting)
		if node.has_method("set_hovered"):
			node.set_hovered(hovered)


func _clear_unit_hover() -> void:
	_hovered_unit = null
	_hovered_cell = Vector2i(-1, -1)
	_apply_hover_visuals()
	_apply_cell_highlights()
	unit_hover_changed.emit(null)


func _update_cell_hover() -> void:
	if _grid == null:
		return
	var cell := _get_grid_cell_under_mouse()
	if cell == _hovered_grid_cell:
		return
	_hovered_grid_cell = cell
	_apply_cell_highlights()
	grid_cell_hover_changed.emit(cell)


func _get_grid_cell_under_mouse() -> Vector2i:
	var local := get_local_mouse_position()
	var board_size := get_board_pixel_size()
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	if local.x >= board_size.x or local.y >= board_size.y:
		return Vector2i(-1, -1)
	var cell := world_to_grid(local)
	if _grid == null or not _grid.in_bounds(cell):
		return Vector2i(-1, -1)
	return cell


func _is_placeable_cell(cell: Vector2i) -> bool:
	if _grid == null or not _placement_mode_active:
		return false
	if not _grid.in_bounds(cell) or _grid.is_blocked(cell):
		return false
	return _grid.get_unit(cell) == null


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


func _apply_cell_highlights() -> void:
	for key in _cells:
		var cell_node: BoardCell = _cells[key]
		if cell_node == null:
			continue
		cell_node.set_highlight(_resolve_cell_highlight(cell_node.cell))
