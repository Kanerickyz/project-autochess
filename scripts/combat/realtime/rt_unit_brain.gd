class_name RtUnitBrain
extends RefCounted
## 即时并行决策：索敌 → 绕障连续滑移 → 进距按攻击间隔出手。
## 攻距 / 索敌用碰撞圆边缘欧氏距；移动意图不推动其他单位（圆裁剪 + 侧向转向）。

## 进入攻击判定的距离容差（格）
const REACH_EPSILON := 0.02
## 已锁定目标时允许超出 reach 的滞回（格）
const REACH_HYSTERESIS := 0.25
const TIME_EPSILON := 0.000001
## 与他圆保持的最小间隙（格），避免贴边抖动。
const BODY_CLEARANCE := 0.03
## Boss 低血阈值：≤ 此比例时优先瞬移拉开威胁
const BOSS_LOW_HP_RATIO := 0.4
## Boss 瞬移默认冷却（秒）；召唤冷却取 UnitData.summon_cooldown_actions（按秒）。
const BOSS_TELEPORT_COOLDOWN_SECONDS := 2.0


## 八方向：兼容旧测例 / Boss 足迹扫描
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
	## 本步连续位移意图（格）；ZERO = 不移动。
	var move: Vector2 = Vector2.ZERO
	## 兼容旧格步偏移；并行主路径保持 ZERO。
	var step: Vector2i = Vector2i.ZERO
	var fire: bool = false
	## Boss 首领：本拍选择召唤（与瞬移/出手互斥）
	var summon: bool = false
	## Boss 首领：瞬移到足迹锚点（-1,-1 = 不瞬移）
	var teleport_cell: Vector2i = Vector2i(-1, -1)
	## 兼容旧一动语义（并行下恒 false）
	var turn_done: bool = false


## 兼容旧测例：一动步数预算。
static func turn_step_budget(unit_or_stats: Variant) -> int:
	if unit_or_stats is RtUnit:
		var rt := unit_or_stats as RtUnit
		if rt == null or rt.unit == null:
			return 0
		return rt.unit.get_steps_per_turn()
	if unit_or_stats is UnitInstance:
		var inst := unit_or_stats as UnitInstance
		if inst == null:
			return 0
		return inst.get_steps_per_turn()
	var stats := unit_or_stats as UnitStats
	if stats == null:
		return 0
	return maxi(0, stats.steps_per_turn)


## 主路径并行决策（普通单位 + Boss 冷却态机）。
static func decide(
	unit: RtUnit,
	units: Array,
	dt: float,
	can_summon: Callable = Callable(),
	can_boss_teleport: Callable = Callable(),
) -> Decision:
	if unit != null and unit.is_boss_leader():
		return decide_boss_leader(
			unit, units, dt, can_summon, can_boss_teleport
		)
	var decision := Decision.new()
	if not unit.is_alive():
		return decision
	## 部署剩余由 sim._tick_all_deploying 推进；此处仅等待。
	if unit.state == RtUnit.State.DEPLOYING:
		return decision

	_refresh_target(unit, units)
	if unit.target == null:
		unit.state = RtUnit.State.MOVING
		return decision

	var stats := unit.get_stats()
	var edge := unit.edge_distance_to(unit.target)
	if unit.state == RtUnit.State.ATTACKING or edge <= stats.attack_reach + REACH_EPSILON:
		if unit.state != RtUnit.State.ATTACKING:
			unit.state = RtUnit.State.ATTACKING
			## 保留入场 interval 门闩；测试可用超大 attack_windup 抬高首刀等待。
			unit.attack_timer = maxf(unit.attack_timer, maxf(0.0, stats.attack_windup))
		unit.attack_timer -= dt
		if unit.attack_timer <= TIME_EPSILON:
			decision.fire = true
			unit.attack_timer += maxf(0.05, stats.attack_interval)
		## 进距后允许微移贴脸，但不主动冲穿。
		return decision

	unit.state = RtUnit.State.MOVING
	var speed := unit.get_move_speed()
	if speed <= 0.0:
		return decision
	var to_target := unit.target.position - unit.position
	var dist := to_target.length()
	if dist <= 0.0:
		return decision
	var travel := minf(speed * dt, maxf(0.0, edge - stats.attack_reach))
	decision.move = steer_move(unit, to_target / dist * travel, units)
	return decision


