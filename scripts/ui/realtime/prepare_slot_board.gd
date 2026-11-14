class_name PrepareSlotBoard
extends RefCounted
## 准备 / 招募角色座位：双方各 4×5（与 5×8 半场对齐铺满）；满座 ≠ 上场人数上限。

const DEFAULT_SEAT_ROWS := 4
const DEFAULT_SEAT_COLS := 5
## 逻辑行间距（整格）；0 = 相邻行占座。半格观感见 SEAT_ROW_EXTRA_GAP。
const SEAT_ROW_GAP_CELLS := 0
## 前后排额外行距（格）：4 行铺满半场时略收，避免剪影互盖；仍保留可读分层。
const SEAT_ROW_EXTRA_GAP := 0.25
## 座位列间距（格）；默认 0 铺满棋盘宽。与行距分离，避免加行距时因列向放不下整块被收拢。
const SEAT_COL_GAP_CELLS := 0
## 兼容旧名：等同列间距（历史调用若仍引用则不影响行距）。
const SEAT_GAP_CELLS := SEAT_COL_GAP_CELLS

var seat_rows: int = DEFAULT_SEAT_ROWS
var seat_cols: int = DEFAULT_SEAT_COLS
## 座位总数（= seat_rows × seat_cols）；保留旧字段名供调用方兼容。
var slot_count: int = 0
var is_enemy_side: bool = false
## 与 configure_grid 的 match_ally_row_order 一致；影响 get_display_center 前后排偏移方向。
var match_ally_row_order: bool = false
## configure_grid 时的棋盘尺寸；供 get_display_center 判断贴满/外推。
var board_size: Vector2i = Vector2i.ZERO
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
	is_enemy_side = false
	match_ally_row_order = false
	board_size = Vector2i.ZERO


func configure_custom_cells(custom_cells: Array[Vector2i]) -> void:
	clear()
	cells = custom_cells.duplicate()
	slot_count = cells.size()
	seat_rows = 0
	seat_cols = 0
	is_enemy_side = false
	match_ally_row_order = false
	occupants.resize(slot_count)
	seat_assign_seq.resize(slot_count)
	for i in slot_count:
		occupants[i] = null
		seat_assign_seq[i] = -1


func configure_grid(
	rows: int,
	cols: int,
	p_board_size: Vector2i,
	enemy_side: bool = false,
	p_match_ally_row_order: bool = false,
) -> void:
	clear()
	seat_rows = maxi(1, rows)
	seat_cols = maxi(1, cols)
	slot_count = seat_rows * seat_cols
	is_enemy_side = enemy_side
	match_ally_row_order = p_match_ally_row_order
	board_size = p_board_size
	cells = build_grid_cells(
		board_size, seat_rows, seat_cols, enemy_side, match_ally_row_order
	)
	occupants.resize(slot_count)
	seat_assign_seq.resize(slot_count)
	for i in slot_count:
		occupants[i] = null
		seat_assign_seq[i] = -1


## 兼容旧单排 API：改为默认 4×5 网格（忽略旧 slot_count，改用默认行列）。
func configure(_p_slot_count: int, p_board_size: Vector2i) -> void:
	configure_grid(DEFAULT_SEAT_ROWS, DEFAULT_SEAT_COLS, p_board_size, false)


## 备战区一行：默认棋盘底边下方（y = board_size.y）；招募可传 midline 夹在队伍与招募半场之间。
func configure_bench_row(p_board_size: Vector2i, capacity: int = 5, row_y: int = -1) -> void:
	configure_custom_cells(build_bench_cells(p_board_size, capacity, row_y))
	board_size = p_board_size


## row_y < 0：棋盘外虚拟行（y = board_size.y）；否则落在指定逻辑行（如招募中缝 midline）。
static func build_bench_cells(
	p_board_size: Vector2i, capacity: int = 5, row_y: int = -1
) -> Array[Vector2i]:
	var n := maxi(1, capacity)
	var cols := maxi(1, p_board_size.x)
	var start_x := (cols - n) / 2
	start_x = clampi(start_x, 0, maxi(0, cols - 1))
	var y := row_y if row_y >= 0 else maxi(0, p_board_size.y)
	var result: Array[Vector2i] = []
	for i in n:
		var x := start_x + i
		x = clampi(x, 0, maxi(0, cols - 1))
		result.append(Vector2i(x, y))
	return result


