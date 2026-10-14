class_name DeckEntry
extends RefCounted

var entry_id: int = -1
var unit: UnitData
var attached_buffs: Array[BuffCardData] = []
var attached_abilities: Array[AbilityData] = []
var rule_flags: Dictionary = {}
var level: int = 1
var experience: int = 0
var bonus_attack: int = 0
var bonus_max_hp: int = 0
var bonus_crit_rate_percent: int = 0


func get_unit_id() -> String:
	if unit == null:
		return ""
	return unit.id


func get_display_name() -> String:
	if unit != null and not unit.display_name.is_empty():
		return unit.display_name
	if unit != null:
		return unit.id
	return "未知"


func get_command_cost() -> int:
	if unit == null:
		return 1
	return unit.get_command_cost()


func get_buff_summary() -> String:
	if attached_buffs.is_empty():
		return ""
	var names: PackedStringArray = []
	for buff in attached_buffs:
		if buff != null and not buff.display_name.is_empty():
			names.append(buff.display_name)
		elif buff != null:
			names.append(buff.id)
	return ", ".join(names)