## Boss：冷却到了才招/瞬移/打；重动作互斥；否则连续滑移靠近。
static func decide_boss_leader(
	unit: RtUnit,
	units: Array,
	dt: float,
	can_summon: Callable,
	can_boss_teleport: Callable,
) -> Decision:
	var decision := Decision.new()
	if not unit.is_alive():
		return decision
	## 部署剩余由 sim 推进。
	if unit.state == RtUnit.State.DEPLOYING:
		return decision

	_refresh_target(unit, units)
	var low_hp := is_boss_low_hp(unit)
	var teleport_ready := unit.boss_teleport_cooldown_left <= TIME_EPSILON
	if (
		low_hp
		and teleport_ready
		and is_boss_threatened(unit, units)
	):
		var flee := pick_boss_flee_teleport(unit, units, can_boss_teleport)
		if flee != Vector2i(-1, -1):
			unit.state = RtUnit.State.MOVING
			decision.teleport_cell = flee
			return decision

	var stats := unit.get_stats()
	if unit.target != null:
		var edge := unit.edge_distance_to(unit.target)
		if unit.state == RtUnit.State.ATTACKING or edge <= stats.attack_reach + REACH_EPSILON:
			if unit.state != RtUnit.State.ATTACKING:
				unit.state = RtUnit.State.ATTACKING
				unit.attack_timer = maxf(unit.attack_timer, maxf(0.0, stats.attack_windup))
			unit.attack_timer -= dt
			if unit.attack_timer <= TIME_EPSILON:
				decision.fire = true
				unit.attack_timer += maxf(0.05, stats.attack_interval)
			return decision

	if can_summon.is_valid() and bool(can_summon.call(unit)):
		unit.state = RtUnit.State.SUMMONING
		decision.summon = true
		return decision

	if teleport_ready:
		unit.state = RtUnit.State.MOVING
		if low_hp:
			decision.teleport_cell = pick_boss_flee_teleport(unit, units, can_boss_teleport)
		elif unit.target != null:
			decision.teleport_cell = pick_boss_teleport(unit, unit.target, can_boss_teleport)
		if decision.teleport_cell != Vector2i(-1, -1):
			return decision

	## 冷却未到：连续滑移靠近（Boss 也可走）；同样绕障不顶人。
	unit.state = RtUnit.State.MOVING
	if unit.target == null:
		return decision
	var speed := unit.get_move_speed()
	if speed <= 0.0:
		return decision
	var to_target := unit.target.position - unit.position
	var dist := to_target.length()
	if dist <= 0.0:
		return decision
	var edge2 := unit.edge_distance_to(unit.target)
	var travel := minf(speed * dt, maxf(0.0, edge2 - stats.attack_reach))
	decision.move = steer_move(unit, to_target / dist * travel, units)
	return decision


