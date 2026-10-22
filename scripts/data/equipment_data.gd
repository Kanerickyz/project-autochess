class_name EquipmentData
extends Resource
## 地图商店装备：本版仅护甲，挂在 DeckEntry 上跨遭遇保留。

@export var id: String = ""
@export var display_name: String = ""
@export_range(0, 99, 1) var cost: int = 1
## 受伤结算时抵消的伤害点数。
@export_range(0, 99, 1) var armor_block: int = 0


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return id if not id.is_empty() else "装备"


func get_armor_block() -> int:
	return maxi(0, armor_block)
