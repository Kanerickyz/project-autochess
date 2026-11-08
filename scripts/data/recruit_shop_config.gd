class_name RecruitShopConfig
extends Resource
## 招募半场道具行配置；角色 5 槽由 RecruitConfig.candidate_count 管。

const DEFAULT_PATH := "res://resources/recruit_shop/default_recruit_shop.tres"
const DEFAULT_POTION_COST := 1
const DEFAULT_BANNER_COST := 2

## 道具池（生命药水 / 力量药水 / 旗帜）；空则用代码默认三件。
@export var item_pool: Array[PrepareItemData] = []
@export_range(0, 99, 1) var default_potion_cost: int = DEFAULT_POTION_COST
@export_range(0, 99, 1) var default_banner_cost: int = DEFAULT_BANNER_COST


static func load_or_default() -> RecruitShopConfig:
	if ResourceLoader.exists(DEFAULT_PATH):
		var loaded := load(DEFAULT_PATH)
		if loaded is RecruitShopConfig:
			return loaded as RecruitShopConfig
		push_warning("RecruitShopConfig: %s is not RecruitShopConfig; using code defaults" % DEFAULT_PATH)
	return make_code_defaults()


static func make_code_defaults() -> RecruitShopConfig:
	var config := RecruitShopConfig.new()
	config.default_potion_cost = DEFAULT_POTION_COST
	config.default_banner_cost = DEFAULT_BANNER_COST
	config.item_pool = [
		_make_item("hp_potion", "生命药水", PrepareItemData.ItemType.HP_POTION, DEFAULT_POTION_COST),
		_make_item("atk_potion", "力量药水", PrepareItemData.ItemType.ATK_POTION, DEFAULT_POTION_COST),
		_make_item("banner", "旗帜", PrepareItemData.ItemType.BANNER, DEFAULT_BANNER_COST),
	]
	return config


static func _make_item(
	id: String,
	name: String,
	item_type: PrepareItemData.ItemType,
	cost: int,
) -> PrepareItemData:
	var item := PrepareItemData.new()
	item.id = id
	item.display_name = name
	item.item_type = item_type
	item.cost = cost
	item.bonus_value = 1
	return item


func get_item_pool(exclude_banner: bool = false) -> Array[PrepareItemData]:
	var source: Array[PrepareItemData] = item_pool
	if source.is_empty():
		source = make_code_defaults().item_pool
	var result: Array[PrepareItemData] = []
	for item in source:
		if item == null:
			continue
		if exclude_banner and item.item_type == PrepareItemData.ItemType.BANNER:
			continue
		result.append(item)
	return result


func resolve_item_cost(item: PrepareItemData) -> int:
	if item == null:
		return 0
	if item.cost > 0:
		return item.cost
	if item.item_type == PrepareItemData.ItemType.BANNER:
		return maxi(0, default_banner_cost)
	return maxi(0, default_potion_cost)
