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
