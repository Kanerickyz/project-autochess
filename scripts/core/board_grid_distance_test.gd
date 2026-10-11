class_name BoardGridDistanceTest
extends RefCounted


static func run_all() -> bool:
	var ok := true
	ok = _test_combat_distance_matches_chebyshev() and ok
	ok = _test_find_nearest_uses_combat_distance() and ok
	ok = _test_path_cost_is_orthogonal() and ok
	return ok


static func _test_combat_distance_matches_chebyshev() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var a := Vector2i(2, 2)
	var b := Vector2i(5, 4)
	if grid.combat_distance(a, b) != 3:
		push_error("BoardGridDistanceTest: combat_distance expected 3")
		return false
	if grid.combat_distance(a, b) != grid.chebyshev_distance(a, b):
		push_error("BoardGridDistanceTest: combat_distance != chebyshev_distance")
		return false
	return true


static func _test_find_nearest_uses_combat_distance() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var player := UnitInstance.new("p", Vector2i(3, 3), UnitInstance.Team.PLAYER)
	var near := UnitInstance.new("near", Vector2i(5, 5), UnitInstance.Team.ENEMY)
	var far := UnitInstance.new("far", Vector2i(6, 3), UnitInstance.Team.ENEMY)
	var stats := UnitStats.new()
	stats.max_hp = 1
	stats.attack = 1
	for unit in [player, near, far]:
		unit.stats = stats.duplicate_stats() if stats.has_method("duplicate_stats") else stats
		unit.current_hp = 1
	grid.place(player, Vector2i(3, 3))
	grid.place(near, Vector2i(5, 5)) # combat dist 2
	grid.place(far, Vector2i(6, 3)) # combat dist 3
	var found := grid.find_nearest_enemy(Vector2i(3, 3), UnitInstance.Team.PLAYER)
	if found == null or found.id != "near":
		push_error("BoardGridDistanceTest: nearest enemy should be Chebyshev-nearest")
		return false
	return true


static func _test_path_cost_is_orthogonal() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	if grid.path_cost(Vector2i(0, 0), Vector2i(2, 2)) != 4:
		push_error("BoardGridDistanceTest: path_cost should be Manhattan steps")
		return false
	return true
