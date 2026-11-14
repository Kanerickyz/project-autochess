class_name MapShopServiceTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("equipment_pool_costs_1_2_4", _test_equipment_pool_costs())
	_check("open_rolls_five_equipment_slots", _test_open_rolls_five_equipment())
	_check("buy_consumable", _test_buy_consumable())
	_check("consumable_destroys_at_zero_hp", _test_consumable_destroys_at_zero_hp())
	_check("cant_afford_keeps_shelf", _test_cant_afford())
	_check("refresh_equipment_five_slots", _test_refresh())
	_check("armor_replace_keeps_new", _test_armor_replace())
	_check("emblem_reject_same_occupation", _test_emblem_reject_same_occupation())
	_check("emblem_attach_and_with_armor", _test_emblem_attach_with_armor())
	_check("triple_merge_keeps_one_armor", _test_triple_merge_equipment())
	_check("triple_merge_dedupes_emblems", _test_triple_merge_emblems())
	if _failures == 0:
		print("MapShopServiceTest: all tests passed")
	else:
		push_error("MapShopServiceTest: %d failure(s)" % _failures)
	return _failures == 0


static func _test_equipment_pool_costs() -> bool:
	var cfg := MapShopConfig.load_or_default()
	var by_id: Dictionary = {}
	for item in cfg.get_equipment_pool():
		var eq := item as EquipmentData
		if eq == null:
			continue
		by_id[eq.id] = eq
	var t1: EquipmentData = by_id.get("armor_t1") as EquipmentData
	var t2: EquipmentData = by_id.get("armor_t2") as EquipmentData
	var t3: EquipmentData = by_id.get("armor_t3") as EquipmentData
	if t1 == null or t2 == null or t3 == null:
		return false
	if not (t1.cost == 1 and t2.cost == 2 and t3.cost == 4):
		return false
	## 六职纹章 cost=4（balance 定稿）。
	for eid in [
		"emblem_tank",
		"emblem_warrior",
		"emblem_ranged",
		"emblem_artisan",
		"emblem_band",
		"emblem_arcane",
	]:
		var em: EquipmentData = by_id.get(eid) as EquipmentData
		if em == null or em.cost != 4 or not em.is_occupation_emblem():
			return false
	return cfg.get_equipment_slot_count() == 5


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("MapShopServiceTest FAIL: %s" % name)


static func _make_unit(id: String = "u1", occupation: String = SynergyOccupations.WARRIOR) -> UnitData:
	var unit := UnitData.new()
	unit.id = id
	unit.display_name = id
	unit.occupation = occupation
	unit.stats = UnitStats.new()
	unit.stats.attack = 2
	unit.stats.max_hp = 10
	return unit


static func _make_deck(unit: UnitData, count: int = 1) -> DeckState:
	var config := DeckConfig.new()
	config.max_size = 10
	config.starting_units = []
	var deck := DeckState.new()
	deck.configure(config)
	for _i in count:
		deck.add_entry(unit)
	return deck


static func _make_economy(gold: int) -> RunEconomy:
	var econ := RunEconomy.new()
	econ.configure(load("res://resources/economy/default_economy.tres") as EconomyConfig)
	econ.reset()
	## 直接设金，避免依赖起始金。
	while econ.gold < gold:
		econ.grant(gold - econ.gold)
	while econ.gold > gold:
		econ.spend(econ.gold - gold)
	return econ


