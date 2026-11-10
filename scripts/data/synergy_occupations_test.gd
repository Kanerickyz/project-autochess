class_name SynergyOccupationsTest
extends RefCounted
## 职业计数纯函数烟测（无 SceneTree）。


static func run_all() -> bool:
	var ok := true
	ok = _case_order_and_filter() and ok
	ok = _case_empty_and_unknown() and ok
	ok = _case_display_rows_sorted() and ok
	return ok


static func _case_order_and_filter() -> bool:
	var a := UnitData.new()
	a.occupation = SynergyOccupations.WARRIOR
	var b := UnitData.new()
	b.occupation = SynergyOccupations.TANK
	var c := UnitData.new()
	c.occupation = SynergyOccupations.WARRIOR
	var counts := SynergyOccupations.count_from_unit_datas([a, b, c])
	if int(counts.get(SynergyOccupations.TANK, 0)) != 1:
		push_error("tank count expected 1")
		return false
	if int(counts.get(SynergyOccupations.WARRIOR, 0)) != 2:
		push_error("warrior count expected 2")
		return false
	return true


static func _case_empty_and_unknown() -> bool:
	var blank := UnitData.new()
	blank.occupation = ""
	var junk := UnitData.new()
	junk.occupation = "法师"
	var counts := SynergyOccupations.count_from_unit_datas([blank, junk, null])
	for occ in SynergyOccupations.ORDER:
		if int(counts.get(occ, 0)) != 0:
			push_error("empty/unknown should not count")
			return false
	return true


static func _case_display_rows_sorted() -> bool:
	var counts := {
		SynergyOccupations.ARCANE: 2,
		SynergyOccupations.TANK: 1,
		SynergyOccupations.RANGED: 0,
	}
	var rows := SynergyOccupations.to_display_rows(counts)
	if rows.size() != 2:
		push_error("display rows expected 2 (count>=1 only)")
		return false
	if str(rows[0].get("name", "")) != SynergyOccupations.TANK:
		push_error("first row should be tank by ORDER")
		return false
	if str(rows[1].get("name", "")) != SynergyOccupations.ARCANE:
		push_error("second row should be arcane by ORDER")
		return false
	return true
