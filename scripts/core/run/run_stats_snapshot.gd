class_name RunStatsSnapshot
extends RefCounted

var victory: bool = false
var encounters_won: int = 0
var shop_visits: int = 0
## 本局现实用时（秒）：自开局招募起至胜/败快照，不受战斗倍速影响。
var combat_seconds: float = 0.0
var gold: int = 0
## 无尽败局：到达的地图战斗层号 N（死在第 N 层记 N）；主爬塔通关可为 0。
var reached_floor: int = 0
## 本局是否无尽模式（文案/统计用）。
var endless_mode: bool = false
## 结束时仍在队伍中的成员（展示用）。
var roster: Array[DeckEntry] = []
var ledger: RunStatLedger = RunStatLedger.new()
## 并列时可能多名。
var highest_attack_entries: Array[DeckEntry] = []
var highest_max_hp_entries: Array[DeckEntry] = []
## 战中攻+血历史最高（来自 ledger 峰值冻条目；并列可多名）。
var highest_combat_atk_hp_entries: Array[DeckEntry] = []


static func entry_panel_attack(entry: DeckEntry) -> int:
	if entry == null or entry.unit == null or entry.unit.stats == null:
		return 0
	return entry.unit.stats.attack + entry.bonus_attack


static func entry_panel_max_hp(entry: DeckEntry) -> int:
	if entry == null or entry.unit == null or entry.unit.stats == null:
		return 0
	return entry.unit.stats.max_hp + entry.bonus_max_hp


static func pick_highest_attack(entries: Array[DeckEntry]) -> Array[DeckEntry]:
	var best := 0
	var out: Array[DeckEntry] = []
	for entry in entries:
		if entry == null:
			continue
		var atk := entry_panel_attack(entry)
		if out.is_empty() or atk > best:
			best = atk
			out = [entry]
		elif atk == best:
			out.append(entry)
	return out


static func pick_highest_max_hp(entries: Array[DeckEntry]) -> Array[DeckEntry]:
	var best := 0
	var out: Array[DeckEntry] = []
	for entry in entries:
		if entry == null:
			continue
		var hp := entry_panel_max_hp(entry)
		if out.is_empty() or hp > best:
			best = hp
			out = [entry]
		elif hp == best:
			out.append(entry)
	return out
