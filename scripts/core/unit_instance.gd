class_name UnitInstance
extends RefCounted

enum Team { PLAYER, ENEMY }

static var _next_instance_id: int = 0

var instance_id: int
var id: String
var grid_pos: Vector2i
var team: Team
var unit_data: UnitData
var deck_entry_id: int = -1
var level: int = 1
var cannot_move: bool = false
var death_grant_gold: int = 0
var attached_abilities: Array[AbilityData] = []
var stats: UnitStats
var current_hp: int
var stat_modifiers: StatModifierStack = StatModifierStack.new()
## 战中召唤随从（技能生成 / Boss 衍生小兵等）；溃散与上限计数用。
var is_combat_summon: bool = false
## 本场已成功生成的随从只数（统计用；不设每角色上限）。
var combat_summons_spawned: int = 0
## 队伍条目 runtime 主技能（熔印者等）；优先于 unit_data.ability。
var main_ability_override: AbilityData = null


func is_boss_leader() -> bool:
	return unit_data != null and unit_data.is_boss_leader


func get_footprint_size() -> Vector2i:
	if unit_data == null:
		return Vector2i(1, 1)
	return Vector2i(maxi(1, unit_data.footprint_w), maxi(1, unit_data.footprint_h))


func _init(
	p_id: String = "",
	p_pos: Vector2i = Vector2i.ZERO,
	p_team: Team = Team.PLAYER,
) -> void:
	instance_id = _next_instance_id
	_next_instance_id += 1
	id = p_id
	grid_pos = p_pos
	team = p_team


## 将牌库条目的等级、永久加成与规则同步到已在场上的实例（保留当前生命，升级加血）。
static func sync_from_deck_entry(unit: UnitInstance, entry: DeckEntry) -> void:
	if unit == null or entry == null or entry.unit == null:
		return
	var old_max := unit.get_effective_max_hp()
	unit.level = entry.level
	unit.unit_data = entry.unit
	unit.stats = entry.unit.stats.duplicate_stats() if entry.unit.stats else UnitStats.new()
	unit.stats.attack += entry.bonus_attack
	unit.stats.max_hp += entry.bonus_max_hp
	unit.stats.crit_rate_percent += entry.bonus_crit_rate_percent
	var new_max := unit.get_effective_max_hp()
	if new_max > old_max:
		unit.current_hp += new_max - old_max
	unit.current_hp = clampi(unit.current_hp, 0, new_max)
	unit.cannot_move = entry.rule_flags.get("cannot_move", false)
	unit.death_grant_gold = 0
	unit.attached_abilities = entry.attached_abilities.duplicate()
	if entry.runtime_main_ability != null:
		unit.main_ability_override = entry.runtime_main_ability
	else:
		unit.main_ability_override = null
	for buff in entry.attached_buffs:
		if buff == null:
			continue
		if buff.effect_type == BuffCardData.EffectType.DEATH_GOLD:
			unit.death_grant_gold += buff.value


static func from_deck_entry(entry: DeckEntry, cell: Vector2i, team: Team) -> UnitInstance:
	if entry == null or entry.unit == null:
		return null
	var unit := from_unit_data(entry.unit, cell, team)
	unit.deck_entry_id = entry.entry_id
	if entry.runtime_main_ability != null:
		unit.main_ability_override = entry.runtime_main_ability
	sync_from_deck_entry(unit, entry)
	unit.current_hp = unit.get_effective_max_hp()
	return unit


## 远程（projectile_speed>0）攻距硬顶：attack_range / attack_reach 最多 2 格。
const RANGED_ATTACK_CELLS_MAX := 2
## 三合一技能数值倍率：每升一星 ×6 → 1★×1、2★×6、3★×36。
const ABILITY_MERGE_VALUE_MULT := 6


## 星级对应的技能效果数值倍率（与 EffectResolver / 商店 / UI 共用）。
static func ability_value_multiplier(level: int, step_mult: int = 0) -> int:
	var step := step_mult if step_mult > 0 else ABILITY_MERGE_VALUE_MULT
	var lv := maxi(1, level)
	var mult := 1
	for _i in range(lv - 1):
		mult *= step
	return mult


