class_name ShopService
extends RefCounted

enum BuyCharacterResult { FAILED, ADDED_NEW, MERGED, MERGED_LEVEL_UP }

signal shop_changed

var _pool_config: ShopPoolConfig
var _economy: RunEconomy
var _rng: RandomNumberGenerator
var _character_offers: Array[ShopOffer] = []
var _buff_offers: Array[ShopOffer] = []
var _shop_wave: int = 1


func configure(
	pool_config: ShopPoolConfig,
	economy: RunEconomy,
	rng: RandomNumberGenerator,
) -> void:
	_pool_config = pool_config
	_economy = economy
	_rng = rng
	_character_offers.clear()
	_buff_offers.clear()


func get_character_slot_count() -> int:
	if _pool_config == null:
		return 0
	return _pool_config.character_slot_count


func get_buff_slot_count() -> int:
	if _pool_config == null:
		return 0
	return _pool_config.buff_slot_count


func get_character_offer(index: int) -> ShopOffer:
	if index < 0 or index >= _character_offers.size():
		return null
	return _character_offers[index]


func get_buff_offer(index: int) -> ShopOffer:
	if index < 0 or index >= _buff_offers.size():
		return null
	return _buff_offers[index]


func get_character_offers() -> Array[ShopOffer]:
	return _character_offers.duplicate()


func get_buff_offers() -> Array[ShopOffer]:
	return _buff_offers.duplicate()


func get_shop_wave() -> int:
	return _shop_wave


func get_max_unlocked_tier() -> int:
	return TierUnlock.get_max_unlocked_tier(_shop_wave)


func roll_shop(shop_wave: int = 1) -> void:
	_shop_wave = maxi(1, shop_wave)
	_character_offers.clear()
	_buff_offers.clear()
	if _pool_config == null:
		shop_changed.emit()
		return

	for i in _pool_config.character_slot_count:
		_character_offers.append(_roll_character_offer())
	for i in _pool_config.buff_slot_count:
		_buff_offers.append(_roll_buff_offer())
	shop_changed.emit()


func try_buy_character(slot_index: int, deck: DeckState) -> Dictionary:
	var failed := {
		"result": BuyCharacterResult.FAILED,
		"entry": null,
		"level_up": false,
	}
	var offer := get_character_offer(slot_index)
	if offer == null or offer.type != ShopOffer.OfferType.CHARACTER:
		return failed
	if deck == null or _economy == null or offer.unit == null:
		return failed

	var unit_id := offer.unit.id
	var merge_target := DeckUpgradeService.find_merge_target(deck, unit_id)
	if merge_target == null and _all_copies_max_level(deck, unit_id):
		return failed

	var shop_bonus := offer.shop_bonus_max_hp

	if merge_target != null:
		if not _economy.spend(offer.get_cost()):
			return failed
		var merge_result := deck.try_merge_from_shop(offer.unit, shop_bonus)
		if not merge_result.get("ok", false):
			_economy.grant(offer.get_cost())
			return failed
		_character_offers[slot_index] = null
		shop_changed.emit()
		var leveled: bool = merge_result.get("level_up", false)
		if leveled:
			return {
				"result": BuyCharacterResult.MERGED_LEVEL_UP,
				"entry": merge_result.get("entry"),
				"level_up": true,
			}
		return {
			"result": BuyCharacterResult.MERGED,
			"entry": merge_result.get("entry"),
			"level_up": false,
		}

	if not _economy.spend(offer.get_cost()):
		return failed
	var new_entry := deck.add_entry(offer.unit, shop_bonus)
	if new_entry != null:
		_character_offers[slot_index] = null
		shop_changed.emit()
		return {
			"result": BuyCharacterResult.ADDED_NEW,
			"entry": new_entry,
			"level_up": false,
		}
	_economy.grant(offer.get_cost())
	return failed


func try_buy_buff(slot_index: int) -> BuffCardData:
	var offer := get_buff_offer(slot_index)
	if offer == null or offer.type != ShopOffer.OfferType.BUFF:
		return null
	if _economy == null or offer.buff == null:
		return null
	if not _economy.spend(offer.get_cost()):
		return null
	return offer.buff


