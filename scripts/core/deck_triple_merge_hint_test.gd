class_name DeckTripleMergeHintTest
extends RefCounted

const ARCHER := preload("res://resources/units/realtime/archer.tres")


static func run_all() -> bool:
	var ok := true
	ok = _check("bench_pair_hints", _test_bench_pair_hints()) and ok
	ok = _check("bench_only_one_of_pair", _test_bench_only_one_of_pair()) and ok
	ok = _check("clears_after_merge", _test_clears_after_merge()) and ok
	if ok:
		print("DeckTripleMergeHintTest: all passed")
	else:
		push_error("DeckTripleMergeHintTest: failures detected")
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("  PASS %s" % name)
	else:
		push_error("DeckTripleMergeHintTest: FAIL %s" % name)
	return passed


static func _empty_deck() -> DeckState:
	var deck := DeckState.new()
	var cfg := DeckConfig.new()
	cfg.max_size = 5
	cfg.seat_rows = 2
	cfg.seat_cols = 5
	cfg.max_board_units = 5
	deck.configure(cfg)
	return deck


static func _test_bench_pair_hints() -> bool:
	var deck := _empty_deck()
	deck.add_entry(ARCHER, 0, -1, true)
	deck.add_entry(ARCHER, 0, -1, true)
	var hints := deck.get_bench_triple_merge_hint_entry_ids()
	return hints.size() == 2


static func _test_bench_only_one_of_pair() -> bool:
	var deck := _empty_deck()
	deck.add_entry(ARCHER, 0, -1, true)
	deck.add_entry(ARCHER)
	var hints := deck.get_bench_triple_merge_hint_entry_ids()
	return hints.size() == 1


static func _test_clears_after_merge() -> bool:
	var deck := _empty_deck()
	deck.add_entry(ARCHER, 0, -1, true)
	deck.add_entry(ARCHER, 0, -1, true)
	deck.add_entry(ARCHER, 0, -1, true)
	return deck.get_bench_triple_merge_hint_entry_ids().is_empty() and deck.size() == 1
