class_name GhostGraveyardCadenceTest
extends RefCounted

const _BuildingAbility := preload("res://resources/abilities/cadence_spawn_skeleton_1_10.tres")
const _BuildingData := preload("res://resources/units/realtime/ghost_graveyard.tres")
const _EffectResolver := preload("res://scripts/combat/effects/effect_resolver.gd")


static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_brain_cadence_tick()
	_test_cadence_spawn_toward_enemy()
	_test_building_order_has_seven_occupations()
	_test_building_roster_population()
	_test_deck_entry_sync_immobile()
	if _failures == 0:
		print("GhostGraveyardCadenceTest: all tests passed")
	else:
		push_error("GhostGraveyardCadenceTest: %d failure(s)" % _failures)
	return _failures == 0


static func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("GhostGraveyardCadenceTest FAIL: %s" % message)


static func _test_building_roster_population() -> void:
	var data: UnitData = _BuildingData
	_assert(data.get_roster_population() == 2, "building roster population is 2")
	var skel := UnitData.new()
	skel.occupation = SynergyOccupations.WARRIOR
	_assert(skel.get_roster_population() == 1, "non-building population is 1")


static func _test_building_order_has_seven_occupations() -> void:
	_assert(SynergyOccupations.ORDER.size() == 7, "occupation ORDER should be 7")
	_assert(
		SynergyOccupations.ORDER.has(SynergyOccupations.BUILDING),
		"BUILDING in ORDER",
	)


static func _test_deck_entry_sync_immobile() -> void:
	var data: UnitData = _BuildingData.duplicate(true)
	var entry := DeckEntry.new()
	entry.entry_id = 1
	entry.unit = data
	var unit := UnitInstance.from_deck_entry(entry, Vector2i(1, 1), UnitInstance.Team.PLAYER)
	_assert(unit != null and unit.cannot_move, "from_deck_entry keeps immobile on building")


static func _test_brain_cadence_tick() -> void:
	var data: UnitData = _BuildingData.duplicate(true)
	var unit := UnitInstance.from_unit_data(data, Vector2i(2, 2), UnitInstance.Team.PLAYER)
	unit.cannot_move = true
	var rt := RtUnit.new(unit, RtUnit.cell_center(Vector2i(2, 2)))
	rt.attack_timer = 0.01
	var decision := RtUnitBrain.decide(rt, [], 0.02)
	_assert(decision.cadence_tick, "cadence_tick when timer expires")
	_assert(not decision.fire, "no normal attack fire")


static func _test_cadence_spawn_toward_enemy() -> void:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var building := UnitInstance.from_unit_data(
		_BuildingData,
		Vector2i(2, 3),
		UnitInstance.Team.PLAYER,
	)
	building.cannot_move = true
	grid.place(building, Vector2i(2, 3))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	var payload := CombatEventPayload.new()
	payload.source = building
	payload.target = building
	resolver.on_event(CombatEvents.ON_ATTACK_CADENCE, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
	var spawned := false
	for u in grid.get_units_by_team(UnitInstance.Team.PLAYER, true):
		if u.id == "token_skeleton_swarm":
			spawned = true
			var cell := grid.find_cell_of(u)
			_assert(cell.y > 3, "spawn toward enemy (+y for player)")
	_assert(spawned, "skeleton spawned on cadence")