static func build_grid_cells(
	p_board_size: Vector2i,
	rows: int,
	cols: int,
	enemy_side: bool,
	match_ally_row_order: bool = false,
) -> Array[Vector2i]:
	var n_rows := maxi(1, rows)
	var n_cols := maxi(1, cols)
	var row_gap := maxi(0, SEAT_ROW_GAP_CELLS)
	var col_gap := maxi(0, SEAT_COL_GAP_CELLS)
	var mid := BoardHalf.midline_row(p_board_size.y)
	var half_h := mid if enemy_side else maxi(0, p_board_size.y - mid)
	## 块放不下半场/棋盘宽时分别收拢对应轴向间距。
	var block_w := n_cols + (n_cols - 1) * col_gap
	var block_h := n_rows + (n_rows - 1) * row_gap
	if block_w > p_board_size.x:
		col_gap = 0
		block_w = n_cols
	if block_h > half_h:
		row_gap = 0
		block_h = n_rows
	var col_stride := 1 + col_gap
	var row_stride := 1 + row_gap
	var start_x := (p_board_size.x - block_w) / 2
	start_x = clampi(start_x, 0, maxi(0, p_board_size.x - 1))
	var row_ys := _centered_row_ys(
		p_board_size.y, n_rows, row_stride, block_h, enemy_side, match_ally_row_order
	)
	var result: Array[Vector2i] = []
	for row_i in row_ys.size():
		var y: int = row_ys[row_i]
		for c in n_cols:
			var x := start_x + c * col_stride
			x = clampi(x, 0, maxi(0, p_board_size.x - 1))
			result.append(Vector2i(x, y))
	return result


## 旧单排落点（仅兼容）；主路径请用 build_grid_cells。
static func build_default_cells(p_board_size: Vector2i, _count: int) -> Array[Vector2i]:
	return build_grid_cells(p_board_size, DEFAULT_SEAT_ROWS, DEFAULT_SEAT_COLS, false)


## 理想跨中线逻辑空档：配合 ±EXTRA/2 使敌前↔我前显示距 = 1+EXTRA。
static func _desired_mid_sep_cells() -> int:
	return maxi(1, int(round(1.0 + 2.0 * SEAT_ROW_EXTRA_GAP)))


## 半场放不下理想空档时收拢（5×4 贴满：mid_sep=1；5×8：mid_sep=2）。
static func _effective_mid_sep_cells(height: int, rows: int, stride: int) -> int:
	var mid := BoardHalf.midline_row(height)
	var half_h := mid
	var max_sep := maxi(1, half_h - (maxi(1, rows) - 1) * maxi(1, stride))
	return mini(_desired_mid_sep_cells(), max_sep)


## 贴满盘（mid_sep 相对理想值收拢）：禁止再加逻辑空行，改用显示外推。
static func uses_packed_row_visual(p_board_size: Vector2i) -> bool:
	if p_board_size.y <= 0:
		return false
	var stride := 1 + maxi(0, SEAT_ROW_GAP_CELLS)
	return (
		_effective_mid_sep_cells(p_board_size.y, DEFAULT_SEAT_ROWS, stride)
		< _desired_mid_sep_cells()
	)


## 战斗座位贴中线排布，使敌我共 4 行之间观感行距一致（隔半格）。
## 战斗半场：索引 0 为前排（更近中线）。
## match_ally_row_order：招募上区把友方画在敌半场时用——索引 0 仍为前排，
## 但行序与我半场一致（屏幕上前排在上、后排在下），半场内仍垂直居中以免与敌前排撞格。
## 配合 SEAT_ROW_EXTRA_GAP=0.5：战斗四行显示格心距均为 1.5。
## 贴满盘（如旧 5×4）mid_sep 收拢为 1，显示侧改累积半格外推；5×8 用 mid_sep=2。
static func _centered_row_ys(
	height: int,
	rows: int,
	stride: int,
	block_h: int,
	enemy_side: bool,
	match_ally_row_order: bool = false,
) -> Array[int]:
	var mid := BoardHalf.midline_row(height)
	var half_h := mid if enemy_side else maxi(0, height - mid)
	## 跨中线逻辑空档：高大盘用 mid_sep=2 空一行；贴满盘收拢为 1，不叠格。
	var mid_sep_cells := _effective_mid_sep_cells(height, rows, stride)
	var ys: Array[int] = []
	for i in rows:
		var y: int
		if enemy_side:
			if match_ally_row_order:
				## 招募友方上区：半场内垂直居中 + 同序（i=0 更靠屏顶 = 前排）。
				var start_in_half := int(round((float(half_h) - float(block_h)) * 0.5))
				start_in_half = clampi(start_in_half, 0, maxi(0, half_h - block_h))
				y = start_in_half + i * stride
			else:
				## 敌战斗半场：前排贴在 mid - mid_sep_cells，后排再往顶。
				var front_y := mid - mid_sep_cells
				var back_y := front_y - (rows - 1) * stride
				y = back_y + (rows - 1 - i) * stride
			y = clampi(y, 0, maxi(0, mid - 1))
		else:
			## 我半场：前排贴中线 mid，后排往底。
			y = mid + i * stride
			y = clampi(y, mid, maxi(mid, height - 1))
		ys.append(y)
	return ys


