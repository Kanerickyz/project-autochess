class_name CombatStatusRevive
extends RefCounted
## 战斗状态「复活」：死亡时按层数生成无技能复制体（攻=层、血=5×层）。

const ATK_PER_STACK := 1
const HP_PER_STACK := 5


static func stacks_on_unit(unit: UnitInstance) -> int:
	if unit == null:
		return 0
	return unit.combat_statuses.get_stacks(CombatStatusStack.ID_REVIVE)


## 按共识生成复制体实例（全新 instance_id；无队伍条目、无技能、无战斗状态）。
static func build_replica_from(dead: UnitInstance, stacks: int) -> UnitInstance:
	if dead == null or dead.unit_data == null or stacks <= 0:
		return null
	var cell := dead.grid_pos
	var replica := UnitInstance.from_unit_data(dead.unit_data, cell, dead.team)
	if replica == null or replica.stats == null:
		return null
	replica.level = dead.level
	replica.is_combat_summon = true
	replica.combat_abilities_suppressed = true
	replica.deck_entry_id = -1
	replica.stats.attack = maxi(1, stacks * ATK_PER_STACK)
	replica.stats.max_hp = maxi(1, stacks * HP_PER_STACK)
	replica.current_hp = replica.stats.max_hp
	replica.stat_modifiers = StatModifierStack.new()
	replica.combat_statuses = CombatStatusStack.new()
	if replica.stats.deploy_time > 0.0:
		replica.stats.deploy_time = 0.0
	return replica