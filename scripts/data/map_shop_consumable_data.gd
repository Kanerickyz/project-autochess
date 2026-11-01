class_name MapShopConsumableData
extends Resource
## 地图商店消耗品：战斗外永久改队伍成员攻/血加成（可负）。
## theme_bond != NONE：主题药水——对当下队伍快照（含备战）该主题全员展示攻/生命翻倍。

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(0, 99, 1) var cost: int = 1
@export var bonus_attack: int = 0
@export var bonus_max_hp: int = 0
## 非 NONE 时为本主题药水（见 MAP_SHOP §4.1）；单目标魔药保持 NONE。
@export var theme_bond: UnitData.ThemeBond = UnitData.ThemeBond.NONE


func is_theme_potion() -> bool:
	return theme_bond != UnitData.ThemeBond.NONE


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return id if not id.is_empty() else "消耗品"


func get_icon() -> Texture2D:
	return icon


func get_effect_summary() -> String:
	if is_theme_potion():
		return "%s全队：攻/生命×2" % UnitData.theme_bond_label(theme_bond)
	var parts: PackedStringArray = []
	if bonus_attack != 0:
		parts.append("%+d 攻" % bonus_attack)
	if bonus_max_hp != 0:
		parts.append("%+d 生命" % bonus_max_hp)
	if parts.is_empty():
		return "无效果"
	return "，".join(parts)
