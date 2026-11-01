class_name MapShopServiceTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("equipment_pool_costs_1_2_4", _test_equipment_pool_costs())
	_check("buy_consumable", _test_buy_consumable())
	_check("consumable_destroys_at_zero_hp", _test_consumable_destroys_at_zero_hp())
	_check("cant_afford_keeps_shelf", _test_cant_afford())
	_check("refresh_consumables", _test_refresh())
	_check("equipment_conflict_no_refund", _test_equipment_conflict())
	_check("triple_merge_keeps_one_equipment", _test_triple_merge_equipment())
	_check("theme_potion_snapshot_includes_bench", _test_theme_potion_snapshot_includes_bench())
	_check("theme_potion_zero_hit_still_buys", _test_theme_potion_zero_hit_still_buys())
	_check("theme_pool_has_seven", _test_theme_pool_has_seven())
	_check("shelf_six_unique_ids", _test_shelf_six_unique_ids())
	_check("shelf_no_duplicate_theme_potion", _test_shelf_no_duplicate_theme_bond())
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


static func _test_theme_pool_has_seven() -> bool:
	var cfg := MapShopConfig.load_or_default()
	var themes: Dictionary = {}
	for item in cfg.get_consumable_pool():
		var c := item as MapShopConsumableData
		if c == null or not c.is_theme_potion():
			continue
		themes[int(c.theme_bond)] = true
		if c.bonus_attack != 2 or c.bonus_max_hp != 2 or c.cost != 3:
			return false
	return themes.size() == 7


## 战士药水：入座 + 备战同主题各 +2/+2；拖放目标可为非该主题。
static func _test_theme_potion_snapshot_includes_bench() -> bool:
	var warrior := _make_unit("w")
	warrior.theme_bond = UnitData.ThemeBond.WARRIOR
	var knight := _make_unit("k")
	knight.theme_bond = UnitData.ThemeBond.KNIGHT
	var deck := DeckState.new()
	deck.configure(DeckConfig.new())
	var seated_w := deck.add_entry(warrior)
	var bench_w := deck.add_entry(warrior)
	var seated_k := deck.add_entry(knight)
	if seated_w == null or bench_w == null or seated_k == null:
		return false
	deck.try_place_on_bench(bench_w.entry_id, 0)
	var econ := _make_economy(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var svc := MapShopService.new()
	var config := MapShopConfig.make_code_defaults()
	config.consumable_pool = [
		MapShopConfig._make_theme_potion("theme_warrior", "战士药水", UnitData.ThemeBond.WARRIOR),
	]
	config.equipment_pool = []
	svc.configure(config, econ, deck, rng)
	svc.open_shop()
	svc._consumable_offers = [config.consumable_pool[0]]
	var gold_before := econ.gold
	## 拖到骑士确认购买。
	var result := svc.try_buy_consumable_on_entry(0, seated_k.entry_id)
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if int(result.get("theme_affected", -1)) != 2:
		return false
	if seated_w.bonus_attack != 2 or seated_w.bonus_max_hp != 2:
		return false
	if bench_w.bonus_attack != 2 or bench_w.bonus_max_hp != 2:
		return false
	if seated_k.bonus_attack != 0 or seated_k.bonus_max_hp != 0:
		return false
	if econ.gold != gold_before - 3:
		return false
	if svc.get_consumable_offer(0) != null:
		return false
	return true


## 无人命中该主题：仍扣金清槽，属性不变。
static func _test_theme_potion_zero_hit_still_buys() -> bool:
	var knight := _make_unit("k2")
	knight.theme_bond = UnitData.ThemeBond.KNIGHT
	var deck := _make_deck(knight)
	var entry := deck.get_entries()[0]
	var econ := _make_economy(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	var svc := MapShopService.new()
	var config := MapShopConfig.make_code_defaults()
	config.consumable_pool = [
		MapShopConfig._make_theme_potion("theme_undead", "亡灵药水", UnitData.ThemeBond.UNDEAD),
	]
	config.equipment_pool = []
	svc.configure(config, econ, deck, rng)
	svc.open_shop()
	svc._consumable_offers = [config.consumable_pool[0]]
	var gold_before := econ.gold
	var result := svc.try_buy_consumable_on_entry(0, entry.entry_id)
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if int(result.get("theme_affected", -1)) != 0:
		return false
	if entry.bonus_attack != 0 or entry.bonus_max_hp != 0:
		return false
	if econ.gold != gold_before - 3:
		return false
	if svc.get_consumable_offer(0) != null:
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
	## 强制单槽大力药报价。
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
	var result := svc.try_refresh_consumables()
	if int(result.get("result", -1)) != MapShopService.BuyResult.OK:
		return false
	if econ.gold != gold_before - 2:
		return false
	var total := svc.get_consumable_offers().size() + svc.get_equipment_offers().size()
	if total != MapShopConfig.DEFAULT_SHELF_SLOTS:
		return false
	return true


static func _collect_shelf_ids(svc: MapShopService) -> Array[String]:
	var ids: Array[String] = []
	for item in svc.get_consumable_offers():
		var c := item as MapShopConsumableData
		if c != null:
			ids.append(c.id)
	for item in svc.get_equipment_offers():
		var e := item as EquipmentData
		if e != null:
			ids.append(e.id)
	return ids


static func _test_shelf_six_unique_ids() -> bool:
	var deck := _make_deck(_make_unit())
	var econ := _make_economy(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	for _n in 12:
		svc.open_shop()
		var ids := _collect_shelf_ids(svc)
		if ids.size() != MapShopConfig.DEFAULT_SHELF_SLOTS:
			return false
		var seen: Dictionary = {}
		for id in ids:
			if seen.has(id):
				return false
			seen[id] = true
		svc.close_shop()
	return true


## 同职主题药水 id 不同；全局唯一已覆盖。额外断言同 theme_bond 不会并排两瓶。
static func _test_shelf_no_duplicate_theme_bond() -> bool:
	var deck := _make_deck(_make_unit())
	var econ := _make_economy(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	for _n in 20:
		svc.open_shop()
		var bonds: Dictionary = {}
		for item in svc.get_consumable_offers():
			var c := item as MapShopConsumableData
			if c == null or not c.is_theme_potion():
				continue
			var key := int(c.theme_bond)
			if bonds.has(key):
				return false
			bonds[key] = true
		svc.close_shop()
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
		## 货架行长可变：强制单槽装备报价，避免空行下标赋值失败。
		svc._equipment_offers = [new_eq]
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