## 朝目标位移：圆裁剪防穿体；受阻则沿障碍切线 / 侧向绕行（不推动他单位）。
static func steer_move(unit: RtUnit, desired: Vector2, units: Array) -> Vector2:
	if unit == null or desired.length_squared() < 0.00000001:
		return Vector2.ZERO
	var travel := desired.length()
	var goal_dir := desired / travel
	var candidates: Array[Vector2] = []
	candidates.append(desired)
	var perp := Vector2(-goal_dir.y, goal_dir.x)
	var side_options: Array[float] = [1.0, -1.0]
	var weight_options: Array[float] = [0.45, 0.9, 1.4, 2.2]
	for side in side_options:
		## 纯侧向：正前方堵死时先横移让开。
		candidates.append(perp * side * travel)
		for weight in weight_options:
			var blended: Vector2 = goal_dir + perp * side * weight
			if blended.length_squared() < 0.00000001:
				continue
			candidates.append(blended.normalized() * travel)
	## 对近距挡路圆取切线方向。
	for item in units:
		var other := item as RtUnit
		if other == null or other == unit or not other.is_alive():
			continue
		if unit.is_deploying() and other.is_deploying():
			continue
		var clear_r := unit.get_radius() + other.get_radius() + BODY_CLEARANCE
		var to_o := other.position - unit.position
		var dist := to_o.length()
		if dist < 0.0001 or dist > clear_r + travel * 2.5:
			continue
		for tangent in _circle_tangents(to_o, clear_r):
			candidates.append(tangent * travel)

	var best := clip_move(unit, desired, units)
	var best_score := _steer_score(unit, best, goal_dir)
	for raw in candidates:
		var cand := clip_move(unit, raw, units)
		if cand.length_squared() < 0.00000001:
			continue
		var score := _steer_score(unit, cand, goal_dir)
		if score > best_score + 0.00001:
			best_score = score
			best = cand
	return best


## 将位移裁到不与其他存活单位碰撞圆重叠（可沿切向滑过）。
static func clip_move(unit: RtUnit, desired: Vector2, units: Array) -> Vector2:
	if unit == null or desired.length_squared() < 0.00000001:
		return Vector2.ZERO
	var move := desired
	var origin := unit.position
	var radius := unit.get_radius()
	for item in units:
		var other := item as RtUnit
		if other == null or other == unit or not other.is_alive():
			continue
		if unit.is_deploying() and other.is_deploying():
			continue
		move = _clip_against_circle(origin, radius, move, other.position, other.get_radius())
		if move.length_squared() < 0.00000001:
			return Vector2.ZERO
	return move