func finalize_character_with_replace(
	slot_index: int,
	deck: DeckState,
	replace_entry_id: int,
) -> DeckEntry:
	var offer := get_character_offer(slot_index)
	if offer == null or offer.type != ShopOffer.OfferType.CHARACTER:
		return null
	if deck == null or offer.unit == null:
		return null
	if not _economy.spend(offer.get_cost()):
		return null
	var entry := deck.replace_entry(
		replace_entry_id,
		offer.unit,
		offer.shop_bonus_max_hp,
	)
	if entry == null:
		_economy.grant(offer.get_cost())
		return null
	_character_offers[slot_index] = null
	shop_changed.emit()
	return entry


func clear_character_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _character_offers.size():
		return
	_character_offers[slot_index] = null
	shop_changed.emit()


func clear_buff_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _buff_offers.size():
		return
	_buff_offers[slot_index] = null
	shop_changed.emit()


func refresh(shop_wave: int = 1) -> bool:
	if _economy == null:
		return false
	var cost := _economy.get_refresh_cost()
	if not _economy.spend(cost):
		return false
	roll_shop(shop_wave)
	return true


func stock_free_buff(buff: BuffCardData, count: int) -> void:
	if buff == null or count <= 0:
		return
	var stocked := 0
	for j in _buff_offers.size():
		if stocked >= count:
			break
		if _buff_offers[j] == null:
			var offer := ShopOffer.new()
			offer.type = ShopOffer.OfferType.BUFF
			offer.buff = buff
			_buff_offers[j] = offer
			stocked += 1
	if stocked > 0:
		shop_changed.emit()


func apply_shop_character_bonus_hp(amount: int) -> void:
	if amount <= 0:
		return
	for i in _character_offers.size():
		var offer: ShopOffer = _character_offers[i]
		if offer != null and offer.type == ShopOffer.OfferType.CHARACTER:
			offer.shop_bonus_max_hp += amount
	shop_changed.emit()


func _roll_character_offer() -> ShopOffer:
	var pool := _get_filtered_character_pool()
	if pool.is_empty():
		return null
	var offer := ShopOffer.new()
	offer.type = ShopOffer.OfferType.CHARACTER
	offer.unit = pool[_rng.randi_range(0, pool.size() - 1)]
	return offer


func _roll_buff_offer() -> ShopOffer:
	var pool := _get_filtered_buff_pool()
	if pool.is_empty():
		return null
	var offer := ShopOffer.new()
	offer.type = ShopOffer.OfferType.BUFF
	offer.buff = pool[_rng.randi_range(0, pool.size() - 1)]
	return offer


func _get_filtered_character_pool() -> Array[UnitData]:
	var raw := _get_character_pool()
	var max_tier := TierUnlock.get_max_unlocked_tier(_shop_wave)
	var filtered: Array = TierUnlock.filter_by_tier(
		raw,
		_get_unit_tier,
		max_tier,
	)
	return _to_unit_data_array(filtered)


func _get_filtered_buff_pool() -> Array[BuffCardData]:
	if _pool_config == null:
		return []
	var max_tier := TierUnlock.get_max_unlocked_tier(_shop_wave)
	var filtered: Array = TierUnlock.filter_by_tier(
		_pool_config.buff_pool,
		_get_buff_tier,
		max_tier,
	)
	return _to_buff_array(filtered)


func _get_character_pool() -> Array[UnitData]:
	if _pool_config == null:
		return []
	return _pool_config.get_character_pool()


static func _get_unit_tier(item: Variant) -> int:
	if item is UnitData:
		return (item as UnitData).tier
	return 99


static func _get_buff_tier(item: Variant) -> int:
	if item is BuffCardData:
		return (item as BuffCardData).tier
	return 99


func _to_unit_data_array(items: Array) -> Array[UnitData]:
	var result: Array[UnitData] = []
	for item in items:
		if item is UnitData:
			result.append(item)
	return result


func _to_buff_array(items: Array) -> Array[BuffCardData]:
	var result: Array[BuffCardData] = []
	for item in items:
		if item is BuffCardData:
			result.append(item)
	return result


func _all_copies_max_level(deck: DeckState, unit_id: String) -> bool:
	if deck == null or unit_id.is_empty():
		return false
	var config := deck.get_level_config()
	var found := false
	for entry in deck.get_entries():
		if entry == null or entry.get_unit_id() != unit_id:
			continue
		found = true
		if not DeckUpgradeService.is_max_level(entry, config):
			return false
	return found
