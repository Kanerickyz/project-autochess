class_name UnitInfoAttachmentsTest
extends RefCounted


static func run_all() -> bool:
	var passed := true
	passed = _check("entry_skills_exclude_equipment", _test_entry_skills_exclude_equipment()) and passed
	passed = _check("entry_equipment_attachment", _test_entry_equipment_attachment()) and passed
	passed = _check("bold_skill_trigger_bbcode", _test_bold_skill_trigger_bbcode()) and passed
	return passed


static func _check(label: String, ok: bool) -> bool:
	if not ok:
		push_error("UnitInfoAttachmentsTest: %s failed" % label)
	return ok


static func _test_entry_skills_exclude_equipment() -> bool:
	var entry := DeckEntry.new()
	var unit := UnitData.new()
	unit.id = "test_unit"
	entry.unit = unit
	var eq := EquipmentData.new()
	eq.id = "armor_t1"
	eq.display_name = "皮甲"
	eq.armor_block = 4
	entry.attach_equipment(eq)
	var skills := UnitInfoText.get_skills_block_from_entry(entry, false)
	if skills.contains("【装备】"):
		return false
	var attachments := UnitInfoText.collect_info_attachments_from_entry(entry, false)
	return attachments.size() == 1


static func _test_entry_equipment_attachment() -> bool:
	var entry := DeckEntry.new()
	var unit := UnitData.new()
	entry.unit = unit
	var eq := EquipmentData.new()
	eq.display_name = "链甲"
	eq.armor_block = 6
	entry.attach_equipment(eq)
	entry.apply_armor_remaining(2)
	var attachments := UnitInfoText.collect_info_attachments_from_entry(entry, false)
	if attachments.size() != 1:
		return false
	var info: Dictionary = attachments[0]
	if String(info.get("name", "")) != "链甲":
		return false
	if int(info.get("armor", -1)) != 2:
		return false
	var body := String(info.get("skills", ""))
	return body.contains("2 / 6")


static func _test_bold_skill_trigger_bbcode() -> bool:
	var out := UnitInfoText.bold_skill_trigger_bbcode("击杀时 对全场 造成 2 点伤害")
	if out != "[b]击杀时[/b] 对全场 造成 2 点伤害":
		return false
	var multi := UnitInfoText.bold_skill_trigger_bbcode(
		"攻击击杀时 对随机敌人造成 1 点伤害；死亡时 对全场造成 2 点伤害"
	)
	return multi.begins_with("[b]攻击击杀时[/b]") and multi.contains("；[b]死亡时[/b]")