static func _test_open_rolls_five_equipment() -> bool:
	var deck := _make_deck(_make_unit())
	var econ := _make_economy(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	svc.open_shop()
	if svc.get_equipment_offers().size() != 5:
		return false
	## 本切片 open 不填充消耗品。
	if not svc.get_consumable_offers().is_empty():
		return false
	return true


static func _test_buy_consumable() -> bool:
	var unit := _make_unit()
	var deck := _make_deck(unit)
	var entry := deck.get_entries()[0]
	var econ := _make_economy(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var svc := MapShopService.new()
	var config := MapShopConfig.make_code_defaults()
	## 固定货架：只放大力药水。
	config.consumable_pool = [
		MapShopConfig._make_consumable("big_atk_potion", "大力量魔药", 2, 5, -1),
	]
	config.equipment_pool = []
	svc.configure(config, econ, deck, rng)
	svc.open_shop()
	## 强制第一槽为大力药（open 默认空消耗品）。
	svc._consumable_offers = [config.consumable_pool[0]]
	var atk_before := entry.bonus_attack
	var hp_before := entry.bonus_max_hp
	var gold_before := econ.gold
	var result := svc.try_buy_consumable_on_entry(0, entry.entry_id)
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if entry.bonus_attack != atk_before + 5:
		return false
	if entry.bonus_max_hp != hp_before - 1:
		return false
	if econ.gold != gold_before - 2:
		return false
	if svc.get_consumable_offer(0) != null:
		return false
	return true


## 1 血角色吃生命 −1：扣金、货架清空、角色离队（不退出售金）。
static func _test_consumable_destroys_at_zero_hp() -> bool:
	var unit := _make_unit("fragile")
	unit.stats.max_hp = 1
	unit.stats.attack = 1
	var deck := _make_deck(unit)
	var entry := deck.get_entries()[0]
	var entry_id := entry.entry_id
	var econ := _make_economy(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var svc := MapShopService.new()
	var config := MapShopConfig.make_code_defaults()
	config.consumable_pool = [
		MapShopConfig._make_consumable("big_atk_potion", "大力量魔药", 2, 5, -1),
	]
	config.equipment_pool = []
	svc.configure(config, econ, deck, rng)
	svc.open_shop()
	svc._consumable_offers = [config.consumable_pool[0]]
	var gold_before := econ.gold
	var result := svc.try_buy_consumable_on_entry(0, entry_id)
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if not bool(result.get("destroyed", false)):
		return false
	if result.get("entry", entry) != null:
		return false
	if deck.get_entry(entry_id) != null:
		return false
	if deck.get_entries().size() != 0:
		return false
	if econ.gold != gold_before - 2:
		return false
	if svc.get_consumable_offer(0) != null:
		return false
	return true


static func _test_cant_afford() -> bool:
	var unit := _make_unit()
	var deck := _make_deck(unit)
	var entry := deck.get_entries()[0]
	var econ := _make_economy(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var svc := MapShopService.new()
	var config := MapShopConfig.make_code_defaults()
	svc.configure(config, econ, deck, rng)
	svc.open_shop()
	svc._consumable_offers = [MapShopConfig._make_consumable("qunbolong", "群伯龙", 5, 10, -5)]
	var offer_before := svc.get_consumable_offer(0)
	var result := svc.try_buy_consumable_on_entry(0, entry.entry_id)
	if int(result.get("result", -1)) != MapShopService.BuyResult.FAILED:
		return false
	if String(result.get("reason", "")) != "cant_afford":
		return false
	if svc.get_consumable_offer(0) != offer_before:
		return false
	if econ.gold != 1:
		return false
	return true


static func _test_refresh() -> bool:
	var deck := _make_deck(_make_unit())
	var econ := _make_economy(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	svc.open_shop()
	var gold_before := econ.gold
	var result := svc.try_refresh()
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if econ.gold != gold_before - 2:
		return false
	if svc.get_equipment_offers().size() != 5:
		return false
	if not svc.get_consumable_offers().is_empty():
		return false
	return true


## 护甲再拖：新替旧，不退金。
static func _test_armor_replace() -> bool:
	var unit := _make_unit()
	var deck := _make_deck(unit)
	var entry := deck.get_entries()[0]
	var old_eq := MapShopConfig._make_equipment("armor_t1", "护甲 I", 1, 2)
	var new_eq := MapShopConfig._make_equipment("armor_t3", "护甲 III", 4, 10)
	entry.attach_equipment(old_eq)
	var econ := _make_economy(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	svc.open_shop()
	svc._equipment_offers[0] = new_eq
	var gold_before := econ.gold
	var result := svc.try_buy_equipment_on_entry(0, entry.entry_id)
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if econ.gold != gold_before - 4:
		return false
	if not bool(result.get("kept_new", false)):
		return false
	if entry.equipment == null or entry.equipment.id != new_eq.id:
		return false
	if entry.get_armor_block() != 10:
		return false
	return true


## 本职或已装同职纹章 → 拒装、不扣金、货架保留。
static func _test_emblem_reject_same_occupation() -> bool:
	var unit := _make_unit("w1", SynergyOccupations.WARRIOR)
	var deck := _make_deck(unit)
	var entry := deck.get_entries()[0]
	var warrior_em := MapShopConfig._make_equipment(
		"emblem_warrior", "战士纹章", 4, 0, MapShopConfig.ICON_ARMOR, SynergyOccupations.WARRIOR
	)
	var econ := _make_economy(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	svc.open_shop()
	svc._equipment_offers[0] = warrior_em
	var gold_before := econ.gold
	var result := svc.try_buy_equipment_on_entry(0, entry.entry_id)
	if int(result.get("result", -1)) != MapShopService.BuyResult.FAILED:
		return false
	if String(result.get("reason", "")) != "occupation_conflict":
		return false
	if econ.gold != gold_before:
		return false
	if svc.get_equipment_offer(0) != warrior_em:
		return false
	## 已装坦克纹章后再拖坦克 → 拒。
	var tank_em := MapShopConfig._make_equipment(
		"emblem_tank", "坦克纹章", 4, 0, MapShopConfig.ICON_ARMOR, SynergyOccupations.TANK
	)
	svc._equipment_offers[1] = tank_em
	var ok_buy := svc.try_buy_equipment_on_entry(1, entry.entry_id)
	if int(ok_buy.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	svc._equipment_offers[2] = tank_em
	var gold2 := econ.gold
	var reject2 := svc.try_buy_equipment_on_entry(2, entry.entry_id)
	if int(reject2.get("result", -1)) != MapShopService.BuyResult.FAILED:
		return false
	if String(reject2.get("reason", "")) != "occupation_conflict":
		return false
	if econ.gold != gold2:
		return false
	if svc.get_equipment_offer(2) != tank_em:
		return false
	return true


static func _test_emblem_attach_with_armor() -> bool:
	var unit := _make_unit("w2", SynergyOccupations.WARRIOR)
	var deck := _make_deck(unit)
	var entry := deck.get_entries()[0]
	var armor := MapShopConfig._make_equipment("armor_t2", "护甲 II", 2, 6)
	var tank_em := MapShopConfig._make_equipment(
		"emblem_tank", "坦克纹章", 4, 0, MapShopConfig.ICON_ARMOR, SynergyOccupations.TANK
	)
	var econ := _make_economy(30)
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	svc.open_shop()
	svc._equipment_offers[0] = armor
	svc._equipment_offers[1] = tank_em
	if int(svc.try_buy_equipment_on_entry(0, entry.entry_id).get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if int(svc.try_buy_equipment_on_entry(1, entry.entry_id).get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if entry.equipment == null or entry.get_armor_block() != 6:
		return false
	if entry.occupation_emblems.size() != 1:
		return false
	if not entry.has_occupation_tag(SynergyOccupations.WARRIOR):
		return false
	if not entry.has_occupation_tag(SynergyOccupations.TANK):
		return false
	var tags := entry.get_occupation_tags()
	if tags.size() != 2:
		return false
	return true


static func _test_triple_merge_equipment() -> bool:
	var unit := _make_unit("merge_u")
	var deck := _make_deck(unit, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	deck.set_rng(rng)
	var eq_a := MapShopConfig._make_equipment("armor_t1", "护甲 I", 1, 2)
	var eq_b := MapShopConfig._make_equipment("armor_t2", "护甲 II", 2, 6)
	var eq_c := MapShopConfig._make_equipment("armor_t3", "护甲 III", 4, 10)
	## restore_roster 不触发三合一，便于先挂装备再 merge。
	var a := DeckEntry.new()
	a.entry_id = 1
	a.unit = unit
	a.level = 1
	a.equipment = eq_a
	a.seat_index = 0
	a.seat_assign_seq = 1
	var b := DeckEntry.new()
	b.entry_id = 2
	b.unit = unit
	b.level = 1
	b.equipment = eq_b
	b.seat_index = 1
	b.seat_assign_seq = 2
	var c := DeckEntry.new()
	c.entry_id = 3
	c.unit = unit
	c.level = 1
	c.equipment = eq_c
	c.seat_index = 2
	c.seat_assign_seq = 3
	var copies: Array[DeckEntry] = [a, b, c]
	deck.restore_roster({
		"entries": copies,
		"next_entry_id": 4,
		"next_seat_seq": 3,
		"seat_cap_override": -1,
	})
	if not deck.try_auto_merge():
		return false
	if deck.size() != 1:
		return false
	var product: DeckEntry = deck.get_entries()[0]
	if product == null or product.equipment == null:
		return false
	var id := product.equipment.id
	return id == "armor_t1" or id == "armor_t2" or id == "armor_t3"


static func _test_triple_merge_emblems() -> bool:
	var unit := _make_unit("merge_em", SynergyOccupations.WARRIOR)
	var deck := _make_deck(unit, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	deck.set_rng(rng)
	var tank := MapShopConfig._make_equipment(
		"emblem_tank", "坦克纹章", 4, 0, MapShopConfig.ICON_ARMOR, SynergyOccupations.TANK
	)
	var ranged := MapShopConfig._make_equipment(
		"emblem_ranged", "远程纹章", 4, 0, MapShopConfig.ICON_ARMOR, SynergyOccupations.RANGED
	)
	var tank2 := MapShopConfig._make_equipment(
		"emblem_tank", "坦克纹章", 4, 0, MapShopConfig.ICON_ARMOR, SynergyOccupations.TANK
	)
	var a := DeckEntry.new()
	a.entry_id = 1
	a.unit = unit
	a.level = 1
	a.occupation_emblems.append(tank)
	a.seat_index = 0
	a.seat_assign_seq = 1
	var b := DeckEntry.new()
	b.entry_id = 2
	b.unit = unit
	b.level = 1
	b.occupation_emblems.append(ranged)
	b.seat_index = 1
	b.seat_assign_seq = 2
	var c := DeckEntry.new()
	c.entry_id = 3
	c.unit = unit
	c.level = 1
	c.occupation_emblems.append(tank2)
	c.seat_index = 2
	c.seat_assign_seq = 3
	var copies: Array[DeckEntry] = [a, b, c]
	deck.restore_roster({
		"entries": copies,
		"next_entry_id": 4,
		"next_seat_seq": 3,
		"seat_cap_override": -1,
	})
	if not deck.try_auto_merge():
		return false
	var product: DeckEntry = deck.get_entries()[0]
	if product == null:
		return false
	## 坦克去重 + 远程；本职战士不进纹章列表。
	if product.occupation_emblems.size() != 2:
		return false
	if not product.has_occupation_tag(SynergyOccupations.TANK):
		return false
	if not product.has_occupation_tag(SynergyOccupations.RANGED):
		return false
	if not product.has_occupation_tag(SynergyOccupations.WARRIOR):
		return false
	return true
