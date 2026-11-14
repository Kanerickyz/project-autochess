class_name SynergyOccupationsTest
extends RefCounted
## 职业计数纯函数烟测（无 SceneTree）。


static func run_all() -> bool:
	var ok := true
	ok = _case_order_and_filter() and ok
	ok = _case_empty_and_unknown() and ok
	ok = _case_duplicate_unit_id_counts_once() and ok
	ok = _case_display_rows_sorted() and ok
	ok = _case_emblem_tags_count_from_entries() and ok
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


## 入座 entry：本职 + 转职附加计入；同 id 只处理第一次。
static func _case_emblem_tags_count_from_entries() -> bool:
	var unit_a := UnitData.new()
	unit_a.id = "hero"
	unit_a.occupation = SynergyOccupations.WARRIOR
	var unit_b := UnitData.new()
	unit_b.id = "hero"
	unit_b.occupation = SynergyOccupations.WARRIOR
	var unit_c := UnitData.new()
	unit_c.id = "mage"
	unit_c.occupation = SynergyOccupations.ARCANE

	var e1 := DeckEntry.new()
	e1.unit = unit_a
	var tank_em := EquipmentData.new()
	tank_em.id = "emblem_tank"
	tank_em.granted_occupation = SynergyOccupations.TANK
	e1.occupation_emblems.append(tank_em)

	var e2 := DeckEntry.new()
	e2.unit = unit_b
	## 第二份同 id：即使无纹章也应被跳过（不覆盖第一次的坦克计数）。

	var e3 := DeckEntry.new()
	e3.unit = unit_c

	var counts := SynergyOccupations.count_from_deck_entries([e1, e2, e3])
	if int(counts.get(SynergyOccupations.WARRIOR, 0)) != 1:
		push_error("warrior expected 1 (hero once)")
		return false
	if int(counts.get(SynergyOccupations.TANK, 0)) != 1:
		push_error("tank expected 1 from emblem on first hero")
		return false
	if int(counts.get(SynergyOccupations.ARCANE, 0)) != 1:
		push_error("arcane expected 1")
		return false
	return true
