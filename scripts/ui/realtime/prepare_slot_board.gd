class_name PrepareSlotBoard
extends RefCounted
## 准备阶段我半场角色槽：固定座位、入槽/收回占用（见 Features/PLAYER.md / COMBATLEVEL.md）。

## 槽位相对我半场底部的行偏移（board_height - 1 - offset）。
const DEFAULT_ROW_FROM_BOTTOM := 4

var slot_count: int = 3
var cells: Array[Vector2i] = []
## 与 cells 等长；null 表示空槽。
var occupants: Array = []


func clear() -> void:
	cells.clear()
	occupants.clear()
	slot_count = 0


func configure(p_slot_count: int, board_size: Vector2i) -> void:
	clear()
	slot_count = maxi(1, p_slot_count)
	cells = build_default_cells(board_size, slot_count)
	occupants.resize(slot_count)
	for i in slot_count:
		occupants[i] = null


static func build_default_cells(board_size: Vector2i, count: int) -> Array[Vector2i]:
	var n := maxi(1, count)
	var mid := BoardHalf.midline_row(board_size.y)
	var row := board_size.y - 1 - DEFAULT_ROW_FROM_BOTTOM
	if row < mid:
		row = mid
	if row >= board_size.y:
		row = board_size.y - 1
	var result: Array[Vector2i] = []
	for i in n:
		var x := int(round(float(i + 1) * float(board_size.x) / float(n + 1)))
		x = clampi(x, 0, board_size.x - 1)
		result.append(Vector2i(x, row))
	return result


func get_cell(slot_index: int) -> Vector2i:
	if slot_index < 0 or slot_index >= cells.size():
		return Vector2i(-1, -1)
	return cells[slot_index]


func get_entry(slot_index: int) -> DeckEntry:
	if slot_index < 0 or slot_index >= occupants.size():
		return null
	return occupants[slot_index] as DeckEntry


func is_empty(slot_index: int) -> bool:
	return get_entry(slot_index) == null


func is_full() -> bool:
	return occupied_count() >= slot_count


func occupied_count() -> int:
	var n := 0
	for i in occupants.size():
		if occupants[i] != null:
			n += 1
	return n


func find_slot_at_cell(cell: Vector2i) -> int:
	for i in cells.size():
		if cells[i] == cell:
			return i
	return -1


## 最近空槽（曼哈顿距离）；无可入槽返回 -1。
func find_nearest_empty_slot(cell: Vector2i) -> int:
	var best := -1
	var best_dist := 999999
	for i in cells.size():
		if occupants[i] != null:
			continue
		var dist := absi(cells[i].x - cell.x) + absi(cells[i].y - cell.y)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


func try_assign(slot_index: int, entry: DeckEntry) -> bool:
	if entry == null or slot_index < 0 or slot_index >= occupants.size():
		return false
	if occupants[slot_index] != null:
		return false
	occupants[slot_index] = entry
	return true


func try_recall(slot_index: int) -> DeckEntry:
	if slot_index < 0 or slot_index >= occupants.size():
		return null
	var entry: DeckEntry = occupants[slot_index] as DeckEntry
	if entry == null:
		return null
	occupants[slot_index] = null
	return entry


func find_slot_by_entry(entry_id: int) -> int:
	for i in occupants.size():
		var entry: DeckEntry = occupants[i] as DeckEntry
		if entry != null and entry.entry_id == entry_id:
			return i
	return -1
