class_name RtUnitBrain
extends RefCounted
## 八方向格步决策：索敌/出手用切比雪夫格距；移动选邻格；不修改其他单位。

## 进入攻击判定的距离容差（格）
const REACH_EPSILON := 0.02
## 已锁定目标时允许超出 reach 的滞回（格）
const REACH_HYSTERESIS := 0.25
const TIME_EPSILON := 0.000001

## 八方向：先正四向再对角（平局稳定次序）
const DIR8: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1, -1),
]


class Decision:
	## 本步要踏入的邻格相对偏移；ZERO = 不移动（攻击中 / 等待占格）
	var step: Vector2i = Vector2i.ZERO
	var fire: bool = false


static func decide(unit: RtUnit, units: Array, dt: float, is_cell_free: Callable) -> Decision:
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
		var lock_dist := float(unit.cell_distance_to(unit.target))
		if lock_dist > grid_reach(stats.attack_reach) + REACH_HYSTERESIS:
			_drop_target(unit)
	if unit.state != RtUnit.State.ATTACKING:
		unit.target = acquire_target(unit, units)
	if unit.target == null:
		unit.state = RtUnit.State.MOVING
		return decision

	var dist := float(unit.cell_distance_to(unit.target))
	var reach := grid_reach(stats.attack_reach)
	if unit.state == RtUnit.State.ATTACKING or dist <= reach + REACH_EPSILON:
		if unit.state != RtUnit.State.ATTACKING:
			unit.state = RtUnit.State.ATTACKING
			unit.attack_timer = maxf(0.0, stats.attack_windup)
		unit.attack_timer -= dt
		if unit.attack_timer <= TIME_EPSILON:
			decision.fire = true
			unit.attack_timer += maxf(0.05, stats.attack_interval)
		## 逻辑停在当前格攻击；若仍在格间插值，表现继续滑完，不新开步
		return decision

	unit.state = RtUnit.State.MOVING
	if maxf(0.0, stats.move_speed) <= 0.0:
		return decision
	## 步进中：若本帧尚走不完则等待；走得完则衔接下一步（避免格间空帧）
	if unit.is_stepping():
		var remain := 1.0 - unit.step_t
		if remain > stats.move_speed * dt + TIME_EPSILON:
			return decision
	decision.step = pick_step(unit, unit.target, is_cell_free)
	return decision


## 旧欧氏近战 reach 常 < 1；一格一体下邻格切比雪夫为 1，正 reach 至少按邻格处理。
static func grid_reach(reach: float) -> float:
	if reach <= 0.0:
		return 0.0
	if reach < 1.0:
		return 1.0
	return reach


## sight_range 内格距最近敌人；没有则全场最近。平局取较小 instance_id。
static func acquire_target(unit: RtUnit, units: Array) -> RtUnit:
	var sight := unit.get_stats().sight_range
	var best_in_sight: RtUnit = null
	var best_in_sight_dist := 999999
	var best_in_sight_id := 0x7fffffff
	var best_any: RtUnit = null
	var best_any_dist := 999999
	var best_any_id := 0x7fffffff
	for item in units:
		var other := item as RtUnit
		if other == null or other == unit or not other.is_alive():
			continue
		if other.get_team() == unit.get_team():
			continue
		var d := unit.cell_distance_to(other)
		var oid := other.get_id()
		if d < best_any_dist or (d == best_any_dist and oid < best_any_id):
			best_any_dist = d
			best_any_id = oid
			best_any = other
		if float(d) <= sight and (d < best_in_sight_dist or (d == best_in_sight_dist and oid < best_in_sight_id)):
			best_in_sight_dist = d
			best_in_sight_id = oid
			best_in_sight = other
	return best_in_sight if best_in_sight != null else best_any


## 八向贪心：优先减小切比雪夫；同距再减曼哈顿；目标格被占则改道或返回 ZERO（短等）。
static func pick_step(unit: RtUnit, target: RtUnit, is_cell_free: Callable) -> Vector2i:
	if unit == null or target == null:
		return Vector2i.ZERO
	var cur := unit.cell
	var goal := target.cell
	var cur_d := RtUnit.chebyshev(cur, goal)
	var cur_man := absi(cur.x - goal.x) + absi(cur.y - goal.y)
	var best_dir := Vector2i.ZERO
	var best_d := cur_d
	var best_man := cur_man
	var found := false
	for dir in DIR8:
		var nxt: Vector2i = cur + dir
		if not bool(is_cell_free.call(nxt)):
			continue
		var d := RtUnit.chebyshev(nxt, goal)
		var man := absi(nxt.x - goal.x) + absi(nxt.y - goal.y)
		if not found or d < best_d or (d == best_d and man < best_man):
			found = true
			best_d = d
			best_man = man
			best_dir = dir
	if not found:
		return Vector2i.ZERO
	## 不恶化格距；同距时须更靠近（曼哈顿下降）才挪步
	if best_d > cur_d:
		return Vector2i.ZERO
	if best_d == cur_d and best_man >= cur_man:
		return Vector2i.ZERO
	return best_dir


static func _drop_target(unit: RtUnit) -> void:
	unit.target = null
	unit.attack_timer = 0.0
	if unit.state == RtUnit.State.ATTACKING:
		unit.state = RtUnit.State.MOVING
