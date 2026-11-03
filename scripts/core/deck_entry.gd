class_name DeckEntry
extends RefCounted

const EQUIPMENT_SLOT_HARD_MAX := 3
const COMMANDER_EQUIPMENT_SLOTS := 1

var entry_id: int = -1
var unit: UnitData
var attached_buffs: Array[BuffCardData] = []
var attached_abilities: Array[AbilityData] = []
var rule_flags: Dictionary = {}
var level: int = 1
var experience: int = 0
var bonus_attack: int = 0
var bonus_max_hp: int = 0
## 装备槽内容：最多 3 件（受行为职业槽上限限制）；跨遭遇保留。
## 护甲与技能类共槽；合计护甲 = 各件护甲 armor_block 之和（战斗扫读/结算一条）。
var equipments: Array[EquipmentData] = []
## 各件护甲满额（与 equipments 对齐；战斗耗尽后 refill 用）。
var equipment_piece_max: Array[int] = []
## 合计护甲满额缓存（attach / refill 时更新）。
var equipment_armor_max: int = 0
## 友方持久占位：座位下标（0 .. seat_grid-1）；-1 表示未入座。
var seat_index: int = -1
## 备战区格位（0 .. DeckState.BENCH_CAPACITY-1）；仅 seat_index < 0 时有效；-1 表示未分配。
var bench_slot_index: int = -1
## 落座时间序：越大越晚；0 表示从未成功落座。开战生成序 / 三合一最早座用。
var seat_assign_seq: int = 0
## 附魔熔印者等 runtime 主技能；优先于 unit.ability。
var runtime_main_ability: AbilityData = null
## 指挥官跨遭遇当前生命；-1 = 尚未写入（开战按满血）。普通成员忽略，每场仍满血开局。
var persisted_current_hp: int = -1


## 兼容旧调用：第一件装备（只读语义为主；赋值视为「只保留这一件」）。
var equipment: EquipmentData:
	get:
		return get_equipment_at(0)
	set(value):
		_set_equipment_compat(value)


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


## 场上指挥官条目：可换座 / 可强化；不占上场席位上限；不可出售、不可入备战、不参与三合一。
func is_commander() -> bool:
	return get_unit_id() == "commander"


func is_fused_enchant() -> bool:
	return FusedEnchantIds.is_fused_unit_id(get_unit_id())


func get_main_ability() -> AbilityData:
	if runtime_main_ability != null:
		return runtime_main_ability
	var equipped := get_equipment_abilities()
	if not equipped.is_empty():
		return equipped[0]
	## 模板回退：献祭/熔印等仍可读角色关联技能；开战友方空装不靠此触发。
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


## 装备槽上限：由行为职业派生（坦克 0／近战 1／刺客 2／远程 3）；无 unit 时默认 1。
func get_equipment_slot_count() -> int:
	if unit == null:
		return 1
	## 指挥官不属于四职业槽位表：固定 1 格。
	if is_commander():
		return COMMANDER_EQUIPMENT_SLOTS
	return clampi(unit.get_equipment_slot_count_resolved(), 0, EQUIPMENT_SLOT_HARD_MAX)


func get_equipment_occupied() -> int:
	return equipments.size()


func has_empty_equipment_slot() -> bool:
	return get_equipment_occupied() < get_equipment_slot_count()


func get_equipments() -> Array[EquipmentData]:
	return equipments.duplicate()


func get_equipment_at(index: int) -> EquipmentData:
	if index < 0 or index >= equipments.size():
		return null
	return equipments[index]


## 技能类装备上的 AbilityData 列表（槽序；同 id 两件会各出现一次）。
func get_equipment_abilities() -> Array[AbilityData]:
	var out: Array[AbilityData] = []
	for item in equipments:
		if item == null or not item.is_ability_kind():
			continue
		var ab := item.get_ability()
		if ab != null:
			out.append(ab)
	return out


## 合计当前护甲（仅护甲类各件 armor_block 之和）。
func get_armor_block() -> int:
	var total := 0
	for item in equipments:
		if item != null:
			total += item.get_armor_block()
	return total


