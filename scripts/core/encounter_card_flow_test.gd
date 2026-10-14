extends RefCounted
## Headless checks for EncounterCardFlow (optional; light verify does not require).


static func run_all() -> bool:
	var ok := true
	ok = _test_begin_draws_hand_with_cooldown() and ok
	ok = _test_play_moves_to_discard_and_refills() and ok
	ok = _test_reshuffle_when_draw_empty() and ok
	ok = _test_allows_replay_same_entry() and ok
	return ok


static func _make_deck(count: int) -> DeckState:
	var config := DeckConfig.new()
	config.hand_width = 4
	config.enter_hand_cooldown = 1.0
	config.max_size = 40
	var deck := DeckState.new()
	deck.configure(config)
	var unit := UnitData.new()
	unit.id = "test_unit"
	unit.display_name = "试作"
	unit.stats = UnitStats.new()
	for _i in count:
		deck.add_entry(unit)
	return deck


static func _test_begin_draws_hand_with_cooldown() -> bool:
	var deck := _make_deck(8)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	flow.begin_from_deck(deck, rng)
	if flow.get_hand().size() != 4:
		push_error("begin: expected hand 4, got %d" % flow.get_hand().size())
		return false
	if flow.get_draw_count() != 4:
		push_error("begin: expected draw 4, got %d" % flow.get_draw_count())
		return false
	var first := flow.get_hand()[0]
	if flow.is_ready(first.entry_id):
		push_error("begin: hand cards should start on cooldown")
		return false
	flow.tick(1.0)
	if not flow.is_ready(first.entry_id):
		push_error("begin: card should be ready after 1s cooldown")
		return false
	return true


static func _test_play_moves_to_discard_and_refills() -> bool:
	var deck := _make_deck(6)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	flow.enter_hand_cooldown = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	flow.begin_from_deck(deck, rng)
	var played_id := flow.get_hand()[0].entry_id
	var entry := flow.try_play(played_id)
	if entry == null or entry.entry_id != played_id:
		push_error("play: failed to play ready card")
		return false
	if flow.get_discard_count() != 1:
		push_error("play: discard should be 1")
		return false
	if flow.get_hand().size() != 4:
		push_error("play: hand should refill to 4, got %d" % flow.get_hand().size())
		return false
	if flow.is_in_hand(played_id):
		push_error("play: played card should leave hand")
		return false
	return true


static func _test_reshuffle_when_draw_empty() -> bool:
	var deck := _make_deck(4)
	var flow := EncounterCardFlow.new()
	flow.hand_width = 4
	flow.enter_hand_cooldown = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	flow.begin_from_deck(deck, rng)
	if flow.get_draw_count() != 0:
		push_error("reshuffle setup: draw should be empty")
		return false
	var first_id := flow.get_hand()[0].entry_id
	flow.try_play(first_id)
	# After playing last draw-empty deck, discard washes back so hand stays full.
	if flow.get_hand().size() != 4:
		push_error("reshuffle: expected hand refill via discard wash, got %d" % flow.get_hand().size())
		return false
	return true


static func _test_allows_replay_same_entry() -> bool:
	var deck := _make_deck(1)
	var flow := EncounterCardFlow.new()
	flow.hand_width = 1
	flow.enter_hand_cooldown = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	flow.begin_from_deck(deck, rng)
	var entry_id := flow.get_hand()[0].entry_id
	if flow.try_play(entry_id) == null:
		push_error("replay: first play failed")
		return false
	# Single-card deck: play -> discard -> wash -> redraw same entry.
	if flow.get_hand().size() != 1 or flow.get_hand()[0].entry_id != entry_id:
		push_error("replay: expected same entry redrawn")
		return false
	if flow.try_play(entry_id) == null:
		push_error("replay: second play of same entry should be allowed")
		return false
	return true
