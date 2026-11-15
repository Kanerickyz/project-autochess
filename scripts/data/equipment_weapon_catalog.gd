class_name EquipmentWeaponCatalog
extends RefCounted
## 地图商店武器条目（代码池；与护甲/纹章共用主槽）。

const ICON := "res://resources/map_shop/icons/armor_icon.tres"


static func get_all() -> Array[EquipmentData]:
	var out: Array[EquipmentData] = []
	for def in _DEFINITIONS:
		out.append(_make(def))
	return out


static func get_by_id(weapon_id: String) -> EquipmentData:
	for def in _DEFINITIONS:
		if str(def.get("id", "")) == weapon_id:
			return _make(def)
	return null


static func _make(def: Dictionary) -> EquipmentData:
	var item := EquipmentData.new()
	item.id = str(def.get("id", ""))
	item.display_name = str(def.get("name", item.id))
	item.cost = int(def.get("cost", 2))
	item.weapon_attack_bonus = int(def.get("atk_bonus", 0))
	item.weapon_lifesteal = int(def.get("leech", 0))
	item.weapon_haste_percent = int(def.get("haste", 0))
	item.weapon_poison_stacks = int(def.get("poison", 0))
	item.weapon_burn_stacks = int(def.get("burn", 0))
	item.weapon_spawn_attack = int(def.get("sk_atk", 0))
	item.weapon_spawn_max_hp = int(def.get("sk_hp", 0))
	if ResourceLoader.exists(ICON):
		item.icon = load(ICON) as Texture2D
	return item


const _DEFINITIONS: Array[Dictionary] = [
	{"id": "weapon_flat_t1", "name": "粗砺砥石", "cost": 2, "atk_bonus": 2},
	{"id": "weapon_flat_t2", "name": "淬锋铁刃", "cost": 3, "atk_bonus": 5},
	{"id": "weapon_flat_t3", "name": "斩将重刃", "cost": 5, "atk_bonus": 10},
	{"id": "weapon_leech_t1", "name": "回春牙刃", "cost": 2, "leech": 3},
	{"id": "weapon_leech_t2", "name": "饮血弯刀", "cost": 3, "leech": 5},
	{"id": "weapon_leech_t3", "name": "命脉双刃", "cost": 5, "leech": 10},
	{"id": "weapon_haste_t1", "name": "攻速刀", "cost": 2, "haste": 3},
	{"id": "weapon_haste_t2", "name": "攻速刀+", "cost": 3, "haste": 5},
	{"id": "weapon_haste_t3", "name": "攻速刀++", "cost": 5, "haste": 10},
	{
		"id": "weapon_bone_t1",
		"name": "指骨护符",
		"cost": 3,
		"sk_atk": 3,
		"sk_hp": 10,
	},
	{"id": "weapon_bone_t2", "name": "唤冢铃", "cost": 4, "sk_atk": 5, "sk_hp": 20},
	{
		"id": "weapon_bone_t3",
		"name": "冥主徽记",
		"cost": 6,
		"sk_atk": 10,
		"sk_hp": 30,
	},
	{"id": "weapon_burn_t1", "name": "火焰刀", "cost": 2, "burn": 1},
	{"id": "weapon_burn_t2", "name": "火焰刀+", "cost": 3, "burn": 2},
	{"id": "weapon_burn_t3", "name": "火焰刀++", "cost": 5, "burn": 5},
	{"id": "weapon_poison_t1", "name": "毒刀", "cost": 2, "poison": 1},
	{"id": "weapon_poison_t2", "name": "毒刀+", "cost": 3, "poison": 2},
	{"id": "weapon_poison_t3", "name": "毒刀++", "cost": 5, "poison": 5},
]