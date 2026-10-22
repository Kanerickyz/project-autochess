class_name RtProjectile
extends RefCounted
## 观战用投射物包装：朝目标飞、到点或目标已死则结束。
## 伤害/对砍已在出手瞬间由 RealtimeCombatSim 结算；本类不参与攻击判定。

static var _next_id: int = 0

var id: int
var source: RtUnit
var target: RtUnit
var position: Vector2
var speed: float
## 仅供演出/调试只读；逻辑层不在落地时再扣血。
var damage: int
var splash_radius: float
var finished: bool = false


func _init(
	p_source: RtUnit,
	p_target: RtUnit,
	p_position: Vector2,
	p_speed: float,
	p_damage: int,
	p_splash_radius: float,
) -> void:
	id = _next_id
	_next_id += 1
	source = p_source
	target = p_target
	position = p_position
	speed = p_speed
	damage = p_damage
	splash_radius = p_splash_radius


func is_player_owned() -> bool:
	return source != null and source.is_player()


## 推进一步；返回 true 表示本步视觉到达目标（非伤害结算信号）。
func advance(dt: float) -> bool:
	if finished:
		return false
	if target == null or not is_instance_valid(target) or not target.is_alive():
		finished = true
		return false
	var aim: Vector2 = target.position
	var to_target := aim - position
	var dist := to_target.length()
	var travel := speed * dt
	if dist <= travel or dist <= target.get_radius():
		position = aim
		finished = true
		return true
	position += to_target / dist * travel
	return false
