class_name VictoryBoostSessionTest
extends RefCounted
## VictoryBoostSession 规则烟测（轻量；非强制完全验收）。

const ARCHER := preload("res://resources/units/realtime/archer.tres")


static func run_all() -> bool:
	var passed := true
	passed = _test_amount_by_tier() and passed
	passed = _test_apply_writes_bonus() and passed
	passed = _test_skip_no_change() and passed
	passed = _test_empty_roster() and passed
	if passed:
		print("VictoryBoostSessionTest: all passed")
	else:
		push_error("VictoryBoostSessionTest: failures detected")
	return passed


static func _test_amount_by_tier() -> bool:
	## 层 1 → T1 → +1；层 4 → T2 → +2；倒数 6 层 / 无尽 10 → T3 → +3。
	if VictoryBoostSession.compute_boost_amount(1, 15, false) != 1:
		push_error("victory_boost: floor1 amount != 1")
		return false
	if VictoryBoostSession.compute_boost_amount(4, 15, false) != 2:
		push_error("victory_boost: floor4 amount != 2")
		return false
	if VictoryBoostSession.compute_boost_amount(10, 15, false) != 3:
		push_error("victory_boost: late band amount != 3")
		return false
	if VictoryBoostSession.compute_boost_amount(10, 30, true) != 3:
		push_error("victory_boost: endless forward T3 amount != 3")
		return false
	return true


static func _make_deck(units: Array) -> DeckState:
	var deck := DeckState.new()
	var deck_config := DeckConfig.new()
	deck_config.max_size = 5
	deck_config.seat_rows = 2
	deck_config.seat_cols = 5
	deck_config.max_board_units = 5
	deck.configure(deck_config)
	for unit in units:
		if unit is UnitData:
			deck.add_entry(unit as UnitData)
	return deck


static func _test_apply_writes_bonus() -> bool:
	var deck := _make_deck([ARCHER])
	if deck.size() <= 0:
		push_error("victory_boost: no unit for apply test")
		return false
	var entry := deck.get_entries()[0] as DeckEntry
	var atk0 := entry.bonus_attack
	var hp0 := entry.bonus_max_hp
	var session := VictoryBoostSession.new()
	session.configure(deck, 4, 15, false)
	session.begin()
	if session.boost_amount != 2:
		push_error("victory_boost: expected amount 2 at floor4")
		return false
	if not session.select_entry(entry.entry_id):
		push_error("victory_boost: select failed")
		return false
	if not session.apply_boost():
		push_error("victory_boost: apply failed")
		return false
	if entry.bonus_attack != atk0 + 2 or entry.bonus_max_hp != hp0 + 2:
		push_error("victory_boost: bonus not written")
		return false
	if session.can_confirm():
		push_error("victory_boost: should not confirm again after apply")
		return false
	return true


static func _test_skip_no_change() -> bool:
	var deck := _make_deck([ARCHER])
	if deck.size() <= 0:
		push_error("victory_boost: no unit for skip test")
		return false
	var entry := deck.get_entries()[0] as DeckEntry
	var atk0 := entry.bonus_attack
	var hp0 := entry.bonus_max_hp
	var session := VictoryBoostSession.new()
	session.configure(deck, 1, 15, false)
	session.begin()
	session.select_entry(entry.entry_id)
	session.skip()
	if entry.bonus_attack != atk0 or entry.bonus_max_hp != hp0:
		push_error("victory_boost: skip mutated stats")
		return false
	if session.is_active:
		push_error("victory_boost: still active after skip")
		return false
	return true


static func _test_empty_roster() -> bool:
	var deck := _make_deck([])
	var session := VictoryBoostSession.new()
	session.configure(deck, 1, 15, false)
	session.begin()
	if session.has_boostable_roster():
		push_error("victory_boost: empty deck should not be boostable")
		return false
	return true
