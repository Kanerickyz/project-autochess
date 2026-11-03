class_name DayLoopTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("schedule_step_order", _test_schedule_step_order())
	_check("schedule_recruit_picks_6_then_1", _test_recruit_picks())
	_check("schedule_battle_index", _test_battle_index())
	_check("schedule_boss_only_day15_third", _test_boss_only_last())
	_check("schedule_finishes_after_15_days", _test_finishes())
	_check("shop_category_by_source_unit", _test_category_by_source_unit())
	_check("shop_pools_partition_equipment", _test_pools_partition())
	_check("shop_roll_offers_unique", _test_roll_offers_unique())
	_check("buy_equipment_goes_to_stash", _test_buy_to_stash())
	_check("buy_equipment_cant_afford_no_charge", _test_buy_cant_afford())
	_check("commander_one_slot_30hp", _test_commander())
	if _failures == 0:
		print("DayLoopTest: all tests passed")
	else:
		push_error("DayLoopTest: %d failure(s)" % _failures)
	return _failures == 0


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("DayLoopTest FAIL: %s" % name)


static func _test_schedule_step_order() -> bool:
	var s := DayRunSchedule.new()
	var got: Array = []
	for _i in s.get_steps_per_day():
		got.append(s.get_step())
		s.advance()
	var want: Array = [
		DayRunSchedule.Step.RECRUIT,
		DayRunSchedule.Step.COMBAT,
		DayRunSchedule.Step.SHOP,
		DayRunSchedule.Step.COMBAT,
		DayRunSchedule.Step.EVENT,
		DayRunSchedule.Step.COMBAT,
	]
	return got == want and s.get_day() == 2 and s.get_step_index() == 0


static func _test_recruit_picks() -> bool:
	var s := DayRunSchedule.new()
	if s.get_recruit_pick_count() != 6 or s.can_skip_recruit():
		return false
	for _i in s.get_steps_per_day():
		s.advance()
	return s.get_recruit_pick_count() == 1 and s.can_skip_recruit()


static func _test_battle_index() -> bool:
	var s := DayRunSchedule.new()
	var seen: Array = []
	for _i in s.get_steps_per_day():
		if s.get_step() == DayRunSchedule.Step.COMBAT:
			seen.append(s.get_battle_index())
		s.advance()
	return seen == [1, 2, 3] and s.get_battles_per_day() == 3


static func _test_boss_only_last() -> bool:
	var s := DayRunSchedule.new()
	var boss_hits := 0
	var boss_day := -1
	var boss_battle := -1
	while not s.is_finished():
		if s.is_boss_battle():
			boss_hits += 1
			boss_day = s.get_day()
			boss_battle = s.get_battle_index()
		s.advance()
	return boss_hits == 1 and boss_day == 15 and boss_battle == 3


static func _test_finishes() -> bool:
	var s := DayRunSchedule.new()
	var new_days := 0
	var guard := 0
	while not s.is_finished() and guard < 1000:
		if s.advance():
			new_days += 1
		guard += 1
	return new_days == 15 and guard == 15 * s.get_steps_per_day()


static func _make_skill(unit_id: String) -> EquipmentData:
	var e := EquipmentData.new()
	e.id = "skill_%s" % unit_id
	e.kind = EquipmentData.Kind.ABILITY
	return e


static func _test_category_by_source_unit() -> bool:
	var armor := EquipmentData.new()
	armor.id = "armor_test"
	armor.kind = EquipmentData.Kind.ARMOR
	return (
		DayShopCatalog.category_of_equipment(armor) == DayShopCatalog.Category.ARMORY
		and DayShopCatalog.category_of_equipment(_make_skill("archer"))
		== DayShopCatalog.Category.RANGED
		and DayShopCatalog.category_of_equipment(_make_skill("arcane"))
		== DayShopCatalog.Category.MAGIC
		and DayShopCatalog.category_of_equipment(_make_skill("knight"))
		== DayShopCatalog.Category.ARMORY
	)


