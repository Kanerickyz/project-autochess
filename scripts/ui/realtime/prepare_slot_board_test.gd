class_name PrepareSlotBoardTest
extends RefCounted
## 座位几何：战斗半场前排贴中线；招募上区与我半场同行序；4×5 铺满半场（主路径 5×8）。


static func run_all() -> bool:
	var ok := true
	ok = _check("ally_front_above_back", _test_ally_front_above_back()) and ok
	ok = _check("enemy_front_near_midline", _test_enemy_front_near_midline()) and ok
	ok = _check("recruit_matches_ally_row_order", _test_recruit_matches_ally_row_order()) and ok
	ok = _check("recruit_front_not_enemy_front", _test_recruit_front_not_enemy_front()) and ok
	ok = _check("fills_half_field", _test_fills_half_field()) and ok
	ok = _check("combat_row_bias_follows_cell", _test_combat_row_visual_bias()) and ok
	ok = _check("bench_row_below_board", _test_bench_row_below_board()) and ok
	ok = _check("footprint_display_center_span2", _test_footprint_display_center_span2()) and ok
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
	board.configure_grid(4, 5, Vector2i(5, 8), false)
	var front := board.get_cell(0)
	var back := board.get_cell(15) ## 末行首列
	var mid := BoardHalf.midline_row(8)
	return front.y >= mid and front.y < back.y and board.slot_count == 20


static func _test_enemy_front_near_midline() -> bool:
	var board := PrepareSlotBoard.new()
	board.configure_grid(4, 5, Vector2i(5, 8), true)
	var front := board.get_cell(0)
	var back := board.get_cell(15)
	var mid := BoardHalf.midline_row(8)
	## 5×8 + 4 行铺满：敌前 y=3、敌后 y=0（mid_sep=1）。
	return front.y < mid and front.y > back.y and front.y == 3 and back.y == 0


static func _test_recruit_matches_ally_row_order() -> bool:
	var recruit := PrepareSlotBoard.new()
	recruit.configure_grid(4, 5, Vector2i(5, 8), true, true)
	var ally := PrepareSlotBoard.new()
	ally.configure_grid(4, 5, Vector2i(5, 8), false)
	var r_front := recruit.get_cell(0)
	var r_back := recruit.get_cell(15)
	var a_front := ally.get_cell(0)
	var a_back := ally.get_cell(15)
	## 同行序：前排 y 小于后排；列对齐。
	if not (r_front.y < r_back.y and a_front.y < a_back.y):
		return false
	if r_front.x != a_front.x or r_back.x != a_back.x:
		return false
	return BoardHalf.midline_row(8) > r_front.y


static func _test_recruit_front_not_enemy_front() -> bool:
	## 招募上区前排 ≠ 敌方前排落点（避免再退回旧颠倒映射）。
	var recruit := PrepareSlotBoard.new()
	recruit.configure_grid(4, 5, Vector2i(5, 8), true, true)
	var enemy := PrepareSlotBoard.new()
	enemy.configure_grid(4, 5, Vector2i(5, 8), true, false)
	return recruit.get_cell(0).y != enemy.get_cell(0).y


static func _test_fills_half_field() -> bool:
	## 4×5 铺满我半场（y=4..7）；共 20 格。
	var ally := PrepareSlotBoard.new()
	ally.configure_grid(4, 5, Vector2i(5, 8), false)
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
	if seen.size() != 20 or ally.slot_count != 20:
		return false
	if not (min_y == mid and max_y == half_bottom - 1):
		return false
	var front_c := ally.get_display_center(0)
	var next_c := ally.get_display_center(5)
	var gap := 1.0 + PrepareSlotBoard.SEAT_ROW_EXTRA_GAP
	if not is_equal_approx(next_c.y - front_c.y, gap):
		return false
	var enemy := PrepareSlotBoard.new()
	enemy.configure_grid(4, 5, Vector2i(5, 8), true)
	var e_front := enemy.get_display_center(0).y
	var a_front := ally.get_display_center(0).y
	return is_equal_approx(a_front - e_front, gap)


static func _test_combat_row_visual_bias() -> bool:
	var board := Vector2i(5, 8)
	## 贴满 4 行：友前 y=4 … 友后 y=7；累积外推。
	var spread := PrepareSlotBoard.SEAT_ROW_EXTRA_GAP * 0.5
	var extra := PrepareSlotBoard.SEAT_ROW_EXTRA_GAP
	var front_b := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 4), board, false)
	var back_b := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 7), board, false)
	var empty_b := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 0), board, true)
	## empty_b with enemy_side true on y=0 is enemy back, not empty — use mid gap cell if any.
	## y=0 is enemy back when packed; check a non-seat? All half cells are seats when 4×5.
	## 用友半场外不应出现：此处仅验友侧 bias。
	if empty_b == Vector2.ZERO:
		## y=0 在敌侧有座位；换用不存在的列外——跳过 empty 断言。
		pass
	if not is_equal_approx(front_b.y, spread):
		return false
	if not is_equal_approx(back_b.y, spread + 3.0 * extra):
		return false
	var enemy_front := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 3), board, true)
	var enemy_back := PrepareSlotBoard.combat_row_visual_bias(Vector2i(0, 0), board, true)
	return (
		is_equal_approx(enemy_front.y, -spread)
		and is_equal_approx(enemy_back.y, -spread - 3.0 * extra)
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
	var mid := BoardHalf.midline_row(8)
	var seam := PrepareSlotBoard.new()
	seam.configure_bench_row(Vector2i(5, 8), 5, mid)
	for cell in seam.cells:
		if cell.y != mid:
			return false
	return seam.find_slot_at_cell(Vector2i(2, mid)) == 2


static func _test_footprint_display_center_span2() -> bool:
	var unit := load("res://resources/units/realtime/ghost_graveyard.tres") as UnitData
	if unit == null or unit.footprint_w < 2:
		return false
	var board := PrepareSlotBoard.new()
	board.configure_grid(4, 5, Vector2i(5, 8), false)
	var indices := board.get_footprint_seat_indices(0, unit)
	if indices.size() != 2 or indices[0] != 0 or indices[1] != 1:
		return false
	var c0 := board.get_display_center(0)
	var c1 := board.get_display_center(1)
	var mid := board.get_footprint_display_center(0, unit)
	return is_equal_approx(mid.x, (c0.x + c1.x) * 0.5) and is_equal_approx(mid.y, (c0.y + c1.y) * 0.5)
