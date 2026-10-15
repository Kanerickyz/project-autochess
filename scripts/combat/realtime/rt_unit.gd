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


## 切比雪夫格距（整数格；用双方站立格）。
func cell_distance_to(other: RtUnit) -> int:
	if other == null:
		return 999999
	return chebyshev(cell, other.cell)


## 兼容旧调用：表现坐标间距（非出手主轴）。
func edge_distance_to(other: RtUnit) -> float:
	return position.distance_to(other.position) - get_radius() - other.get_radius()


func get_cell() -> Vector2i:
	return cell


## 占格查询用：步进中为预占的 dest，否则为站立格。
func get_occupied_cell() -> Vector2i:
	return step_dest if is_stepping() else cell


## 将逻辑格设到 p_cell 并立刻对齐表现（无插值）。
func snap_to_cell(p_cell: Vector2i) -> void:
	cell = p_cell
	step_dest = p_cell
	position = cell_center(cell)
	step_t = 1.0
	step_from = position
	step_to = position


## 开始一格步进：站立格留在 from，直到 step_t>=1 才提交到 dest；表现从 from 插值到 dest 格心。
func begin_step(from_cell: Vector2i, dest_cell: Vector2i) -> void:
	step_from = cell_center(from_cell)
	step_to = cell_center(dest_cell)
	cell = from_cell
	step_dest = dest_cell
	step_t = 0.0
	position = step_from


## As-Is 字段名 move_speed：表现上完成一格步进的速率（格/秒）；正/斜等价。
## 一动步数预算由 RtUnitBrain.turn_step_budget 用同一字段启发式换算。
## 本帧若足以走完则落稳提交（容忍浮点误差）；不在此衔接下一步。
func advance_step_visual(dt: float) -> void:
	if not is_stepping():
		position = cell_center(cell)
		return
	var speed := maxf(0.0, get_stats().move_speed)
	if speed <= 0.0:
		_commit_step()
		return
	var delta_t := dt * speed
	## 本帧将达/过格心即提交，避免 15×(1/30×2) 浮点欠一丝导致晚一帧落格
	if step_t + delta_t >= 1.0 - 0.000001:
		_commit_step()
		return
	step_t += delta_t
	position = step_from.lerp(step_to, step_t)


func _commit_step() -> void:
	cell = step_dest
	step_t = 1.0
	position = cell_center(cell)
	step_from = position
	step_to = position
