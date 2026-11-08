class_name RtUnitBrain
extends RefCounted
## 八方向格步决策：索敌/出手用切比雪夫格距；移动选邻格；不修改其他单位。
## 主路径为一动决策（decide_turn）；decide 保留给旧并行测例兼容。

## 进入攻击判定的距离容差（格）
const REACH_EPSILON := 0.02
## 已锁定目标时允许超出 reach 的滞回（格）
const REACH_HYSTERESIS := 0.25
const TIME_EPSILON := 0.000001
## Boss 低血阈值：≤ 此比例时优先瞬移拉开威胁
const BOSS_LOW_HP_RATIO := 0.4


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
	## Boss 首领：本动选择召唤（与出手/移动/瞬移互斥）
	var summon: bool = false
	## Boss 首领：瞬移到足迹锚点（-1,-1 = 不瞬移）
	var teleport_cell: Vector2i = Vector2i(-1, -1)
	## 一动决策：true = 本动已无事可做（交给 sim 结束当前行动者）
	var turn_done: bool = false


## 一动最多走几格：含临时 steps_per_turn 修正（0 = 本动不挪步）。
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


## 回合制一动：选目标 → 预算内靠近 → 能打则出手一次（不按 attack_interval 连打）。
## Boss 首领走三选一策略机（出手 / 召唤 / 瞬移），不套普通「靠近并出手」。
## can_summon / can_boss_teleport 由 sim 注入；空 Callable 时首领跳过对应分支。
static func decide_turn(
	unit: RtUnit,
	units: Array,
	dt: float,
	is_cell_free: Callable,
	steps_left: int,
	has_attacked: bool,
	can_summon: Callable = Callable(),
	can_boss_teleport: Callable = Callable(),
) -> Decision:
	if unit != null and unit.is_boss_leader():
		return decide_boss_leader_turn(
			unit, units, dt, steps_left, has_attacked, can_summon, can_boss_teleport
		)
	var decision := Decision.new()
	if not unit.is_alive():
		decision.turn_done = true
		return decision
	if unit.state == RtUnit.State.DEPLOYING:
		## 部署由 sim 用全局时钟推进；轮到仍在部署则让出行动权。
		decision.turn_done = true
		return decision
	if has_attacked:
		decision.turn_done = true
		return decision

	_refresh_target(unit, units)
	if unit.target == null:
		unit.state = RtUnit.State.MOVING
		decision.turn_done = true
		return decision

	## 落格顿步：未落稳不判攻、不新开步
	if unit.is_stepping():
		return decision

	var stats := unit.get_stats()
	var dist := float(unit.cell_distance_to(unit.target))
	var reach := grid_reach(stats.attack_reach)
	if unit.state == RtUnit.State.ATTACKING or dist <= reach + REACH_EPSILON:
		if unit.state != RtUnit.State.ATTACKING:
			unit.state = RtUnit.State.ATTACKING
			unit.attack_timer = maxf(0.0, stats.attack_windup)
		unit.attack_timer -= dt
		if unit.attack_timer <= TIME_EPSILON:
			decision.fire = true
			## 一动最多出手一次；不 refill interval
		return decision

	unit.state = RtUnit.State.MOVING
	if steps_left <= 0:
		decision.turn_done = true
		return decision
	## 规则锁死不可移动时本动结束（Boss 召唤体会强制 cannot_move=false）
	if unit.unit != null and unit.unit.cannot_move:
		decision.turn_done = true
		return decision
	decision.step = pick_step(unit, unit.target, is_cell_free)
	if decision.step == Vector2i.ZERO:
		## 被挡或无法靠近：本动结束（不空挥）
		decision.turn_done = true
	return decision


