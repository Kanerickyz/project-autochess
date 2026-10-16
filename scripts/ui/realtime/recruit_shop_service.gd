class_name RecruitShopService
extends RefCounted
## 招募半场道具行：生命/力量药水与旗帜；即时扣金；买走槽空。
## 角色候选仍由 RecruitSession 负责。

signal shop_changed

enum BuyResult { FAILED, OK }

var _config: RecruitShopConfig
var _economy: RunEconomy
var _item_offers: Array[PrepareItemData] = []
var _snapshot_items: Array[PrepareItemData] = []
var _open: bool = false


func configure(config: RecruitShopConfig, economy: RunEconomy) -> void:
	_config = config if config != null else RecruitShopConfig.make_code_defaults()
	_economy = economy
	_item_offers.clear()
	_snapshot_items.clear()
	_open = false


func is_open() -> bool:
	return _open


func open_shop(deck: DeckState) -> void:
	_open = true
	roll_offers(deck)
	_snapshot_items = _item_offers.duplicate()


func close_shop() -> void:
	_open = false
	_item_offers.clear()
	_snapshot_items.clear()
	shop_changed.emit()


func roll_offers(deck: DeckState) -> void:
	_item_offers.clear()
	if _config == null:
		shop_changed.emit()
		return
	var exclude_banner := deck != null and deck.is_seat_cap_maxed()
	var items := _config.get_item_pool(exclude_banner)
	for item in items:
		_item_offers.append(item)
	shop_changed.emit()


## 重置到进门快照（与 RecruitSession.reset 对齐）。
func restore_snapshot() -> void:
	_item_offers = _snapshot_items.duplicate()
	shop_changed.emit()


func get_item_offers() -> Array[PrepareItemData]:
	return _item_offers.duplicate()


func get_item_offer(index: int) -> PrepareItemData:
	if index < 0 or index >= _item_offers.size():
		return null
	return _item_offers[index]


func get_item_cost(item: PrepareItemData) -> int:
	if _config == null:
		return 0 if item == null else maxi(0, item.cost)
	return _config.resolve_item_cost(item)


func can_afford_item(index: int) -> bool:
	if not _open or _economy == null:
		return false
	var item := get_item_offer(index)
	if item == null:
		return false
	return _economy.can_afford(get_item_cost(item))


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
