class_name ShopPoolConfig
extends Resource

## Legacy alias; prefer character_pool. Kept for existing .tres compatibility.
@export var pool: Array[UnitData] = []
@export var character_pool: Array[UnitData] = []
@export var buff_pool: Array[BuffCardData] = []
@export_range(1, 8, 1) var character_slot_count: int = 5
@export_range(0, 8, 1) var buff_slot_count: int = 2


func get_character_pool() -> Array[UnitData]:
	if not character_pool.is_empty():
		return character_pool
	return pool
