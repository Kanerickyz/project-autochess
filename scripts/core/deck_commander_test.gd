class_name DeckCommanderTest
extends RefCounted
## 指挥官入队：不占容量、不可卖/备战、可换座与强化。


static func run_all() -> bool:
	var ok := true
	ok = _check("ensure_seated_back_center", _test_ensure_seated_back_center()) and ok
	ok = _check("excluded_from_capacity", _test_excluded_from_capacity()) and ok
	ok = _check("unsellable_and_no_bench", _test_unsellable_and_no_bench()) and ok
	ok = _check("boost_bumps_run_hp", _test_boost_bumps_run_hp()) and ok
	ok = _check("roster_unit_count_ignores_commander", _test_roster_unit_count()) and ok
	ok = _check("hp_persists_across_set", _test_hp_persists_across_set()) and ok
	ok = _check("starter_empty_cap_two", _test_starter_empty_cap_two()) and ok
	return ok


static func _check(label: String, passed: bool) -> bool:
	if passed:
		print("  PASS %s" % label)
	else:
		push_error("DeckCommanderTest: FAIL %s" % label)
	return passed


static func _make_deck() -> DeckState:
	var config := DeckConfig.new()
	config.max_size = 2
	config.seat_rows = 4
	config.seat_cols = 5
	config.starting_units = []
	config.starting_unit = null
	config.starting_count = 0
	var deck := DeckState.new()
	deck.configure(config)
	deck.reset_from_config()
	return deck


static func _test_ensure_seated_back_center() -> bool:
	var deck := _make_deck()
	var cmd := deck.ensure_commander()
	if cmd == null or not cmd.is_commander():
		push_error("ensure: missing commander entry")
		return false
	var expect := SeatLayout.back_center_seat_index(deck.get_seat_cols(), deck.get_slot_count())
	if cmd.seat_index != expect:
		push_error("ensure: seat %d want back-center %d" % [cmd.seat_index, expect])
		return false
	if deck.ensure_commander().entry_id != cmd.entry_id:
		push_error("ensure: should be idempotent")
		return false
	return true


static func _test_excluded_from_capacity() -> bool:
	var deck := _make_deck()
	deck.ensure_commander()
	if deck.get_seated_count() != 0:
		push_error("capacity: commander should not count as seated")
		return false
	if not deck.can_seat_more():
		push_error("capacity: can_seat_more should ignore commander")
		return false
	var knight := load("res://resources/units/realtime/knight.tres") as UnitData
	var archer := load("res://resources/units/realtime/archer.tres") as UnitData
	if knight == null or archer == null:
		push_error("capacity: missing unit data")
		return false
	deck.add_entry(knight)
	deck.add_entry(archer)
	if deck.get_seated_count() != 2:
		push_error("capacity: seated want 2 got %d" % deck.get_seated_count())
		return false
	if deck.can_seat_more():
		push_error("capacity: max_size=2 should be full ignoring commander")
		return false
	if deck.get_commander_entry() == null or deck.get_commander_entry().seat_index < 0:
		push_error("capacity: commander must remain seated")
		return false
	return true


static func _test_unsellable_and_no_bench() -> bool:
	var deck := _make_deck()
	var cmd := deck.ensure_commander()
	if deck.try_place_on_bench(cmd.entry_id):
		push_error("bench: commander must not move to bench")
		return false
	if deck.remove_entry(cmd.entry_id):
		push_error("remove: commander must not be removable")
		return false
	var economy := RunEconomy.new()
	economy.reset()
	economy.grant(50)
	var session := RecruitSession.new()
	session.configure(null, deck, economy, RandomNumberGenerator.new())
	session.is_active = true
	var sell := session.try_sell(cmd.entry_id)
	if sell.get("ok", false) or String(sell.get("reason", "")) != "commander_unsellable":
		push_error("sell: want commander_unsellable, got %s" % str(sell))
		return false
	var empty := deck.find_first_empty_seat()
	if empty < 0 or not deck.swap_seats(cmd.entry_id, empty):
		push_error("swap: commander should be movable to empty seat")
		return false
	return true


