class_name RtUnit
extends RefCounted
## 战斗单位运行态：逻辑格坐标 + 一动内落格顿步表现插值。属性只读自 UnitInstance。

enum State { DEPLOYING, MOVING, ATTACKING, DEAD }

const NEVER := -1000.0

var unit: UnitInstance
## 站立格（规则位置；出手/索敌只认此格）。步进未落稳前仍为 from。
var cell: Vector2i = Vector2i.ZERO
## 步进目标格；未在步进时与 cell 相同。占格预占此格。
var step_dest: Vector2i = Vector2i.ZERO
## 表现位置（格心或格间插值；不参与出手判定）
var position: Vector2 = Vector2.ZERO
var state: State = State.DEPLOYING
var target: RtUnit
var deploy_remaining: float = 0.0
## ATTACKING 时距下一次出手的剩余秒数
var attack_timer: float = 0.0
## 表现层读取：最近一次出手 / 受击 / 落地时刻（sim.elapsed_seconds）
var last_attack_time: float = NEVER
var last_hit_time: float = NEVER
var spawn_time: float = 0.0
## 格步插值：0..1，>=1 表示静止在格心
var step_t: float = 1.0
var step_from: Vector2 = Vector2.ZERO
var step_to: Vector2 = Vector2.ZERO


func _init(p_unit: UnitInstance, p_position: Vector2) -> void:
	unit = p_unit
	cell = Vector2i(floori(p_position.x), floori(p_position.y))
	step_dest = cell
	position = cell_center(cell)
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


## 足迹几何中心（表现坐标用）。
func footprint_center(anchor: Vector2i = Vector2i(-99999, -99999)) -> Vector2:
	var origin := cell if anchor == Vector2i(-99999, -99999) else anchor
	var size := get_footprint_size()
	return Vector2(origin) + Vector2(float(size.x) * 0.5, float(size.y) * 0.5)


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


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## 切比雪夫格距（整数格；足迹单位取双方占格之最近格）。
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


## 兼容旧调用：表现坐标间距（非出手主轴）。
func edge_distance_to(other: RtUnit) -> float:
	return position.distance_to(other.position) - get_radius() - other.get_radius()


func get_cell() -> Vector2i:
	return cell


## 占格查询用：步进中为预占的 dest，否则为站立格。
func get_occupied_cell() -> Vector2i:
	return step_dest if is_stepping() else cell


## 将逻辑格设到 p_cell（足迹锚点）并立刻对齐表现（无插值）。
func snap_to_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	step_dest = p_cell
	position = footprint_center(cell)
	step_t = 1.0
	step_from = position
	step_to = position


## 开始一格步进：站立锚留在 from，直到 step_t>=1 才提交到 dest；表现从足迹中心插值。
func begin_step(from_cell: Vector2i, dest_cell: Vector2i) -> void:
	step_from = footprint_center(from_cell)
	step_to = footprint_center(dest_cell)
	cell = from_cell
	step_dest = dest_cell
	step_t = 0.0
	position = step_from


## 一格步进表现时长（秒）；与一动可走几格解耦，避免再用移速绑演出。
const CELL_STEP_SECONDS := 0.2

## 按固定短时长插值一格；一动步数预算见 UnitStats.steps_per_turn。
## 本帧若足以走完则落稳提交（容忍浮点误差）；不在此衔接下一步。
func advance_step_visual(dt: float) -> void:
	if not is_stepping():
		position = footprint_center(cell)
		return
	var duration := maxf(0.05, CELL_STEP_SECONDS)
	var delta_t := dt / duration
	## 本帧将达/过格心即提交，避免浮点欠一丝导致晚一帧落格
	if step_t + delta_t >= 1.0 - 0.000001:
		_commit_step()
		return
	step_t += delta_t
	position = step_from.lerp(step_to, step_t)


func _commit_step() -> void:
	cell = step_dest
	step_t = 1.0
	position = footprint_center(cell)
	step_from = position
	step_to = position
