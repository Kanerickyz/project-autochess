class_name EffectResolverAssassinTest
extends RefCounted

const _EffectResolver := preload("res://scripts/combat/effects/effect_resolver.gd")
const _AssassinData := preload("res://resources/units/assassin.tres")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_swap_retargets_damage()
	_test_counterattack_swap_when_assassin_attacks()
	_test_from_deck_entry_emits_swap_event()
	_test_fizzle_without_allies()
	_test_picks_highest_current_hp()
	if _failures == 0:
		print("EffectResolverAssassinTest: all tests passed")
	else:
		push_error("EffectResolverAssassinTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid(size: Vector2i = Vector2i(8, 8)) -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(size)
	return grid


static func _bus() -> CombatEventBus:
	return CombatEventBus.new()


static func _assassin(cell: Vector2i, team: UnitInstance.Team = UnitInstance.Team.PLAYER) -> UnitInstance:
	var unit := UnitInstance.from_unit_data(_AssassinData, cell, team)
	unit.current_hp = unit.get_effective_max_hp()
	return unit


static func _ally(
	grid: BoardGrid,
	cell: Vector2i,
	hp: int,
	max_hp: int = -1,
) -> UnitInstance:
	var unit := UnitInstance.new("ally", cell, UnitInstance.Team.PLAYER)
	if max_hp < 0:
		max_hp = hp
	unit.stats = UnitStats.new()
	unit.stats.max_hp = max_hp
	unit.current_hp = hp
	grid.place(unit, cell)
	return unit


static func _enemy(grid: BoardGrid, cell: Vector2i, attack: int = 3) -> UnitInstance:
	var unit := UnitInstance.new("enemy", cell, UnitInstance.Team.ENEMY)
	unit.stats = UnitStats.new()
	unit.stats.attack = attack
	unit.current_hp = 5
	grid.place(unit, cell)
	return unit


static func _hit_payload(attacker: UnitInstance, defender: UnitInstance) -> CombatEventPayload:
	var payload := CombatEventPayload.new()
	payload.source = attacker
	payload.target = defender
	return payload


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"EffectResolverAssassinTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("EffectResolverAssassinTest FAIL: %s" % message)


static func _test_swap_retargets_damage() -> void:
	var grid := _grid()
	var bus := _bus()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	pipeline.set_effect_resolver(resolver)

	var assassin := _assassin(Vector2i(2, 2))
	grid.place(assassin, Vector2i(2, 2))
	var tank := _ally(grid, Vector2i(0, 2), 5, 5)
	var attacker := _enemy(grid, Vector2i(2, 0), 3)

	var ally_hp_before := tank.current_hp
	pipeline.apply_attack_exchange(attacker, assassin)
	_assert_eq(grid.find_cell_of(assassin), Vector2i(0, 2), "assassin moved to tank cell")
	_assert_eq(grid.find_cell_of(tank), Vector2i(2, 2), "tank moved to assassin cell")
	_assert_eq(tank.current_hp, ally_hp_before - attacker.get_effective_attack(), "tank takes attacker damage")
	_assert_eq(assassin.current_hp, assassin.get_effective_max_hp(), "assassin avoids direct hit")


static func _test_counterattack_swap_when_assassin_attacks() -> void:
	var grid := _grid()
	var bus := _bus()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	pipeline.set_effect_resolver(resolver)

	var assassin := _assassin(Vector2i(2, 2))
	grid.place(assassin, Vector2i(2, 2))
	var tank := _ally(grid, Vector2i(0, 2), 5, 5)
	var enemy := _enemy(grid, Vector2i(3, 2), 2)

	var assassin_hp_before := assassin.current_hp
	var ally_hp_before := tank.current_hp
	pipeline.apply_attack_exchange(assassin, enemy)

	_assert_eq(grid.find_cell_of(assassin), Vector2i(0, 2), "assassin swapped on counterattack")
	_assert_eq(grid.find_cell_of(tank), Vector2i(2, 2), "tank occupies assassin original cell")
	_assert_eq(
		tank.current_hp,
		ally_hp_before - enemy.get_effective_attack(),
		"tank takes enemy counterattack damage",
	)
	_assert_eq(assassin.current_hp, assassin_hp_before, "assassin not hit by counterattack")
	_assert_true(enemy.current_hp < 5, "enemy still takes assassin strike damage")


static func _test_from_deck_entry_emits_swap_event() -> void:
	var grid := _grid()
	var bus := _bus()
	var swap_events := [0]
	bus.combat_event.connect(func(event_type: StringName, payload: CombatEventPayload) -> void:
		if event_type != CombatEvents.ON_EFFECT_RESOLVED:
			return
		if payload == null or payload.effect_action == null:
			return
		if payload.effect_action.action_type == EffectAction.Type.SWAP_POSITIONS:
			swap_events[0] += 1
	)

	var entry := DeckEntry.new()
	entry.unit = _AssassinData
	var assassin := UnitInstance.from_deck_entry(entry, Vector2i(2, 2), UnitInstance.Team.PLAYER)
	grid.place(assassin, Vector2i(2, 2))
	_assert_true(assassin.get_all_effect_specs().size() > 0, "deck entry assassin has specs")

	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	_assert_true(pipeline._effect_resolver != null, "pipeline auto-wired to resolver")

	_ally(grid, Vector2i(0, 2), 5, 5)
	var attacker := _enemy(grid, Vector2i(2, 0), 2)
	pipeline.apply_attack_exchange(attacker, assassin)

	_assert_eq(swap_events[0], 1, "swap resolved event emitted once")
	_assert_eq(grid.find_cell_of(assassin), Vector2i(0, 2), "deck entry assassin swapped")


static func _test_fizzle_without_allies() -> void:
	var grid := _grid()
	var bus := _bus()
	var fizzled_flag := [false]
	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_EFFECT_FIZZLED:
			fizzled_flag[0] = true
	)

	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	pipeline.set_effect_resolver(resolver)

	var assassin := _assassin(Vector2i(1, 1))
	grid.place(assassin, Vector2i(1, 1))
	var attacker := _enemy(grid, Vector2i(1, 0), 2)

	var hit := resolver.process_attack_hit_immediate(_hit_payload(attacker, assassin))
	_assert_true(hit.get("fizzled", false), "assassin fizzles without allies")
	_assert_true(fizzled_flag[0], "fizzle event emitted")
	_assert_eq(hit.get("damage_target"), assassin, "damage stays on assassin")

	var hp_before := assassin.current_hp
	pipeline.apply_attack_exchange(attacker, assassin)
	_assert_eq(
		assassin.current_hp,
		hp_before - attacker.get_effective_attack(),
		"assassin takes damage after fizzle",
	)


static func _test_picks_highest_current_hp() -> void:
	var grid := _grid()
	var bus := _bus()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := _EffectResolver.new(grid, bus, pipeline)

	var assassin := _assassin(Vector2i(3, 3))
	grid.place(assassin, Vector2i(3, 3))
	var low := _ally(grid, Vector2i(0, 3), 2, 4)
	var high := _ally(grid, Vector2i(1, 3), 4, 4)
	var attacker := _enemy(grid, Vector2i(3, 0), 1)

	var hit := resolver.process_attack_hit_immediate(_hit_payload(attacker, assassin))
	_assert_true(hit.get("swapped", false), "swap succeeds with allies")
	_assert_eq(hit.get("damage_target"), high, "highest current hp ally is swap partner")
	_assert_eq(grid.find_cell_of(high), Vector2i(3, 3), "high hp ally occupies assassin cell")
	_assert_eq(grid.find_cell_of(low), Vector2i(0, 3), "other ally unchanged")
	_assert_eq(grid.find_cell_of(assassin), Vector2i(1, 3), "assassin occupies high ally cell")