static func _test_boost_bumps_run_hp() -> bool:
	var deck := _make_deck()
	var run_state := RunState.new()
	deck.set_run_state(run_state)
	var cmd := deck.ensure_commander()
	var before := deck.get_commander_current_hp()
	deck.add_bonus_max_hp(cmd, 5)
	var new_max := DeckUpgradeService.get_display_max_hp(cmd)
	if new_max != RunState.COMMANDER_MAX_HP + 5:
		push_error("boost: max hp want %d got %d" % [RunState.COMMANDER_MAX_HP + 5, new_max])
		return false
	if deck.get_commander_current_hp() != before + 5:
		push_error(
			"boost: current hp want %d got %d"
			% [before + 5, deck.get_commander_current_hp()]
		)
		return false
	if run_state.get_commander_hp(new_max) != before + 5:
		push_error("boost: RunState hp out of sync")
		return false
	return true


static func _test_roster_unit_count() -> bool:
	var deck := _make_deck()
	deck.ensure_commander()
	if deck.get_roster_unit_count() != 0 or deck.size() != 1:
		push_error("roster: commander-only should count 0 units")
		return false
	var knight := load("res://resources/units/realtime/knight.tres") as UnitData
	deck.add_entry(knight)
	if deck.get_roster_unit_count() != 1:
		push_error("roster: want 1 after add knight")
		return false
	return true


static func _test_hp_persists_across_set() -> bool:
	var deck := _make_deck()
	var run_state := RunState.new()
	deck.set_run_state(run_state)
	var cmd := deck.ensure_commander()
	var max_hp := DeckUpgradeService.get_display_max_hp(cmd)
	deck.set_commander_current_hp(maxi(1, max_hp - 37))
	if deck.get_commander_current_hp() != max_hp - 37:
		push_error("persist: deck current hp not saved")
		return false
	if run_state.get_commander_hp(max_hp) != max_hp - 37:
		push_error("persist: RunState not synced")
		return false
	## 模拟下场开战前 ensure：不得回满。
	deck.ensure_commander()
	if deck.get_commander_current_hp() != max_hp - 37:
		push_error("persist: ensure_commander restored hp")
		return false
	if DeckUpgradeService.get_display_current_hp(cmd) != max_hp - 37:
		push_error("persist: display current should stay damaged")
		return false
	if DeckUpgradeService.get_display_max_hp(cmd) != max_hp:
		push_error("persist: display max should stay full")
		return false
	return true


static func _test_starter_empty_cap_two() -> bool:
	var cfg := load("res://resources/deck/realtime_starter_deck.tres") as DeckConfig
	if cfg == null:
		push_error("starter: missing realtime_starter_deck")
		return false
	if cfg.max_size != 2:
		push_error("starter: max_size want 2 got %d" % cfg.max_size)
		return false
	if not cfg.starting_units.is_empty() or cfg.starting_count != 0:
		push_error("starter: should be empty roster")
		return false
	var deck := DeckState.new()
	deck.configure(cfg)
	deck.reset_from_config()
	deck.ensure_commander()
	if deck.get_roster_unit_count() != 0:
		push_error("starter: roster should be empty after reset+commander")
		return false
	if deck.get_max_size() != 2:
		push_error("starter: runtime max_size want 2")
		return false
	if DeckState.SEAT_CAP_HARD_MAX != 6:
		push_error("starter: hard max want 6")
		return false
	## 旗帜可扩到 6
	while deck.get_max_size() < DeckState.SEAT_CAP_HARD_MAX:
		if not deck.try_increase_seat_cap(1):
			push_error("starter: banner expand failed at %d" % deck.get_max_size())
			return false
	if deck.get_max_size() != 6 or not deck.is_seat_cap_maxed():
		push_error("starter: should reach hard max 6")
		return false
	return true
