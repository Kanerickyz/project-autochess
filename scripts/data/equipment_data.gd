class_name EquipmentData
extends Resource
## 地图商店装备：护甲 / 技能类共槽，挂在 DeckEntry 上跨遭遇保留。

enum Kind {
	ARMOR = 0,
	ABILITY = 1,
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(0, 99, 1) var cost: int = 1
## 装备种类：护甲挡伤 / 技能类挂 AbilityData。
@export var kind: Kind = Kind.ARMOR
## 受伤结算时抵消的伤害点数（仅护甲类有效）。
@export_range(0, 99, 1) var armor_block: int = 0
## 技能类装备携带的效果；护甲类忽略。
@export var ability: AbilityData


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if is_ability_kind() and ability != null:
		if not ability.display_name.is_empty():
			return ability.display_name
		if not ability.id.is_empty():
			return ability.id
	return id if not id.is_empty() else "装备"


func get_icon() -> Texture2D:
	return icon


func is_armor_kind() -> bool:
	return kind == Kind.ARMOR


func is_ability_kind() -> bool:
	return kind == Kind.ABILITY


func get_armor_block() -> int:
	if not is_armor_kind():
		return 0
	return maxi(0, armor_block)


func get_ability() -> AbilityData:
	if not is_ability_kind():
		return null
	return ability


func get_kind_label() -> String:
	match kind:
		Kind.ABILITY:
			return "技能"
		_:
			return "护甲"


func get_summary() -> String:
	if is_ability_kind():
		var ab := get_ability()
		if ab == null:
			return "技能装"
		if not ab.display_name.is_empty():
			return ab.display_name
		return ab.id if not ab.id.is_empty() else "技能装"
	return "抵挡 %d" % get_armor_block()