## 按技能配置的 merge_value_mult（0=全局×6）计算倍率。
static func ability_value_multiplier_for(ability: AbilityData, level: int) -> int:
	var step := 0
	if ability != null:
		step = ability.merge_value_mult
	return ability_value_multiplier(level, step)


static func from_unit_data(data: UnitData, cell: Vector2i, team: Team) -> UnitInstance:
	var unit := UnitInstance.new(data.id, cell, team)
	unit.unit_data = data
	unit.stats = data.stats.duplicate_stats() if data.stats else UnitStats.new()
	_clamp_ranged_attack_distance(unit.stats)
	unit.current_hp = unit.stats.max_hp
	return unit


static func _clamp_ranged_attack_distance(stats: UnitStats) -> void:
	if stats == null or stats.projectile_speed <= 0.0:
		return
	stats.attack_range = mini(stats.attack_range, RANGED_ATTACK_CELLS_MAX)
	stats.attack_reach = minf(stats.attack_reach, float(RANGED_ATTACK_CELLS_MAX))



func is_alive() -> bool:
	return current_hp > 0


func get_attack_range() -> int:
	if stats == null:
		return 1
	return maxi(1, stats.attack_range)


func get_movement_pattern() -> UnitStats.MovementPattern:
	if stats == null:
		return UnitStats.MovementPattern.ORTHOGONAL
	return stats.movement_pattern


func get_steps_per_turn() -> int:
	if stats == null:
		return 1
	var bonus := 0
	if stat_modifiers != null:
		bonus = stat_modifiers.get_flat_bonus(&"steps_per_turn")
	return maxi(0, stats.steps_per_turn + bonus)


func uses_sliding_move_presentation() -> bool:
	var pattern := get_movement_pattern()
	return (
		pattern == UnitStats.MovementPattern.ROOK
		or pattern == UnitStats.MovementPattern.QUEEN
	)


func uses_teleport_move_presentation() -> bool:
	return get_movement_pattern() == UnitStats.MovementPattern.TELEPORT


func get_main_ability() -> AbilityData:
	if main_ability_override != null:
		return main_ability_override
	if unit_data != null:
		return unit_data.ability
	return null


func skips_attack_after_move() -> bool:
	var ability := get_main_ability()
	if ability == null:
		return false
	return ability.skip_attack_after_move


func can_perform_normal_attack() -> bool:
	var ability := get_main_ability()
	if ability == null:
		return true
	return ability.can_normal_attack


func uses_line_attack() -> bool:
	var ability := get_main_ability()
	if ability == null:
		return false
	return ability.uses_line_attack


func get_line_attack_damage() -> int:
	var ability := get_main_ability()
	if ability == null:
		return 0
	if ability.line_attack_uses_attack:
		return get_effective_attack()
	return maxi(0, ability.line_attack_damage)


func can_move_ahead_damage() -> bool:
	var ability := get_main_ability()
	if ability == null:
		return false
	for spec in ability.effect_specs:
		if spec == null:
			continue
		if (
			spec.trigger == CombatEvents.ON_MOVE
			and spec.target_selector == EffectSpec.TargetSelector.UNIT_AHEAD_OF_MOVE
		):
			return true
	return false


func get_effective_attack() -> int:
	if stats == null:
		return 1
	return maxi(1, stats.attack + stat_modifiers.get_flat_bonus(&"attack"))


func get_effective_max_hp() -> int:
	if stats == null:
		return 1
	return maxi(1, stats.max_hp + stat_modifiers.get_flat_bonus(&"max_hp"))


func get_effective_crit_rate() -> float:
	if stats == null:
		return 0.0
	var rate := stats.crit_rate_percent + stat_modifiers.get_flat_bonus(&"crit_rate_percent")
	return clampf(float(rate) / 100.0, 0.0, 1.0)


func get_all_effect_specs() -> Array[EffectSpec]:
	var specs: Array[EffectSpec] = []
	if unit_data == null:
		return specs
	var main_ab := get_main_ability()
	if main_ab != null:
		specs.append_array(main_ab.effect_specs)
	for passive in unit_data.passives:
		if passive != null:
			specs.append_array(passive.effect_specs)
	for attached in attached_abilities:
		if attached != null:
			specs.append_array(attached.effect_specs)
	return specs
