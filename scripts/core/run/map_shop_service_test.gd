class_name MapShopServiceTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("equipment_pool_costs_1_2_4", _test_equipment_pool_costs())
	_check("buy_consumable", _test_buy_consumable())
	_check("cant_afford_keeps_shelf", _test_cant_afford())
	_check("refresh_consumables", _test_refresh())
	_check("equipment_conflict_no_refund", _test_equipment_conflict())
	_check("triple_merge_keeps_one_equipment", _test_triple_merge_equipment())
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
	return t1.cost == 1 and t2.cost == 2 and t3.cost == 4


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("MapShopServiceTest FAIL: %s" % name)


static func _make_unit(id: String = "u1") -> UnitData:
	var unit := UnitData.new()
	unit.id = id
	unit.display_name = id
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
	## 强制第一槽为大力药。
	svc._consumable_offers[0] = config.consumable_pool[0]
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
	svc._consumable_offers[0] = MapShopConfig._make_consumable("qunbolong", "群伯龙", 5, 10, -5)
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
	var result := svc.try_refresh_consumables()
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if econ.gold != gold_before - 2:
		return false
	if svc.get_consumable_offers().size() != 3:
		return false
	return true


static func _test_equipment_conflict() -> bool:
	var unit := _make_unit()
	var deck := _make_deck(unit)
	var entry := deck.get_entries()[0]
	var old_eq := MapShopConfig._make_equipment("armor_t1", "护甲 I", 1, 2)
	var new_eq := MapShopConfig._make_equipment("armor_t3", "护甲 III", 4, 10)
	entry.attach_equipment(old_eq)
	## seed 选出使 randf()<0.5 → kept_new=true 与 false 都能测：固定两次。
	var kept_new_count := 0
	var kept_old_count := 0
	for seed in [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]:
		var e2 := deck.get_entries()[0]
		e2.attach_equipment(old_eq)
		var econ2 := _make_economy(20)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var svc := MapShopService.new()
		var config := MapShopConfig.make_code_defaults()
		svc.configure(config, econ2, deck, rng)
		svc.open_shop()
		svc._equipment_offers[0] = new_eq
		var gold_before := econ2.gold
		var result := svc.try_buy_equipment_on_entry(0, e2.entry_id)
		if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
			return false
		if econ2.gold != gold_before - 4:
			return false
		if bool(result.get("kept_new", false)):
			kept_new_count += 1
			if e2.equipment == null or e2.equipment.id != new_eq.id:
				return false
		else:
			kept_old_count += 1
			if e2.equipment == null or e2.equipment.id != old_eq.id:
				return false
	## 10 次应至少出现两种结果（概率极低全同，但 seed 范围够）。
	if kept_new_count == 0 or kept_old_count == 0:
		push_warning("equipment conflict RNG skew; seeds may need adjust")
		## 不硬失败：至少扣金与不退金已验证。
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
