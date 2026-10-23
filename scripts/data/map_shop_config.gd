class_name MapShopConfig
extends Resource
## 地图商店货架配置：消耗品池 / 装备池 / 刷新费。

const DEFAULT_PATH := "res://resources/map_shop/default_map_shop.tres"
const DEFAULT_CONSUMABLE_SLOTS := 3
const DEFAULT_EQUIPMENT_SLOTS := 3
const DEFAULT_REFRESH_COST := 2

@export var consumable_pool: Array[MapShopConsumableData] = []
@export var equipment_pool: Array[EquipmentData] = []
@export_range(1, 8, 1) var consumable_slot_count: int = DEFAULT_CONSUMABLE_SLOTS
@export_range(1, 8, 1) var equipment_slot_count: int = DEFAULT_EQUIPMENT_SLOTS
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
	config.refresh_cost = DEFAULT_REFRESH_COST
	config.consumable_pool = [
		_make_consumable("big_hp_potion", "大生命魔药", 2, -1, 5, ICON_HP),
		_make_consumable("big_atk_potion", "大力量魔药", 2, 5, -1, ICON_ATK),
		_make_consumable("qunbolong", "群伯龙", 5, 10, -5, ICON_RARE),
	]
	config.equipment_pool = [
		_make_equipment("armor_t1", "护甲 I", 1, 2, ICON_ARMOR),
		_make_equipment("armor_t2", "护甲 II", 2, 6, ICON_ARMOR),
		_make_equipment("armor_t3", "护甲 III", 4, 10, ICON_ARMOR),
	]
	return config


const ICON_HP := "res://resources/map_shop/icons/big_hp_potion_icon.tres"
const ICON_ATK := "res://resources/map_shop/icons/big_atk_potion_icon.tres"
const ICON_RARE := "res://resources/map_shop/icons/qunbolong_icon.tres"
const ICON_ARMOR := "res://resources/map_shop/icons/armor_icon.tres"


static func _make_consumable(
	id: String,
	name: String,
	cost: int,
	atk: int,
	hp: int,
	icon_path: String = "",
) -> MapShopConsumableData:
	var item := MapShopConsumableData.new()
	item.id = id
	item.display_name = name
	item.cost = cost
	item.bonus_attack = atk
	item.bonus_max_hp = hp
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
	return item


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
	item.armor_block = block
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
	return item


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
	for item in equipment_pool:
		if item != null:
			out.append(item)
	return out


func get_consumable_slot_count() -> int:
	return maxi(1, consumable_slot_count)


func get_equipment_slot_count() -> int:
	return maxi(1, equipment_slot_count)


func get_refresh_cost() -> int:
	return maxi(0, refresh_cost)
