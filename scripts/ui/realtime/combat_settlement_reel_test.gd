class_name CombatSettlementReelTest
extends RefCounted


static var _failures: int = 0


static func run_all(host: Node = null) -> bool:
	_failures = 0
	_check("skill_short_label", _test_skill_short_label())
	_check("chip_key_status", _test_chip_key_status())
	_check("settlement_reel_motion", _test_settlement_reel_motion(host))
	if _failures == 0:
		print("CombatSettlementReelTest: all passed")
	else:
		push_error("CombatSettlementReelTest: %d failure(s)" % _failures)
	return _failures == 0


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("CombatSettlementReelTest FAIL: %s" % name)


static func _test_skill_short_label() -> bool:
	var unit := UnitInstance.new("u", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.unit_data = UnitData.new()
	unit.unit_data.ability = AbilityData.new()
	unit.unit_data.ability.display_name = "破甲箭"
	if CombatEntryStrip.skill_short_label(unit) != "破甲":
		return false
	unit.unit_data.ability.display_name = ""
	unit.unit_data.ability.id = "hurt_nearby_enemies_apply_weak"
	return CombatEntryStrip.skill_short_label(unit) == "hu"


static func _test_chip_key_status() -> bool:
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
	action.stat_name = CombatStatusStack.ID_WEAK
	return CombatEntryStrip.chip_key_for_action(action) == CombatStatusStack.ID_WEAK


static func _test_settlement_reel_motion(host: Node) -> bool:
	if host == null:
		return false
	var motion := RealtimeUnitMotion.new()
	host.add_child(motion)
	var unit := UnitInstance.new("t", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	var rt := RtUnit.new(unit, Vector2(2.5, 3.5))
	motion.sync_units([rt], null)
	motion.play_settlement_intro(rt)
	var pose := motion.get_pose(rt)
	if pose == null:
		motion.queue_free()
		return false
	motion.play_settlement_punch(rt, 0.5)
	motion.queue_free()
	return pose.reel_scale is Vector2
