class_name EffectResolverFaintTest
extends RefCounted

const _AntAbility := preload("res://resources/abilities/faint_buff_random_ally.tres")
const _EffectResolver := preload("res://scripts/combat/effects/effect_resolver.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_ant_faint_buffs_random_ally()
	_test_ant_faint_no_allies()
	_test_ant_faint_after_removal()
	if _failures == 0:
		print("EffectResolverFaintTest: all tests passed")
	else:
		push_error("EffectResolverFaintTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid() -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	return grid


static func _ant(cell: Vector2i, team: UnitInstance.Team) -> UnitInstance:
	var data := UnitData.new()
	data.id = "ant"
	data.ability = _AntAbility
	data.stats = UnitStats.new()
	data.stats.attack = 2
	data.stats.max_hp = 2
	var unit := UnitInstance.from_unit_data(data, cell, team)
	return unit


static func _ally(cell: Vector2i, team: UnitInstance.Team, hp: int = 2) -> UnitInstance:
	var unit := UnitInstance.new("ally", cell, team)
	unit.stats = UnitStats.new()
	unit.stats.attack = 1
	unit.stats.max_hp = 2
	unit.current_hp = hp
	return unit


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"EffectResolverFaintTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _run_death(
	grid: BoardGrid,
	dead: UnitInstance,
	defer_removal: bool,
) -> void:
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = defer_removal
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var attacker := UnitInstance.new("enemy", Vector2i(0, 0), UnitInstance.Team.ENEMY)
	attacker.stats = UnitStats.new()
	attacker.stats.attack = 5

	if not defer_removal:
		grid.remove_unit(dead)

	var payload := CombatEventPayload.new()
	payload.source = attacker
	payload.target = dead
	payload.amount = 5
	resolver.on_event(CombatEvents.ON_DEATH, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()


static func _test_ant_faint_buffs_random_ally() -> void:
	var grid := _grid()
	var ant := _ant(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var friend := _ally(Vector2i(2, 0), UnitInstance.Team.PLAYER, 1)
	grid.place(ant, Vector2i(1, 0))
	grid.place(friend, Vector2i(2, 0))
	ant.current_hp = 0

	_run_death(grid, ant, true)

	_assert_eq(friend.get_effective_attack(), 2, "ally attack after ant faint")
	_assert_eq(friend.get_effective_max_hp(), 4, "ally max hp after ant faint")
	## max_hp 临时层会同步抬当前生命，再吃 heal：1→3→4。
	_assert_eq(friend.current_hp, 4, "ally current hp after ant faint (+2 max sync +2 heal from 1/2)")


static func _test_ant_faint_no_allies() -> void:
	var grid := _grid()
	var ant := _ant(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	grid.place(ant, Vector2i(1, 0))
	ant.current_hp = 0

	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var payload := CombatEventPayload.new()
	payload.target = ant
	resolver.on_event(CombatEvents.ON_DEATH, payload)
	_assert_eq(resolver.has_pending_steps(), false, "no faint steps without allies")


static func _test_ant_faint_after_removal() -> void:
	var grid := _grid()
	var ant := _ant(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var friend := _ally(Vector2i(2, 0), UnitInstance.Team.PLAYER, 2)
	grid.place(ant, Vector2i(1, 0))
	grid.place(friend, Vector2i(2, 0))
	ant.current_hp = 0

	_run_death(grid, ant, false)

	_assert_eq(friend.get_effective_attack(), 2, "ally attack after ant removed from grid")
	_assert_eq(friend.get_effective_max_hp(), 4, "ally max hp after ant removed from grid")
	_assert_eq(friend.current_hp, 4, "ally current hp at full after +2 max +2 heal from 2/2")
