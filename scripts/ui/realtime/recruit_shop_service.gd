class_name RecruitShopService
extends RefCounted
## 招募半场道具行：生命/力量药水与旗帜；装备随机货架；即时扣金；买走槽空。
## 角色候选仍由 RecruitSession 负责。

signal shop_changed

enum BuyResult { FAILED, OK }

var _config: RecruitShopConfig
var _economy: RunEconomy
var _deck: DeckState
var _rng: RandomNumberGenerator
var _item_offers: Array[PrepareItemData] = []
var _equipment_offers: Array[EquipmentData] = []
var _snapshot_items: Array[PrepareItemData] = []
var _snapshot_equipment: Array[EquipmentData] = []
var _snapshot_banner_purchase_count: int = 0
var _open: bool = false


func configure(
	config: RecruitShopConfig,
	economy: RunEconomy,
	deck: DeckState = null,
	rng: RandomNumberGenerator = null,
) -> void:
	_config = config if config != null else RecruitShopConfig.make_code_defaults()
	_economy = economy
	_deck = deck
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_item_offers.clear()
	_equipment_offers.clear()
	_snapshot_items.clear()
	_snapshot_equipment.clear()
	_snapshot_banner_purchase_count = 0
	_open = false


func is_open() -> bool:
	return _open


func open_shop(deck: DeckState) -> void:
	_deck = deck if deck != null else _deck
	_open = true
	roll_offers(deck)
	_snapshot_items = _item_offers.duplicate()
	_snapshot_equipment = _equipment_offers.duplicate()
	_snapshot_banner_purchase_count = (
		_economy.banner_purchase_count if _economy != null else 0
	)


func close_shop() -> void:
	_open = false
	_item_offers.clear()
	_equipment_offers.clear()
	_snapshot_items.clear()
	_snapshot_equipment.clear()
	shop_changed.emit()


func roll_offers(deck: DeckState) -> void:
	_deck = deck if deck != null else _deck
	_item_offers.clear()
	_equipment_offers.clear()
	if _config == null:
		shop_changed.emit()
		return
	var exclude_banner := deck != null and deck.is_seat_cap_maxed()
	var items := _config.get_item_pool(exclude_banner)
	for item in items:
		_item_offers.append(item)
	_roll_equipment_offers()
	shop_changed.emit()


func _roll_equipment_offers() -> void:
	_equipment_offers.clear()
	if _config == null:
		return
	var slots := _config.get_equipment_slot_count()
	if slots <= 0:
		return
	var pool := _config.get_equipment_pool()
	for _i in slots:
		if pool.is_empty():
			_equipment_offers.append(null)
			continue
		var pick: EquipmentData = pool[_rng.randi_range(0, pool.size() - 1)]
		_equipment_offers.append(pick)


## 重置到进门快照（与 RecruitSession.reset 对齐）。
func restore_snapshot() -> void:
	_item_offers = _snapshot_items.duplicate()
	_equipment_offers = _snapshot_equipment.duplicate()
	if _economy != null:
		_economy.banner_purchase_count = _snapshot_banner_purchase_count
	shop_changed.emit()


func get_item_offers() -> Array[PrepareItemData]:
	return _item_offers.duplicate()


func get_equipment_offers() -> Array[EquipmentData]:
	return _equipment_offers.duplicate()


func get_item_offer(index: int) -> PrepareItemData:
	if index < 0 or index >= _item_offers.size():
		return null
	return _item_offers[index]


func get_equipment_offer(index: int) -> EquipmentData:
	if index < 0 or index >= _equipment_offers.size():
		return null
	return _equipment_offers[index]


func is_equipment_preview_index(preview_index: int) -> bool:
	return preview_index >= _item_offers.size()


func get_item_cost(item: PrepareItemData) -> int:
	if item != null and item.item_type == PrepareItemData.ItemType.BANNER:
		if _economy != null:
			return _economy.get_banner_cost()
		return RecruitShopConfig.DEFAULT_BANNER_COST
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


func can_afford_equipment(index: int) -> bool:
	if not _open or _economy == null:
		return false
	var item := get_equipment_offer(index)
	if item == null:
		return false
	return _economy.can_afford(maxi(0, item.cost))


func can_afford(cost: int) -> bool:
	if _economy == null:
		return false
	return _economy.can_afford(maxi(0, cost))


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
	_economy.note_banner_purchased()
	## 未满席时可反复购买同一旗帜槽；满 10 后清空该槽。
	if deck.is_seat_cap_maxed():
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
			deck.add_bonus_max_hp(entry, bonus)
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


## 拖装备到角色：规则与地图商店一致。
func try_buy_equipment_on_entry(slot_index: int, deck: DeckState, entry_id: int) -> Dictionary:
	var failed := {
		"result": BuyResult.FAILED,
		"reason": "failed",
		"entry": null,
		"kept_new": false,
	}
	if not _open or deck == null or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var item := get_equipment_offer(slot_index)
	if item == null:
		failed["reason"] = "empty_slot"
		return failed
	var entry := deck.get_entry(entry_id)
	if entry == null:
		failed["reason"] = "no_target"
		return failed

	if item.is_occupation_emblem():
		var occ := item.get_granted_occupation()
		if not SynergyOccupations.is_known(occ) or entry.has_occupation_tag(occ):
			failed["reason"] = "occupation_conflict"
			return failed
		var cost_emblem := maxi(0, item.cost)
		if not _economy.spend(cost_emblem):
			failed["reason"] = "cant_afford"
			return failed
		if not entry.try_attach_occupation_emblem(item):
			_economy.grant(cost_emblem)
			failed["reason"] = "occupation_conflict"
			return failed
		_equipment_offers[slot_index] = null
		deck.deck_changed.emit()
		shop_changed.emit()
		return {
			"result": BuyResult.OK,
			"reason": "",
			"entry": entry,
			"kept_new": true,
		}

	var cost := maxi(0, item.cost)
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	entry.attach_equipment(item)
	_equipment_offers[slot_index] = null
	deck.deck_changed.emit()
	shop_changed.emit()
	return {
		"result": BuyResult.OK,
		"reason": "",
		"entry": entry,
		"kept_new": true,
	}