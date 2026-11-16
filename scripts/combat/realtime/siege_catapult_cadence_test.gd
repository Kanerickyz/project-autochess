class_name SiegeCatapultCadenceTest
extends RefCounted

const _BuildingData := preload("res://resources/units/realtime/siege_catapult.tres")
const _EnemySkeleton := preload("res://resources/units/enemies/enemy_skeleton.tres")


static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_resource_mount()
	_test_brain_normal_attack_tick()
	_test_realtime_sim_normal_attack_damage()
	if _failures == 0:
		print("SiegeCatapultCadenceTest: all tests passed")
	else:
		push_error("SiegeCatapultCadenceTest: %d failure(s)" % _failures)
	return _failures == 0


static func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("SiegeCatapultCadenceTest FAIL: %s" % message)


static func _test_resource_mount() -> void:
	var data: UnitData = _BuildingData
	_assert(data != null and data.tier == 2, "siege_catapult tier 2")
	_assert(data.get_roster_population() == 2, "building population 2")
	_assert(data.footprint_w >= 2, "footprint 2-wide")
	_assert(data.stats != null and data.stats.attack == 5, "siege_catapult attack 5")
	_assert(data.bombard_random_enemy, "bombard_random_enemy flag")
	_assert(data.ability == null, "no main skill — damage is normal attack")


static func _test_brain_normal_attack_tick() -> void:
	var data: UnitData = _BuildingData.duplicate(true)
	var unit := UnitInstance.from_unit_data(data, Vector2i(2, 2), UnitInstance.Team.PLAYER)
	unit.cannot_move = true
	var rt := RtUnit.new(unit, RtUnit.cell_center(Vector2i(2, 2)))
	rt.state = RtUnit.State.MOVING
	rt.attack_timer = 0.0
	var foe_data := _EnemySkeleton.duplicate(true) as UnitData
	var foe := UnitInstance.from_unit_data(foe_data, Vector2i(2, 0), UnitInstance.Team.ENEMY)
	var foe_rt := RtUnit.new(foe, RtUnit.cell_center(Vector2i(2, 0)))
	var decision := RtUnitBrain.decide(rt, [rt, foe_rt], 0.02)
	_assert(decision.fire, "normal attack fire when timer expires")
	_assert(not decision.cadence_tick, "not skill cadence tick")
	_assert(rt.target == foe_rt, "picked enemy target for bombard")


static func _test_realtime_sim_normal_attack_damage() -> void:
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
	_assert(hp_after < hp_before, "enemy took normal attack damage (steps=%d)" % steps)