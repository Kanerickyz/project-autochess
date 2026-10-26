class_name SkillExpectation
extends RefCounted
## 从 EffectSpec 结构估技能预期强度（深评分）。输出 raw，再映射为 α（锚定「标准技能≈1.0」）。
## 不做点数定稿；系数可被 SpawnBudgetConfig.skill_alpha_by_unit_id 覆盖。

## raw 等于该值时 α ≈ alpha_has_skill（默认 1.0）。
const STANDARD_RAW := 1.0
const RAW_SENSITIVITY := 0.22
const ALPHA_MIN := 0.85
const ALPHA_MAX := 1.40

## 触发可靠度 / 强度权重（相对 STANDARD）。
const TRIGGER_WEIGHTS := {
	CombatEvents.ON_COMBAT_START: 0.85,
	CombatEvents.ON_COMBAT_END: 0.7,
	CombatEvents.ON_ROUND_START: 1.15,
	CombatEvents.ON_ACTOR_TURN_END: 1.1,
	CombatEvents.ON_SUMMONED: 0.7,
	CombatEvents.ON_FRIEND_SUMMONED: 0.95,
	CombatEvents.ON_FRIEND_DEATH: 0.9,
	CombatEvents.ON_ENEMY_DEATH: 0.95,
	CombatEvents.ON_FRIEND_DAMAGE_TAKEN: 1.05,
	CombatEvents.ON_DAMAGE_TAKEN: 1.1,
	CombatEvents.ON_ATTACK_HIT: 1.0,
	CombatEvents.ON_DEAL_DAMAGE: 1.05,
	CombatEvents.ON_KILL: 1.25,
	CombatEvents.ON_FRIEND_KILL: 1.0,
	CombatEvents.ON_DEATH: 0.8,
	CombatEvents.ON_MOVE: 0.65,
	CombatEvents.ON_LINE_ATTACK: 0.9,
	CombatEvents.ON_ACTOR_TURN_REFRESH: 0.5,
	CombatEvents.ON_LEVEL_UP: 0.55,
}

## 效果族权重。
const ACTION_WEIGHTS := {
	EffectAction.Type.SPAWN_UNIT: 1.35,
	EffectAction.Type.SPLIT_SELF: 1.3,
	EffectAction.Type.GRANT_ACTOR_TURN_REFRESH: 1.4,
	EffectAction.Type.ADD_BANKED_TURN_REFRESH_CHARGE: 1.2,
	EffectAction.Type.CONSUME_BANKED_TURN_REFRESH_FOR_BONUS_TURN: 1.15,
	EffectAction.Type.FUSE_EXPLODE: 1.2,
	EffectAction.Type.DEAL_DAMAGE: 1.05,
	EffectAction.Type.FRIENDS_HURT_AOE: 1.15,
	EffectAction.Type.HEAL: 0.95,
	EffectAction.Type.SET_HP_FROM_ALLY_PERCENT: 0.9,
	EffectAction.Type.MODIFY_STAT: 0.85,
	EffectAction.Type.PERMANENT_DECK_STAT: 0.8,
	EffectAction.Type.TELEPORT_ADJACENT_TO_TARGET: 0.9,
	EffectAction.Type.SWAP_POSITIONS: 0.75,
	EffectAction.Type.APPLY_CELL_EFFECT: 0.8,
	EffectAction.Type.GRANT_GOLD: 0.4,
	EffectAction.Type.BUFF_STATS_FROM_GOLD_HALF: 1.15,
	EffectAction.Type.STOCK_FREE_BUFF: 0.5,
	EffectAction.Type.SHOP_CHARACTER_BONUS_HP: 0.45,
}


static func score_ability(ability: AbilityData) -> float:
	if ability == null:
		return 0.0
	var total := 0.0
	for spec in ability.effect_specs:
		total += _score_spec(spec)
	return total


static func score_abilities(abilities: Array) -> float:
	var total := 0.0
	for item in abilities:
		if item is AbilityData:
			total += score_ability(item as AbilityData)
	return total


## 单位内建主技能 + 被动；可选 override 替换主技能（熔印 runtime）。
static func score_unit_data(unit: UnitData, main_override: AbilityData = null) -> float:
	if unit == null:
		return 0.0
	var main_ab := main_override if main_override != null else unit.ability
	var raw := score_ability(main_ab)
	for passive in unit.passives:
		raw += score_ability(passive)
	return raw


static func raw_to_alpha(
	raw: float,
	alpha_no_skill: float = UnitPowerScore.DEFAULT_ALPHA_NO_SKILL,
	alpha_has_skill: float = UnitPowerScore.DEFAULT_ALPHA_HAS_SKILL,
) -> float:
	if raw <= 0.001:
		return alpha_no_skill
	## 标准 raw → alpha_has_skill；高于/低于标准做相对分化，夹在 [ALPHA_MIN, ALPHA_MAX]。
	var centered := alpha_has_skill + (raw - STANDARD_RAW) * RAW_SENSITIVITY
	return clampf(centered, ALPHA_MIN, ALPHA_MAX)


static func alpha_for_ability(
	ability: AbilityData,
	alpha_no_skill: float = UnitPowerScore.DEFAULT_ALPHA_NO_SKILL,
	alpha_has_skill: float = UnitPowerScore.DEFAULT_ALPHA_HAS_SKILL,
) -> float:
	return raw_to_alpha(score_ability(ability), alpha_no_skill, alpha_has_skill)


static func _score_spec(spec: EffectSpec) -> float:
	if spec == null:
		return 0.0
	var tw := float(TRIGGER_WEIGHTS.get(spec.trigger, 0.7))
	var action_sum := 0.0
	for action in spec.actions:
		action_sum += _score_action(action)
	if action_sum <= 0.0:
		return 0.0
	var scope := _target_scope_mult(spec)
	var cond := _condition_mult(spec)
	return tw * action_sum * scope * cond


static func _score_action(action: EffectAction) -> float:
	if action == null:
		return 0.0
	var base := float(ACTION_WEIGHTS.get(action.action_type, 0.7))
	match action.action_type:
		EffectAction.Type.SPAWN_UNIT:
			base *= 1.0 + 0.15 * float(maxi(0, action.spawn_count - 1))
		EffectAction.Type.MODIFY_STAT:
			if action.stat_name == &"attack" or action.stat_name == &"max_hp":
				base *= 1.05
		EffectAction.Type.HEAL:
			if action.value >= 8:
				base *= 1.08
		EffectAction.Type.DEAL_DAMAGE:
			if action.damage_mode == EffectAction.DamageMode.OWNER_ATTACK_PERCENT:
				base *= 1.05
		_:
			pass
	return base


static func _target_scope_mult(spec: EffectSpec) -> float:
	match spec.target_selector:
		EffectSpec.TargetSelector.ALL_ALLIES, EffectSpec.TargetSelector.ALL_UNITS:
			return 1.2
		EffectSpec.TargetSelector.NEARBY_ALLIES, EffectSpec.TargetSelector.ENEMIES_ADJACENT_TO_EVENT_TARGET:
			return 1.1
		EffectSpec.TargetSelector.RANDOM_CELLS, EffectSpec.TargetSelector.CELLS_AROUND_EVENT:
			return 1.05
		_:
			return 1.0


static func _condition_mult(spec: EffectSpec) -> float:
	if spec.condition == EffectSpec.Condition.NONE:
		return 1.0
	## 有条件略降可靠度。
	return 0.92
