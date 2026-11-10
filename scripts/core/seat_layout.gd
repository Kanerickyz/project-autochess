class_name SeatLayout
extends RefCounted
## 角色座位落座序：同行从中间向两侧展开。
## 5 列时列优先标签「53124」（中=1），填充次序为中→右→左→远右→远左 → 列索引 [2,3,1,4,0]。

## 单行列填充次序（0-based）。cols=5 → [2, 3, 1, 4, 0]。
static func row_column_fill_order(cols: int) -> Array[int]:
	var n := maxi(1, cols)
	var center := n / 2
	var order: Array[int] = [center]
	var offset := 1
	while order.size() < n:
		var right := center + offset
		var left := center - offset
		if right < n:
			order.append(right)
		if left >= 0:
			order.append(left)
		offset += 1
	return order


## 前排水平居中座位（5 列 → 2）。
static func front_center_seat_index(cols: int) -> int:
	return maxi(1, cols) / 2


## 最后一排（敌方半场后方）水平居中座位。
## seat_count 可能被硬顶截断（小于 rows×cols）。
static func back_center_seat_index(cols: int, seat_count: int) -> int:
	var c := maxi(1, cols)
	var n := maxi(1, seat_count)
	var back_row_start := n - (n % c)
	if back_row_start == n:
		back_row_start = maxi(0, n - c)
	var center_in_row := c / 2
	var idx := back_row_start + center_in_row
	if idx >= n:
		idx = n - 1
	return idx


## 半场全部座位的默认遍历序：先前排到后排，同行中心向外。
static func iter_seats_center_out(rows: int, cols: int) -> Array[int]:
	var r := maxi(1, rows)
	var c := maxi(1, cols)
	var col_order := row_column_fill_order(c)
	var out: Array[int] = []
	for row in r:
		for col in col_order:
			out.append(row * c + col)
	return out


## 行动队列子序：列优先（先完成一列再右移）。
## 友方：左→右，列内上→下（屏坐标 y 升序；半场内更靠中线的前排先）。
## 敌方：左→右，列内下→上（屏坐标 y 降序；半场内更靠中线的前排先，与友方镜像）。
## board_height 保留供调用方签名兼容，排序不再依赖中线距离。
static func compare_cells_for_action_queue(
	ca: Vector2i,
	cb: Vector2i,
	_board_height: int,
	enemy_side: bool = false,
) -> bool:
	if ca == cb:
		return false
	if ca.x != cb.x:
		return ca.x < cb.x
	if enemy_side:
		return ca.y > cb.y
	return ca.y < cb.y


static func compare_rt_units_for_action_queue(a: RtUnit, b: RtUnit, board_height: int) -> bool:
	if a == null or b == null:
		return a != null
	var enemy_side := not a.is_player()
	return compare_cells_for_action_queue(a.get_cell(), b.get_cell(), board_height, enemy_side)
