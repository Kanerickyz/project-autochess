class_name PrepareSlotBoard
extends RefCounted
## 准备阶段角色座位：双方各 2×5 网格；满座 ≠ 上场人数上限（见 Features/PLAYER.md / COMBATLEVEL.md）。

const DEFAULT_SEAT_ROWS := 2
const DEFAULT_SEAT_COLS := 5
## 前排相对中线向己半场内偏移的格数（0 = 贴中线第一行）。
const FRONT_OFFSET_FROM_MID := 0
## 后排相对己方底边向内偏移的格数（0 = 贴边）。
const BACK_INSET_FROM_EDGE := 1

var seat_rows: int = DEFAULT_SEAT_ROWS
var seat_cols: int = DEFAULT_SEAT_COLS
## 座位总数（= seat_rows × seat_cols）；保留旧字段名供调用方兼容。
var slot_count: int = 0
var is_enemy_side: bool = false
var cells: Array[Vector2i] = []
## 与 cells 等长；null 表示空座。友方存 DeckEntry；敌方座位表可仅用几何。
var occupants: Array = []


func clear() -> void:
	cells.clear()
	occupants.clear()
	slot_count = 0
	seat_rows = 0
	seat_cols = 0


func configure_grid(
	rows: int,
	cols: int,
	board_size: Vector2i,
	enemy_side: bool = false,
) -> void:
	clear()
	seat_rows = maxi(1, rows)
	seat_cols = maxi(1, cols)
	slot_count = seat_rows * seat_cols
	is_enemy_side = enemy_side
	cells = build_grid_cells(board_size, seat_rows, seat_cols, enemy_side)
	occupants.resize(slot_count)
	for i in slot_count:
		occupants[i] = null


## 兼容旧单排 API：改为默认 2×5 网格（忽略旧 slot_count，改用默认行列）。
func configure(_p_slot_count: int, board_size: Vector2i) -> void:
	configure_grid(DEFAULT_SEAT_ROWS, DEFAULT_SEAT_COLS, board_size, false)


static func build_grid_cells(
	board_size: Vector2i,
	rows: int,
	cols: int,
	enemy_side: bool,
) -> Array[Vector2i]:
	var n_rows := maxi(1, rows)
	var n_cols := maxi(1, cols)
	var row_ys := _row_ys_for_side(board_size.y, n_rows, enemy_side)
	var result: Array[Vector2i] = []
	for row_i in row_ys.size():
		var y: int = row_ys[row_i]
		for c in n_cols:
			var x := int(round(float(c + 1) * float(board_size.x) / float(n_cols + 1)))
			x = clampi(x, 0, maxi(0, board_size.x - 1))
			result.append(Vector2i(x, y))
	return result


## 旧单排落点（仅兼容）；主路径请用 build_grid_cells。
static func build_default_cells(board_size: Vector2i, _count: int) -> Array[Vector2i]:
	return build_grid_cells(board_size, DEFAULT_SEAT_ROWS, DEFAULT_SEAT_COLS, false)


static func _row_ys_for_side(height: int, rows: int, enemy_side: bool) -> Array[int]:
	var mid := BoardHalf.midline_row(height)
	var front_y: int
	var back_y: int
	if enemy_side:
		front_y = clampi(mid - 1 - FRONT_OFFSET_FROM_MID, 0, maxi(0, mid - 1))
		back_y = clampi(BACK_INSET_FROM_EDGE, 0, front_y)
	else:
		front_y = clampi(mid + FRONT_OFFSET_FROM_MID, mid, maxi(mid, height - 1))
		back_y = clampi(height - 1 - BACK_INSET_FROM_EDGE, front_y, maxi(0, height - 1))
	var ys: Array[int] = []
	if rows <= 1:
		ys.append(front_y)
		return ys
	## 前排在前（索引 0..cols-1），后排在后；多行时在前后之间插值。
	for i in rows:
		var t := 0.0 if rows <= 1 else float(i) / float(rows - 1)
		ys.append(int(round(lerpf(float(front_y), float(back_y), t))))
	return ys


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


## 全部座位是否被占满（与上场人数上限无关）。
func is_full() -> bool:
	return occupied_count() >= slot_count and slot_count > 0


## 是否还能再入座：未达 deploy_cap，且仍有空座。
func can_assign_more(deploy_cap: int) -> bool:
	if slot_count <= 0:
		return false
	if occupied_count() >= maxi(0, deploy_cap):
		return false
	return occupied_count() < slot_count


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