func get_cell(slot_index: int) -> Vector2i:
	if slot_index < 0 or slot_index >= cells.size():
		return Vector2i(-1, -1)
	return cells[slot_index]


## row_i 相对前排的显示 Y 偏移。combat_order：敌战斗序（前排 y 更大）或友方战斗序。
## packed：自中线向外累积半格，使逻辑相邻四行显示距均为 1+EXTRA。
static func _row_visual_y_offset(row_i: int, enemy_combat_order: bool, packed: bool) -> float:
	if SEAT_ROW_EXTRA_GAP <= 0.0:
		return 0.0
	var spread := SEAT_ROW_EXTRA_GAP * 0.5
	var ri := maxi(0, row_i)
	if packed:
		if enemy_combat_order:
			return -spread - float(ri) * SEAT_ROW_EXTRA_GAP
		return spread + float(ri) * SEAT_ROW_EXTRA_GAP
	if enemy_combat_order:
		return spread if ri == 0 else -spread
	return -spread if ri == 0 else spread


## 绘制/开战落点用的格心（可含半格行距）；逻辑占座仍用 get_cell 整格。
## 与 DeckState 足迹规则一致：以 anchor 为左上，横向 footprint_w、纵向 footprint_h。
func get_footprint_seat_indices(anchor_slot: int, unit: UnitData) -> Array[int]:
	var fw := 1
	var fh := 1
	if unit != null:
		fw = maxi(1, unit.footprint_w)
		fh = maxi(1, unit.footprint_h)
	var cols := maxi(1, seat_cols)
	var rows := maxi(1, seat_rows)
	if cols <= 0 or rows <= 0:
		cols = maxi(1, DEFAULT_SEAT_COLS)
		rows = maxi(1, DEFAULT_SEAT_ROWS)
	var anchor_col := anchor_slot % cols
	var anchor_row := anchor_slot / cols
	var out: Array[int] = []
	for dy in fh:
		for dx in fw:
			var c := anchor_col + dx
			var r := anchor_row + dy
			if c >= cols or r >= rows:
				return []
			var si := r * cols + c
			if si < 0 or si >= slot_count:
				return []
			out.append(si)
	return out


## 多格单位绘制/命中用：足迹格 display_center 的算术平均。
func get_footprint_display_center(anchor_slot: int, unit: UnitData) -> Vector2:
	var indices := get_footprint_seat_indices(anchor_slot, unit)
	if indices.is_empty():
		return get_display_center(anchor_slot)
	var sum := Vector2.ZERO
	for si in indices:
		sum += get_display_center(si)
	return sum / float(indices.size())


## 该槽是否为单位的 anchor 座（扩展格不单独作画）。
func is_anchor_seat(slot_index: int) -> bool:
	var entry := get_entry(slot_index)
	return entry != null and entry.seat_index == slot_index


## 命中锚点或足迹扩展格时返回条目（扩展格自身 occupants 为空）。
func get_entry_at_slot(slot_index: int) -> DeckEntry:
	var direct := get_entry(slot_index)
	if direct != null:
		return direct
	for i in slot_count:
		var entry := get_entry(i)
		if entry == null or entry.seat_index != i:
			continue
		for si in get_footprint_seat_indices(i, entry.unit):
			if si == slot_index:
				return entry
	return null


