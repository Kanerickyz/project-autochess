class_name PrepareItemData
extends Resource
## 准备商店道具：生命/力量药水（永久加成）与旗帜（席位上限 +1）。

enum ItemType {
	HP_POTION,
	ATK_POTION,
	BANNER,
}

@export var id: String = ""
@export var display_name: String = ""
@export var item_type: ItemType = ItemType.HP_POTION
@export_range(0, 99, 1) var cost: int = 1
## 药水加成点数；旗帜忽略（固定 +1 席位）。
@export_range(1, 10, 1) var bonus_value: int = 1


func needs_target() -> bool:
	return item_type == ItemType.HP_POTION or item_type == ItemType.ATK_POTION


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	match item_type:
		ItemType.HP_POTION:
			return "生命药水"
		ItemType.ATK_POTION:
			return "力量药水"
		ItemType.BANNER:
			return "旗帜"
		_:
			return id if not id.is_empty() else "道具"
