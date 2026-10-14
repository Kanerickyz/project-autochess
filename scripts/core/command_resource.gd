class_name CommandResource
extends RefCounted
## 【已弃用】号令系统已按 Features/PLAYER.md 删除。保留空壳以免旧脚本解析失败；勿再用于出牌费用。

signal changed

const DEFAULT_MAX := 0.0
const DEFAULT_REGEN_SECONDS_PER_POINT := 1.0
const DEFAULT_START := 0.0

var max_command: float = 0.0
var regen_seconds_per_point: float = 1.0
var current: float = 0.0


func configure(_p_max: float = 0.0, _p_regen_seconds_per_point: float = 1.0) -> void:
	max_command = 0.0
	regen_seconds_per_point = 1.0


func reset(_start: float = 0.0) -> void:
	current = 0.0
	changed.emit()


func clear() -> void:
	current = 0.0
	changed.emit()


func tick(_delta: float) -> void:
	pass


func get_current() -> float:
	return 0.0


func get_max() -> float:
	return 0.0


func can_afford(_cost: int) -> bool:
	return false


func try_spend(_cost: int) -> bool:
	return false


func refund(_cost: int) -> void:
	pass
