class_name GridMovement
extends RefCounted

const _UnitStats := preload("res://scripts/data/unit_stats.gd")

const FOUR_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

const DIAGONAL_DIRS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]

const KNIGHT_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 2),
	Vector2i(1, -2),
	Vector2i(-1, 2),
	Vector2i(-1, -2),
	Vector2i(2, 1),
	Vector2i(2, -1),
	Vector2i(-2, 1),
	Vector2i(-2, -1),
]


static func get_step_toward(grid: BoardGrid, from: Vector2i, target: Vector2i) -> Vector2i:
	var path := plan_move_path(
		grid,
		from,
		target,
		_UnitStats.MovementPattern.ORTHOGONAL,
		1,
	)
	if path.is_empty():
		return from
	return path[0]


static func plan_move_path(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
	pattern: _UnitStats.MovementPattern,
	steps: int,
) -> Array[Vector2i]:
	if from == target:
		return []

	match pattern:
		_UnitStats.MovementPattern.ORTHOGONAL:
			return _walk_greedy_steps(grid, from, target, FOUR_DIRS, maxi(1, steps))
		_UnitStats.MovementPattern.LINE:
			return _plan_line_path(grid, from, target, maxi(1, steps))
		_UnitStats.MovementPattern.ROOK:
			return _plan_rook_path(grid, from, target)
		_UnitStats.MovementPattern.KNIGHT:
			return _plan_knight_path(grid, from, target)
		_UnitStats.MovementPattern.DIAGONAL:
			return _walk_greedy_steps(grid, from, target, DIAGONAL_DIRS, maxi(1, steps))
		_UnitStats.MovementPattern.BISHOP:
			return _plan_bishop_path(grid, from, target)
		_UnitStats.MovementPattern.QUEEN:
			return _plan_queen_path(grid, from, target)
		_UnitStats.MovementPattern.TELEPORT:
			return _plan_teleport_path(grid, from, target, maxi(1, steps))
		_:
			return _walk_greedy_steps(grid, from, target, FOUR_DIRS, maxi(1, steps))


static func _can_enter(grid: BoardGrid, cell: Vector2i) -> bool:
	return grid.in_bounds(cell) and not grid.is_blocked(cell) and not grid.is_occupied(cell)


