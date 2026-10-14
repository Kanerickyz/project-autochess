class_name PrepareSlotBoard
extends RefCounted
## 准备阶段角色座位：双方各 2×5 网格；满座 ≠ 上场人数上限（见 Features/PLAYER.md / COMBATLEVEL.md）。

const DEFAULT_SEAT_ROWS := 2
const DEFAULT_SEAT_COLS := 5
## 座位行与行、列与列之间空出的格数。
const SEAT_GAP_CELLS := 1

var seat_rows: int = DEFAULT_SEAT_ROWS
var seat_cols: int = DEFAULT_SEAT_COLS
## 座位总数（= seat_rows × seat_cols）；保留旧字段名供调用方兼容。
var slot_count: int = 0
var is_enemy_side: bool = false
var cells: Array[Vector2i] = []
## 与 cells 等长；null 表示空座。友方存 DeckEntry；敌方座位表可仅用几何。
var occupants: Array = []
## 与 occupants 等长；成功入座序号（越大越晚）；空座为 -1。开战友方生成序用。
var seat_assign_seq: Array[int] = []
var _assign_seq_counter: int = 0


func clear() -> void:
	cells.clear()
	occupants.clear()
	seat_assign_seq.clear()
	_assign_seq_counter = 0
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
	seat_assign_seq.resize(slot_count)
	for i in slot_count:
		occupants[i] = null
		seat_assign_seq[i] = -1


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
	var gap := maxi(0, SEAT_GAP_CELLS)
	var stride := 1 + gap
	var block_w := n_cols + (n_cols - 1) * gap
	var block_h := n_rows + (n_rows - 1) * gap
	var start_x := (board_size.x - block_w) / 2
	start_x = clampi(start_x, 0, maxi(0, board_size.x - 1))
	var row_ys := _centered_row_ys(board_size.y, n_rows, stride, block_h, enemy_side)
	var result: Array[Vector2i] = []
	for row_i in row_ys.size():
		var y: int = row_ys[row_i]
		for c in n_cols:
			var x := start_x + c * stride
			x = clampi(x, 0, maxi(0, board_size.x - 1))
			result.append(Vector2i(x, y))
	return result


## 旧单排落点（仅兼容）；主路径请用 build_grid_cells。
static func build_default_cells(board_size: Vector2i, _count: int) -> Array[Vector2i]:
	return build_grid_cells(board_size, DEFAULT_SEAT_ROWS, DEFAULT_SEAT_COLS, false)


## 在各自半场可放置区内垂直居中；索引 0 为前排（更近中线），行距 = stride。
static func _centered_row_ys(
	height: int,
	rows: int,
	stride: int,
	block_h: int,
	enemy_side: bool,
) -> Array[int]:
	var mid := BoardHalf.midline_row(height)
	var half_h := mid if enemy_side else maxi(0, height - mid)
	var start_in_half := (half_h - block_h) / 2
	start_in_half = maxi(0, start_in_half)
	var ys: Array[int] = []
	for i in rows:
		var y: int
		if enemy_side:
			## 敌半场：块从顶侧居中；前排靠近中线（更大 y）。
			var back_y := start_in_half
			y = back_y + (rows - 1 - i) * stride
			y = clampi(y, 0, maxi(0, mid - 1))
		else:
			## 我半场：块从中线起居中；前排靠近中线（更小 y）。
			y = mid + start_in_half + i * stride
			y = clampi(y, mid, maxi(mid, height - 1))
		ys.append(y)
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
	_assign_seq_counter += 1
	if slot_index < seat_assign_seq.size():
		seat_assign_seq[slot_index] = _assign_seq_counter
	return true


func try_recall(slot_index: int) -> DeckEntry:
	if slot_index < 0 or slot_index >= occupants.size():
		return null
	var entry: DeckEntry = occupants[slot_index] as DeckEntry
	if entry == null:
		return null
	occupants[slot_index] = null
	if slot_index < seat_assign_seq.size():
		seat_assign_seq[slot_index] = -1
	return entry


func find_slot_by_entry(entry_id: int) -> int:
	for i in occupants.size():
		var entry: DeckEntry = occupants[i] as DeckEntry
		if entry != null and entry.entry_id == entry_id:
			return i
	return -1


## 已占用座位下标，按入座时间序（先入座在前；收回再入 = 最后一次成功入座）。
func get_occupied_indices_by_seat_order() -> Array[int]:
	var indices: Array[int] = []
	for i in occupants.size():
		if occupants[i] != null:
			indices.append(i)
	indices.sort_custom(_compare_seat_order)
	return indices


func get_seat_assign_seq(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= seat_assign_seq.size():
		return -1
	return seat_assign_seq[slot_index]


func _compare_seat_order(a: int, b: int) -> bool:
	var sa := get_seat_assign_seq(a)
	var sb := get_seat_assign_seq(b)
	if sa == sb:
		return a < b
	return sa < sb
