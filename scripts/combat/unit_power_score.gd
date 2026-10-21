class_name UnitPowerScore
extends RefCounted
## 单位强度分 U：友敌同族尺子。敌方用 UnitData；友方用 DeckEntry 星级后身体 + 技能预期 α。
## 不含站位、代理角色、增益卡（本版无增益卡；不读 attached_buffs）。
## 技能 α：优先 skill_alpha_by_unit_id（敌 id 可回退去 enemy_ 前缀）；否则 SkillExpectation 深评分。

const TIER_GROWTH := 0.08
const ATK_WEIGHT := 1.5
const DPS_WEIGHT := 0.5
const SPLASH_BODY_MULT := 1.05
const DEFAULT_ALPHA_NO_SKILL := 0.85
const DEFAULT_ALPHA_HAS_SKILL := 1.0
const ENEMY_ID_PREFIX := "enemy_"


## U = (HP + 1.5*ATK + 0.5*DPS) * α_skill * (1 + 0.08*(tier-1))
## splash_radius > 0 时身体项 ×1.05。DPS = ATK / attack_interval。
static func compute_u(
	unit: UnitData,
	skill_alpha_by_id: Dictionary = {},
	alpha_no_skill: float = DEFAULT_ALPHA_NO_SKILL,
	alpha_has_skill: float = DEFAULT_ALPHA_HAS_SKILL,
) -> float:
	if unit == null or unit.stats == null:
		return 0.0
	return _compute_u_body(
		unit,
		float(unit.stats.max_hp),
		float(unit.stats.attack),
		unit.stats.attack_interval,
		unit.stats.splash_radius,
		null,
		skill_alpha_by_id,
		alpha_no_skill,
		alpha_has_skill,
	)


## 整局队伍成员：星级后身体（base + bonus）+ 主技能（含熔印 runtime）预期系数。
static func compute_u_from_entry(
	entry: DeckEntry,
	skill_alpha_by_id: Dictionary = {},
	alpha_no_skill: float = DEFAULT_ALPHA_NO_SKILL,
	alpha_has_skill: float = DEFAULT_ALPHA_HAS_SKILL,
) -> float:
	if entry == null or entry.unit == null or entry.unit.stats == null:
		return 0.0
	var unit := entry.unit
	var stats := unit.stats
	var hp := float(DeckUpgradeService.get_display_max_hp(entry))
	var atk := float(DeckUpgradeService.get_display_attack(entry))
	return _compute_u_body(
		unit,
		hp,
		atk,
		stats.attack_interval,
		stats.splash_radius,
		entry.get_main_ability(),
		skill_alpha_by_id,
		alpha_no_skill,
		alpha_has_skill,
	)


static func _compute_u_body(
	unit: UnitData,
	hp: float,
	atk: float,
	attack_interval: float,
	splash_radius: float,
	main_override: AbilityData,
	skill_alpha_by_id: Dictionary,
	alpha_no_skill: float,
	alpha_has_skill: float,
) -> float:
	var interval := maxf(0.05, attack_interval)
	var dps := atk / interval
	var body := hp + ATK_WEIGHT * atk + DPS_WEIGHT * dps
	if splash_radius > 0.0:
		body *= SPLASH_BODY_MULT
	var alpha := resolve_skill_alpha(
		unit, skill_alpha_by_id, alpha_no_skill, alpha_has_skill, main_override
	)
	var tier_mult := 1.0 + TIER_GROWTH * float(maxi(0, unit.tier - 1))
	return body * alpha * tier_mult


static func has_skill(unit: UnitData, main_override: AbilityData = null) -> bool:
	if main_override != null:
		return true
	if unit == null:
		return false
	if unit.ability != null:
		return true
	return not unit.passives.is_empty()


static func resolve_skill_alpha(
	unit: UnitData,
	skill_alpha_by_id: Dictionary = {},
	alpha_no_skill: float = DEFAULT_ALPHA_NO_SKILL,
	alpha_has_skill: float = DEFAULT_ALPHA_HAS_SKILL,
	main_override: AbilityData = null,
) -> float:
	if unit == null and main_override == null:
		return alpha_no_skill
	if unit != null:
		var override_alpha := _lookup_alpha_override(unit.id, skill_alpha_by_id)
		if not is_nan(override_alpha):
			return override_alpha
	var raw := SkillExpectation.score_unit_data(unit, main_override)
	if raw <= 0.001:
		## 有技能资源但无 EffectSpec（占位）时仍用有技能默认，避免 stub 被当成白板。
		return alpha_has_skill if has_skill(unit, main_override) else alpha_no_skill
	return SkillExpectation.raw_to_alpha(raw, alpha_no_skill, alpha_has_skill)


## 显式表优先；敌方 id `enemy_foo` 可回退查 `foo`，保证友敌同尺。
static func _lookup_alpha_override(unit_id: String, skill_alpha_by_id: Dictionary) -> float:
	if skill_alpha_by_id.is_empty() or unit_id.is_empty():
		return NAN
	if skill_alpha_by_id.has(unit_id):
		return float(skill_alpha_by_id[unit_id])
	if unit_id.begins_with(ENEMY_ID_PREFIX):
		var base_id := unit_id.substr(ENEMY_ID_PREFIX.length())
		if skill_alpha_by_id.has(base_id):
			return float(skill_alpha_by_id[base_id])
	return NAN


static func team_power(
	units: Array,
	skill_alpha_by_id: Dictionary = {},
	alpha_no_skill: float = DEFAULT_ALPHA_NO_SKILL,
	alpha_has_skill: float = DEFAULT_ALPHA_HAS_SKILL,
) -> float:
	var total := 0.0
	for item in units:
		if item is UnitData:
			total += compute_u(item as UnitData, skill_alpha_by_id, alpha_no_skill, alpha_has_skill)
		elif item is DeckEntry:
			total += compute_u_from_entry(
				item as DeckEntry, skill_alpha_by_id, alpha_no_skill, alpha_has_skill
			)
	return total


## 整局队伍快照合计 S（DeckEntry 数组）。
static func team_power_from_entries(
	entries: Array,
	skill_alpha_by_id: Dictionary = {},
	alpha_no_skill: float = DEFAULT_ALPHA_NO_SKILL,
	alpha_has_skill: float = DEFAULT_ALPHA_HAS_SKILL,
) -> float:
	var total := 0.0
	for item in entries:
		if item is DeckEntry:
			total += compute_u_from_entry(
				item as DeckEntry, skill_alpha_by_id, alpha_no_skill, alpha_has_skill
			)
	return total


static func is_melee(unit: UnitData) -> bool:
	if unit == null or unit.stats == null:
		return true
	return unit.stats.projectile_speed <= 0.0


static func is_ranged(unit: UnitData) -> bool:
	return not is_melee(unit)


## 可招 id ↔ 敌镜像 id（内容契约 A）。
static func ally_id_from_enemy_id(enemy_id: String) -> String:
	if enemy_id.begins_with(ENEMY_ID_PREFIX):
		return enemy_id.substr(ENEMY_ID_PREFIX.length())
	return enemy_id


static func enemy_id_from_ally_id(ally_id: String) -> String:
	if ally_id.is_empty() or ally_id.begins_with(ENEMY_ID_PREFIX):
		return ally_id
	return ENEMY_ID_PREFIX + ally_id
