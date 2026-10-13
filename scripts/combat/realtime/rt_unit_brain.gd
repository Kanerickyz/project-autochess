class_name RtUnitBrain
extends RefCounted
## 皇室战争式单位决策：只更新自身的目标/状态/计时器，并返回本步的移动意图与是否出手。
## 不修改其他单位；伤害由 RealtimeCombatSim 交给 RealtimeDamagePipeline。

## 进入攻击判定的距离容差（格）
const REACH_EPSILON := 0.02
## 已锁定目标时允许超出 reach 的滞回（格）
const REACH_HYSTERESIS := 0.25
const TIME_EPSILON := 0.000001
## 前进方向短探测距离（格）；至少覆盖一步位移
const AVOID_PROBE := 0.75
## 侧向试探角（弧度），固定顺序：平局取先出现者
const AVOID_ANGLES: Array[float] = [
	PI / 6.0,
	-PI / 6.0,
	PI / 3.0,
	-PI / 3.0,
]


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
	if travel <= 0.0:
		return decision
	var forward := to_target / dist
	var move_dir := _steer_avoid(unit, units, unit.target, forward, travel)
	decision.move = move_dir * travel
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


## 简单避障：先只避同队；不够再扩到非当前目标。无随机，平局固定角序。
static func _steer_avoid(
	unit: RtUnit,
	units: Array,
	target: RtUnit,
	forward: Vector2,
	travel: float,
) -> Vector2:
	var probe := maxf(AVOID_PROBE, travel)
	var ally_hits := _probe_hit_count(unit, units, forward, probe, true, target)
	if ally_hits > 0:
		var steered := _pick_avoid_dir(unit, units, target, forward, probe, travel, true)
		if _probe_hit_count(unit, units, steered, probe, true, target) == 0:
			return steered
		return _pick_avoid_dir(unit, units, target, forward, probe, travel, false)
	var other_hits := _probe_hit_count(unit, units, forward, probe, false, target)
	if other_hits > 0:
		return _pick_avoid_dir(unit, units, target, forward, probe, travel, false)
	return forward


## allies_only=true 只计同队；false 计任意非当前目标。
static func _pick_avoid_dir(
	unit: RtUnit,
	units: Array,
	target: RtUnit,
	forward: Vector2,
	probe: float,
	travel: float,
	allies_only: bool,
) -> Vector2:
	var best_dir := forward
	var best_hits := _probe_hit_count(unit, units, forward, probe, allies_only, target)
	for angle in AVOID_ANGLES:
		var cand: Vector2 = forward.rotated(angle)
		# 可行侧向：本步仍靠近目标，且探测碰撞严格更少；平局保留先试到的方向
		if _approach_score(unit, target, cand, travel) <= 0.0:
			continue
		var hits := _probe_hit_count(unit, units, cand, probe, allies_only, target)
		if hits < best_hits:
			best_hits = hits
			best_dir = cand
	return best_dir


## 探测点处与障碍圆重叠的数量（不含自身）。
static func _probe_hit_count(
	unit: RtUnit,
	units: Array,
	dir: Vector2,
	probe: float,
	allies_only: bool,
	target: RtUnit,
) -> int:
	var probe_pos := unit.position + dir * probe
	var hits := 0
	for item in units:
		var other := item as RtUnit
		if other == null or other == unit or not other.is_alive():
			continue
		if allies_only:
			if other.get_team() != unit.get_team():
				continue
		elif other == target:
			continue
		var min_dist := unit.get_radius() + other.get_radius()
		if probe_pos.distance_squared_to(other.position) < min_dist * min_dist:
			hits += 1
	return hits


## 本步位移后缩短的目标距离；<=0 表示不靠近。
static func _approach_score(unit: RtUnit, target: RtUnit, dir: Vector2, travel: float) -> float:
	var before := unit.position.distance_to(target.position)
	var after := (unit.position + dir * travel).distance_to(target.position)
	return before - after


static func _drop_target(unit: RtUnit) -> void:
	unit.target = null
	unit.attack_timer = 0.0
	if unit.state == RtUnit.State.ATTACKING:
		unit.state = RtUnit.State.MOVING
