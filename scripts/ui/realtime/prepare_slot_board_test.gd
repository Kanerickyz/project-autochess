class_name PrepareSlotBoardTest
extends RefCounted
## 座位几何：战斗半场前排贴中线；招募上区与我半场同行序；2×5 + 半格行距。


static func run_all() -> bool:
	var ok := true
	ok = _check("ally_front_above_back", _test_ally_front_above_back()) and ok
	ok = _check("enemy_front_near_midline", _test_enemy_front_near_midline()) and ok
	ok = _check("recruit_matches_ally_row_order", _test_recruit_matches_ally_row_order()) and ok
	ok = _check("recruit_front_not_enemy_front", _test_recruit_front_not_enemy_front()) and ok
	ok = _check("fills_half_field", _test_fills_half_field()) and ok
	ok = _check("combat_row_bias_follows_cell", _test_combat_row_bias_follows_cell()) and ok
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
	board.configure_grid(2, 5, Vector2i(5, 8), false)
	var front := board.get_cell(0)
	var back := board.get_cell(5) ## 末行首列
	var mid := BoardHalf.midline_row(8)
	return front.y >= mid and front.y < back.y and board.slot_count == 10


static func _test_enemy_front_near_midline() -> bool:
	var board := PrepareSlotBoard.new()
	board.configure_grid(2, 5, Vector2i(5, 8), true)
	var front := board.get_cell(0)
	var back := board.get_cell(5)
	var mid := BoardHalf.midline_row(8)
	return front.y < mid and front.y > back.y


static func _test_recruit_matches_ally_row_order() -> bool:
	var recruit := PrepareSlotBoard.new()
	recruit.configure_grid(2, 5, Vector2i(5, 8), true, true)
	var ally := PrepareSlotBoard.new()
	ally.configure_grid(2, 5, Vector2i(5, 8), false)
	var r_front := recruit.get_cell(0)
	var r_back := recruit.get_cell(5)
	var a_front := ally.get_cell(0)
	var a_back := ally.get_cell(5)
	## 同行序：前排 y 小于后排；列对齐。
	if not (r_front.y < r_back.y and a_front.y < a_back.y):
		return false
	if r_front.x != a_front.x or r_back.x != a_back.x:
		return false
	return BoardHalf.midline_row(8) > r_front.y


static func _test_recruit_front_not_enemy_front() -> bool:
	## 招募上区前排 ≠ 敌方前排落点（避免再退回旧颠倒映射）。
	var recruit := PrepareSlotBoard.new()
	recruit.configure_grid(2, 5, Vector2i(5, 8), true, true)
	var enemy := PrepareSlotBoard.new()
	enemy.configure_grid(2, 5, Vector2i(5, 8), true, false)
	return recruit.get_cell(0).y != enemy.get_cell(0).y


static func _test_fills_half_field() -> bool:
	## 2×5 贴中线落在半场内（共 10 格）；半场仍 4 行高，不要求填满 20 格。
	var ally := PrepareSlotBoard.new()
	ally.configure_grid(2, 5, Vector2i(5, 8), false)
	var mid := BoardHalf.midline_row(8)
	var half_bottom := 8
	var seen: Dictionary = {}
	var min_y := 999
	var max_y := -1
	for cell in ally.cells:
		if cell.y < mid or cell.y >= half_bottom or cell.x < 0 or cell.x >= 5:
			return false
		seen["%d,%d" % [cell.x, cell.y]] = true
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	if seen.size() != 10 or ally.slot_count != 10:
		return false
	## 逻辑相邻行贴中线：y = mid / mid+1；半格观感由 get_display_center 额外拉开。
	if not (min_y == mid and max_y == mid + 1 and max_y - min_y == 1):
		return false
	var front_c := ally.get_display_center(0)
	var back_c := ally.get_display_center(5)
	if not is_equal_approx(back_c.y - front_c.y, 1.0 + PrepareSlotBoard.SEAT_ROW_EXTRA_GAP):
		return false
	## 敌我四行显示格心距一致（隔半格）。
	var enemy := PrepareSlotBoard.new()
	enemy.configure_grid(2, 5, Vector2i(5, 8), true)
	var gap := 1.0 + PrepareSlotBoard.SEAT_ROW_EXTRA_GAP
	var e_back := enemy.get_display_center(5).y
	var e_front := enemy.get_display_center(0).y
	var a_front := ally.get_display_center(0).y
	var a_back := ally.get_display_center(5).y
	return (
		is_equal_approx(e_front - e_back, gap)
		and is_equal_approx(a_front - e_front, gap)
		and is_equal_approx(a_back - a_front, gap)
	)


static func _test_combat_row_bias_follows_cell() -> bool:
	var board := Vector2i(5, 8)
	var front_y := 4
	var back_y := 5
	var front_b := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, front_y), board, false)
	var back_b := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, back_y), board, false)
	var empty_b := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 6), board, false)
	if not is_equal_approx(front_b.y, -PrepareSlotBoard.SEAT_ROW_EXTRA_GAP * 0.5):
		return false
	if not is_equal_approx(back_b.y, PrepareSlotBoard.SEAT_ROW_EXTRA_GAP * 0.5):
		return false
	if empty_b != Vector2.ZERO:
		return false
	var enemy_front := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 2), board, true)
	var enemy_back := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 1), board, true)
	return (
		is_equal_approx(enemy_front.y, PrepareSlotBoard.SEAT_ROW_EXTRA_GAP * 0.5)
		and is_equal_approx(enemy_back.y, -PrepareSlotBoard.SEAT_ROW_EXTRA_GAP * 0.5)
	)


static func _test_bench_row_below_board() -> bool:
	var board := PrepareSlotBoard.new()
	board.configure_bench_row(Vector2i(5, 8), 5)
	if board.slot_count != 5 or board.cells.size() != 5:
		return false
	var xs: Dictionary = {}
	for cell in board.cells:
		if cell.y != 8:
			return false
		if cell.x < 0 or cell.x >= 5:
			return false
		xs[cell.x] = true
	if not (xs.size() == 5 and board.find_slot_at_cell(Vector2i(2, 8)) == 2):
		return false
	## 招募中缝：显式 row_y = midline。
	var mid := BoardHalf.midline_row(8)
	var seam := PrepareSlotBoard.new()
	seam.configure_bench_row(Vector2i(5, 8), 5, mid)
	for cell in seam.cells:
		if cell.y != mid:
			return false
	return seam.find_slot_at_cell(Vector2i(2, mid)) == 2
