class_name EffectResolverBomberTest
extends RefCounted

const _BomberAbility := preload("res://resources/abilities/bomber_fuse_explode.tres")
const _EffectResolver := preload("res://scripts/combat/effects/effect_resolver.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_no_explosion_before_round_five()
	_test_explosion_on_round_five_hits_by_radius()
	_test_explosion_radius_follows_current_hp()
	_test_explosion_kills_bomber()
	if _failures == 0:
		print("EffectResolverBomberTest: all tests passed")
	else:
		push_error("EffectResolverBomberTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid() -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	return grid


static func _bomber(cell: Vector2i, team: UnitInstance.Team, hp: int = 3) -> UnitInstance:
	var data := UnitData.new()
	data.id = "bomber"
	data.ability = _BomberAbility
	data.stats = UnitStats.new()
	data.stats.max_hp = 3
	data.stats.attack = 2
	var unit := UnitInstance.from_unit_data(data, cell, team)
	unit.current_hp = hp
	return unit


static func _enemy(cell: Vector2i, hp: int = 10) -> UnitInstance:
	var unit := UnitInstance.new("enemy", cell, UnitInstance.Team.ENEMY)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = hp
	unit.stats.attack = 1
	unit.current_hp = hp
	return unit


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"EffectResolverBomberTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error("EffectResolverBomberTest FAIL: %s" % message)


static func _run_round(resolver: EffectResolver, round: int) -> void:
	var payload := CombatEventPayload.new()
	payload.amount = round
	resolver.on_event(CombatEvents.ON_ROUND_START, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()


static func _test_no_explosion_before_round_five() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)

	var bomber := _bomber(Vector2i(2, 2), UnitInstance.Team.PLAYER, 3)
	var near := _enemy(Vector2i(3, 2), 10)
	grid.place(bomber, Vector2i(2, 2))
	grid.place(near, Vector2i(3, 2))

	_run_round(resolver, 3)
	_assert_eq(near.current_hp, 10, "round 3 should not damage enemies")
	_assert_true(bomber.is_alive(), "round 3 should not kill bomber")


static func _test_explosion_on_round_five_hits_by_radius() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)

	var bomber := _bomber(Vector2i(2, 2), UnitInstance.Team.PLAYER, 3)
	var near := _enemy(Vector2i(3, 2), 10)
	var edge := _enemy(Vector2i(5, 2), 10)
	var out_of_range := _enemy(Vector2i(6, 2), 10)
	grid.place(bomber, Vector2i(2, 2))
	grid.place(near, Vector2i(3, 2))
	grid.place(edge, Vector2i(5, 2))
	grid.place(out_of_range, Vector2i(6, 2))

	_run_round(resolver, 4)
	_assert_eq(near.current_hp, 10, "round 4 should not damage near enemy")

	_run_round(resolver, 5)
	_assert_eq(near.current_hp, 8, "near enemy takes bomber attack damage")
	_assert_eq(edge.current_hp, 8, "edge enemy at radius 3 takes damage")
	_assert_eq(out_of_range.current_hp, 10, "enemy outside radius 3 is safe")


static func _test_explosion_radius_follows_current_hp() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)

	var bomber := _bomber(Vector2i(2, 2), UnitInstance.Team.PLAYER, 1)
	var near := _enemy(Vector2i(3, 2), 10)
	var far := _enemy(Vector2i(4, 2), 10)
	grid.place(bomber, Vector2i(2, 2))
	grid.place(near, Vector2i(3, 2))
	grid.place(far, Vector2i(4, 2))

	_run_round(resolver, 5)
	_assert_eq(near.current_hp, 8, "1 hp radius hits distance 1 enemy")
	_assert_eq(far.current_hp, 10, "1 hp radius misses distance 2 enemy")


static func _test_explosion_kills_bomber() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	var death_count := [0]

	bus.combat_event.connect(func(event_type: StringName, payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DEATH and payload.target != null:
			if payload.target.id == "bomber":
				death_count[0] += 1
	)

	var bomber := _bomber(Vector2i(2, 2), UnitInstance.Team.PLAYER, 3)
	var near := _enemy(Vector2i(3, 2), 10)
	grid.place(bomber, Vector2i(2, 2))
	grid.place(near, Vector2i(3, 2))

	_run_round(resolver, 5)
	_assert_true(not bomber.is_alive(), "bomber dies after fuse explosion")
	_assert_eq(death_count[0], 1, "bomber emits ON_DEATH once")