## 从原点看向圆心 to_center、避让半径 clear_r 的两条单位切线方向。
static func _circle_tangents(to_center: Vector2, clear_r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var dist := to_center.length()
	if dist <= clear_r + 0.0001:
		## 已贴上：左右切向即垂直方向。
		var n := to_center.normalized() if dist > 0.0001 else Vector2.RIGHT
		out.append(Vector2(-n.y, n.x))
		out.append(Vector2(n.y, -n.x))
		return out
	var sin_a := clampf(clear_r / dist, 0.0, 0.999)
	var cos_a := sqrt(1.0 - sin_a * sin_a)
	var basis := to_center / dist
	var left := Vector2(
		basis.x * cos_a - basis.y * sin_a,
		basis.x * sin_a + basis.y * cos_a,
	)
	var right := Vector2(
		basis.x * cos_a + basis.y * sin_a,
		-basis.x * sin_a + basis.y * cos_a,
	)
	out.append(left.normalized())
	out.append(right.normalized())
	return out


static func _steer_score(unit: RtUnit, move: Vector2, goal_dir: Vector2) -> float:
	if unit == null:
		return 0.0
	var progress := move.length()
	var forward := 0.0
	if goal_dir.length_squared() > 0.0001 and progress > 0.0001:
		forward = move.normalized().dot(goal_dir)
	var target := unit.target
	if target == null or not target.is_alive():
		return progress + forward * 0.2
	var next := unit.position + move
	var edge_now := unit.edge_distance_to(target)
	var edge_next := next.distance_to(target.position) - unit.get_radius() - target.get_radius()
	## 缩短边缘距为主；前进分量与位移量为辅（便于先横移再绕）。
	return (edge_now - edge_next) * 6.0 + progress * 0.55 + forward * progress * 0.35


static func _clip_against_circle(
	origin: Vector2,
	radius_self: float,
	move: Vector2,
	center: Vector2,
	radius_other: float,
) -> Vector2:
	var min_dist := radius_self + radius_other + BODY_CLEARANCE
	var to_center := center - origin
	var sep_sq := to_center.length_squared()
	var min_sq := min_dist * min_dist
	## 已重叠：去掉朝向对方的分量，只允许切向 / 离开。
	if sep_sq < min_sq - 0.0000001:
		var normal := to_center.normalized() if sep_sq > 0.00000001 else Vector2.RIGHT
		var toward := move.dot(normal)
		if toward > 0.0:
			return move - normal * toward
		return move
	var aa := move.length_squared()
	if aa < 0.00000001:
		return Vector2.ZERO
	## |origin + t*move - center| = min_dist → 二次方程。
	var w := origin - center
	var bb := 2.0 * w.dot(move)
	var cc := w.length_squared() - min_sq
	var disc := bb * bb - 4.0 * aa * cc
	if disc < 0.0:
		return move
	var root := sqrt(disc)
	var inv := 1.0 / (2.0 * aa)
	var t1 := (-bb - root) * inv
	var t2 := (-bb + root) * inv
	var t_hit := 1.0
	if t1 > 0.0001 and t1 < t_hit:
		t_hit = t1
	if t2 > 0.0001 and t2 < t_hit:
		t_hit = t2
	if t_hit >= 1.0:
		return move
	return move * maxf(0.0, t_hit - 0.002)


## 兼容旧一动 API：转调并行 decide（忽略 steps / has_attacked）。
static func decide_turn(
	unit: RtUnit,
	units: Array,
	dt: float,
	_is_cell_free: Callable,
	_steps_left: int,
	_has_attacked: bool,
	can_summon: Callable = Callable(),
	can_boss_teleport: Callable = Callable(),
) -> Decision:
	return decide(unit, units, dt, can_summon, can_boss_teleport)


static func decide_boss_leader_turn(
	unit: RtUnit,
	units: Array,
	dt: float,
	_steps_left: int,
	_has_attacked: bool,
	can_summon: Callable,
	can_boss_teleport: Callable,
) -> Decision:
	return decide_boss_leader(unit, units, dt, can_summon, can_boss_teleport)


static func is_boss_low_hp(unit: RtUnit) -> bool:
	if unit == null or unit.unit == null:
		return false
	var max_hp := unit.unit.get_effective_max_hp()
	if max_hp <= 0:
		return false
	return float(unit.unit.current_hp) / float(max_hp) <= BOSS_LOW_HP_RATIO


## 任意存活敌对单位已进入其攻距（欧氏边缘）。
static func is_boss_threatened(unit: RtUnit, units: Array) -> bool:
	if unit == null or not unit.is_alive():
		return false
	for item in units:
		var other := item as RtUnit
		if other == null or not other.is_alive() or other.get_team() == unit.get_team():
			continue
		var reach := other.get_stats().attack_reach
		var edge := unit.edge_distance_to(other)
		if edge <= reach + REACH_EPSILON:
			return true
	return false


## Boss 瞬移：在任意空足迹锚点中选缩短最近格距者（由 can_boss_teleport(origin) 判定占格）。
static func pick_boss_teleport(unit: RtUnit, target: RtUnit, can_boss_teleport: Callable) -> Vector2i:
	if unit == null or target == null or not can_boss_teleport.is_valid():
		return Vector2i(-1, -1)
	var cur_d := unit.cell_distance_to(target)
	var best_origin := Vector2i(-1, -1)
	var best_d := cur_d
	var best_man := _footprint_manhattan_at(unit, target, unit.cell)
	var arena := _boss_teleport_scan_bounds(unit)
	for y in range(arena.position.y, arena.end.y):
		for x in range(arena.position.x, arena.end.x):
			var origin := Vector2i(x, y)
			if origin == unit.cell:
				continue
			if not bool(can_boss_teleport.call(unit, origin)):
				continue
			var d := _footprint_chebyshev_at(unit, target, origin)
			var man := _footprint_manhattan_at(unit, target, origin)
			if d < best_d or (d == best_d and man < best_man):
				best_d = d
				best_man = man
				best_origin = origin
	if best_origin == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	if best_d == cur_d and best_man >= _footprint_manhattan_at(unit, target, unit.cell):
		return Vector2i(-1, -1)
	return best_origin


static func pick_boss_flee_teleport(
	unit: RtUnit,
	units: Array,
	can_boss_teleport: Callable,
) -> Vector2i:
	if unit == null or not can_boss_teleport.is_valid():
		return Vector2i(-1, -1)
	var threats: Array[RtUnit] = []
	for item in units:
		var other := item as RtUnit
		if other == null or not other.is_alive() or other.get_team() == unit.get_team():
			continue
		threats.append(other)
	if threats.is_empty():
		return Vector2i(-1, -1)
	var cur_min := _min_threat_chebyshev_at(unit, threats, unit.cell)
	var best_origin := Vector2i(-1, -1)
	var best_min := cur_min
	var best_sum := _sum_threat_chebyshev_at(unit, threats, unit.cell)
	var arena := _boss_teleport_scan_bounds(unit)
	for y in range(arena.position.y, arena.end.y):
		for x in range(arena.position.x, arena.end.x):
			var origin := Vector2i(x, y)
			if origin == unit.cell:
				continue
			if not bool(can_boss_teleport.call(unit, origin)):
				continue
			var d_min := _min_threat_chebyshev_at(unit, threats, origin)
			var d_sum := _sum_threat_chebyshev_at(unit, threats, origin)
			if d_min > best_min or (d_min == best_min and d_sum > best_sum):
				best_min = d_min
				best_sum = d_sum
				best_origin = origin
	if best_origin == Vector2i(-1, -1) or best_min <= cur_min:
		return Vector2i(-1, -1)
	return best_origin


static func _min_threat_chebyshev_at(unit: RtUnit, threats: Array[RtUnit], origin: Vector2i) -> int:
	var best := 999999
	for t in threats:
		best = mini(best, _footprint_chebyshev_at(unit, t, origin))
	return best


static func _sum_threat_chebyshev_at(unit: RtUnit, threats: Array[RtUnit], origin: Vector2i) -> int:
	var total := 0
	for t in threats:
		total += _footprint_chebyshev_at(unit, t, origin)
	return total


static func _boss_teleport_scan_bounds(unit: RtUnit) -> Rect2i:
	var w := maxi(1, unit.arena_size.x)
	var h := maxi(1, unit.arena_size.y)
	var fp := unit.get_footprint_size()
	return Rect2i(0, 0, maxi(1, w - fp.x + 1), maxi(1, h - fp.y + 1))


static func _footprint_chebyshev_at(unit: RtUnit, target: RtUnit, origin: Vector2i) -> int:
	var mine := unit.get_footprint_cells(origin)
	var theirs := target.get_footprint_cells(target.cell)
	var best := 999999
	for a in mine:
		for b in theirs:
			best = mini(best, RtUnit.chebyshev(a, b))
	return best


static func _footprint_manhattan_at(unit: RtUnit, target: RtUnit, origin: Vector2i) -> int:
	var mine := unit.get_footprint_cells(origin)
	var theirs := target.get_footprint_cells(target.cell)
	var best := 999999
	for a in mine:
		for b in theirs:
			best = mini(best, absi(a.x - b.x) + absi(a.y - b.y))
	return best


static func _footprint_manhattan(unit: RtUnit, target: RtUnit, dir: Vector2i) -> int:
	var origin: Vector2i = unit.cell + dir
	var mine := unit.get_footprint_cells(origin)
	var theirs := target.get_footprint_cells(target.cell)
	var best := 999999
	for a in mine:
		for b in theirs:
			best = mini(best, absi(a.x - b.x) + absi(a.y - b.y))
	return best


static func _refresh_target(unit: RtUnit, units: Array) -> void:
	var stats := unit.get_stats()
	if unit.target != null and not unit.target.is_alive():
		_drop_target(unit)
	if unit.state == RtUnit.State.ATTACKING and unit.target != null:
		var lock_edge := unit.edge_distance_to(unit.target)
		if lock_edge > stats.attack_reach + REACH_HYSTERESIS:
			_drop_target(unit)
	if unit.state != RtUnit.State.ATTACKING:
		unit.target = acquire_target(unit, units)


## 兼容旧名：欧氏 reach 不再抬到邻格。
static func grid_reach(reach: float) -> float:
	return maxf(0.0, reach)


## 优先本列（同 cell.x）前方敌人，避免全体锁左侧先生成单位；无同列再全场最近。
## sight_range 内优先；没有则全场。平局：列差更小 → 边缘距更近 → 较小 instance_id。
static func acquire_target(unit: RtUnit, units: Array) -> RtUnit:
	var sight := unit.get_stats().sight_range
	var my_col := unit.cell.x
	var lane := _pick_acquire_candidate(unit, units, sight, true, my_col)
	if lane != null:
		return lane
	return _pick_acquire_candidate(unit, units, sight, false, my_col)


static func _pick_acquire_candidate(
	unit: RtUnit,
	units: Array,
	sight: float,
	same_column_only: bool,
	my_col: int,
) -> RtUnit:
	var best_in_sight: RtUnit = null
	var best_in_sight_dist := INF
	var best_in_sight_col := 0x7fffffff
	var best_in_sight_id := 0x7fffffff
	var best_any: RtUnit = null
	var best_any_dist := INF
	var best_any_col := 0x7fffffff
	var best_any_id := 0x7fffffff
	for item in units:
		var other := item as RtUnit
		if other == null or other == unit or not other.is_alive():
			continue
		if other.get_team() == unit.get_team():
			continue
		var col_delta := absi(other.cell.x - my_col)
		if same_column_only and col_delta != 0:
			continue
		var edge := unit.edge_distance_to(other)
		var oid := other.get_id()
		if _is_better_acquire(edge, col_delta, oid, best_any_dist, best_any_col, best_any_id):
			best_any_dist = edge
			best_any_col = col_delta
			best_any_id = oid
			best_any = other
		if edge <= sight and _is_better_acquire(
			edge, col_delta, oid, best_in_sight_dist, best_in_sight_col, best_in_sight_id
		):
			best_in_sight_dist = edge
			best_in_sight_col = col_delta
			best_in_sight_id = oid
			best_in_sight = other
	return best_in_sight if best_in_sight != null else best_any


static func _is_better_acquire(
	edge: float,
	col_delta: int,
	oid: int,
	best_edge: float,
	best_col: int,
	best_id: int,
) -> bool:
	if col_delta < best_col:
		return true
	if col_delta > best_col:
		return false
	if edge < best_edge:
		return true
	if not is_equal_approx(edge, best_edge):
		return false
	return oid < best_id


## 兼容旧格步贪心（测例 / 工具）；并行主路径不用。
static func pick_step(unit: RtUnit, target: RtUnit, is_cell_free: Callable) -> Vector2i:
	if unit == null or target == null:
		return Vector2i.ZERO
	var cur := unit.cell
	var goal := _nearest_footprint_cell(cur, target)
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
		var nxt_goal := _nearest_footprint_cell(nxt, target)
		var d := RtUnit.chebyshev(nxt, nxt_goal)
		var man := absi(nxt.x - nxt_goal.x) + absi(nxt.y - nxt_goal.y)
		if not found or d < best_d or (d == best_d and man < best_man):
			found = true
			best_d = d
			best_man = man
			best_dir = dir
	if not found:
		return Vector2i.ZERO
	if best_d > cur_d:
		return Vector2i.ZERO
	if best_d == cur_d and best_man >= cur_man:
		return Vector2i.ZERO
	return best_dir


static func _nearest_footprint_cell(from: Vector2i, target: RtUnit) -> Vector2i:
	if target == null:
		return from
	var cells := target.get_footprint_cells(target.cell)
	if cells.is_empty():
		return target.cell
	var best := cells[0]
	var best_d := RtUnit.chebyshev(from, best)
	for c in cells:
		var d := RtUnit.chebyshev(from, c)
		if d < best_d:
			best_d = d
			best = c
	return best


static func _drop_target(unit: RtUnit) -> void:
	unit.target = null
	## 保留 attack_timer：丢目标不刷新出手门闩。
	if unit.state == RtUnit.State.ATTACKING:
		unit.state = RtUnit.State.MOVING