static func _walk_greedy_steps(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
	dirs: Array[Vector2i],
	max_steps: int,
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := from

	for _step in max_steps:
		var candidates: Array[Vector2i] = []
		for dir in dirs:
			var next := current + dir
			if _can_enter(grid, next):
				candidates.append(next)

		if candidates.is_empty():
			break

		candidates.sort_custom(_sort_cells)
		var best_cell := current
		var best_dist := BoardGrid._path_cost(current, target)
		for cell in candidates:
			var dist := BoardGrid._path_cost(cell, target)
			if dist < best_dist:
				best_dist = dist
				best_cell = cell

		if best_cell == current:
			break

		path.append(best_cell)
		current = best_cell

	return path


static func _plan_line_path(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
	max_steps: int,
) -> Array[Vector2i]:
	var x_path := _walk_line_axis(grid, from, target, true, max_steps)
	var y_path := _walk_line_axis(grid, from, target, false, max_steps)
	return _pick_better_axis_path(x_path, y_path, target)


static func _plan_rook_path(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
) -> Array[Vector2i]:
	var x_path := _walk_line_axis(grid, from, target, true, -1)
	var y_path := _walk_line_axis(grid, from, target, false, -1)
	return _pick_better_axis_path(x_path, y_path, target)


static func _plan_bishop_path(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
) -> Array[Vector2i]:
	var pos_diag_path := _walk_diagonal_axis(grid, from, target, true, -1)
	var neg_diag_path := _walk_diagonal_axis(grid, from, target, false, -1)
	return _pick_better_axis_path(pos_diag_path, neg_diag_path, target)


static func _plan_queen_path(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
) -> Array[Vector2i]:
	var paths: Array[Array] = [
		_walk_line_axis(grid, from, target, true, -1),
		_walk_line_axis(grid, from, target, false, -1),
		_walk_diagonal_axis(grid, from, target, true, -1),
		_walk_diagonal_axis(grid, from, target, false, -1),
	]
	return _pick_best_path(paths, target)


static func _pick_best_path(paths: Array, target: Vector2i) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	var best_dist := 1_000_000
	for candidate in paths:
		if candidate.is_empty():
			continue
		var end: Vector2i = candidate[candidate.size() - 1]
		var dist := BoardGrid._path_cost(end, target)
		if dist < best_dist:
			best_dist = dist
			best_path = candidate
		elif dist == best_dist and not best_path.is_empty():
			var best_end: Vector2i = best_path[best_path.size() - 1]
			if _sort_cells(end, best_end):
				best_path = candidate
	return best_path


static func _walk_diagonal_axis(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
	positive_slope: bool,
	max_steps: int,
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := from
	var steps_taken := 0
	var unlimited := max_steps < 0

	while unlimited or steps_taken < max_steps:
		var next := current
		if positive_slope:
			if target.x > current.x and target.y > current.y:
				next = current + Vector2i(1, 1)
			elif target.x < current.x and target.y < current.y:
				next = current + Vector2i(-1, -1)
			else:
				break
		elif target.x > current.x and target.y < current.y:
			next = current + Vector2i(1, -1)
		elif target.x < current.x and target.y > current.y:
			next = current + Vector2i(-1, 1)
		else:
			break

		if not _can_enter(grid, next):
			break

		path.append(next)
		current = next
		steps_taken += 1

	return path


static func _pick_better_axis_path(
	x_path: Array[Vector2i],
	y_path: Array[Vector2i],
	target: Vector2i,
) -> Array[Vector2i]:
	if x_path.is_empty() and y_path.is_empty():
		return []

	if x_path.is_empty():
		return y_path
	if y_path.is_empty():
		return x_path

	var x_end: Vector2i = x_path[x_path.size() - 1]
	var y_end: Vector2i = y_path[y_path.size() - 1]
	var x_dist := BoardGrid._path_cost(x_end, target)
	var y_dist := BoardGrid._path_cost(y_end, target)

	if x_dist < y_dist:
		return x_path
	if y_dist < x_dist:
		return y_path

	if _sort_cells(x_end, y_end):
		return x_path
	return y_path


static func _walk_line_axis(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
	axis_x: bool,
	max_steps: int,
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current := from
	var steps_taken := 0
	var unlimited := max_steps < 0

	while unlimited or steps_taken < max_steps:
		var next := current
		if axis_x:
			if target.x > current.x:
				next = current + Vector2i(1, 0)
			elif target.x < current.x:
				next = current + Vector2i(-1, 0)
			else:
				break
		elif target.y > current.y:
			next = current + Vector2i(0, 1)
		elif target.y < current.y:
			next = current + Vector2i(0, -1)
		else:
			break

		if not _can_enter(grid, next):
			break

		path.append(next)
		current = next
		steps_taken += 1

	return path


static func _plan_teleport_path(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
	range: int,
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for dy in range(-range, range + 1):
		for dx in range(-range, range + 1):
			if dx == 0 and dy == 0:
				continue
			if maxi(absi(dx), absi(dy)) > range:
				continue
			var cell := from + Vector2i(dx, dy)
			if _can_enter(grid, cell):
				candidates.append(cell)

	if candidates.is_empty():
		return []

	candidates.sort_custom(_sort_cells)
	var best_cell := candidates[0]
	var best_dist := BoardGrid._chebyshev(best_cell, target)
	for cell in candidates:
		var dist := BoardGrid._chebyshev(cell, target)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
		elif dist == best_dist and _sort_cells(cell, best_cell):
			best_cell = cell

	return [best_cell]


static func _plan_knight_path(
	grid: BoardGrid,
	from: Vector2i,
	target: Vector2i,
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	for offset in KNIGHT_OFFSETS:
		var next := from + offset
		if _can_enter(grid, next):
			candidates.append(next)

	if candidates.is_empty():
		return []

	candidates.sort_custom(_sort_cells)
	var best_cell := candidates[0]
	var best_dist := BoardGrid._path_cost(best_cell, target)
	for cell in candidates:
		var dist := BoardGrid._path_cost(cell, target)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell

	return [best_cell]


static func _sort_cells(a: Vector2i, b: Vector2i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y