static func _test_pools_partition() -> bool:
	var cfg := MapShopConfig.load_or_default()
	var total := 0
	var ids: Dictionary = {}
	for cat in [
		DayShopCatalog.Category.ARMORY,
		DayShopCatalog.Category.RANGED,
		DayShopCatalog.Category.MAGIC,
	]:
		for item in DayShopCatalog.pool_for(cat, cfg):
			var eq := item as EquipmentData
			if eq == null or ids.has(eq.id):
				return false
			ids[eq.id] = true
			total += 1
	var eq_count := 0
	for e in cfg.get_equipment_pool():
		if e != null:
			eq_count += 1
	var consumables := DayShopCatalog.pool_for(DayShopCatalog.Category.CONSUMABLE, cfg)
	for c in consumables:
		if not c is MapShopConsumableData:
			return false
	return total == eq_count and eq_count > 0 and not consumables.is_empty()


static func _test_roll_offers_unique() -> bool:
	var cfg := MapShopConfig.load_or_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var offers := DayShopCatalog.roll_offers(DayShopCatalog.Category.ARMORY, cfg, rng)
	var pool_size := DayShopCatalog.pool_for(DayShopCatalog.Category.ARMORY, cfg).size()
	if offers.size() != mini(DayShopCatalog.DEFAULT_OFFER_COUNT, pool_size):
		return false
	var seen: Dictionary = {}
	for o in offers:
		if seen.has(o):
			return false
		seen[o] = true
	return true


static func _make_deck() -> DeckState:
	var config := DeckConfig.new()
	config.max_size = 10
	config.starting_units = []
	var deck := DeckState.new()
	deck.configure(config)
	var unit := UnitData.new()
	unit.id = "u1"
	unit.display_name = "u1"
	unit.stats = UnitStats.new()
	unit.stats.attack = 2
	unit.stats.max_hp = 10
	deck.add_entry(unit)
	return deck


static func _make_economy(gold: int) -> RunEconomy:
	var econ := RunEconomy.new()
	econ.configure(load("res://resources/economy/default_economy.tres") as EconomyConfig)
	econ.reset()
	while econ.gold < gold:
		econ.grant(gold - econ.gold)
	while econ.gold > gold:
		econ.spend(econ.gold - gold)
	return econ


static func _make_armor(cost: int) -> EquipmentData:
	var e := EquipmentData.new()
	e.id = "armor_test_%d" % cost
	e.kind = EquipmentData.Kind.ARMOR
	e.cost = cost
	return e


static func _test_buy_to_stash() -> bool:
	var deck := _make_deck()
	var econ := _make_economy(5)
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck)
	svc.open_with_offers([], [_make_armor(2)])
	var res := svc.try_buy_equipment_to_stash(0)
	return (
		int(res.get("result", -1)) == MapShopService.BuyResult.OK
		and econ.gold == 3
		and deck.get_equipment_stash_count() == 1
		and svc.get_equipment_offer(0) == null
		and deck.get_entries()[0].get_equipment_occupied() == 0
	)


static func _test_buy_cant_afford() -> bool:
	var deck := _make_deck()
	var econ := _make_economy(1)
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck)
	svc.open_with_offers([], [_make_armor(4)])
	var res := svc.try_buy_equipment_to_stash(0)
	return (
		str(res.get("reason", "")) == "cant_afford"
		and econ.gold == 1
		and deck.get_equipment_stash_count() == 0
		and svc.get_equipment_offer(0) != null
	)


static func _test_commander() -> bool:
	var unit := load("res://resources/units/realtime/commander.tres") as UnitData
	if unit == null or unit.stats.max_hp != 30 or unit.stats.attack != 2:
		return false
	var deck := DeckState.new()
	var config := DeckConfig.new()
	config.max_size = 10
	config.starting_units = []
	deck.configure(config)
	var entry := deck.add_entry(unit)
	return entry != null and entry.is_commander() and entry.get_equipment_slot_count() == 1
