extends RefCounted

## Headless：对局记录 JSON 编解码往返。


static func run_all() -> bool:
	var ok := true
	ok = _test_roundtrip_snapshot() and ok
	ok = _test_summary_title() and ok
	return ok


static func _make_snapshot() -> RunStatsSnapshot:
	var snap := RunStatsSnapshot.new()
	snap.victory = false
	snap.endless_mode = true
	snap.reached_floor = 7
	snap.encounters_won = 6
	snap.shop_visits = 2
	snap.combat_seconds = 125.5
	snap.gold = 42
	snap.final_trial_floors_cleared = 1
	var unit := UnitData.new()
	unit.id = "knight"
	unit.display_name = "Knight"
	unit.stats = UnitStats.new()
	unit.stats.attack = 3
	unit.stats.max_hp = 10
	var entry := DeckEntry.new()
	entry.entry_id = 0
	entry.unit = unit
	entry.level = 2
	entry.bonus_attack = 1
	entry.bonus_max_hp = 2
	snap.roster = [entry]
	var ledger := RunStatLedger.new()
	ledger.apply_persisted_display_totals(900, 50, 3, 4, 1, 15, [entry])
	snap.ledger = ledger
	snap.highest_attack_entries = RunStatsSnapshot.pick_highest_attack(snap.roster)
	snap.highest_max_hp_entries = RunStatsSnapshot.pick_highest_max_hp(snap.roster)
	snap.highest_combat_atk_hp_entries.assign(ledger.peak_combat_entries)
	return snap


static func _test_roundtrip_snapshot() -> bool:
	var original := _make_snapshot()
	var encoded := RunMatchHistoryCodec.encode_snapshot(original, 1_700_000_000, "test-id")
	var restored := RunMatchHistoryCodec.decode_snapshot(encoded)
	if restored == null:
		push_error("run_match_history: decode failed")
		return false
	if restored.encounters_won != 6 or not restored.endless_mode or restored.reached_floor != 7:
		push_error("run_match_history: scalar mismatch")
		return false
	if restored.roster.size() != 1 or restored.roster[0].get_unit_id() != "knight":
		push_error("run_match_history: roster mismatch")
		return false
	if restored.ledger.sum_damage_dealt() != 900 or restored.ledger.sum_kills() != 4:
		push_error("run_match_history: ledger mismatch")
		return false
	return true


static func _test_summary_title() -> bool:
	var snap := RunStatsSnapshot.new()
	snap.endless_mode = true
	snap.reached_floor = 3
	var record := RunMatchHistoryCodec.encode_snapshot(snap, 0, "x")
	var summary := RunMatchHistoryCodec.summary_for_record(record)
	var title := String(summary.get("title", ""))
	if not title.contains("无尽") or not title.contains("3"):
		push_error("run_match_history: summary title unexpected: %s" % title)
		return false
	return true
