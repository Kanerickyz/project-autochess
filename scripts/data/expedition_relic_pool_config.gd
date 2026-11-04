class_name ExpeditionRelicPoolConfig
extends Resource

## 事件三选一池与层深偏抽权重。

@export var relics: Array[ExpeditionRelicData] = []
## 三段：early / mid / late；每段为 [T1,T2,T3] 权重（相对）。
@export var weight_early: Vector3i = Vector3i(70, 25, 5)
@export var weight_mid: Vector3i = Vector3i(35, 50, 15)
@export var weight_late: Vector3i = Vector3i(15, 45, 40)
@export_range(1, 99, 1) var early_floor_max: int = 4
@export_range(1, 99, 1) var mid_floor_max: int = 9


func get_weights_for_floor(floor_index: int) -> Vector3i:
	var n := floor_index if floor_index >= 1 else 1
	if n <= early_floor_max:
		return weight_early
	if n <= mid_floor_max:
		return weight_mid
	return weight_late


func relics_of_tier(tier: int) -> Array[ExpeditionRelicData]:
	var out: Array[ExpeditionRelicData] = []
	for r in relics:
		if r != null and r.tier == tier:
			out.append(r)
	return out
