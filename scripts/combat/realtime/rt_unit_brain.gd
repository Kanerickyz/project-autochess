class_name RtUnitBrain
extends RefCounted
## 皇室战争式单位决策：只更新自身的目标/状态/计时器，并返回本步的移动意图与是否出手。
## 不修改其他单位；伤害由 RealtimeCombatSim 交给 RealtimeDamagePipeline。

## 进入攻击判定的距离容差（格）
const REACH_EPSILON := 0.02
## 已锁定目标时允许超出 reach 的滞回（格）
const REACH_HYSTERESIS := 0.25
const TIME_EPSILON := 0.000001


class Decision:
	var move: Vector2 = Vector2.ZERO
	var fire: bool = false


static func decide(unit: RtUnit, units: Array, dt: float) -> Decision:
	var decision := Decision.new()
	if not unit.is_alive():
		return decision
	if unit.state == RtUnit.State.DEPLOYING:
		unit.deploy_remaining -= dt
		if unit.deploy_remaining > TIME_EPSILON:
			return decision
		unit.deploy_remaining = 0.0
		unit.state = RtUnit.State.MOVING

	var stats := unit.get_stats()
	if unit.target != null and not unit.target.is_alive():
		_drop_target(unit)
	if unit.state == RtUnit.State.ATTACKING and unit.target != null:
		if unit.edge_distance_to(unit.target) > stats.attack_reach + REACH_HYSTERESIS:
			_drop_target(unit)
	if unit.state != RtUnit.State.ATTACKING:
		unit.target = acquire_target(unit, units)
	if unit.target == null:
		unit.state = RtUnit.State.MOVING
		return decision

	var edge := unit.edge_distance_to(unit.target)
	if unit.state == RtUnit.State.ATTACKING or edge <= stats.attack_reach + REACH_EPSILON:
		if unit.state != RtUnit.State.ATTACKING:
			unit.state = RtUnit.State.ATTACKING
			unit.attack_timer = maxf(0.0, stats.attack_windup)
		unit.attack_timer -= dt
		if unit.attack_timer <= TIME_EPSILON:
			decision.fire = true
			unit.attack_timer += maxf(0.05, stats.attack_interval)
		return decision

	unit.state = RtUnit.State.MOVING
	var to_target := unit.target.position - unit.position
	var dist := to_target.length()
	if dist <= 0.0:
		return decision
	var travel := minf(maxf(0.0, stats.move_speed) * dt, maxf(0.0, edge - stats.attack_reach))
	decision.move = to_target / dist * travel
	return decision


## sight_range 内最近敌人；没有则全场最近敌人。距离按碰撞圆边缘，平局取较小 instance_id。
static func acquire_target(unit: RtUnit, units: Array) -> RtUnit:
	var sight := unit.get_stats().sight_range
	var best_in_sight: RtUnit = null
	var best_in_sight_dist := INF
	var best_any: RtUnit = null
	var best_any_dist := INF
	for item in units:
		var other := item as RtUnit
		if other == null or other == unit or not other.is_alive():
			continue
		if other.get_team() == unit.get_team():
			continue
		var edge := unit.edge_distance_to(other)
		if edge < best_any_dist:
			best_any_dist = edge
			best_any = other
		if edge <= sight and edge < best_in_sight_dist:
			best_in_sight_dist = edge
			best_in_sight = other
	return best_in_sight if best_in_sight != null else best_any


static func _drop_target(unit: RtUnit) -> void:
	unit.target = null
	unit.attack_timer = 0.0
	if unit.state == RtUnit.State.ATTACKING:
		unit.state = RtUnit.State.MOVING
