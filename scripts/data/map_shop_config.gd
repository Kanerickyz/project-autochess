class_name MapShopConfig
extends Resource
## 地图商店货架配置：消耗品池 / 装备池 / 合计槽位 / 刷新费。

const DEFAULT_PATH := "res://resources/map_shop/default_map_shop.tres"
## 遗留分栏槽位字段默认；抽签以 shelf_slot_count 为准。
const DEFAULT_CONSUMABLE_SLOTS := 3
const DEFAULT_EQUIPMENT_SLOTS := 3
const DEFAULT_SHELF_SLOTS := 6
const DEFAULT_REFRESH_COST := 2

@export var consumable_pool: Array[MapShopConsumableData] = []
@export var equipment_pool: Array[EquipmentData] = []
@export_range(1, 8, 1) var consumable_slot_count: int = DEFAULT_CONSUMABLE_SLOTS
@export_range(1, 8, 1) var equipment_slot_count: int = DEFAULT_EQUIPMENT_SLOTS
## 药+装合计槽位；合并池无放回抽满（MAP_SHOP §3.1）。
@export_range(1, 12, 1) var shelf_slot_count: int = DEFAULT_SHELF_SLOTS
@export_range(0, 99, 1) var refresh_cost: int = DEFAULT_REFRESH_COST


static func load_or_default() -> MapShopConfig:
	if ResourceLoader.exists(DEFAULT_PATH):
		var loaded := load(DEFAULT_PATH)
		if loaded is MapShopConfig:
			return loaded as MapShopConfig
		push_warning("MapShopConfig: %s is not MapShopConfig; using code defaults" % DEFAULT_PATH)
	return make_code_defaults()


static func make_code_defaults() -> MapShopConfig:
	var config := MapShopConfig.new()
	config.consumable_slot_count = DEFAULT_CONSUMABLE_SLOTS
	config.equipment_slot_count = DEFAULT_EQUIPMENT_SLOTS
	config.shelf_slot_count = DEFAULT_SHELF_SLOTS
	config.refresh_cost = DEFAULT_REFRESH_COST
	config.consumable_pool = [
		_make_consumable("big_hp_potion", "大生命魔药", 2, -1, 5, ICON_HP),
		_make_consumable("big_atk_potion", "大力量魔药", 2, 5, -1, ICON_ATK),
		_make_consumable("qunbolong", "群伯龙", 5, 10, -5, ICON_RARE),
		_make_theme_potion("theme_undead", "亡灵药水", UnitData.ThemeBond.UNDEAD),
		_make_theme_potion("theme_warrior", "战士药水", UnitData.ThemeBond.WARRIOR),
		_make_theme_potion("theme_knight", "骑士药水", UnitData.ThemeBond.KNIGHT),
		_make_theme_potion("theme_artisan", "工匠药水", UnitData.ThemeBond.ARTISAN),
		_make_theme_potion("theme_band", "军乐队药水", UnitData.ThemeBond.BAND),
		_make_theme_potion("theme_arcana", "秘术药水", UnitData.ThemeBond.ARCANA),
		_make_theme_potion("theme_guard", "护卫药水", UnitData.ThemeBond.GUARD),
	]
	config.equipment_pool = [
		_make_equipment("armor_t1", "护甲 I", 1, 2, ICON_ARMOR),
		_make_equipment("armor_t2", "护甲 II", 2, 6, ICON_ARMOR),
		_make_equipment("armor_t3", "护甲 III", 4, 10, ICON_ARMOR),
	]
	config.equipment_pool.append_array(_make_skill_equipment_defaults())
	return config


const ICON_HP := "res://resources/map_shop/icons/big_hp_potion_icon.tres"
const ICON_ATK := "res://resources/map_shop/icons/big_atk_potion_icon.tres"
const ICON_RARE := "res://resources/map_shop/icons/qunbolong_icon.tres"
const ICON_ARMOR := "res://resources/map_shop/icons/armor_icon.tres"
const DEFAULT_THEME_POTION_COST := 3
## 主题药水效果为翻倍，不再读 flat bonus；字段保留 0 以免摘要误导。
const DEFAULT_THEME_POTION_ATK := 0
const DEFAULT_THEME_POTION_HP := 0
## 技能装默认售价（占位；数值可后调）。
const DEFAULT_SKILL_EQUIP_COST := 3
## 从角色模板 ability 生成技能装时扫描的友方单位目录。
const REALTIME_UNITS_DIR := "res://resources/units/realtime"


