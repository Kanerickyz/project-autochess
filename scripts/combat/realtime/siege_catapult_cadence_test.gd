class_name SiegeCatapultCadenceTest
extends RefCounted

const _Ability := preload("res://resources/abilities/cadence_damage_random_enemy_5.tres")
const _BuildingData := preload("res://resources/units/realtime/siege_catapult.tres")
const _EnemySkeleton := preload("res://resources/units/enemies/enemy_skeleton.tres")


static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_ability_mount()
	_test_brain_cadence_tick()
	_test_realtime_sim_cadence_damage()
	if _failures == 0:
		print("SiegeCatapultCadenceTest: all tests passed")
	else:
		push_error("SiegeCatapultCadenceTest: %d failure(s)" % _failures)
	return _failures == 0


static func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("SiegeCatapultCadenceTest FAIL: %s" % message)


static func _test_ability_mount() -> void:
	var data: UnitData = _BuildingData
	_assert(data != null and data.tier == 2, "siege_catapult tier 2")
	_assert(data.get_roster_population() == 2, "building population 2")
	_assert(data.footprint_w >= 2, "footprint 2-wide")
	_assert(data.stats != null and data.stats.attack == 5, "siege_catapult attack 5 (panel / cadence hit)")
	var ab: AbilityData = data.ability
	_assert(ab != null and ab.id == "cadence_damage_random_enemy_5", "ability id")
	_assert(is_equal_approx(ab.passive_cadence_seconds, 5.0), "cadence 5s")
	if ab.effect_specs.size() > 0:
		var spec: EffectSpec = ab.effect_specs[0]
		_assert(spec.max_triggers_per_combat <= 0, "unlimited triggers")


static func _test_brain_cadence_tick() -> void:
	var data: UnitData = _BuildingData.duplicate(true)
	var unit := UnitInstance.from_unit_data(data, Vector2i(2, 2), UnitInstance.Team.PLAYER)
	unit.cannot_move = true
	var rt := RtUnit.new(unit, RtUnit.cell_center(Vector2i(2, 2)))
	rt.state = RtUnit.State.MOVING
	rt.attack_timer = 0.0
	var decision := RtUnitBrain.decide(rt, [], 0.02)
	_assert(decision.cadence_tick, "cadence_tick when timer expires")
	_assert(not decision.fire, "no normal attack")


static func _test_realtime_sim_cadence_damage() -> void:
	var sim := RealtimeCombatSim.new()
	sim.configure(Vector2i(5, 8), 44102)
	sim.defer_effect_resolve = false
	var building := UnitInstance.from_unit_data(
		_BuildingData,
		Vector2i(0, 6),
		UnitInstance.Team.PLAYER,
	)
	var foe := UnitInstance.from_unit_data(_EnemySkeleton, Vector2i(2, 2), UnitInstance.Team.ENEMY)
	sim.add_unit(building, RtUnit.cell_center(Vector2i(0, 6)))
	var foe_rt := sim.add_unit(foe, RtUnit.cell_center(Vector2i(2, 2)))
	_assert(foe_rt != null, "foe added")
	var hp_before := foe_rt.unit.current_hp
	sim.begin_combat()
	sim.flush_combat_start_lock()
	var steps := 0
	while not sim.is_finished() and steps < 900:
		sim.advance_fixed_step()
		steps += 1
	var hp_after := foe_rt.unit.current_hp
	_assert(hp_after < hp_before, "enemy took cadence damage (steps=%d)" % steps)