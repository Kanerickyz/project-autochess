class_name BoardGrid
extends RefCounted

var _size: Vector2i = Vector2i.ZERO
var _blocked: Dictionary = {}
var _units: Dictionary = {}
var _terrain: Dictionary = {}
var cell_effects: CellEffectStack = CellEffectStack.new()


func configure(size: Vector2i, blocked: Array[Vector2i] = []) -> void:
	_size = size
	_blocked.clear()
	_units.clear()
	_terrain.clear()
	cell_effects.clear()
	for cell in blocked:
		if in_bounds(cell):
			_blocked[cell] = true


func configure_from_terrain(
	size: Vector2i,
	terrain_map: Dictionary,
	tileset: TerrainTileset,
) -> void:
	_size = size
	_blocked.clear()
	_units.clear()
	_terrain.clear()
	cell_effects.clear()
	var default_type := TerrainType.Type.GRASS
	if tileset != null:
		default_type = tileset.default_type
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var t: TerrainType.Type = terrain_map.get(cell, default_type)
			_terrain[cell] = t
			var walkable := true
			if tileset != null:
				walkable = tileset.is_walkable(t)
			elif t == TerrainType.Type.LAKE or t == TerrainType.Type.ROCK or t == TerrainType.Type.DENSE_JUNGLE:
				walkable = false
			if not walkable:
				_blocked[cell] = true


func get_terrain(cell: Vector2i) -> TerrainType.Type:
	if _terrain.has(cell):
		return _terrain[cell]
	return TerrainType.Type.GRASS


func has_terrain() -> bool:
	return not _terrain.is_empty()


func get_terrain_map() -> Dictionary:
	return _terrain.duplicate()


func get_size() -> Vector2i:
	return _size


func in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < _size.x
		and cell.y < _size.y
	)


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func is_occupied(cell: Vector2i) -> bool:
	if not _units.has(cell):
		return false
	var unit: UnitInstance = _units[cell]
	return unit != null and unit.is_alive()


func can_place_at(cell: Vector2i) -> bool:
	return in_bounds(cell) and not is_blocked(cell) and not is_occupied(cell)


func get_unit(cell: Vector2i) -> UnitInstance:
	return _units.get(cell)


func place(unit: UnitInstance, cell: Vector2i) -> bool:
	if not in_bounds(cell) or is_blocked(cell):
		return false
	var existing := get_unit(cell)
	if existing != null and existing.is_alive():
		return false
	if existing != null:
		_units.erase(cell)
	unit.grid_pos = cell
	_units[cell] = unit
	return true


func remove(cell: Vector2i) -> UnitInstance:
	if not _units.has(cell):
		return null
	var unit: UnitInstance = _units[cell]
	_units.erase(cell)
	return unit


func remove_unit(unit: UnitInstance) -> UnitInstance:
	var cell := find_cell_of(unit)
	if cell == Vector2i(-1, -1):
		return null
	return remove(cell)


func move_unit(from: Vector2i, to: Vector2i) -> bool:
	if not _units.has(from):
		return false
	if not can_place_at(to):
		return false
	var unit: UnitInstance = _units[from]
	_units.erase(from)
	unit.grid_pos = to
	_units[to] = unit
	return true


func find_cell_of(unit: UnitInstance) -> Vector2i:
	if unit == null:
		return Vector2i(-1, -1)
	for cell in _units:
		if _units[cell] == unit:
			return cell
	return Vector2i(-1, -1)


func sync_unit_grid_pos(unit: UnitInstance) -> void:
	if unit == null:
		return
	var cell := find_cell_of(unit)
	if cell != Vector2i(-1, -1):
		unit.grid_pos = cell


func move_unit_for(unit: UnitInstance, to: Vector2i) -> bool:
	if unit == null:
		return false
	var from := find_cell_of(unit)
	if from == Vector2i(-1, -1):
		return false
	if from == to:
		unit.grid_pos = to
		return true
	var dest := get_unit(to)
	if dest != null and dest.is_alive():
		return false
	if dest != null:
		_units.erase(to)
	_units.erase(from)
	unit.grid_pos = to
	_units[to] = unit
	return true


func swap_units_at(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	if not in_bounds(from) or not in_bounds(to):
		return false
	if is_blocked(from) or is_blocked(to):
		return false
	if not _units.has(from):
		return false
	if not _units.has(to):
		return move_unit(from, to)
	var unit_a: UnitInstance = _units[from]
	var unit_b: UnitInstance = _units[to]
	_units.erase(from)
	_units.erase(to)
	unit_a.grid_pos = to
	unit_b.grid_pos = from
	_units[to] = unit_a
	_units[from] = unit_b
	return true


func get_empty_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in _size.y:
		for x in _size.x:
			var cell := Vector2i(x, y)
			if not is_blocked(cell) and not is_occupied(cell):
				result.append(cell)
	return result


func clear_units() -> void:
	_units.clear()
	cell_effects.clear()


func clear_team(team: UnitInstance.Team) -> void:
	var to_remove: Array[Vector2i] = []
	for cell in _units:
		var unit: UnitInstance = _units[cell]
		if unit.team == team:
			to_remove.append(cell)
	for cell in to_remove:
		_units.erase(cell)


func get_all_units() -> Array:
	return _units.values()


func get_alive_units() -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	for unit in _units.values():
		var inst: UnitInstance = unit as UnitInstance
		if inst.is_alive():
			result.append(inst)
	return result


func get_units_by_team(team: UnitInstance.Team, alive_only: bool = true) -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	for unit in _units.values():
		var inst: UnitInstance = unit as UnitInstance
		if inst.team != team:
			continue
		if alive_only and not inst.is_alive():
			continue
		result.append(inst)
	return result


func find_nearest_enemy(from_cell: Vector2i, team: UnitInstance.Team) -> UnitInstance:
	var best: UnitInstance = null
	var best_dist := 999999
	for cell in _units:
		var inst: UnitInstance = _units[cell] as UnitInstance
		if inst == null or inst.team == team or not inst.is_alive():
			continue
		var dist := combat_distance(from_cell, cell)
		if dist < best_dist:
			best_dist = dist
			best = inst
	return best


## Combat adjacency / attack range / nearest-enemy (8-way Chebyshev).
func combat_distance(a: Vector2i, b: Vector2i) -> int:
	return _chebyshev(a, b)


func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return combat_distance(a, b)


## Orthogonal step count for path-cost heuristics only — not "nearest enemy".
func path_cost(a: Vector2i, b: Vector2i) -> int:
	return _path_cost(a, b)


func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return path_cost(a, b)


static func _path_cost(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return _path_cost(a, b)
