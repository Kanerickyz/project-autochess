class_name StageChoiceBoardTest
extends RefCounted


static func run_all() -> bool:
	var ok := true
	ok = _expect(
		StageChoiceBoard.build_row_cells(2, Vector2i(5, 4), 0).size() == 2,
		"two choice cells",
	) and ok
	var cells := StageChoiceBoard.build_row_cells(3, Vector2i(5, 4), 0)
	ok = _expect(cells.size() == 3, "three choice cells") and ok
	var mid := BoardHalf.midline_row(4)
	for c in cells:
		ok = _expect(c.y < mid, "choice cells stay above mid") and ok
	var laid := StageChoiceBoard.layout_choices(
		[{"id": &"a", "label": "A"}, {"id": &"b", "label": "B"}],
		Vector2i(5, 4),
		0,
	)
	ok = _expect(laid.size() == 2, "layout preserves count") and ok
	ok = _expect(
		StageChoiceBoard.find_index_at(laid, (laid[0] as Dictionary).get("cell")) == 0,
		"find index at cell",
	) and ok
	var anchor: Vector2i = (laid[0] as Dictionary).get("cell")
	ok = _expect(
		StageChoiceBoard.find_index_at(laid, Vector2i(anchor.x, 1), Vector2i(5, 4)) == 0,
		"find index by same column in enemy half",
	) and ok
	ok = _expect(
		StageChoiceBoard.find_index_at(laid, Vector2i(anchor.x, 2), Vector2i(5, 4)) < 0,
		"ignore ally-half clicks",
	) and ok
	ok = _expect(
		StageChoiceBoard.truncate_preview("远征圣物效果说明很长很长", 8) == "远征圣物效果说…",
		"truncate preview",
	) and ok
	ok = _expect(
		StageChoiceBoard.truncate_preview("短文") == "短文",
		"truncate keeps short",
	) and ok
	return ok


static func _expect(cond: bool, label: String) -> bool:
	if cond:
		print("StageChoiceBoardTest: %s OK" % label)
		return true
	push_error("StageChoiceBoardTest: %s failed" % label)
	return false
