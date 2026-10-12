class_name MapNodeType
extends RefCounted

enum Type {
	START,
	COMBAT,
	ELITE,
	SHOP,
	REST,
	EVENT,
	TREASURE,
	MYSTERY,
	SACRIFICE,
	BOSS,
	ENCHANT,
}


static func is_combat(type: Type) -> bool:
	return type == Type.COMBAT or type == Type.ELITE or type == Type.BOSS


static func display_name(type: Type) -> String:
	match type:
		Type.START:
			return "起点"
		Type.COMBAT:
			return "战斗"
		Type.ELITE:
			return "精英"
		Type.SHOP:
			return "商店"
		Type.REST:
			return "休息"
		Type.EVENT:
			return "事件"
		Type.TREASURE:
			return "宝箱"
		Type.MYSTERY:
			return "?"
		Type.SACRIFICE:
			return "献祭"
		Type.BOSS:
			return "Boss"
		Type.ENCHANT:
			return "附魔"
		_:
			return "未知"
