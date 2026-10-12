class_name DrawServiceTest
extends RefCounted


static func run_all() -> bool:
	var ok := true
	ok = _test_draw_count_default() and ok
	ok = _test_draw_when_deck_smaller() and ok
	ok = _test_without_replacement() and ok
	ok = _test_wave_hand_is_subset_not_full_deck() and ok
	ok = _test_empty_deck() and ok
	return ok


static func _make_deck(unit_count: int) -> DeckState:
	var config := DeckConfig.new()
	config.max_size = maxi(unit_count, 1)
	config.draw_count = 5
	config.max_board_units = 5
	var unit := UnitData.new()
	unit.id = "test_unit"
	unit.display_name = "Test"
	config.starting_unit = unit
	config.starting_count = unit_count
	config.starting_units = []
	var deck := DeckState.new()
	deck.configure(config)
	deck.reset_from_config()
	return deck


static func _test_draw_count_default() -> bool:
	var deck := _make_deck(8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var hand := DrawService.draw_wave_hand(deck, 5, rng)
	if hand.size() != 5:
		push_error("DrawServiceTest: expected 5 cards, got %d" % hand.size())
		return false
	if deck.size() != 8:
		push_error("DrawServiceTest: constructed deck must stay size 8, got %d" % deck.size())
		return false
	return true


static func _test_draw_when_deck_smaller() -> bool:
	var deck := _make_deck(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hand := DrawService.draw_wave_hand(deck, 5, rng)
	if hand.size() != 3:
		push_error("DrawServiceTest: expected min(5,3)=3, got %d" % hand.size())
		return false
	return true


static func _test_without_replacement() -> bool:
	var deck := _make_deck(6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var hand := DrawService.draw_wave_hand(deck, 5, rng)
	var seen: Dictionary = {}
	for entry in hand:
		if entry == null:
			push_error("DrawServiceTest: null entry in hand")
			return false
		if seen.has(entry.entry_id):
			push_error("DrawServiceTest: duplicate entry_id %d (with replacement?)" % entry.entry_id)
			return false
		seen[entry.entry_id] = true
	if hand.size() != 5:
		push_error("DrawServiceTest: without-replacement draw size expected 5")
		return false
	return true


static func _test_wave_hand_is_subset_not_full_deck() -> bool:
	var deck := _make_deck(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var hand := DrawService.draw_wave_hand(deck, 5, rng)
	if hand.size() == deck.size():
		push_error("DrawServiceTest: wave hand must not equal full deck when deck > draw_count")
		return false
	var deck_ids: Dictionary = {}
	for entry in deck.get_entries():
		deck_ids[entry.entry_id] = true
	for entry in hand:
		if not deck_ids.has(entry.entry_id):
			push_error("DrawServiceTest: hand entry not in constructed deck")
			return false
	return true


static func _test_empty_deck() -> bool:
	var config := DeckConfig.new()
	config.max_size = 5
	config.draw_count = 5
	var deck := DeckState.new()
	deck.configure(config)
	deck.reset_from_config()
	var hand := DrawService.draw_wave_hand(deck, 5, null)
	if not hand.is_empty():
		push_error("DrawServiceTest: empty deck should draw empty hand")
		return false
	return true
