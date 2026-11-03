class_name DayShopCatalog
extends RefCounted
## 天内商店：四类店 → 各自货池。货品内容后续设计；本版按装备来源角色粗分。
## 军械：护甲 + 近战/坦克/刺客来源技能装；远程：远程来源技能装；
## 魔法：亡灵/秘术主题来源技能装；消耗品：魔药与主题药水。

enum Category { ARMORY, RANGED, MAGIC, CONSUMABLE }

const CATEGORIES: Array[Category] = [
	Category.ARMORY,
	Category.RANGED,
	Category.MAGIC,
	Category.CONSUMABLE,
]
const DEFAULT_OFFER_COUNT := 4
const SKILL_ID_PREFIX := "skill_"
const UNITS_DIR := "res://resources/units/realtime"

static var _source_unit_cache: Dictionary = {}


static func label(category: Category) -> String:
	match category:
		Category.ARMORY:
			return "军械商店"
		Category.RANGED:
			return "远程商店"
		Category.MAGIC:
			return "魔法商店"
		Category.CONSUMABLE:
			return "消耗品商店"
	return "商店"


static func blurb(category: Category) -> String:
	match category:
		Category.ARMORY:
			return "护甲与近身技能装备"
		Category.RANGED:
			return "远程角色的技能装备"
		Category.MAGIC:
			return "亡灵与秘术的技能装备"
		Category.CONSUMABLE:
			return "魔药：永久改攻击与生命"
	return ""


static func icon_path(category: Category) -> String:
	match category:
		Category.ARMORY:
			return MapShopConfig.ICON_ARMOR
		Category.RANGED:
			return MapShopConfig.ICON_ATK
		Category.MAGIC:
			return MapShopConfig.ICON_RARE
		Category.CONSUMABLE:
			return MapShopConfig.ICON_HP
	return ""


static func category_of_equipment(item: EquipmentData) -> Category:
	if item == null or item.is_armor_kind():
		return Category.ARMORY
	var unit := _source_unit_for(item)
	if unit != null:
		if (
			unit.theme_bond == UnitData.ThemeBond.ARCANA
			or unit.theme_bond == UnitData.ThemeBond.UNDEAD
		):
			return Category.MAGIC
		if unit.combat_profession == UnitData.CombatProfession.RANGED:
			return Category.RANGED
	return Category.ARMORY


## 该店货池（装备店只含装备；消耗品店只含消耗品）。
static func pool_for(category: Category, config: MapShopConfig) -> Array:
	var cfg := config if config != null else MapShopConfig.load_or_default()
	var out: Array = []
	if category == Category.CONSUMABLE:
		for c in cfg.get_consumable_pool():
			if c != null:
				out.append(c)
		return out
	for e in cfg.get_equipment_pool():
		if e != null and category_of_equipment(e) == category:
			out.append(e)
	return out


## 无放回随机抽 count 件；池不足则全给。
static func roll_offers(
	category: Category,
	config: MapShopConfig,
	rng: RandomNumberGenerator,
	count: int = DEFAULT_OFFER_COUNT,
) -> Array:
	var bag := pool_for(category, config)
	var r := rng if rng != null else RandomNumberGenerator.new()
	for i in range(bag.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	return bag.slice(0, mini(maxi(0, count), bag.size()))


static func _source_unit_for(item: EquipmentData) -> UnitData:
	if item == null or not item.id.begins_with(SKILL_ID_PREFIX):
		return null
	var unit_id := item.id.trim_prefix(SKILL_ID_PREFIX)
	if _source_unit_cache.has(unit_id):
		return _source_unit_cache[unit_id] as UnitData
	var path := UNITS_DIR.path_join("%s.tres" % unit_id)
	var unit: UnitData = null
	if ResourceLoader.exists(path):
		unit = load(path) as UnitData
	_source_unit_cache[unit_id] = unit
	return unit
