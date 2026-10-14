class_name CommandResource
extends RefCounted
## 遭遇内号令：可自动回复、有上限的出牌资源（见 Documents/Features/PLAYER.md）。

signal changed

const DEFAULT_MAX := 10.0
const DEFAULT_REGEN_SECONDS_PER_POINT := 2.8
const DEFAULT_START := 5.0

var max_command: float = DEFAULT_MAX
var regen_seconds_per_point: float = DEFAULT_REGEN_SECONDS_PER_POINT
var current: float = 0.0


func configure(
	p_max: float = DEFAULT_MAX,
	p_regen_seconds_per_point: float = DEFAULT_REGEN_SECONDS_PER_POINT,
) -> void:
	max_command = maxf(1.0, p_max)
	regen_seconds_per_point = maxf(0.05, p_regen_seconds_per_point)


func reset(start: float = DEFAULT_START) -> void:
	current = clampf(start, 0.0, max_command)
	changed.emit()


func clear() -> void:
	current = 0.0
	changed.emit()


func tick(delta: float) -> void:
	if delta <= 0.0 or current >= max_command:
		return
	var rate := 1.0 / regen_seconds_per_point
	var next := minf(max_command, current + rate * delta)
	if is_equal_approx(next, current):
		return
	current = next
	changed.emit()


func get_current() -> float:
	return current


func get_max() -> float:
	return max_command


func can_afford(cost: int) -> bool:
	return cost <= 0 or current + 0.0001 >= float(cost)


func try_spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	if cost > 0:
		current = maxf(0.0, current - float(cost))
		changed.emit()
	return true


func refund(cost: int) -> void:
	if cost <= 0:
		return
	current = minf(max_command, current + float(cost))
	changed.emit()
