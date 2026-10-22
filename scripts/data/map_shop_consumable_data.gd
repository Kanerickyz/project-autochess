class_name MapShopConsumableData
extends Resource
## 地图商店消耗品：战斗外永久改队伍成员攻/血加成（可负）。

@export var id: String = ""
@export var display_name: String = ""
@export_range(0, 99, 1) var cost: int = 1
@export var bonus_attack: int = 0
@export var bonus_max_hp: int = 0


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return id if not id.is_empty() else "消耗品"


func get_effect_summary() -> String:
	var parts: PackedStringArray = []
	if bonus_attack != 0:
		parts.append("%+d 攻" % bonus_attack)
	if bonus_max_hp != 0:
		parts.append("%+d 生命" % bonus_max_hp)
	if parts.is_empty():
		return "无效果"
	return "，".join(parts)