## 召唤统领一动三态互斥：移动(瞬移) / 攻击 / 召唤。
## 低血且受威胁时优先瞬移拉开；否则已在攻距→出手；可召则召；否则瞬移靠近（低血则拉远）。
static func decide_boss_leader_turn(
	unit: RtUnit,
	units: Array,
	dt: float,
	steps_left: int,
	has_attacked: bool,
	can_summon: Callable,
	can_boss_teleport: Callable,
) -> Decision:
	var decision := Decision.new()
	if not unit.is_alive():
		decision.turn_done = true
		return decision
	if unit.state == RtUnit.State.DEPLOYING:
		decision.turn_done = true
		return decision
	if has_attacked:
		decision.turn_done = true
		return decision
	## 本动已瞬移过：不再出手/再召（三选一互斥）
	var budget := turn_step_budget(unit)
	if budget > 0 and steps_left < budget:
		decision.turn_done = true
		return decision
	if unit.is_stepping():
		return decision

	_refresh_target(unit, units)
	var low_hp := is_boss_low_hp(unit)
	if low_hp and steps_left > 0 and is_boss_threatened(unit, units):
		var flee := pick_boss_flee_teleport(unit, units, can_boss_teleport)
		if flee != Vector2i(-1, -1):
			unit.state = RtUnit.State.MOVING
			decision.teleport_cell = flee
			return decision

	var stats := unit.get_stats()
	if unit.target != null:
		var dist := float(unit.cell_distance_to(unit.target))
		var reach := grid_reach(stats.attack_reach)
		if unit.state == RtUnit.State.ATTACKING or dist <= reach + REACH_EPSILON:
			if unit.state != RtUnit.State.ATTACKING:
				unit.state = RtUnit.State.ATTACKING
				unit.attack_timer = maxf(0.0, stats.attack_windup)
			unit.attack_timer -= dt
			if unit.attack_timer <= TIME_EPSILON:
				decision.fire = true
			return decision

	if can_summon.is_valid() and bool(can_summon.call(unit)):
		unit.state = RtUnit.State.SUMMONING
		decision.summon = true
		return decision

	unit.state = RtUnit.State.MOVING
	if steps_left <= 0:
		decision.turn_done = true
		return decision
	if low_hp:
		decision.teleport_cell = pick_boss_flee_teleport(unit, units, can_boss_teleport)
	elif unit.target != null:
		decision.teleport_cell = pick_boss_teleport(unit, unit.target, can_boss_teleport)
	if decision.teleport_cell == Vector2i(-1, -1):
		decision.turn_done = true
	return decision


static func is_boss_low_hp(unit: RtUnit) -> bool:
	if unit == null or unit.unit == null:
		return false
	var max_hp := unit.unit.get_effective_max_hp()
	if max_hp <= 0:
		return false
	return float(unit.unit.current_hp) / float(max_hp) <= BOSS_LOW_HP_RATIO


## 任意存活敌对单位已进入其攻距，或切比雪夫格距 ≤ 其 reach。
static func is_boss_threatened(unit: RtUnit, units: Array) -> bool:
	if unit == null or not unit.is_alive():
		return false
	for item in units:
		var other := item as RtUnit
		if other == null or not other.is_alive() or other.get_team() == unit.get_team():
			continue
		var reach := grid_reach(other.get_stats().attack_reach)
		var dist := float(unit.cell_distance_to(other))
		if dist <= reach + REACH_EPSILON:
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
	var found := false
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
			if not found or d < best_d or (d == best_d and man < best_man):
				found = true
				best_d = d
				best_man = man
				best_origin = origin
	if not found:
		return Vector2i(-1, -1)
	if best_d > cur_d:
		return Vector2i(-1, -1)
	if best_d == cur_d and best_man >= _footprint_manhattan_at(unit, target, unit.cell):
		return Vector2i(-1, -1)
	return best_origin


## 低血躲避：选使「距最近敌对」最大化的空足迹锚点；须严格优于当前位置。
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
	var found := false
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
			if (
				not found
				or d_min > best_min
				or (d_min == best_min and d_sum > best_sum)
			):
				found = true
				best_min = d_min
				best_sum = d_sum
				best_origin = origin
	if not found or best_min <= cur_min:
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



