class_name EffectResolverSplitTest
extends RefCounted

const SLIME_UNIT := preload("res://resources/units/slime.tres")
const ANT_ABILITY := preload("res://resources/abilities/faint_buff_random_ally.tres")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_full_hp_slime_splits_five()
	_test_injured_slime_splits_current_hp()
	_test_limited_cells_partial_split()
	_test_split_does_not_trigger_friend_death()
	if _failures == 0:
		print("EffectResolverSplitTest: all tests passed")
	else:
		push_error("EffectResolverSplitTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid() -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	return grid


static func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	return rng


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"EffectResolverSplitTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _run_combat_start(grid: BoardGrid) -> EffectResolver:
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline, _rng())
	bus.combat_event.connect(resolver.on_event)
	bus.emit_event(CombatEvents.ON_COMBAT_START, CombatEventPayload.new())
	while resolver.has_pending_steps():
		resolver.process_next_step()
	return resolver


static func _slime(cell: Vector2i, team: UnitInstance.Team, current_hp: int = -1) -> UnitInstance:
	var unit := UnitInstance.from_unit_data(SLIME_UNIT, cell, team)
	if current_hp >= 0:
		unit.current_hp = current_hp
	return unit


static func _count_slime_splits(grid: BoardGrid, team: UnitInstance.Team) -> int:
	var count := 0
	for unit in grid.get_units_by_team(team, true):
		if unit.id == "slime_split":
			count += 1
	return count


static func _test_full_hp_slime_splits_five() -> void:
	var grid := _grid()
	var slime := _slime(Vector2i(2, 2), UnitInstance.Team.PLAYER)
	var slime_instance_id := slime.instance_id
	grid.place(slime, Vector2i(2, 2))

	_run_combat_start(grid)

	_assert_eq(_count_slime_splits(grid, UnitInstance.Team.PLAYER), 5, "five splits at full hp")
	_assert_eq(grid.find_cell_of(slime), Vector2i(-1, -1), "original slime removed from grid")
	for unit in grid.get_units_by_team(UnitInstance.Team.PLAYER, true):
		if unit.id != "slime_split":
			continue
		_assert_eq(unit.get_effective_attack(), 1, "split inherits attack")
		_assert_eq(unit.current_hp, 1, "split hp")
		_assert_eq(unit.get_effective_max_hp(), 1, "split max hp")
	_assert_eq(slime_instance_id > 0, true, "slime instance id captured")


static func _test_injured_slime_splits_current_hp() -> void:
	var grid := _grid()
	var slime := _slime(Vector2i(1, 1), UnitInstance.Team.PLAYER, 3)
	grid.place(slime, Vector2i(1, 1))

	_run_combat_start(grid)

	_assert_eq(_count_slime_splits(grid, UnitInstance.Team.PLAYER), 3, "splits match current hp")


static func _test_limited_cells_partial_split() -> void:
	var grid := _grid()
	var slime := _slime(Vector2i(3, 3), UnitInstance.Team.PLAYER)
	grid.place(slime, Vector2i(3, 3))
	for y in range(8):
		for x in range(8):
			var cell := Vector2i(x, y)
			if cell == Vector2i(3, 3) or cell == Vector2i(3, 4):
				continue
			var blocker := UnitInstance.new("blocker", cell, UnitInstance.Team.PLAYER)
			blocker.stats = UnitStats.new()
			blocker.stats.max_hp = 1
			blocker.current_hp = 1
			grid.place(blocker, cell)

	_run_combat_start(grid)

	var split_count := _count_slime_splits(grid, UnitInstance.Team.PLAYER)
	_assert_eq(split_count, 2, "partial split when only two spawn cells remain")


static func _test_split_does_not_trigger_friend_death() -> void:
	var grid := _grid()
	var slime := _slime(Vector2i(2, 2), UnitInstance.Team.PLAYER)
	var ant := UnitInstance.new("ant", Vector2i(3, 2), UnitInstance.Team.PLAYER)
	ant.stats = UnitStats.new()
	ant.stats.attack = 2
	ant.stats.max_hp = 2
	ant.current_hp = 2
	ant.unit_data = UnitData.new()
	ant.unit_data.id = "ant"
	ant.unit_data.ability = ANT_ABILITY
	var ant_atk_before := ant.get_effective_attack()
	grid.place(slime, Vector2i(2, 2))
	grid.place(ant, Vector2i(3, 2))

	_run_combat_start(grid)

	_assert_eq(
		ant.get_effective_attack(),
		ant_atk_before,
		"ant does not gain faint buff when slime splits without death",
	)
