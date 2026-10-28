class_name RunMatchHistoryCodec
extends RefCounted

const FORMAT_VERSION := 1


class RecordMeta extends RefCounted:
	var id: String = ""
	var saved_at: int = 0


static func encode_snapshot(snapshot: RunStatsSnapshot, saved_at: int, record_id: String) -> Dictionary:
	if snapshot == null:
		return {}
	var ledger := snapshot.ledger if snapshot.ledger != null else RunStatLedger.new()
	return {
		"format_version": FORMAT_VERSION,
		"id": record_id,
		"saved_at": saved_at,
		"victory": snapshot.victory,
		"encounters_won": snapshot.encounters_won,
		"shop_visits": snapshot.shop_visits,
		"combat_seconds": snapshot.combat_seconds,
		"gold": snapshot.gold,
		"reached_floor": snapshot.reached_floor,
		"endless_mode": snapshot.endless_mode,
		"final_trial_floors_cleared": snapshot.final_trial_floors_cleared,
		"roster_rows": BattleLayoutClipboard.deck_entries_to_ally_rows(snapshot.roster),
		"ledger": {
			"damage_dealt": ledger.sum_damage_dealt(),
			"healing_done": ledger.sum_healing_done(),
			"max_hp_gained": ledger.sum_max_hp_gained(),
			"kills": ledger.sum_kills(),
			"summons": ledger.sum_summons(),
			"peak_combat_sum": ledger.peak_combat_atk_hp_sum,
			"peak_rows": BattleLayoutClipboard.deck_entries_to_ally_rows(ledger.peak_combat_entries),
		},
	}


static func decode_snapshot(record: Dictionary) -> RunStatsSnapshot:
	if record.is_empty():
		return null
	var version := int(record.get("format_version", 0))
	if version != FORMAT_VERSION:
		return null
	var snap := RunStatsSnapshot.new()
	snap.victory = bool(record.get("victory", false))
	snap.encounters_won = int(record.get("encounters_won", 0))
	snap.shop_visits = int(record.get("shop_visits", 0))
	snap.combat_seconds = float(record.get("combat_seconds", 0.0))
	snap.gold = int(record.get("gold", 0))
	snap.reached_floor = int(record.get("reached_floor", 0))
	snap.endless_mode = bool(record.get("endless_mode", false))
	snap.final_trial_floors_cleared = int(record.get("final_trial_floors_cleared", 0))
	var roster_rows: Array = record.get("roster_rows", [])
	snap.roster.assign(BattleLayoutClipboard.deck_entries_from_ally_rows(roster_rows))
	var ledger_dict: Dictionary = record.get("ledger", {})
	var peak_rows: Array = ledger_dict.get("peak_rows", [])
	var peak_entries := BattleLayoutClipboard.deck_entries_from_ally_rows(peak_rows)
	var ledger := RunStatLedger.new()
	ledger.apply_persisted_display_totals(
		int(ledger_dict.get("damage_dealt", 0)),
		int(ledger_dict.get("healing_done", 0)),
		int(ledger_dict.get("max_hp_gained", 0)),
		int(ledger_dict.get("kills", 0)),
		int(ledger_dict.get("summons", 0)),
		int(ledger_dict.get("peak_combat_sum", 0)),
		peak_entries,
	)
	snap.ledger = ledger
	snap.highest_attack_entries = RunStatsSnapshot.pick_highest_attack(snap.roster)
	snap.highest_max_hp_entries = RunStatsSnapshot.pick_highest_max_hp(snap.roster)
	snap.highest_combat_atk_hp_entries.assign(ledger.peak_combat_entries)
	return snap


static func summary_for_record(record: Dictionary) -> Dictionary:
	var snap := decode_snapshot(record)
	if snap == null:
		return {"title": "记录损坏", "subtitle": ""}
	var saved_at := int(record.get("saved_at", 0))
	return {
		"title": _outcome_title(snap),
		"subtitle": _summary_subtitle(snap, saved_at),
	}


static func _outcome_title(snapshot: RunStatsSnapshot) -> String:
	var mode := "无尽" if snapshot.endless_mode else "爬塔"
	if snapshot.victory:
		return "%s · 远征完成" % mode
	if snapshot.endless_mode and snapshot.reached_floor > 0:
		return "%s · 第 %d 层" % [mode, snapshot.reached_floor]
	return "%s · 远征失败" % mode


static func _summary_subtitle(snapshot: RunStatsSnapshot, saved_at: int) -> String:
	var when := _format_saved_at(saved_at)
	var dmg := 0
	if snapshot.ledger != null:
		dmg = snapshot.ledger.sum_damage_dealt()
	return "%s · 胜场 %d · 伤害 %d" % [when, snapshot.encounters_won, dmg]


static func _format_saved_at(saved_at: int) -> String:
	if saved_at <= 0:
		return "未知时间"
	var dict := Time.get_datetime_dict_from_unix_time(saved_at)
	return "%04d-%02d-%02d %02d:%02d" % [
		dict.year,
		dict.month,
		dict.day,
		dict.hour,
		dict.minute,
	]