func get_equipment_display_name() -> String:
	if equipments.is_empty():
		return ""
	if equipments.size() == 1:
		var only := equipments[0]
		return only.get_display_name() if only != null else ""
	var names: PackedStringArray = []
	for item in equipments:
		if item != null:
			names.append(item.get_display_name())
	return "、".join(names)


func _recompute_equipment_armor_max() -> void:
	var total := 0
	for v in equipment_piece_max:
		total += maxi(0, int(v))
	equipment_armor_max = total


func _set_equipment_compat(item: EquipmentData) -> void:
	equipments.clear()
	equipment_piece_max.clear()
	equipment_armor_max = 0
	if item == null:
		return
	var copy := item.duplicate(true) as EquipmentData
	if copy == null:
		return
	equipments.append(copy)
	equipment_piece_max.append(copy.get_armor_block())
	_recompute_equipment_armor_max()


## 挂装备：有空槽则 duplicate 挂入；满槽返回 false。item==null 清空全部。
func attach_equipment(item: EquipmentData) -> bool:
	if item == null:
		equipments.clear()
		equipment_piece_max.clear()
		equipment_armor_max = 0
		return true
	if not has_empty_equipment_slot():
		return false
	var copy := item.duplicate(true) as EquipmentData
	if copy == null:
		return false
	equipments.append(copy)
	equipment_piece_max.append(copy.get_armor_block())
	_recompute_equipment_armor_max()
	return true


## 按槽下标卸下并返回该件（调用方负责进暂存）；非法下标返回 null。
## 返回 Dictionary: { "item": EquipmentData, "piece_max": int }；失败返回空。
func take_equipment_at(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= equipments.size():
		return {}
	var item: EquipmentData = equipments[slot_index]
	var piece_max := 0
	if slot_index < equipment_piece_max.size():
		piece_max = maxi(0, int(equipment_piece_max[slot_index]))
	elif item != null:
		piece_max = item.get_armor_block()
	equipments.remove_at(slot_index)
	if slot_index < equipment_piece_max.size():
		equipment_piece_max.remove_at(slot_index)
	_recompute_equipment_armor_max()
	## 卸载发生在非战斗写阶段；回满便于暂存展示。
	if item != null and piece_max > 0:
		item.armor_block = piece_max
	return {"item": item, "piece_max": piece_max}


## 用已有副本填槽（三合一 / 暂存挪装）；不 duplicate。满槽返回 false。
func try_receive_equipment_instance(item: EquipmentData, piece_max: int = -1) -> bool:
	if item == null:
		return false
	if not has_empty_equipment_slot():
		return false
	equipments.append(item)
	var cap := piece_max if piece_max >= 0 else item.get_armor_block()
	equipment_piece_max.append(maxi(0, cap))
	_recompute_equipment_armor_max()
	return true


## 战斗护甲消耗回写：合计剩余按槽依次分配（前槽优先保留）。
func apply_armor_remaining(remaining: int) -> void:
	var left := maxi(0, remaining)
	for i in equipments.size():
		var item: EquipmentData = equipments[i]
		if item == null:
			continue
		var cap := equipment_piece_max[i] if i < equipment_piece_max.size() else item.get_armor_block()
		cap = maxi(0, cap)
		var give := mini(cap, left)
		item.armor_block = give
		left -= give


## 离开战斗节点 / 新一场开战：护甲恢复至满额。
func refill_equipment_armor() -> void:
	if equipments.is_empty():
		equipment_piece_max.clear()
		equipment_armor_max = 0
		return
	## 对齐长度：旧存档缺 piece_max 时用当前 armor 回填。
	while equipment_piece_max.size() < equipments.size():
		var eq: EquipmentData = equipments[equipment_piece_max.size()]
		equipment_piece_max.append(eq.get_armor_block() if eq != null else 0)
	if equipment_piece_max.size() > equipments.size():
		equipment_piece_max.resize(equipments.size())
	for i in equipments.size():
		var item: EquipmentData = equipments[i]
		if item == null:
			continue
		var cap := maxi(0, int(equipment_piece_max[i]))
		if cap <= 0:
			cap = item.get_armor_block()
			equipment_piece_max[i] = cap
		item.armor_block = cap
	_recompute_equipment_armor_max()
