class_name RosterBudgetTest
extends RefCounted


static func run_all() -> bool:
	var ok := true
	ok = _check("opening_remaining", _test_opening_remaining()) and ok
	ok = _check("occupy_and_release", _test_occupy_and_release()) and ok
	ok = _check("seed_gift_no_cost", _test_seed_gift_no_cost()) and ok
	ok = _check("starter_six_skeletons", _test_starter_six_skeletons()) and ok
	ok = _check("deck_seat_budget_gate", _test_deck_seat_budget_gate()) and ok
	ok = _check("auto_merge_off_by_default", _test_auto_merge_off_by_default()) and ok
	if ok:
		print("RosterBudgetTest: all passed")
	else:
		push_error("RosterBudgetTest: failures detected")
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("  PASS %s" % name)
	else:
		push_error("RosterBudgetTest: FAIL %s" % name)
	return passed


static func _test_opening_remaining() -> bool:
	var budget := RosterBudget.new()
	budget.reset()
	return (
		budget.get_remaining_atk() == RosterBudget.OPENING_ATK_REMAINING
		and budget.get_remaining_hp() == RosterBudget.OPENING_HP_REMAINING
	)


static func _test_occupy_and_release() -> bool:
	var budget := RosterBudget.new()
	budget.reset()
	if not budget.try_occupy(1, 1, 2):
		return false
	if budget.get_remaining_atk() != 1 or budget.get_remaining_hp() != 0:
		return false
	if budget.try_occupy(2, 1, 1):
		return false
	var released := budget.release(1)
	return (
		int(released.get("atk", 0)) == 1
		and int(released.get("hp", 0)) == 2
		and budget.get_remaining_atk() == 2
		and budget.get_remaining_hp() == 2
	)


static func _test_seed_gift_no_cost() -> bool:
	var budget := RosterBudget.new()
	budget.reset()
	budget.seed_occupy_without_cost(7, 1, 3)
	if budget.get_remaining_atk() != 2 or budget.get_remaining_hp() != 2:
		return false
	if not budget.is_occupying(7):
		return false
	budget.release(7)
	return budget.get_remaining_atk() == 3 and budget.get_remaining_hp() == 5


static func _test_starter_six_skeletons() -> bool:
	var config := load("res://resources/deck/realtime_starter_deck.tres") as DeckConfig
	if config == null:
		return false
	if config.starting_units.size() != 6:
		return false
	if config.max_size != 10:
		return false
	var deck := DeckState.new()
	deck.configure(config)
	deck.reset_from_config()
	if deck.size() != 6:
		return false
	if deck.get_seated_count() != 6:
		return false
	if deck.budget.get_remaining_atk() != 2 or deck.budget.get_remaining_hp() != 2:
		return false
	for entry in deck.get_entries():
		if entry == null or entry.unit == null:
			return false
		if entry.unit.stats.attack != 1 or entry.unit.stats.max_hp != 3:
			return false
		if not deck.budget.is_occupying(entry.entry_id):
			return false
	return true


static func _test_deck_seat_budget_gate() -> bool:
	var deck := DeckState.new()
	var cfg := DeckConfig.new()
	cfg.max_size = 10
	cfg.seat_rows = 2
	cfg.seat_cols = 5
	cfg.max_board_units = 10
	deck.configure(cfg)
	deck.reset_from_config()
	var unit := UnitData.new()
	unit.id = "tanky"
	unit.stats = UnitStats.new()
	unit.stats.attack = 1
	unit.stats.max_hp = 3
	var entry := deck.add_entry(unit)
	## 开局 2/2，1/3 入座失败 → 备战。
	if entry == null or entry.seat_index >= 0:
		return false
	deck.budget.grant_hp(1)
	if not deck.assign_seat(entry.entry_id, 0):
		return false
	return (
		entry.seat_index == 0
		and deck.budget.get_remaining_atk() == 1
		and deck.budget.get_remaining_hp() == 0
	)


static func _test_auto_merge_off_by_default() -> bool:
	var deck := DeckState.new()
	var cfg := DeckConfig.new()
	cfg.max_size = 10
	deck.configure(cfg)
	deck.budget.grant_atk(50)
	deck.budget.grant_hp(50)
	var unit := UnitData.new()
	unit.id = "same"
	unit.stats = UnitStats.new()
	unit.stats.attack = 1
	unit.stats.max_hp = 1
	deck.add_entry(unit)
	deck.add_entry(unit)
	deck.add_entry(unit)
	if deck.size() != 3:
		return false
	if deck.try_auto_merge():
		return false
	return deck.size() == 3
