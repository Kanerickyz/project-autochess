class_name MapShopService
extends RefCounted
## 地图商店规则：消耗品/装备货架、刷新、购买冲突 RNG、换座写回。

signal shop_changed

enum BuyResult { FAILED, OK }

var _config: MapShopConfig
var _economy: RunEconomy
var _deck: DeckState
var _rng: RandomNumberGenerator
var _open: bool = false
var _consumable_offers: Array = []
var _equipment_offers: Array = []


func configure(
	config: MapShopConfig,
	economy: RunEconomy,
	deck: DeckState,
	rng: RandomNumberGenerator = null,
) -> void:
	_config = config if config != null else MapShopConfig.make_code_defaults()
	_economy = economy
	_deck = deck
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_open = false
	_consumable_offers.clear()
	_equipment_offers.clear()


func is_open() -> bool:
	return _open


func open_shop() -> void:
	_open = true
	roll_consumables()
	roll_equipment()
	shop_changed.emit()


func close_shop() -> void:
	_open = false
	_consumable_offers.clear()
	_equipment_offers.clear()
	shop_changed.emit()


func get_refresh_cost() -> int:
	if _config == null:
		return MapShopConfig.DEFAULT_REFRESH_COST
	return _config.get_refresh_cost()


func get_gold() -> int:
	return _economy.gold if _economy != null else 0


func get_consumable_offers() -> Array:
	return _consumable_offers.duplicate()


func get_equipment_offers() -> Array:
	return _equipment_offers.duplicate()


func get_consumable_offer(index: int) -> MapShopConsumableData:
	if index < 0 or index >= _consumable_offers.size():
		return null
	return _consumable_offers[index] as MapShopConsumableData


func get_equipment_offer(index: int) -> EquipmentData:
	if index < 0 or index >= _equipment_offers.size():
		return null
	return _equipment_offers[index] as EquipmentData


func can_afford(cost: int) -> bool:
	if _economy == null:
		return false
	return _economy.can_afford(maxi(0, cost))


func can_refresh() -> bool:
	return _open and can_afford(get_refresh_cost())


func roll_consumables() -> void:
	_consumable_offers.clear()
	if _config == null:
		return
	var pool := _config.get_consumable_pool()
	var slots := _config.get_consumable_slot_count()
	for _i in slots:
		if pool.is_empty():
			_consumable_offers.append(null)
			continue
		var pick: MapShopConsumableData = pool[_rng.randi_range(0, pool.size() - 1)]
		_consumable_offers.append(pick)


func roll_equipment() -> void:
	_equipment_offers.clear()
	if _config == null:
		return
	var pool := _config.get_equipment_pool()
	var slots := _config.get_equipment_slot_count()
	for _i in slots:
		if pool.is_empty():
			_equipment_offers.append(null)
			continue
		var pick: EquipmentData = pool[_rng.randi_range(0, pool.size() - 1)]
		_equipment_offers.append(pick)


func try_refresh_consumables() -> Dictionary:
	var failed := {"result": BuyResult.FAILED, "reason": "failed"}
	if not _open or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var cost := get_refresh_cost()
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	roll_consumables()
	shop_changed.emit()
	return {"result": BuyResult.OK, "reason": ""}


## 拖消耗品到角色：扣金、永久改攻血、槽空。金不足/非法目标失败且货架保留。
func try_buy_consumable_on_entry(slot_index: int, entry_id: int) -> Dictionary:
	var failed := {"result": BuyResult.FAILED, "reason": "failed", "entry": null}
	if not _open or _deck == null or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var item := get_consumable_offer(slot_index)
	if item == null:
		failed["reason"] = "empty_slot"
		return failed
	var entry := _deck.get_entry(entry_id)
	if entry == null:
		failed["reason"] = "no_target"
		return failed
	var cost := maxi(0, item.cost)
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	entry.bonus_attack += item.bonus_attack
	entry.bonus_max_hp += item.bonus_max_hp
	_consumable_offers[slot_index] = null
	_deck.deck_changed.emit()
	shop_changed.emit()
	return {"result": BuyResult.OK, "reason": "", "entry": entry}


## 拖装备到角色：扣金；已有装备时旧/新随机留一件，不退金；槽空。
func try_buy_equipment_on_entry(slot_index: int, entry_id: int) -> Dictionary:
	var failed := {"result": BuyResult.FAILED, "reason": "failed", "entry": null, "kept_new": false}
	if not _open or _deck == null or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var item := get_equipment_offer(slot_index)
	if item == null:
		failed["reason"] = "empty_slot"
		return failed
	var entry := _deck.get_entry(entry_id)
	if entry == null:
		failed["reason"] = "no_target"
		return failed
	var cost := maxi(0, item.cost)
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	var kept_new := true
	if entry.equipment != null:
		## 旧/新各 50% 留一件；另一件消失，不退金。
		kept_new = _rng.randf() < 0.5
		if kept_new:
			entry.attach_equipment(item)
	else:
		entry.attach_equipment(item)
	_equipment_offers[slot_index] = null
	_deck.deck_changed.emit()
	shop_changed.emit()
	return {
		"result": BuyResult.OK,
		"reason": "",
		"entry": entry,
		"kept_new": kept_new,
	}


func try_swap_seat(entry_id: int, target_seat: int) -> bool:
	if not _open or _deck == null:
		return false
	return _deck.swap_seats(entry_id, target_seat)
