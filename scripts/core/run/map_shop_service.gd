class_name MapShopService
extends RefCounted
## 地图商店规则：消耗品/装备货架、刷新、购买挂装、换座写回。

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
	roll_shelf()
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


## 合并消耗品+装备池，按资源 id 去重后无放回抽满 shelf_slot_count；再按类型拆成两行。
func roll_shelf() -> void:
	_consumable_offers.clear()
	_equipment_offers.clear()
	if _config == null:
		return
	var by_id: Dictionary = {}
	for item in _config.get_consumable_pool():
		var c := item as MapShopConsumableData
		if c == null or c.id.is_empty():
			continue
		by_id[c.id] = {"kind": &"consumable", "res": c}
	for item in _config.get_equipment_pool():
		var e := item as EquipmentData
		if e == null or e.id.is_empty():
			continue
		by_id[e.id] = {"kind": &"equipment", "res": e}
	var bag: Array = by_id.values()
	_shuffle_inplace(bag)
	var take := mini(_config.get_shelf_slot_count(), bag.size())
	for i in take:
		var entry: Dictionary = bag[i]
		if entry.get("kind", &"") == &"equipment":
			_equipment_offers.append(entry.get("res"))
		else:
			_consumable_offers.append(entry.get("res"))


## 兼容旧名：整架重抽。
func roll_consumables() -> void:
	roll_shelf()


func roll_equipment() -> void:
	## 装备行由 roll_shelf 一并填充；单独调用时整架重抽以保持唯一。
	roll_shelf()


func try_refresh_consumables() -> Dictionary:
	var failed := {"result": BuyResult.FAILED, "reason": "failed"}
	if not _open or _economy == null:
		failed["reason"] = "shop_closed"
		return failed
	var cost := get_refresh_cost()
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	roll_shelf()
	shop_changed.emit()
	return {"result": BuyResult.OK, "reason": ""}


func _shuffle_inplace(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## 拖消耗品到角色：扣金、永久改攻血、槽空。金不足/非法目标失败且货架保留。
## 主题药水：拖放仅为确认；对当下队伍（含备战）该主题全员写攻/血；0 命中仍扣金清槽。
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
	if item.is_theme_potion():
		var affected := _apply_theme_potion_snapshot(item)
		_consumable_offers[slot_index] = null
		_deck.deck_changed.emit()
		shop_changed.emit()
		return {
			"result": BuyResult.OK,
			"reason": "",
			"entry": entry,
			"destroyed": false,
			"theme_affected": affected,
		}
	entry.bonus_attack += item.bonus_attack
	if item.bonus_max_hp > 0:
		_deck.add_bonus_max_hp(entry, item.bonus_max_hp)
	elif item.bonus_max_hp < 0:
		entry.bonus_max_hp += item.bonus_max_hp
	## 永久生命降至 ≤0：角色销毁离队（不退金、不出售）。
	var destroyed := false
	if DeckUpgradeService.get_display_max_hp(entry) <= 0:
		var doomed_id := entry.entry_id
		destroyed = _deck.remove_entry(doomed_id)
		entry = null
	_consumable_offers[slot_index] = null
	if not destroyed:
		_deck.deck_changed.emit()
	shop_changed.emit()
	return {
		"result": BuyResult.OK,
		"reason": "",
		"entry": entry,
		"destroyed": destroyed,
	}


## 当下快照：入座 + 备战中 theme_bond 匹配者展示攻/生命各翻倍；返回命中人数（可为 0）。
func _apply_theme_potion_snapshot(item: MapShopConsumableData) -> int:
	if item == null or _deck == null or not item.is_theme_potion():
		return 0
	var bond: UnitData.ThemeBond = item.theme_bond
	var hit := 0
	for member in _deck.get_entries():
		if member == null or member.unit == null:
			continue
		if member.unit.theme_bond != bond:
			continue
		var atk_now := DeckUpgradeService.get_display_attack(member)
		var hp_now := DeckUpgradeService.get_display_max_hp(member)
		## 再加等量加成 → 展示值 ×2；不改护甲装备。
		if atk_now > 0:
			member.bonus_attack += atk_now
		if hp_now > 0:
			_deck.add_bonus_max_hp(member, hp_now)
		hit += 1
	return hit


## 拖装备到角色：有空槽且够金 → 扣金挂入；槽满 / 0 槽 → 失败不扣金、货架保留。
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
	if not entry.has_empty_equipment_slot():
		failed["reason"] = "slots_full"
		return failed
	var cost := maxi(0, item.cost)
	if not _economy.spend(cost):
		failed["reason"] = "cant_afford"
		return failed
	if not entry.attach_equipment(item):
		## 极端：扣金后挂装失败则退金并保留货架。
		_economy.grant(cost)
		failed["reason"] = "slots_full"
		return failed
	_equipment_offers[slot_index] = null
	_deck.deck_changed.emit()
	shop_changed.emit()
	return {
		"result": BuyResult.OK,
		"reason": "",
		"entry": entry,
		"kept_new": true,
	}


func try_swap_seat(entry_id: int, target_seat: int) -> bool:
	if not _open or _deck == null:
		return false
	return _deck.swap_seats(entry_id, target_seat)
