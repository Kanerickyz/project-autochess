class_name RtUnit
extends RefCounted
## 实时战斗中的单位运行态：连续坐标（格）、状态机与计时器。属性只读自 UnitInstance。

enum State { DEPLOYING, MOVING, ATTACKING, DEAD }

const NEVER := -1000.0

var unit: UnitInstance
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


func _init(p_unit: UnitInstance, p_position: Vector2) -> void:
	unit = p_unit
	position = p_position
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


## 两个碰撞圆边缘间距（可为负 = 重叠）
func edge_distance_to(other: RtUnit) -> float:
	return position.distance_to(other.position) - get_radius() - other.get_radius()


func get_cell() -> Vector2i:
	return Vector2i(floori(position.x), floori(position.y))
