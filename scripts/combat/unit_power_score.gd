class_name UnitPowerScore
extends RefCounted
## 单位强度分 U：层预算抽阵用。不读玩家真实队伍。

const TIER_GROWTH := 0.08
const ATK_WEIGHT := 1.5
const DPS_WEIGHT := 0.5
const SPLASH_BODY_MULT := 1.05
const DEFAULT_ALPHA_NO_SKILL := 0.85
const DEFAULT_ALPHA_HAS_SKILL := 1.0


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
	var stats := unit.stats
	var interval := maxf(0.05, stats.attack_interval)
	var dps := float(stats.attack) / interval
	var body := float(stats.max_hp) + ATK_WEIGHT * float(stats.attack) + DPS_WEIGHT * dps
	if stats.splash_radius > 0.0:
		body *= SPLASH_BODY_MULT
	var alpha := resolve_skill_alpha(unit, skill_alpha_by_id, alpha_no_skill, alpha_has_skill)
	var tier_mult := 1.0 + TIER_GROWTH * float(maxi(0, unit.tier - 1))
	return body * alpha * tier_mult


static func has_skill(unit: UnitData) -> bool:
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
) -> float:
	if unit == null:
		return alpha_no_skill
	if skill_alpha_by_id.has(unit.id):
		return float(skill_alpha_by_id[unit.id])
	if has_skill(unit):
		return alpha_has_skill
	return alpha_no_skill


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
	return total


static func is_melee(unit: UnitData) -> bool:
	if unit == null or unit.stats == null:
		return true
	return unit.stats.projectile_speed <= 0.0


static func is_ranged(unit: UnitData) -> bool:
	return not is_melee(unit)
