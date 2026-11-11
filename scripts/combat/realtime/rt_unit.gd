class_name RtUnit
extends RefCounted
## 战斗单位运行态：连续平面坐标为主；cell 由 position 同步给 EffectResolver。
## 属性只读自 UnitInstance。

## Boss 重动作可读：MOVING（含瞬移/滑移）、ATTACKING、SUMMONING。
enum State { DEPLOYING, MOVING, ATTACKING, SUMMONING, DEAD }


const NEVER := -1000.0
## 兼容旧测例名；并行主路径不再用落格顿步。
const CELL_STEP_SECONDS := 0.2

var unit: UnitInstance
## 兼容映射格（floor(position)；效果格网 / 足迹锚点）。
var cell: Vector2i = Vector2i.ZERO
## 步进目标格（兼容旧落格 API；并行主路径保持与 cell 相同）。
var step_dest: Vector2i = Vector2i.ZERO
## 连续平面位置（格为单位；出手/索敌/软碰撞主轴）。
var position: Vector2 = Vector2.ZERO
## 站立表现相对 footprint_center 的偏移（开战落点用；滑移后不再每帧强制）。
var visual_bias: Vector2 = Vector2.ZERO
## 棋盘逻辑尺寸；供按座位行计算半格 bias（add_unit 写入）。
var arena_size: Vector2i = Vector2i(5, 8)
var state: State = State.DEPLOYING
var target: RtUnit
var deploy_remaining: float = 0.0
## ATTACKING 时距下一次出手的剩余秒数
var attack_timer: float = 0.0
## 表现层读取：最近一次出手 / 受击 / 落地时刻（sim.elapsed_seconds）
var last_attack_time: float = NEVER
var last_hit_time: float = NEVER
## 最近一次实际扣血量（护甲减免后）；供震屏幅度等表现使用。
var last_hit_amount: int = 0
var spawn_time: float = 0.0
## 兼容旧字段；并行下中途召唤立刻可动（不再推迟）。
var action_eligible_from_round: int = 0
## 格步插值（兼容 API；并行主路径恒为 1 = 未在步进）。
var step_t: float = 1.0
var step_from: Vector2 = Vector2.ZERO
var step_to: Vector2 = Vector2.ZERO
## 首领召唤冷却剩余秒（UnitData.summon_cooldown_actions 按秒解释）。
var boss_summon_cooldown_left: float = 0.0
## 首领瞬移冷却剩余秒。
var boss_teleport_cooldown_left: float = 0.0
## 本场战斗已成功召唤的衍生小兵次数（见 UnitData.summon_max_total）。
var boss_summons_spawned_total: int = 0
## 自身周期脉冲累计（中毒 tick + ON_ROUND_START；默认每 1.0s）。
var status_pulse_accum: float = 0.0


func _init(p_unit: UnitInstance, p_position: Vector2) -> void:
	unit = p_unit
	cell = Vector2i(floori(p_position.x), floori(p_position.y))
	step_dest = cell
	## 多格足迹单位：表现锚在足迹几何中心，而非锚点格心。
	position = standing_visual_at(cell)
	step_t = 1.0
	deploy_remaining = maxf(0.0, get_stats().deploy_time)
	state = State.DEPLOYING if deploy_remaining > 0.0 else State.MOVING


## 开战前就在场的单位（预布阵 / 开战刷出）不走部署时间。
func skip_deploy() -> void:
	deploy_remaining = 0.0
	if state == State.DEPLOYING:
		state = State.MOVING


func get_id() -> int:
	return unit.instance_id


func get_team() -> UnitInstance.Team:
	return unit.team


func is_player() -> bool:
	return unit.team == UnitInstance.Team.PLAYER


func is_alive() -> bool:
	return state != State.DEAD and unit.is_alive()


func is_deploying() -> bool:
	return state == State.DEPLOYING


func is_stepping() -> bool:
	return step_t < 1.0


func get_stats() -> UnitStats:
	if unit.stats == null:
		unit.stats = UnitStats.new()
	return unit.stats


func get_move_speed() -> float:
	if unit != null and unit.cannot_move:
		return 0.0
	if unit != null:
		return unit.get_move_speed()
	return get_stats().get_move_speed()


func get_radius() -> float:
	return maxf(0.05, get_stats().body_radius)


func get_visual_half_width() -> float:
	return get_stats().get_visual_half_width()


func get_visual_half_height() -> float:
	return get_stats().get_visual_half_height()


func get_mass() -> float:
	return maxf(0.01, get_stats().mass)


func get_display_name() -> String:
	if unit.unit_data != null and not unit.unit_data.display_name.is_empty():
		return unit.unit_data.display_name
	return unit.id


func is_boss_leader() -> bool:
	return unit != null and unit.is_boss_leader()


func get_footprint_size() -> Vector2i:
	if unit == null:
		return Vector2i(1, 1)
	return unit.get_footprint_size()


func has_multi_cell_footprint() -> bool:
	var size := get_footprint_size()
	return size.x > 1 or size.y > 1


