class_name EffectResolverBatchTest
extends RefCounted

const _AntAbility := preload("res://resources/abilities/faint_buff_random_ally.tres")
const _HedgehogAbility := preload("res://resources/abilities/faint_aoe_damage.tres")
const _EffectResolver := preload("res://scripts/combat/effects/effect_resolver.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_ant_faint_one_batch_one_step()
	_test_ant_faint_single_resolved_event()
	_test_hedgehog_faint_aoe_one_batch()
	_test_hedgehog_faint_damages_all_targets()
	if _failures == 0:
		print("EffectResolverBatchTest: all tests passed")
	else:
		push_error("EffectResolverBatchTest: %d failure(s)" % _failures)
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
	return UnitInstance.from_unit_data(data, cell, team)


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
			"EffectResolverBatchTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error("EffectResolverBatchTest FAIL: %s" % message)


static func _run_death(
	grid: BoardGrid,
	dead: UnitInstance,
	resolver: EffectResolver,
) -> void:
	var attacker := UnitInstance.new("enemy", Vector2i(0, 0), UnitInstance.Team.ENEMY)
	attacker.stats = UnitStats.new()
	attacker.stats.attack = 5
	var payload := CombatEventPayload.new()
	payload.source = attacker
	payload.target = dead
	payload.amount = 5
	resolver.on_event(CombatEvents.ON_DEATH, payload)


static func _test_ant_faint_one_batch_one_step() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)

	var ant := _ant(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var friend := _ally(Vector2i(2, 0), UnitInstance.Team.PLAYER, 1)
	grid.place(ant, Vector2i(1, 0))
	grid.place(friend, Vector2i(2, 0))
	ant.current_hp = 0

	_run_death(grid, ant, resolver)
	_assert_true(resolver.has_pending_steps(), "ant faint enqueues a batch")
	_assert_eq(
		resolver._pending_batches.size(),
		1,
		"ant faint enqueues exactly one batch",
	)
	_assert_eq(
		resolver._pending_batches[0].entries.size(),
		3,
		"ant batch contains three actions",
	)

	var processed := resolver.process_next_step()
	_assert_true(processed, "process_next_step succeeds")
	_assert_eq(resolver.has_pending_steps(), false, "one step clears ant faint batch")

	_assert_eq(friend.get_effective_attack(), 2, "ally attack after batched faint")
	_assert_eq(friend.get_effective_max_hp(), 4, "ally max hp after batched faint")
	_assert_eq(friend.current_hp, 4, "ally current hp after batched faint")


static func _test_ant_faint_single_resolved_event() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	var resolved_count := [0]
	var last_payload: CombatEventPayload = null

	bus.combat_event.connect(func(event_type: StringName, payload: CombatEventPayload) -> void:
		if event_type != CombatEvents.ON_EFFECT_RESOLVED:
			return
		resolved_count[0] += 1
		last_payload = payload
	)

	var ant := _ant(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var friend := _ally(Vector2i(2, 0), UnitInstance.Team.PLAYER, 1)
	grid.place(ant, Vector2i(1, 0))
	grid.place(friend, Vector2i(2, 0))
	ant.current_hp = 0

	_run_death(grid, ant, resolver)
	resolver.process_next_step()

	_assert_eq(resolved_count[0], 1, "single ON_EFFECT_RESOLVED for ant faint")
	_assert_true(last_payload != null, "resolved payload captured")
	if last_payload != null:
		_assert_eq(last_payload.effect_entries.size(), 3, "batch payload has three entries")


static func _hedgehog(cell: Vector2i, team: UnitInstance.Team) -> UnitInstance:
	var data := UnitData.new()
	data.id = "hedgehog"
	data.ability = _HedgehogAbility
	data.stats = UnitStats.new()
	data.stats.attack = 4
	data.stats.max_hp = 2
	return UnitInstance.from_unit_data(data, cell, team)


static func _unit(
	id: String,
	cell: Vector2i,
	team: UnitInstance.Team,
	hp: int,
) -> UnitInstance:
	var unit := UnitInstance.new(id, cell, team)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = hp
	unit.current_hp = hp
	return unit


static func _test_hedgehog_faint_aoe_one_batch() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)

	var hedgehog := _hedgehog(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var ally := _unit("ally", Vector2i(2, 0), UnitInstance.Team.PLAYER, 3)
	var enemy := _unit("enemy", Vector2i(3, 0), UnitInstance.Team.ENEMY, 3)
	grid.place(hedgehog, Vector2i(1, 0))
	grid.place(ally, Vector2i(2, 0))
	grid.place(enemy, Vector2i(3, 0))
	hedgehog.current_hp = 0

	_run_death(grid, hedgehog, resolver)
	_assert_eq(resolver._pending_batches.size(), 1, "hedgehog faint enqueues one batch")
	_assert_eq(
		resolver._pending_batches[0].entries.size(),
		2,
		"hedgehog batch hits all other alive units",
	)

	var processed := resolver.process_next_step()
	_assert_true(processed, "hedgehog faint batch executes in one step")
	_assert_eq(resolver.has_pending_steps(), false, "hedgehog faint clears queue in one step")


static func _test_hedgehog_faint_damages_all_targets() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	pipeline.defer_death_removal = true
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	var damage_count := [0]

	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			damage_count[0] += 1
	)

	var hedgehog := _hedgehog(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var ally := _unit("ally", Vector2i(2, 0), UnitInstance.Team.PLAYER, 3)
	var enemy := _unit("enemy", Vector2i(3, 0), UnitInstance.Team.ENEMY, 3)
	grid.place(hedgehog, Vector2i(1, 0))
	grid.place(ally, Vector2i(2, 0))
	grid.place(enemy, Vector2i(3, 0))
	hedgehog.current_hp = 0

	_run_death(grid, hedgehog, resolver)
	resolver.process_next_step()

	_assert_eq(damage_count[0], 2, "hedgehog faint damages each alive target once")
	_assert_eq(ally.current_hp, 1, "ally takes 2 damage from hedgehog faint")
	_assert_eq(enemy.current_hp, 1, "enemy takes 2 damage from hedgehog faint")
