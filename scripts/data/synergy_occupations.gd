class_name SynergyOccupations
extends RefCounted
## 职业羁绊词表与已入座计数聚合（仅展示，无阈值/团队数值）。
## 计数按**不同角色 id**：同 id 多份入座只算 1。

const TANK := "坦克"
const WARRIOR := "战士"
const RANGED := "远程"
const ARTISAN := "工匠"
const BAND := "军乐队"
const ARCANE := "秘术"

## 固定展示序（六类）。
const ORDER: PackedStringArray = [
	TANK,
	WARRIOR,
	RANGED,
	ARTISAN,
	BAND,
	ARCANE,
]


static func is_known(occupation: String) -> bool:
	return not occupation.is_empty() and ORDER.has(occupation)


## 从 UnitData 列表聚合：按 unit.id 去重后再计职业；空 id / 空职业 / 未知串跳过。
static func count_from_unit_datas(units: Array) -> Dictionary:
	var counts := {}
	for occ in ORDER:
		counts[occ] = 0
	var seen_ids: Dictionary = {}
	for item in units:
		var data := item as UnitData
		if data == null:
			continue
		var uid := str(data.id).strip_edges()
		if uid.is_empty():
			continue
		if seen_ids.has(uid):
			continue
		seen_ids[uid] = true
		var occ := str(data.occupation).strip_edges()
		if not is_known(occ):
			continue
		counts[occ] = int(counts.get(occ, 0)) + 1
	return counts


## 从已入座 DeckEntry 聚合（备战 / 召唤不在座位板上，天然排除）。
static func count_from_seated_entries(slot_board: PrepareSlotBoard) -> Dictionary:
	var units: Array = []
	if slot_board == null:
		return count_from_unit_datas(units)
	for i in slot_board.slot_count:
		var entry := slot_board.get_entry(i)
		if entry == null or entry.unit == null:
			continue
		units.append(entry.unit)
	return count_from_unit_datas(units)


## 转为 HUD 行：仅 count≥1，按 ORDER 稳定排序。每项 Dictionary{name, count}。
static func to_display_rows(counts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for occ in ORDER:
		var n := int(counts.get(occ, 0))
		if n < 1:
			continue
		rows.append({"name": occ, "count": n})
	return rows