## 足迹锚点（左上角）对应的全部占格；步进中按 step_dest 预占。
func get_footprint_cells(anchor: Vector2i = Vector2i(-99999, -99999)) -> Array[Vector2i]:
	var origin := get_occupied_cell() if anchor == Vector2i(-99999, -99999) else anchor
	var size := get_footprint_size()
	var cells: Array[Vector2i] = []
	for dy in size.y:
		for dx in size.x:
			cells.append(origin + Vector2i(dx, dy))
	return cells


## 足迹几何中心（表现坐标用）：2×2 锚 (3,4) → (4.0, 5.0)，落在四格正中。
func footprint_center(anchor: Vector2i = Vector2i(-99999, -99999)) -> Vector2:
	var origin := cell if anchor == Vector2i(-99999, -99999) else anchor
	return footprint_center_for(origin, get_footprint_size())


static func footprint_center_for(origin: Vector2i, size: Vector2i) -> Vector2:
	var w := maxi(1, size.x)
	var h := maxi(1, size.y)
	return Vector2(origin) + Vector2(float(w) * 0.5, float(h) * 0.5)


func get_hp_ratio() -> float:
	return clampf(float(unit.current_hp) / float(unit.get_effective_max_hp()), 0.0, 1.0)


func get_current_hp() -> int:
	return maxi(0, unit.current_hp)


func get_effective_attack() -> int:
	return unit.get_effective_attack()


func get_deploy_ratio() -> float:
	var total := get_stats().deploy_time
	if total <= 0.0:
		return 0.0
	return clampf(deploy_remaining / total, 0.0, 1.0)


static func cell_center(p_cell: Vector2i) -> Vector2:
	return Vector2(p_cell) + Vector2(0.5, 0.5)


## 按逻辑格所属默认座位行计算半格偏移（非座位行 → ZERO）。
func bias_for_cell(p_cell: Vector2i) -> Vector2:
	return PrepareSlotBoard.combat_row_visual_bias(p_cell, arena_size, not is_player())


## 刷新并缓存 visual_bias（落格/开战时调用）。
func refresh_visual_bias(p_cell: Vector2i = Vector2i(-99999, -99999)) -> void:
	var use_cell := cell if p_cell == Vector2i(-99999, -99999) else p_cell
	visual_bias = bias_for_cell(use_cell)


## 站立时的表现坐标：足迹几何中心 + **该格**座位行半格偏移（开战落点用）。
func standing_visual_at(p_cell: Vector2i) -> Vector2:
	return footprint_center(p_cell) + bias_for_cell(p_cell)


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## 切比雪夫格距（兼容；足迹单位取双方占格之最近格）。主路径出手用 edge_distance_to。
func cell_distance_to(other: RtUnit) -> int:
	if other == null:
		return 999999
	var mine := get_footprint_cells(cell)
	var theirs := other.get_footprint_cells(other.cell)
	var best := 999999
	for a in mine:
		for b in theirs:
			best = mini(best, chebyshev(a, b))
	return best


## 碰撞圆边缘间距（主路径攻距 / 索敌）。
func edge_distance_to(other: RtUnit) -> float:
	if other == null:
		return INF
	return position.distance_to(other.position) - get_radius() - other.get_radius()


func get_cell() -> Vector2i:
	return cell


## 占格查询用：步进中为预占的 dest，否则为站立格。
func get_occupied_cell() -> Vector2i:
	return step_dest if is_stepping() else cell


## 由连续 position 同步兼容格（效果格网 / 足迹锚）。
func sync_cell_from_position() -> void:
	var next := Vector2i(floori(position.x), floori(position.y))
	if next == cell:
		step_dest = cell
		step_t = 1.0
		return
	cell = next
	step_dest = cell
	step_t = 1.0


## 将逻辑格设到 p_cell（足迹锚点）并立刻对齐表现（无插值；按该格座位行刷新 bias）。
func snap_to_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	step_dest = p_cell
	refresh_visual_bias(cell)
	position = standing_visual_at(cell)
	step_t = 1.0
	step_from = position
	step_to = position


## 兼容旧落格 API：并行主路径立即落到目标格。
func begin_step(from_cell: Vector2i, dest_cell: Vector2i) -> void:
	cell = from_cell
	step_dest = dest_cell
	step_t = 1.0
	refresh_visual_bias(dest_cell)
	position = standing_visual_at(dest_cell)
	cell = dest_cell
	step_from = position
	step_to = position


## 兼容旧落格插值；并行主路径无事可做。
func advance_step_visual(dt: float) -> void:
	if not is_stepping():
		return
	var duration := maxf(0.05, CELL_STEP_SECONDS)
	var delta_t := dt / duration
	if step_t + delta_t >= 1.0 - 0.000001:
		_commit_step()
		return
	step_t += delta_t
	position = step_from.lerp(step_to, step_t)


func _commit_step() -> void:
	cell = step_dest
	step_t = 1.0
	refresh_visual_bias(cell)
	position = standing_visual_at(cell)
	step_from = position
	step_to = position
