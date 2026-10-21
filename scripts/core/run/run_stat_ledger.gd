class_name RunStatLedger
extends RefCounted

## 按队伍 entry_id 累计本场 Run 的战斗统计（售出成员仍保留其 entry 记录）。


class EntryTotals extends RefCounted:
	var damage_dealt: int = 0
	var healing_done: int = 0
	var kills: int = 0
	var summons: int = 0


var _entries: Dictionary = {} # int -> EntryTotals


func reset() -> void:
	_entries.clear()


func _bucket(entry_id: int) -> EntryTotals:
	if entry_id < 0:
		return null
	if not _entries.has(entry_id):
		_entries[entry_id] = EntryTotals.new()
	return _entries[entry_id] as EntryTotals


func record_damage(entry_id: int, amount: int) -> void:
	if amount <= 0:
		return
	var b := _bucket(entry_id)
	if b != null:
		b.damage_dealt += amount


func record_healing(entry_id: int, amount: int) -> void:
	if amount <= 0:
		return
	var b := _bucket(entry_id)
	if b != null:
		b.healing_done += amount


func record_kill(entry_id: int) -> void:
	var b := _bucket(entry_id)
	if b != null:
		b.kills += 1


func record_summon(entry_id: int) -> void:
	var b := _bucket(entry_id)
	if b != null:
		b.summons += 1


func get_entry_totals(entry_id: int) -> EntryTotals:
	return _bucket(entry_id)


func sum_damage_dealt() -> int:
	var n := 0
	for v in _entries.values():
		n += (v as EntryTotals).damage_dealt
	return n


func sum_healing_done() -> int:
	var n := 0
	for v in _entries.values():
		n += (v as EntryTotals).healing_done
	return n


func sum_kills() -> int:
	var n := 0
	for v in _entries.values():
		n += (v as EntryTotals).kills
	return n


func sum_summons() -> int:
	var n := 0
	for v in _entries.values():
		n += (v as EntryTotals).summons
	return n
