class_name RecruitShopFloorGoldTest
extends RefCounted
## 招募商店道具、席位旗帜、层结算金、击杀掉金空操作。


static func run_all() -> bool:
	var ok := true
	ok = _check("floor_gold_amount", _test_floor_gold_amount()) and ok
	ok = _check("grant_floor_gold", _test_grant_floor_gold()) and ok
	ok = _check("kill_gold_noop", _test_kill_gold_noop()) and ok
	ok = _check("seat_cap_banner", _test_seat_cap_banner()) and ok
	ok = _check("recruit_shop_potion", _test_recruit_shop_potion()) and ok
	ok = _check("banner_excluded_at_cap10", _test_banner_excluded_at_cap10()) and ok
	ok = _check("recruit_candidate_count_default_5", _test_recruit_candidate_count_default_5()) and ok
	if ok:
		print("RecruitShopFloorGoldTest: all passed")
	else:
		push_error("RecruitShopFloorGoldTest: failures detected")
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("  PASS %s" % name)
	else:
		push_error("RecruitShopFloorGoldTest: FAIL %s" % name)
	return passed


static func _make_unit(id: String, cost: int = 1) -> UnitData:
	var stats := UnitStats.new()
	stats.max_hp = 10
	stats.attack = 2
	stats.attack_interval = 1.0
	var data := UnitData.new()
	data.id = id
	data.display_name = id
	data.cost = cost
	data.tier = 1
	data.stats = stats
	data.team_default = UnitInstance.Team.PLAYER
	return data


static func _make_deck(max_size: int = 5) -> DeckState:
	var config := DeckConfig.new()
	config.max_size = max_size
	config.seat_rows = 2
	config.seat_cols = 5
	config.max_board_units = max_size
	config.starting_count = 0
	var deck := DeckState.new()
	deck.configure(config)
	deck.reset_from_config()
	return deck


static func _make_economy(gold: int) -> RunEconomy:
	var econ := RunEconomy.new()
	var cfg := EconomyConfig.new()
	cfg.starting_gold = gold
	econ.configure(cfg)
	econ.reset()
	return econ


static func _test_floor_gold_amount() -> bool:
	if RunEconomy.resolve_floor_gold_amount(1) != 1:
		return false
	if RunEconomy.resolve_floor_gold_amount(3) != 3:
		return false
	## 0-based 下标兼容 → 第 1 层
	if RunEconomy.resolve_floor_gold_amount(0) != 1:
		return false
	if RunEconomy.resolve_floor_gold_amount(-2) != 0:
		return false
	return true


static func _test_grant_floor_gold() -> bool:
	var econ := _make_economy(0)
	var got := econ.grant_floor_gold(2)
	return got == 2 and econ.gold == 2


static func _test_kill_gold_noop() -> bool:
	var econ := _make_economy(5)
	var unit := _make_unit("x", 1)
	unit.kill_gold_reward = 99
	econ.grant_kill_gold(unit)
	return econ.gold == 5


static func _test_seat_cap_banner() -> bool:
	var deck := _make_deck(5)
	if deck.get_max_size() != 5:
		return false
	if not deck.try_increase_seat_cap(1):
		return false
	if deck.get_max_size() != 6:
		return false
	## 升到 10
	while deck.get_max_size() < 10:
		if not deck.try_increase_seat_cap(1):
			return false
	if not deck.is_seat_cap_maxed():
		return false
	if deck.try_increase_seat_cap(1):
		return false
	return deck.get_max_size() == 10


static func _test_recruit_shop_potion() -> bool:
	var unit := _make_unit("hero", 1)
	var deck := _make_deck(5)
	var entry := deck.add_entry(unit)
	if entry == null:
		return false
	var hp_before := entry.bonus_max_hp
	var atk_before := entry.bonus_attack
	var cfg := RecruitShopConfig.make_code_defaults()
	var econ := _make_economy(10)
	var shop := RecruitShopService.new()
	shop.configure(cfg, econ)
	shop.open_shop(deck)
	var hp_slot := -1
	var atk_slot := -1
	var items := shop.get_item_offers()
	for i in items.size():
		var it: PrepareItemData = items[i]
		if it == null:
			continue
		if it.item_type == PrepareItemData.ItemType.HP_POTION:
			hp_slot = i
		elif it.item_type == PrepareItemData.ItemType.ATK_POTION:
			atk_slot = i
	if hp_slot < 0 or atk_slot < 0:
		return false
	var r1 := shop.try_buy_potion_on_entry(hp_slot, deck, entry.entry_id)
	var r2 := shop.try_buy_potion_on_entry(atk_slot, deck, entry.entry_id)
	if int(r1.get("result", -1)) != RecruitShopService.BuyResult.OK:
		return false
	if int(r2.get("result", -1)) != RecruitShopService.BuyResult.OK:
		return false
	return entry.bonus_max_hp == hp_before + 1 and entry.bonus_attack == atk_before + 1


static func _test_banner_excluded_at_cap10() -> bool:
	var deck := _make_deck(10)
	## 强制 override 到 10
	while not deck.is_seat_cap_maxed():
		deck.try_increase_seat_cap(1)
	var cfg := RecruitShopConfig.make_code_defaults()
	var econ := _make_economy(20)
	var shop := RecruitShopService.new()
	shop.configure(cfg, econ)
	shop.open_shop(deck)
	for item in shop.get_item_offers():
		if item != null and item.item_type == PrepareItemData.ItemType.BANNER:
			return false
	return true


static func _test_recruit_candidate_count_default_5() -> bool:
	if RecruitSession.CANDIDATE_COUNT != 5:
		return false
	if RecruitConfig.DEFAULT_CANDIDATE_COUNT != 5:
		return false
	var cfg := RecruitConfig.new()
	if cfg.get_candidate_count() != 5:
		return false
	var session := RecruitSession.new()
	var deck := _make_deck(5)
	var econ := _make_economy(20)
	var unit := _make_unit("pool", 1)
	cfg.unit_pool = [unit]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	session.configure(cfg, deck, econ, rng)
	session.begin(0.0)
	return session.get_candidates().size() == 5
