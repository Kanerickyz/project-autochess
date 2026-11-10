class_name SynergyOccupationsTest
extends RefCounted
## 职业计数纯函数烟测（无 SceneTree）。


static func run_all() -> bool:
	var ok := true
	ok = _case_order_and_filter() and ok
	ok = _case_empty_and_unknown() and ok
	ok = _case_duplicate_unit_id_counts_once() and ok
	ok = _case_display_rows_sorted() and ok
	return ok


static func _case_order_and_filter() -> bool:
	var a := UnitData.new()
	a.id = "warrior_a"
	a.occupation = SynergyOccupations.WARRIOR
	var b := UnitData.new()
	b.id = "tank_a"
	b.occupation = SynergyOccupations.TANK
	var c := UnitData.new()
	c.id = "warrior_b"
	c.occupation = SynergyOccupations.WARRIOR
	var counts := SynergyOccupations.count_from_unit_datas([a, b, c])
	if int(counts.get(SynergyOccupations.TANK, 0)) != 1:
		push_error("tank count expected 1")
		return false
	if int(counts.get(SynergyOccupations.WARRIOR, 0)) != 2:
		push_error("warrior count expected 2 distinct ids")
		return false
	return true


static func _case_empty_and_unknown() -> bool:
	var blank := UnitData.new()
	blank.id = "blank"
	blank.occupation = ""
	var junk := UnitData.new()
	junk.id = "junk"
	junk.occupation = "法师"
	var counts := SynergyOccupations.count_from_unit_datas([blank, junk, null])
	for occ in SynergyOccupations.ORDER:
		if int(counts.get(occ, 0)) != 0:
			push_error("empty/unknown should not count")
			return false
	return true


static func _case_duplicate_unit_id_counts_once() -> bool:
	var a := UnitData.new()
	a.id = "knight"
	a.occupation = SynergyOccupations.TANK
	var a2 := UnitData.new()
	a2.id = "knight"
	a2.occupation = SynergyOccupations.TANK
	var b := UnitData.new()
	b.id = "spike_shield"
	b.occupation = SynergyOccupations.TANK
	var counts := SynergyOccupations.count_from_unit_datas([a, a2, b])
	if int(counts.get(SynergyOccupations.TANK, 0)) != 2:
		push_error("duplicate knight should count once; expected tank=2 got %d" % int(counts.get(SynergyOccupations.TANK, 0)))
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
