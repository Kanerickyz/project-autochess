class_name SynergyOccupations
extends RefCounted
## 职业羁绊词表与已入座计数聚合（仅展示门槛；团队数值由徽章兑现）。
## 计数按**不同角色 id**：同 id 多份入座只处理第一次；含本职 + 转职附加职。

const TANK := "坦克"
const WARRIOR := "战士"
const RANGED := "远程"
const ARTISAN := "工匠"
const BAND := "军乐队"
const ARCANE := "秘术"
const BUILDING := "建筑"

## 固定展示序（七类）。
const ORDER: PackedStringArray = [
	TANK,
	WARRIOR,
	RANGED,
	ARTISAN,
	BAND,
	ARCANE,
	BUILDING,
]


static func is_known(occupation: String) -> bool:
	return not occupation.is_empty() and ORDER.has(occupation)


static func _empty_counts() -> Dictionary:
	var counts := {}
	for occ in ORDER:
		counts[occ] = 0
	return counts


## 从 UnitData 列表聚合：按 unit.id 去重后再计**本职**；空 id / 空职业 / 未知串跳过。
## 不含转职纹章（无 DeckEntry 上下文时用）。
static func count_from_unit_datas(units: Array) -> Dictionary:
	var counts := _empty_counts()
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


## 从 DeckEntry 列表聚合：按 unit.id 去重；取首次出现 entry 的 get_occupation_tags()，每职 +1。
static func count_from_deck_entries(entries: Array) -> Dictionary:
	var counts := _empty_counts()
	var seen_ids: Dictionary = {}
	for item in entries:
		var entry := item as DeckEntry
		if entry == null or entry.unit == null:
			continue
		var uid := str(entry.unit.id).strip_edges()
		if uid.is_empty():
			continue
		if seen_ids.has(uid):
			continue
		seen_ids[uid] = true
		for occ in entry.get_occupation_tags():
			if not is_known(occ):
				continue
			counts[occ] = int(counts.get(occ, 0)) + 1
	return counts


## 从已入座 DeckEntry 聚合（备战 / 召唤不在座位板上，天然排除）。
static func count_from_seated_entries(slot_board: PrepareSlotBoard) -> Dictionary:
	var entries: Array = []
	if slot_board == null:
		return count_from_deck_entries(entries)
	for i in slot_board.slot_count:
		var entry := slot_board.get_entry(i)
		if entry == null or entry.unit == null:
			continue
		entries.append(entry)
	return count_from_deck_entries(entries)


## 开战友方实例：优先读 linked DeckEntry 标签（含转职）；无 entry 时回退本职。
static func count_from_unit_instances(units: Array) -> Dictionary:
	var counts := _empty_counts()
	var seen_ids: Dictionary = {}
	for item in units:
		var unit := item as UnitInstance
		if unit == null:
			continue
		var uid := str(unit.id).strip_edges()
		if uid.is_empty() and unit.unit_data != null:
			uid = str(unit.unit_data.id).strip_edges()
		if uid.is_empty():
			continue
		if seen_ids.has(uid):
			continue
		seen_ids[uid] = true
		var tags: PackedStringArray = PackedStringArray()
		var entry := unit.get_linked_deck_entry()
		if entry != null:
			tags = entry.get_occupation_tags()
		elif unit.unit_data != null:
			var occ := str(unit.unit_data.occupation).strip_edges()
			if is_known(occ):
				tags.append(occ)
		for occ2 in tags:
			if not is_known(occ2):
				continue
			counts[occ2] = int(counts.get(occ2, 0)) + 1
	return counts


## 转为 HUD 行：仅 count≥1，按 ORDER 稳定排序。每项 Dictionary{name, count}。
static func to_display_rows(counts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for occ in ORDER:
		var n := int(counts.get(occ, 0))
		if n < 1:
			continue
		rows.append({"name": occ, "count": n})
	return rows