## 扫描足迹锚点的可行矩形（调用方需保证 unit 有有效 arena；无则退回宽松范围）。
static func _boss_teleport_scan_bounds(unit: RtUnit) -> Rect2i:
	var fw := 1
	var fh := 1
	if unit != null and unit.unit != null and unit.unit.unit_data != null:
		fw = maxi(1, unit.unit.unit_data.footprint_w)
		fh = maxi(1, unit.unit.unit_data.footprint_h)
	## 宽松扫描窗；合法锚点由 sim 的 can_boss_teleport 过滤。
	return Rect2i(0, 0, maxi(1, 24 - fw + 1), maxi(1, 24 - fh + 1))


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


## 旧并行推进路径（测例/兼容）；新主路径用 decide_turn。
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
	_refresh_target(unit, units)
	if unit.target == null:
		unit.state = RtUnit.State.MOVING
		return decision

	## 落格顿步：未落稳不判攻、不新开步；攻击计时仅落稳后推进
	if unit.is_stepping():
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
		## 落稳后站立攻击；不在出手帧同时开步
		return decision

	unit.state = RtUnit.State.MOVING
	if turn_step_budget(unit) <= 0:
		return decision
	decision.step = pick_step(unit, unit.target, is_cell_free)
	return decision


static func _refresh_target(unit: RtUnit, units: Array) -> void:
	var stats := unit.get_stats()
	if unit.target != null and not unit.target.is_alive():
		_drop_target(unit)
	if unit.state == RtUnit.State.ATTACKING and unit.target != null:
		var lock_dist := float(unit.cell_distance_to(unit.target))
		if lock_dist > grid_reach(stats.attack_reach) + REACH_HYSTERESIS:
			_drop_target(unit)
	if unit.state != RtUnit.State.ATTACKING:
		unit.target = acquire_target(unit, units)


## 旧欧氏近战 reach 常 < 1；一格一体下邻格切比雪夫为 1，正 reach 至少按邻格处理。
static func grid_reach(reach: float) -> float:
	if reach <= 0.0:
		return 0.0
	if reach < 1.0:
		return 1.0
	return reach


## sight_range 内格距最近敌人；没有则全场最近。
## 平局：先比曼哈顿（避免同切比雪夫时全体锁左侧先生成单位），再比 instance_id。
static func acquire_target(unit: RtUnit, units: Array) -> RtUnit:
	var sight := unit.get_stats().sight_range
	var best_in_sight: RtUnit = null
	var best_in_sight_dist := 999999
	var best_in_sight_man := 999999
	var best_in_sight_id := 0x7fffffff
	var best_any: RtUnit = null
	var best_any_dist := 999999
	var best_any_man := 999999
	var best_any_id := 0x7fffffff
	for item in units:
		var other := item as RtUnit
		if other == null or other == unit or not other.is_alive():
			continue
		if other.get_team() == unit.get_team():
			continue
		var d := unit.cell_distance_to(other)
		var man := _footprint_manhattan(unit, other, Vector2i.ZERO)
		var oid := other.get_id()
		if _is_better_target(d, man, oid, best_any_dist, best_any_man, best_any_id):
			best_any_dist = d
			best_any_man = man
			best_any_id = oid
			best_any = other
		if float(d) <= sight and _is_better_target(
			d, man, oid, best_in_sight_dist, best_in_sight_man, best_in_sight_id
		):
			best_in_sight_dist = d
			best_in_sight_man = man
			best_in_sight_id = oid
			best_in_sight = other
	return best_in_sight if best_in_sight != null else best_any


## 切比雪夫更近优先；同距再比曼哈顿；再平局取较小 instance_id。
static func _is_better_target(
	d: int,
	man: int,
	oid: int,
	best_d: int,
	best_man: int,
	best_id: int,
) -> bool:
	if d < best_d:
		return true
	if d > best_d:
		return false
	if man < best_man:
		return true
	if man > best_man:
		return false
	return oid < best_id


## 八向贪心：优先减小切比雪夫；同距再减曼哈顿；目标格被占则改道或返回 ZERO（短等）。
## 目标若为足迹单位，以「当前格 → 目标足迹最近格」为靠近目标（勿只认锚点）。
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
	## 不恶化格距；同距时须更靠近（曼哈顿下降）才挪步
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
	unit.attack_timer = 0.0
	if unit.state == RtUnit.State.ATTACKING:
		unit.state = RtUnit.State.MOVING
