extends RefCounted
## Headless checks for EncounterCardFlow（准备抽选 / 入槽取出 / 刷新 / 开战回抽）。


static func run_all() -> bool:
	var ok := true
	ok = _test_begin_draws_hand() and ok
	ok = _test_take_from_hand_no_refill() and ok
	ok = _test_refresh_returns_to_draw() and ok
	ok = _test_return_hand_to_draw() and ok
	ok = _test_refresh_limit() and ok
	ok = _test_legacy_play_still_works() and ok
	return ok


static func _make_deck(count: int, hand_width: int = 5) -> DeckState:
	var config := DeckConfig.new()
	config.hand_width = hand_width
	config.slot_count = 3
	config.max_refresh = 3
	config.enter_hand_cooldown = 0.0
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


static func _test_begin_draws_hand() -> bool:
	var deck := _make_deck(8, 5)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	flow.begin_from_deck(deck, rng)
	if flow.get_hand().size() != 5:
		push_error("begin: expected hand 5, got %d" % flow.get_hand().size())
		return false
	if flow.get_draw_count() != 3:
		push_error("begin: expected draw 3, got %d" % flow.get_draw_count())
		return false
	return true


static func _test_take_from_hand_no_refill() -> bool:
	var deck := _make_deck(8, 5)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	flow.begin_from_deck(deck, rng)
	var taken_id := flow.get_hand()[0].entry_id
	var entry := flow.try_take_from_hand(taken_id)
	if entry == null or entry.entry_id != taken_id:
		push_error("take: failed to take from hand")
		return false
	if flow.get_hand().size() != 4:
		push_error("take: hand should shrink without refill, got %d" % flow.get_hand().size())
		return false
	if flow.get_discard_count() != 0:
		push_error("take: should not discard")
		return false
	if not flow.try_return_to_hand(entry):
		push_error("return: failed to return to hand")
		return false
	if flow.get_hand().size() != 5:
		push_error("return: hand should be 5 again")
		return false
	return true


static func _test_refresh_returns_to_draw() -> bool:
	var deck := _make_deck(8, 5)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	flow.begin_from_deck(deck, rng)
	var taken := flow.try_take_from_hand(flow.get_hand()[0].entry_id)
	var before_draw := flow.get_draw_count()
	if not flow.try_refresh(rng):
		push_error("refresh: failed")
		return false
	# 4 张回抽 + 原抽堆，再抽满到 5（槽位牌不在手牌）
	if flow.get_hand().size() != 5:
		push_error("refresh: expected hand 5, got %d" % flow.get_hand().size())
		return false
	if flow.refresh_used != 1:
		push_error("refresh: used should be 1")
		return false
	# 取出的牌不在刷新集合里
	if flow.is_in_hand(taken.entry_id):
		push_error("refresh: taken (slotted) card should not be in hand")
		return false
	if before_draw < 0:
		push_error("refresh: sanity")
		return false
	return true


static func _test_return_hand_to_draw() -> bool:
	var deck := _make_deck(6, 5)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	flow.begin_from_deck(deck, rng)
	flow.return_hand_to_draw(rng)
	if not flow.get_hand().is_empty():
		push_error("combat lock: hand should be empty")
		return false
	if flow.get_draw_count() != 6:
		push_error("combat lock: all cards should be in draw, got %d" % flow.get_draw_count())
		return false
	return true


static func _test_refresh_limit() -> bool:
	var deck := _make_deck(8, 5)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	flow.begin_from_deck(deck, rng)
	for i in 3:
		if not flow.try_refresh(rng):
			push_error("refresh limit: refresh %d should succeed" % (i + 1))
			return false
	if flow.try_refresh(rng):
		push_error("refresh limit: 4th refresh should fail")
		return false
	return true


static func _test_legacy_play_still_works() -> bool:
	var deck := _make_deck(6, 4)
	var flow := EncounterCardFlow.new()
	flow.configure_from_deck_config(deck.get_config())
	flow.enter_hand_cooldown = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	flow.begin_from_deck(deck, rng)
	var played_id := flow.get_hand()[0].entry_id
	var entry := flow.try_play(played_id)
	if entry == null or entry.entry_id != played_id:
		push_error("legacy play: failed")
		return false
	if flow.get_discard_count() != 1:
		push_error("legacy play: discard should be 1")
		return false
	return true
