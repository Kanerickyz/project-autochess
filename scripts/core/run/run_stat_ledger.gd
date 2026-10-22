class_name RunStatLedger
extends RefCounted

## 按队伍 entry_id 累计本场 Run 的战斗统计（售出成员仍保留其 entry 记录）。
## entry_id < 0（战中召唤体等）归入孤儿桶，仍计入总和。

const ORPHAN_ENTRY_ID := -1


class EntryTotals extends RefCounted:
	var damage_dealt: int = 0
	var healing_done: int = 0
	var kills: int = 0
	var summons: int = 0


var _entries: Dictionary = {} # int -> EntryTotals


func reset() -> void:
	_entries.clear()


func _bucket(entry_id: int) -> EntryTotals:
	var key := entry_id if entry_id >= 0 else ORPHAN_ENTRY_ID
	if not _entries.has(key):
		_entries[key] = EntryTotals.new()
	return _entries[key] as EntryTotals


## 深拷贝：快照与活账本隔离，避免 reset / 再开局冲掉已展示统计。
func duplicate_ledger() -> RunStatLedger:
	var out := RunStatLedger.new()
	for key in _entries.keys():
		var src := _entries[key] as EntryTotals
		if src == null:
			continue
		var dst := out._bucket(int(key))
		dst.damage_dealt = src.damage_dealt
		dst.healing_done = src.healing_done
		dst.kills = src.kills
		dst.summons = src.summons
	return out


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
