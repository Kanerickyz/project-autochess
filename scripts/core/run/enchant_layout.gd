class_name EnchantLayout
extends RefCounted

## 附魔台三格：A、B、C 之间各隔一格（5 列棋盘常用 x=0,2,4）。


static func forge_slot_cells(board_size: Vector2i) -> Array[Vector2i]:
	var mid := BoardHalf.midline_row(board_size.y)
	var y := clampi(mid - 2, 0, mid - 1)
	return [Vector2i(0, y), Vector2i(2, y), Vector2i(4, y)]


static func forge_slot_name_at(cell: Vector2i, board_size: Vector2i) -> StringName:
	var slots := forge_slot_cells(board_size)
	if cell == slots[0]:
		return &"a"
	if cell == slots[1]:
		return &"b"
	return &""


## 试验场：友方半场多行铺单位（可纵向滚动）。
static func build_expanded_team_cells(board_size: Vector2i, member_count: int, cols: int = 5) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var mid := BoardHalf.midline_row(board_size.y)
	var n := maxi(0, member_count)
	var col_n := maxi(1, cols)
	var rows := int(ceili(float(n) / float(col_n)))
	for r in rows:
		for c in col_n:
			var idx := r * col_n + c
			if idx >= n:
				break
			cells.append(Vector2i(c, mid + r))
	return cells


static func expanded_team_max_scroll_rows(board_size: Vector2i, member_count: int, cols: int = 5) -> float:
	var mid := BoardHalf.midline_row(board_size.y)
	var visible_rows := maxi(1, board_size.y - mid)
	var col_n := maxi(1, cols)
	var total_rows := int(ceili(float(maxi(1, member_count)) / float(col_n)))
	return maxf(0.0, float(total_rows - visible_rows))
