class_name SpawnSystem
extends RefCounted


static func spawn_wave(
	grid: BoardGrid,
	entries: Array[SpawnScheduleEntry],
	rng: RandomNumberGenerator,
) -> Array[UnitInstance]:
	var spawned: Array[UnitInstance] = []
	if grid == null or rng == null:
		return spawned
	for entry in entries:
		if entry != null and entry.combat_tick == 0:
			spawned.append_array(spawn_entry(grid, entry, rng))
	return spawned


static func simulate_spawn_entries(
	grid: BoardGrid,
	entries: Array[SpawnScheduleEntry],
	rng: RandomNumberGenerator,
) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if grid == null or rng == null:
		return placements

	var reserved: Dictionary = {}
	for entry in entries:
		if entry == null or entry.unit == null:
			continue
		placements.append_array(_simulate_entry_placements(grid, entry, rng, reserved))
	return placements


static func stabilize_placements(
	grid: BoardGrid,
	current_placements: Array,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if grid == null:
		return result

	var reserved: Dictionary = {}
	var to_relocate: Array[UnitData] = []

	for item in current_placements:
		if item == null or not item is Dictionary:
			continue
		var unit_data: UnitData = item.get("unit")
		var cell: Vector2i = item.get("cell", Vector2i(-1, -1))
		if unit_data == null or cell == Vector2i(-1, -1):
			continue
		if _is_cell_available_for_spawn(grid, cell, reserved):
			reserved[cell] = true
			result.append({"unit": unit_data, "cell": cell})
		else:
			to_relocate.append(unit_data)

	for unit_data in to_relocate:
		var cells := _get_available_cells(grid, reserved)
		if cells.is_empty():
			break
		_sort_cells_deterministic(cells)
		var cell := cells[0]
		if not grid.can_place_at(cell):
			continue
		reserved[cell] = true
		result.append({"unit": unit_data, "cell": cell})

	return result


static func spawn_entry(
	grid: BoardGrid,
	entry: SpawnScheduleEntry,
	rng: RandomNumberGenerator,
) -> Array[UnitInstance]:
	if entry == null or entry.unit == null or grid == null:
		return []

	var placements := _simulate_entry_placements(grid, entry, rng, {})
	return spawn_at_placements(grid, placements, entry.combat_tick)


static func spawn_at_placements(
	grid: BoardGrid,
	placements: Array,
	combat_tick: int = 0,
) -> Array[UnitInstance]:
	var spawned: Array[UnitInstance] = []
	if grid == null:
		return spawned

	for item in placements:
		if item == null or not item is Dictionary:
			continue
		var unit_data: UnitData = item.get("unit")
		var cell: Vector2i = item.get("cell", Vector2i(-1, -1))
		if unit_data == null or cell == Vector2i(-1, -1):
			continue
		if not grid.can_place_at(cell):
			continue
		var unit := UnitInstance.from_unit_data(
			unit_data,
			cell,
			UnitInstance.Team.ENEMY,
		)
		if grid.place(unit, cell):
			spawned.append(unit)
			print(
				"[Spawn] tick=%d %s at %s"
				% [combat_tick, unit_data.display_name, str(cell)]
			)

	return spawned


static func _simulate_entry_placements(
	grid: BoardGrid,
	entry: SpawnScheduleEntry,
	rng: RandomNumberGenerator,
	reserved: Dictionary,
) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if entry == null or entry.unit == null or grid == null or rng == null:
		return placements

	for _i in entry.count:
		var cells := _get_available_cells(grid, reserved)
		if cells.is_empty():
			break
		_shuffle_cells(cells, rng)
		var cell := cells[0]
		if not grid.can_place_at(cell):
			continue
		reserved[cell] = true
		placements.append({"unit": entry.unit, "cell": cell})

	return placements


static func _get_available_cells(grid: BoardGrid, reserved: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var height := grid.get_size().y
	for cell in grid.get_empty_cells():
		if reserved.has(cell):
			continue
		if not BoardHalf.is_enemy_spawn_cell(cell, height):
			continue
		cells.append(cell)
	return cells


static func _is_cell_available_for_spawn(
	grid: BoardGrid,
	cell: Vector2i,
	reserved: Dictionary,
) -> bool:
	if grid == null or reserved.has(cell):
		return false
	if not grid.can_place_at(cell):
		return false
	if grid.get_unit(cell) != null:
		return false
	return BoardHalf.is_enemy_spawn_cell(cell, grid.get_size().y)


static func _sort_cells_deterministic(cells: Array[Vector2i]) -> void:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)


static func _shuffle_cells(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