static func _make_consumable(
	id: String,
	name: String,
	cost: int,
	atk: int,
	hp: int,
	icon_path: String = "",
	theme_bond: UnitData.ThemeBond = UnitData.ThemeBond.NONE,
) -> MapShopConsumableData:
	var item := MapShopConsumableData.new()
	item.id = id
	item.display_name = name
	item.cost = cost
	item.bonus_attack = atk
	item.bonus_max_hp = hp
	item.theme_bond = theme_bond
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
	return item


static func _make_theme_potion(
	id: String,
	name: String,
	theme_bond: UnitData.ThemeBond,
) -> MapShopConsumableData:
	## 主题药水暂复用大力药图标占位。
	return _make_consumable(
		id,
		name,
		DEFAULT_THEME_POTION_COST,
		DEFAULT_THEME_POTION_ATK,
		DEFAULT_THEME_POTION_HP,
		ICON_ATK,
		theme_bond,
	)


static func _make_equipment(
	id: String,
	name: String,
	cost: int,
	block: int,
	icon_path: String = ICON_ARMOR,
) -> EquipmentData:
	var item := EquipmentData.new()
	item.id = id
	item.display_name = name
	item.cost = cost
	item.kind = EquipmentData.Kind.ARMOR
	item.armor_block = block
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
	return item


static func _make_ability_equipment(
	id: String,
	name: String,
	ability: AbilityData,
	cost: int = DEFAULT_SKILL_EQUIP_COST,
	icon_path: String = ICON_ATK,
) -> EquipmentData:
	var item := EquipmentData.new()
	item.id = id
	item.display_name = name
	item.cost = cost
	item.kind = EquipmentData.Kind.ABILITY
	item.armor_block = 0
	item.ability = ability
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
	return item


## 扫描 realtime 友方单位：有 ability 则生成 skill_<unit_id> 装备（按 ability.id 去重）。
static func _make_skill_equipment_defaults() -> Array[EquipmentData]:
	var out: Array[EquipmentData] = []
	var seen_ability: Dictionary = {}
	var dir := DirAccess.open(REALTIME_UNITS_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := REALTIME_UNITS_DIR.path_join(file_name)
			var loaded := load(path)
			var unit := loaded as UnitData
			if (
				unit != null
				and unit.ability != null
				and not unit.id.is_empty()
				and not unit.id.begins_with("boss_")
				and unit.id != "commander"
			):
				var ab := unit.ability
				var ab_key := ab.id if not ab.id.is_empty() else ab.resource_path
				if not ab_key.is_empty() and not seen_ability.has(ab_key):
					seen_ability[ab_key] = true
					var skill_name := ab.display_name
					if skill_name.is_empty():
						skill_name = unit.display_name if not unit.display_name.is_empty() else unit.id
					var eq_id := "skill_%s" % unit.id
					out.append(
						_make_ability_equipment(
							eq_id,
							"技·%s" % skill_name,
							ab,
							DEFAULT_SKILL_EQUIP_COST + maxi(0, unit.tier - 1),
						)
					)
		file_name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: EquipmentData, b: EquipmentData) -> bool:
		return a.id < b.id
	)
	return out


func get_consumable_pool() -> Array[MapShopConsumableData]:
	if consumable_pool.is_empty():
		return make_code_defaults().consumable_pool
	var out: Array[MapShopConsumableData] = []
	for item in consumable_pool:
		if item != null:
			out.append(item)
	return out


func get_equipment_pool() -> Array[EquipmentData]:
	if equipment_pool.is_empty():
		return make_code_defaults().equipment_pool
	var out: Array[EquipmentData] = []
	var seen: Dictionary = {}
	var has_ability := false
	for item in equipment_pool:
		if item == null or item.id.is_empty():
			continue
		out.append(item)
		seen[item.id] = true
		if item.is_ability_kind():
			has_ability = true
	## .tres 若仍只有护甲，运行时补齐技能装 code defaults。
	if not has_ability:
		for skill in _make_skill_equipment_defaults():
			if skill == null or skill.id.is_empty() or seen.has(skill.id):
				continue
			out.append(skill)
			seen[skill.id] = true
	return out


func get_consumable_slot_count() -> int:
	return maxi(1, consumable_slot_count)


func get_equipment_slot_count() -> int:
	return maxi(1, equipment_slot_count)


func get_shelf_slot_count() -> int:
	return maxi(1, shelf_slot_count)


func get_refresh_cost() -> int:
	return maxi(0, refresh_cost)
