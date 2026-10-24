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
## 地图商店装备：每角色最多一件；跨遭遇保留。
var equipment: EquipmentData = null
## 护甲满额（战斗内可耗尽，离开战斗节点回满；下场开战再同步；装备本身不销毁）。
var equipment_armor_max: int = 0
## 友方持久占位：座位下标（0 .. seat_grid-1）；-1 表示未入座。
var seat_index: int = -1
## 落座时间序：越大越晚；0 表示从未成功落座。开战生成序 / 三合一最早座用。
var seat_assign_seq: int = 0
## 附魔熔印者等 runtime 主技能；优先于 unit.ability。
var runtime_main_ability: AbilityData = null


func get_unit_id() -> String:
	if unit == null:
		return ""
	return unit.id


func get_display_name() -> String:
	if is_fused_enchant():
		return FusedEnchantIds.DISPLAY_NAME
	if unit != null and not unit.display_name.is_empty():
		return unit.display_name
	if unit != null:
		return unit.id
	return "未知"


func is_fused_enchant() -> bool:
	return FusedEnchantIds.is_fused_unit_id(get_unit_id())


func get_main_ability() -> AbilityData:
	if runtime_main_ability != null:
		return runtime_main_ability
	if unit != null:
		return unit.ability
	return null


## 0 = 无星展示（熔印者）；否则 1～3。
func get_star_display_level() -> int:
	if is_fused_enchant():
		return 0
	return clampi(level, 1, 3)


## 【已停用】号令费用；保留兼容旧调用。
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


func get_armor_block() -> int:
	if equipment == null:
		return 0
	return equipment.get_armor_block()


func get_equipment_display_name() -> String:
	if equipment == null:
		return ""
	return equipment.get_display_name()


## 挂装备：duplicate 实例，避免改写商店池 / .tres 共享资源。
func attach_equipment(item: EquipmentData) -> void:
	if item == null:
		equipment = null
		equipment_armor_max = 0
		return
	equipment = item.duplicate(true) as EquipmentData
	equipment_armor_max = equipment.get_armor_block()


## 战斗护甲消耗回写：耗尽仅本回合无效，不回写销毁装备。
func apply_armor_remaining(remaining: int) -> void:
	if equipment == null:
		return
	equipment.armor_block = maxi(0, remaining)


## 离开战斗节点 / 新一场开战：护甲恢复至满额。
func refill_equipment_armor() -> void:
	if equipment == null:
		equipment_armor_max = 0
		return
	if equipment_armor_max <= 0:
		equipment_armor_max = equipment.get_armor_block()
	equipment.armor_block = equipment_armor_max
