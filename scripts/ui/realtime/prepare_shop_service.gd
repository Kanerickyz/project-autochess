class_name PrepareShopService
extends RefCounted
## 准备阶段商店：角色 5 槽 + 道具行；即时扣金；买走槽空。

signal shop_changed

enum BuyResult { FAILED, OK }

var _config: PrepareShopConfig
var _economy: RunEconomy
var _rng: RandomNumberGenerator
var _character_offers: Array[UnitData] = []
var _item_offers: Array[PrepareItemData] = []
var _open: bool = false


func configure(
	config: PrepareShopConfig,
	economy: RunEconomy,
	rng: RandomNumberGenerator,
) -> void:
	_config = config if config != null else PrepareShopConfig.make_code_defaults()
	_economy = economy
	_rng = rng
	_character_offers.clear()
	_item_offers.clear()
	_open = false


func is_open() -> bool:
	return _open


func open_shop(deck: DeckState, tier_index: int = 0) -> void:
	_open = true
	roll_offers(deck, tier_index)


func close_shop() -> void:
	_open = false
	_character_offers.clear()
	_item_offers.clear()
	shop_changed.emit()


func roll_offers(deck: DeckState, tier_index: int = 0) -> void:
	_character_offers.clear()
	_item_offers.clear()
	if _config == null:
		shop_changed.emit()
		return
	var slots := _config.get_character_slot_count()
	var pool := _filtered_character_pool(tier_index)
	for _i in slots:
		if pool.is_empty() or _rng == null:
			_character_offers.append(null)
		else:
			_character_offers.append(pool[_rng.randi_range(0, pool.size() - 1)])
	var exclude_banner := deck != null and deck.is_seat_cap_maxed()
	var items := _config.get_item_pool(exclude_banner)
	for item in items:
		_item_offers.append(item)
	shop_changed.emit()


func get_character_offers() -> Array[UnitData]:
	return _character_offers.duplicate()


func get_item_offers() -> Array[PrepareItemData]:
	return _item_offers.duplicate()


func get_character_offer(index: int) -> UnitData:
	if index < 0 or index >= _character_offers.size():
		return null
	return _character_offers[index]


func get_item_offer(index: int) -> PrepareItemData:
	if index < 0 or index >= _item_offers.size():
		return null
	return _item_offers[index]


func get_character_cost(unit: UnitData) -> int:
	if unit == null:
		return 0
	return maxi(0, unit.cost)


func get_item_cost(item: PrepareItemData) -> int:
	if _config == null:
		return 0 if item == null else maxi(0, item.cost)
	return _config.resolve_item_cost(item)


func can_afford_character(index: int) -> bool:
	if not _open or _economy == null:
		return false
	var unit := get_character_offer(index)
	if unit == null:
		return false
	return _economy.can_afford(get_character_cost(unit))


func can_afford_item(index: int) -> bool:
	if not _open or _economy == null:
		return false
	var item := get_item_offer(index)
	if item == null:
		return false
	return _economy.can_afford(get_item_cost(item))


## 买角色：金够且未满席则入队并占空座；成功清空该槽。
func try_buy_character(slot_index: int, deck: DeckState) -> Dictionary:
	var failed := {"result": BuyResult.FAILED, "entry": null, "reason": "failed"}
	if not _open or deck == null or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var unit := get_character_offer(slot_index)
	if unit == null:
		failed["reason"] = "empty_slot"
		return failed
	if deck.is_full():
		failed["reason"] = "roster_full"
		return failed
	var cost := get_character_cost(unit)
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	var entry := deck.add_entry(unit)
	if entry == null:
		_economy.grant(cost)
		failed["reason"] = "add_failed"
		return failed
	_character_offers[slot_index] = null
	shop_changed.emit()
	return {"result": BuyResult.OK, "entry": entry, "reason": ""}


## 买旗帜：无目标，席位 +1（≤10）；成功清空该槽。
func try_buy_banner(slot_index: int, deck: DeckState) -> Dictionary:
	var failed := {"result": BuyResult.FAILED, "reason": "failed"}
	if not _open or deck == null or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var item := get_item_offer(slot_index)
	if item == null or item.item_type != PrepareItemData.ItemType.BANNER:
		failed["reason"] = "not_banner"
		return failed
	if deck.is_seat_cap_maxed():
		failed["reason"] = "cap_maxed"
		return failed
	var cost := get_item_cost(item)
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	if not deck.try_increase_seat_cap(1):
		_economy.grant(cost)
		failed["reason"] = "cap_failed"
		return failed
	_item_offers[slot_index] = null
	shop_changed.emit()
	return {"result": BuyResult.OK, "reason": ""}


## 买药水并对目标成员施加永久加成。
func try_buy_potion_on_entry(slot_index: int, deck: DeckState, entry_id: int) -> Dictionary:
	var failed := {"result": BuyResult.FAILED, "reason": "failed", "entry": null}
	if not _open or deck == null or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var item := get_item_offer(slot_index)
	if item == null or not item.needs_target():
		failed["reason"] = "not_potion"
		return failed
	var entry := deck.get_entry(entry_id)
	if entry == null:
		failed["reason"] = "no_target"
		return failed
	var cost := get_item_cost(item)
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	var bonus := maxi(1, item.bonus_value)
	match item.item_type:
		PrepareItemData.ItemType.HP_POTION:
			entry.bonus_max_hp += bonus
		PrepareItemData.ItemType.ATK_POTION:
			entry.bonus_attack += bonus
		_:
			_economy.grant(cost)
			failed["reason"] = "bad_type"
			return failed
	deck.deck_changed.emit()
	_item_offers[slot_index] = null
	shop_changed.emit()
	return {"result": BuyResult.OK, "reason": "", "entry": entry}


func _filtered_character_pool(tier_index: int) -> Array[UnitData]:
	var raw: Array[UnitData] = []
	if _config != null:
		raw = _config.get_character_pool()
	if raw.is_empty():
		var fallback := PrepareShopConfig.make_code_defaults().get_character_pool()
		raw = fallback
	var max_tier := TierUnlock.get_max_unlocked_tier(tier_index + 1)
	var filtered: Array = TierUnlock.filter_by_tier(raw, _get_unit_tier, max_tier)
	var result: Array[UnitData] = []
	for item in filtered:
		if item is UnitData:
			result.append(item as UnitData)
	return result


static func _get_unit_tier(item: Variant) -> int:
	if item is UnitData:
		return (item as UnitData).tier
	return 99
