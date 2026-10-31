class_name CombatStatusStack
extends RefCounted

const ID_WEAK := &"weak"
const ID_BERSERK := &"berserk"
const ID_POISON := &"poison"
const ID_RELIC_BONE := &"relic_bone"
const MAX_STACKS := 15

const DISPLAY_ORDER: Array[StringName] = [ID_WEAK, ID_BERSERK, ID_POISON, ID_RELIC_BONE]

var _stacks: Dictionary = {}


static func is_valid_id(status_id: StringName) -> bool:
	return (
		status_id == ID_WEAK
		or status_id == ID_BERSERK
		or status_id == ID_POISON
		or status_id == ID_RELIC_BONE
	)


static func get_display_name(status_id: StringName) -> String:
	match status_id:
		ID_WEAK:
			return "虚弱"
		ID_BERSERK:
			return "狂暴"
		ID_POISON:
			return "中毒"
		ID_RELIC_BONE:
			return "遗骨"
		_:
			return String(status_id)


static func get_rule_summary(status_id: StringName) -> String:
	match status_id:
		ID_WEAK:
			return "受到普攻或技能伤害时，护甲前该次伤害 +1（每层）。"
		ID_BERSERK:
			return "普攻伤害在护甲前 +1（每层）。"
		ID_POISON:
			return "你的回合开始时失去生命（每层 1 点，先于回合开始技能）。"
		ID_RELIC_BONE:
			return "遗骨：死亡时生成攻/血均等于层数×2 的骷髅"
		_:
			return ""


static func adjust_attack_damage(base: int, attacker: UnitInstance) -> int:
	if attacker == null or base <= 0:
		return base
	var stacks := attacker.combat_statuses.get_stacks(ID_BERSERK)
	return base + stacks


static func adjust_incoming_before_armor(base: int, defender: UnitInstance) -> int:
	if defender == null or base <= 0:
		return base
	var stacks := defender.combat_statuses.get_stacks(ID_WEAK)
	return base + stacks


func get_stacks(status_id: StringName) -> int:
	return int(_stacks.get(status_id, 0))


func add_stacks(status_id: StringName, delta: int) -> int:
	if not is_valid_id(status_id) or delta == 0:
		return get_stacks(status_id)
	var next := get_stacks(status_id) + delta
	next = clampi(next, 0, MAX_STACKS)
	if next <= 0:
		_stacks.erase(status_id)
	else:
		_stacks[status_id] = next
	return next


func remove_stacks(status_id: StringName, amount: int) -> int:
	if amount <= 0:
		if get_stacks(status_id) > 0:
			_stacks.erase(status_id)
			return 0
		return 0
	return add_stacks(status_id, -amount)


func list_active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for status_id in DISPLAY_ORDER:
		if get_stacks(status_id) > 0:
			out.append(status_id)
	return out


func clear() -> void:
	_stacks.clear()
