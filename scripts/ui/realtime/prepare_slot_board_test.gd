class_name PrepareSlotBoardTest
extends RefCounted
## 座位几何：战斗半场前排近中线；招募上区与我半场同行序；2×5 铺满半场。


static func run_all() -> bool:
	var ok := true
	ok = _check("ally_front_above_back", _test_ally_front_above_back()) and ok
	ok = _check("enemy_front_near_midline", _test_enemy_front_near_midline()) and ok
	ok = _check("recruit_matches_ally_row_order", _test_recruit_matches_ally_row_order()) and ok
	ok = _check("recruit_front_not_enemy_front", _test_recruit_front_not_enemy_front()) and ok
	ok = _check("fills_half_field", _test_fills_half_field()) and ok
	ok = _check("bench_row_below_board", _test_bench_row_below_board()) and ok
	if ok:
		print("PrepareSlotBoardTest: all passed")
	else:
		push_error("PrepareSlotBoardTest: failures detected")
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("  PASS %s" % name)
	else:
		push_error("PrepareSlotBoardTest: FAIL %s" % name)
	return passed


static func _test_ally_front_above_back() -> bool:
	var board := PrepareSlotBoard.new()
	board.configure_grid(2, 5, Vector2i(5, 4), false)
	var front := board.get_cell(0)
	var back := board.get_cell(5) ## 末行首列
	var mid := BoardHalf.midline_row(4)
	return front.y >= mid and front.y < back.y and board.slot_count == 10


static func _test_enemy_front_near_midline() -> bool:
	var board := PrepareSlotBoard.new()
	board.configure_grid(2, 5, Vector2i(5, 4), true)
	var front := board.get_cell(0)
	var back := board.get_cell(5)
	var mid := BoardHalf.midline_row(4)
	return front.y < mid and front.y > back.y


static func _test_recruit_matches_ally_row_order() -> bool:
	var recruit := PrepareSlotBoard.new()
	recruit.configure_grid(2, 5, Vector2i(5, 4), true, true)
	var ally := PrepareSlotBoard.new()
	ally.configure_grid(2, 5, Vector2i(5, 4), false)
	var r_front := recruit.get_cell(0)
	var r_back := recruit.get_cell(5)
	var a_front := ally.get_cell(0)
	var a_back := ally.get_cell(5)
	## 同行序：前排 y 小于后排；列对齐。
	if not (r_front.y < r_back.y and a_front.y < a_back.y):
		return false
	if r_front.x != a_front.x or r_back.x != a_back.x:
		return false
	return BoardHalf.midline_row(4) > r_front.y


static func _test_recruit_front_not_enemy_front() -> bool:
	## 招募上区前排 ≠ 敌方前排落点（避免再退回旧颠倒映射）。
	var recruit := PrepareSlotBoard.new()
	recruit.configure_grid(2, 5, Vector2i(5, 4), true, true)
	var enemy := PrepareSlotBoard.new()
	enemy.configure_grid(2, 5, Vector2i(5, 4), true, false)
	return recruit.get_cell(0).y != enemy.get_cell(0).y


static func _test_fills_half_field() -> bool:
	var ally := PrepareSlotBoard.new()
	ally.configure_grid(2, 5, Vector2i(5, 4), false)
	var mid := BoardHalf.midline_row(4)
	var seen: Dictionary = {}
	for cell in ally.cells:
		if cell.y < mid or cell.x < 0 or cell.x >= 5:
			return false
		seen["%d,%d" % [cell.x, cell.y]] = true
	return seen.size() == 10


static func _test_bench_row_below_board() -> bool:
	var board := PrepareSlotBoard.new()
	board.configure_bench_row(Vector2i(5, 4), 5)
	if board.slot_count != 5 or board.cells.size() != 5:
		return false
	var xs: Dictionary = {}
	for cell in board.cells:
		if cell.y != 4:
			return false
		if cell.x < 0 or cell.x >= 5:
			return false
		xs[cell.x] = true
	if not (xs.size() == 5 and board.find_slot_at_cell(Vector2i(2, 4)) == 2):
		return false
	## 招募中缝：显式 row_y = midline。
	var mid := BoardHalf.midline_row(4)
	var seam := PrepareSlotBoard.new()
	seam.configure_bench_row(Vector2i(5, 4), 5, mid)
	for cell in seam.cells:
		if cell.y != mid:
			return false
	return seam.find_slot_at_cell(Vector2i(2, mid)) == 2
