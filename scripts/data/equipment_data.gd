class_name EquipmentData
extends Resource
## 地图商店装备：护甲（armor_block>0）或转职纹章（granted_occupation 非空）。

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(0, 99, 1) var cost: int = 1
## 受伤结算时抵消的伤害点数。纹章为 0。
@export_range(0, 99, 1) var armor_block: int = 0
## 转职职名；空 = 护甲。须与 SynergyOccupations 词表一致。
@export var granted_occupation: String = ""


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return id if not id.is_empty() else "装备"


func get_icon() -> Texture2D:
	return icon


func get_armor_block() -> int:
	return maxi(0, armor_block)


func is_occupation_emblem() -> bool:
	return not get_granted_occupation().is_empty()


func get_granted_occupation() -> String:
	return granted_occupation.strip_edges()
