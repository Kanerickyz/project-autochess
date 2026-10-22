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
## 战中友方 effective_attack + effective_max_hp 历史最高（跨遭遇）。
var peak_combat_atk_hp_sum: int = 0
var peak_combat_entries: Array[DeckEntry] = []
## 与 peak_combat_entries 平行：同 instance 不重复堆入并列。
var _peak_instance_ids: Array[int] = []


func reset() -> void:
	_entries.clear()
	peak_combat_atk_hp_sum = 0
	peak_combat_entries.clear()
	_peak_instance_ids.clear()


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
	out.peak_combat_atk_hp_sum = peak_combat_atk_hp_sum
	for entry in peak_combat_entries:
		if entry == null:
			continue
		out.peak_combat_entries.append(_clone_peak_entry(entry))
	out._peak_instance_ids = _peak_instance_ids.duplicate()
	return out


## 采样战中友方攻+血上限；更高则替换巅峰，相等则并列（同 instance 去重）。
func note_combat_atk_hp(unit: UnitInstance) -> void:
	if unit == null or unit.team != UnitInstance.Team.PLAYER or unit.unit_data == null:
		return
	var sum := unit.get_effective_attack() + unit.get_effective_max_hp()
	if sum < peak_combat_atk_hp_sum:
		return
	if sum > peak_combat_atk_hp_sum:
		peak_combat_atk_hp_sum = sum
		peak_combat_entries.clear()
		_peak_instance_ids.clear()
	elif _peak_instance_ids.has(unit.instance_id):
		return
	var frozen := _freeze_peak_entry(unit)
	if frozen == null:
		return
	peak_combat_entries.append(frozen)
	_peak_instance_ids.append(unit.instance_id)


static func _freeze_peak_entry(unit: UnitInstance) -> DeckEntry:
	if unit == null or unit.unit_data == null:
		return null
	var data := unit.unit_data
	var base_atk := 0
	var base_hp := 0
	if data.stats != null:
		base_atk = data.stats.attack
		base_hp = data.stats.max_hp
	var entry := DeckEntry.new()
	entry.entry_id = unit.deck_entry_id
	entry.unit = data
	entry.level = unit.level
	entry.bonus_attack = unit.get_effective_attack() - base_atk
	entry.bonus_max_hp = unit.get_effective_max_hp() - base_hp
	if unit.main_ability_override != null:
		entry.runtime_main_ability = unit.main_ability_override.duplicate(true) as AbilityData
	return entry


static func _clone_peak_entry(source: DeckEntry) -> DeckEntry:
	var entry := DeckEntry.new()
	if source == null:
		return entry
	entry.entry_id = source.entry_id
	entry.unit = source.unit
	entry.level = source.level
	entry.bonus_attack = source.bonus_attack
	entry.bonus_max_hp = source.bonus_max_hp
	entry.bonus_crit_rate_percent = source.bonus_crit_rate_percent
	entry.attached_buffs = source.attached_buffs.duplicate()
	entry.attached_abilities = source.attached_abilities.duplicate()
	entry.rule_flags = source.rule_flags.duplicate(true)
	entry.equipment = source.equipment
	if source.runtime_main_ability != null:
		entry.runtime_main_ability = source.runtime_main_ability.duplicate(true) as AbilityData
	return entry


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
