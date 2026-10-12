class_name RtProjectile
extends RefCounted
## 追踪投射物：每个固定步朝目标当前位置飞行，到达时结算；目标已死则消失。

static var _next_id: int = 0

var id: int
var source: RtUnit
var target: RtUnit
var position: Vector2
var speed: float
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


## 推进一步；返回 true 表示本步命中（调用方负责结算）。
func advance(dt: float) -> bool:
	if finished:
		return false
	if target == null or not target.is_alive():
		finished = true
		return false
	var to_target := target.position - position
	var dist := to_target.length()
	var travel := speed * dt
	if dist <= travel or dist <= target.get_radius():
		position = target.position
		finished = true
		return true
	position += to_target / dist * travel
	return false