func get_display_center(slot_index: int) -> Vector2:
	var cell := get_cell(slot_index)
	if cell.x < 0:
		return Vector2(-1.0, -1.0)
	var center := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
	if seat_rows < 2 or seat_cols <= 0 or SEAT_ROW_EXTRA_GAP <= 0.0:
		return center
	var row_i := slot_index / seat_cols
	var enemy_combat_order := is_enemy_side and not match_ally_row_order
	## 招募同序半场只做块内 ±EXTRA/2；战斗座位在贴满盘上改累积外推。
	var packed := (
		(enemy_combat_order or not is_enemy_side)
		and board_size.y > 0
		and uses_packed_row_visual(board_size)
	)
	center.y += _row_visual_y_offset(row_i, enemy_combat_order, packed)
	return center


## 战斗寻路用：逻辑格若落在默认座位行，返回半格 Y 偏移；否则 ZERO。
## 按「当前格所属座位行」计算，避免开局 bias 随单位换行把前后排间距压扁/颠倒。
static func combat_row_visual_bias(
	cell: Vector2i,
	p_board_size: Vector2i,
	enemy_side: bool,
) -> Vector2:
	if SEAT_ROW_EXTRA_GAP <= 0.0 or p_board_size.x <= 0 or p_board_size.y <= 0:
		return Vector2.ZERO
	var grid := build_grid_cells(
		p_board_size, DEFAULT_SEAT_ROWS, DEFAULT_SEAT_COLS, enemy_side, false
	)
	if grid.is_empty() or DEFAULT_SEAT_COLS <= 0:
		return Vector2.ZERO
	var packed := uses_packed_row_visual(p_board_size)
	for row_i in DEFAULT_SEAT_ROWS:
		var idx := row_i * DEFAULT_SEAT_COLS
		if idx >= grid.size():
			break
		if grid[idx].y != cell.y:
			continue
		return Vector2(0.0, _row_visual_y_offset(row_i, enemy_side, packed))
	return Vector2.ZERO


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
	if occupied_count() >= slot_count:
		return false
	return get_occupied_population() + 1 <= maxi(0, deploy_cap)


## 是否还能让 entry 入座（人口加权；建筑占 2）。
func can_assign_entry(entry: DeckEntry, deploy_cap: int) -> bool:
	if entry == null or slot_count <= 0:
		return false
	if occupied_count() >= slot_count:
		return false
	return get_occupied_population() + entry.get_roster_population() <= maxi(0, deploy_cap)


func get_occupied_population() -> int:
	var n := 0
	for entry_var in occupants:
		var entry := entry_var as DeckEntry
		if entry != null:
			n += entry.get_roster_population()
	return n


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


## 载入持久占位：使用已有落座序，不重新计时。
func try_assign_with_seq(slot_index: int, entry: DeckEntry, seq: int) -> bool:
	if entry == null or slot_index < 0 or slot_index >= occupants.size():
		return false
	if occupants[slot_index] != null:
		return false
	occupants[slot_index] = entry
	var use_seq := seq if seq > 0 else 0
	if use_seq <= 0:
		_assign_seq_counter += 1
		use_seq = _assign_seq_counter
	else:
		_assign_seq_counter = maxi(_assign_seq_counter, use_seq)
	if slot_index < seat_assign_seq.size():
		seat_assign_seq[slot_index] = use_seq
	return true


## 准备/招募换座：空座则移入；目标有人则互换；双方刷新本地入座序。
func try_swap_slots(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= occupants.size():
		return false
	if to_index < 0 or to_index >= occupants.size():
		return false
	if from_index == to_index:
		return false
	var from_entry: DeckEntry = occupants[from_index] as DeckEntry
	if from_entry == null:
		return false
	var to_entry: DeckEntry = occupants[to_index] as DeckEntry
	occupants[from_index] = to_entry
	occupants[to_index] = from_entry
	_assign_seq_counter += 1
	var seq_a := _assign_seq_counter
	_assign_seq_counter += 1
	var seq_b := _assign_seq_counter
	if to_entry == null:
		if from_index < seat_assign_seq.size():
			seat_assign_seq[from_index] = -1
		if to_index < seat_assign_seq.size():
			seat_assign_seq[to_index] = seq_b
	else:
		if from_index < seat_assign_seq.size():
			seat_assign_seq[from_index] = seq_a
		if to_index < seat_assign_seq.size():
			seat_assign_seq[to_index] = seq_b
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
		if entry != null and entry.entry_id == entry_id and entry.seat_index == i:
			return i
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
