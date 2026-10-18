class_name PrepareSlotBoardTest
extends RefCounted
## 座位几何：战斗半场前排近中线；招募上区与我半场同行序；4×5 铺满半场。


static func run_all() -> bool:
	var ok := true
	ok = _check("ally_front_above_back", _test_ally_front_above_back()) and ok
	ok = _check("enemy_front_near_midline", _test_enemy_front_near_midline()) and ok
	ok = _check("recruit_matches_ally_row_order", _test_recruit_matches_ally_row_order()) and ok
	ok = _check("recruit_front_not_enemy_front", _test_recruit_front_not_enemy_front()) and ok
	ok = _check("fills_half_field", _test_fills_half_field()) and ok
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
	return front.y < mid and front.y > back.y


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
	var ally := PrepareSlotBoard.new()
	ally.configure_grid(4, 5, Vector2i(5, 8), false)
	var mid := BoardHalf.midline_row(8)
	var seen: Dictionary = {}
	for cell in ally.cells:
		if cell.y < mid or cell.x < 0 or cell.x >= 5:
			return false
		seen["%d,%d" % [cell.x, cell.y]] = true
	return seen.size() == 20
