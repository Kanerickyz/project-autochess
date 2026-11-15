class_name EnchantSessionTest
extends RefCounted

const _TraitCatalog := preload("res://scripts/core/run/enchant_trait_catalog.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_forge_slot_spacing()
	_test_trait_confirm_and_persist()
	_test_trait_overwrites_previous()
	_test_skip_inactive()
	_test_session_once_per_visit()
	_test_furnace_api_stubbed()
	if _failures == 0:
		print("EnchantSessionTest: all tests passed")
	else:
		push_error("EnchantSessionTest: %d failure(s)" % _failures)
	return _failures == 0


static func _deck_with_seated() -> DeckState:
	var deck := DeckState.new()
	var config := DeckConfig.new()
	config.max_size = 5
	deck.configure(config)
	var u1 := UnitData.new()
	u1.id = "test_a"
	u1.stats = UnitStats.new()
	var u2 := UnitData.new()
	u2.id = "test_b"
	u2.stats = UnitStats.new()
	var e1 := deck.add_entry(u1)
	var e2 := deck.add_entry(u2)
	_assert(e1 != null and e2 != null, "entries added")
	deck.assign_seat(e1.entry_id, 0)
	deck.assign_seat(e2.entry_id, 1)
	return deck


static func _test_forge_slot_spacing() -> void:
	var cells := EnchantLayout.forge_slot_cells(Vector2i(5, 8))
	_assert(cells.size() == 3, "three trait cells")
	if cells.size() >= 3:
		_assert(cells[0].x == 0 and cells[1].x == 2 and cells[2].x == 4, "cells spaced")
		_assert(cells[0].y == cells[1].y and cells[1].y == cells[2].y, "row aligned")


static func _test_trait_confirm_and_persist() -> void:
	var deck := _deck_with_seated()
	var entries := deck.get_entries()
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	_assert(session.trait_offers.size() == _TraitCatalog.OFFER_COUNT, "three offers")
	_assert(session.select_trait(0), "select trait")
	_assert(session.select_entry(entries[0].entry_id), "select entry")
	var result := session.try_confirm()
	_assert(result.get("ok", false), "confirm ok")
	_assert(entries[0].has_enchant_trait(), "entry has trait")
	var offer: Dictionary = session.trait_offers[0]
	_assert(
		entries[0].get_enchant_combat_status_id() == offer.get("id", &""),
		"status id matches offer",
	)


static func _test_trait_overwrites_previous() -> void:
	var deck := _deck_with_seated()
	var entry := deck.get_entries()[0]
	entry.set_enchant_trait(CombatStatusStack.ID_WEAK, 1)
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	var pick_i := 0
	for i in session.trait_offers.size():
		var oid: StringName = session.trait_offers[i].get("id", &"")
		if oid != CombatStatusStack.ID_WEAK:
			pick_i = i
			break
	_assert(session.select_trait(pick_i), "pick non-weak offer")
	_assert(session.select_entry(entry.entry_id), "same entry")
	session.try_confirm()
	var offer: Dictionary = session.trait_offers[pick_i]
	_assert(
		entry.get_enchant_combat_status_id() == offer.get("id", &""),
		"replaced with new offer",
	)


static func _test_skip_inactive() -> void:
	var deck := _deck_with_seated()
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	var finished: Array = []
	session.session_finished.connect(func(_did: bool) -> void: finished.append(true))
	session.skip()
	_assert(not session.is_active, "inactive after skip")
	_assert(not finished.is_empty(), "skip emitted finished")


static func _test_session_once_per_visit() -> void:
	var deck := _deck_with_seated()
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	_assert(session.select_trait(0), "first trait")
	_assert(session.select_entry(deck.get_entries()[0].entry_id), "entry")
	session.try_confirm()
	_assert(not session.select_trait(1), "no re-pick after confirm")


static func _test_furnace_api_stubbed() -> void:
	var deck := _deck_with_seated()
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	_assert(not session.set_slot(&"a", 0), "set_slot false")
	_assert(not session.try_fuse().get("ok", true), "fuse disabled")


static func _assert(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		push_error("EnchantSessionTest: FAIL %s" % label)