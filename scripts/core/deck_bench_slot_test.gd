class_name DeckBenchSlotTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_bench_slots_persist_order()
	_test_seat_to_bench_target_slot()
	_test_seat_bench_swap()
	_test_bench_swap()
	if _failures == 0:
		print("DeckBenchSlotTest: all tests passed")
	else:
		push_error("DeckBenchSlotTest: %d failure(s)" % _failures)
	return _failures == 0


static func _deck() -> DeckState:
	var deck := DeckState.new()
	var cfg := DeckConfig.new()
	cfg.max_size = 5
	cfg.seat_rows = 2
	cfg.seat_cols = 5
	cfg.max_board_units = 5
	deck.configure(cfg)
	return deck


static func _unit(id: String) -> UnitData:
	var data := UnitData.new()
	data.id = id
	data.stats = UnitStats.new()
	data.stats.attack = 1
	data.stats.max_hp = 2
	return data


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"DeckBenchSlotTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error("DeckBenchSlotTest FAIL: %s" % message)


static func _test_bench_slots_persist_order() -> void:
	var deck := _deck()
	var a := deck.add_entry(_unit("a"))
	var b := deck.add_entry(_unit("b"))
	_assert_true(a != null and b != null, "add two bench entries")
	_assert_true(deck.try_place_on_bench(a.entry_id, 2), "place a at slot 2")
	_assert_true(deck.try_place_on_bench(b.entry_id, 0), "place b at slot 0")
	_assert_eq(deck.get_entry_at_bench_slot(0).entry_id, b.entry_id, "slot 0 is b")
	_assert_eq(deck.get_entry_at_bench_slot(2).entry_id, a.entry_id, "slot 2 is a")


static func _test_seat_to_bench_target_slot() -> void:
	var deck := _deck()
	var e := deck.add_entry(_unit("knight"))
	_assert_true(e != null and e.seat_index >= 0, "knight seated")
	_assert_true(deck.try_place_on_bench(e.entry_id, 3), "seat to bench slot 3")
	_assert_eq(e.bench_slot_index, 3, "bench slot persisted")
	_assert_eq(e.seat_index, -1, "no longer seated")


static func _test_seat_bench_swap() -> void:
	var deck := _deck()
	var seated := deck.add_entry(_unit("s1"))
	var bench := deck.add_entry(_unit("s2"))
	_assert_true(seated != null and bench != null, "entries")
	_assert_true(deck.try_place_on_bench(bench.entry_id, 1), "bench at 1")
	var bench_id := bench.entry_id
	var seat_idx := seated.seat_index
	_assert_true(deck.try_place_on_bench(seated.entry_id, 1), "swap seat with bench occupant")
	_assert_eq(seated.bench_slot_index, 1, "seated now on bench 1")
	_assert_eq(deck.get_entry(bench_id).seat_index, seat_idx, "bench occupant took seat")


static func _test_bench_swap() -> void:
	var deck := _deck()
	var a := deck.add_entry(_unit("x"))
	var b := deck.add_entry(_unit("y"))
	_assert_true(deck.try_place_on_bench(a.entry_id, 0), "a at 0")
	_assert_true(deck.try_place_on_bench(b.entry_id, 4), "b at 4")
	_assert_true(deck.try_place_on_bench(a.entry_id, 4), "swap a to 4")
	_assert_eq(a.bench_slot_index, 4, "a moved to 4")
	_assert_eq(b.bench_slot_index, 0, "b moved to 0")
