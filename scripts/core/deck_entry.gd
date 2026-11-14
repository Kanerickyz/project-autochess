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
## 地图商店护甲：每角色最多一件；跨遭遇保留。转职纹章见 occupation_emblems。
var equipment: EquipmentData = null
## 护甲满额（战斗内可耗尽，离开战斗节点回满；下场开战再同步；装备本身不销毁）。
var equipment_armor_max: int = 0
## 转职纹章：附加异职标签；无硬顶；同职不叠；可与护甲同挂。
var occupation_emblems: Array[EquipmentData] = []
## 友方持久占位：座位下标（0 .. seat_grid-1）；-1 表示未入座。
var seat_index: int = -1
## 备战区格位（0 .. DeckState.BENCH_CAPACITY-1）；仅 seat_index < 0 时有效；-1 表示未分配。
var bench_slot_index: int = -1
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


func get_roster_population() -> int:
	if unit == null:
		return 1
	return unit.get_roster_population()


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


## 本职词表名；空 / 未知返回空串。
func get_native_occupation() -> String:
	if unit == null:
		return ""
	var occ := str(unit.occupation).strip_edges()
	if not SynergyOccupations.is_known(occ):
		return ""
	return occ


## 本职 + 转职纹章职业标签（去重，本职优先）。
func get_occupation_tags() -> PackedStringArray:
	var tags: PackedStringArray = []
	var seen: Dictionary = {}
	var native := get_native_occupation()
	if not native.is_empty():
		tags.append(native)
		seen[native] = true
	for emblem in occupation_emblems:
		if emblem == null:
			continue
		var occ := emblem.get_granted_occupation()
		if not SynergyOccupations.is_known(occ) or seen.has(occ):
			continue
		seen[occ] = true
		tags.append(occ)
	return tags


func has_occupation_tag(occupation: String) -> bool:
	var needle := occupation.strip_edges()
	if needle.is_empty():
		return false
	for tag in get_occupation_tags():
		if tag == needle:
			return true
	return false


## 挂护甲：duplicate 实例，避免改写商店池 / .tres 共享资源。新替旧；不碰转职纹章。
func attach_equipment(item: EquipmentData) -> void:
	if item == null:
		equipment = null
		equipment_armor_max = 0
		return
	## 纹章应走 try_attach_occupation_emblem；误传入则拒写护甲槽。
	if item.is_occupation_emblem():
		return
	equipment = item.duplicate(true) as EquipmentData
	equipment_armor_max = equipment.get_armor_block()


## 挂转职纹章：已有同职标签则失败；成功则 append 副本。
func try_attach_occupation_emblem(item: EquipmentData) -> bool:
	if item == null or not item.is_occupation_emblem():
		return false
	var occ := item.get_granted_occupation()
	if not SynergyOccupations.is_known(occ):
		return false
	if has_occupation_tag(occ):
		return false
	var copy := item.duplicate(true) as EquipmentData
	if copy == null:
		return false
	occupation_emblems.append(copy)
	return true


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
