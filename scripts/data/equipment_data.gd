class_name EquipmentData
extends Resource
## 地图商店装备：护甲（armor_block>0）、武器（weapon_*）或转职纹章（granted_occupation 非空）。

const TOKEN_SKELETON := "res://resources/units/tokens/token_skeleton_swarm.tres"

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(0, 99, 1) var cost: int = 1
## 受伤结算时抵消的伤害点数。纹章与武器为 0。
@export_range(0, 99, 1) var armor_block: int = 0
## 转职职名；空 = 护甲/武器。须与 SynergyOccupations 词表一致。
@export var granted_occupation: String = ""
## 普攻额外伤害（护甲前）；仅武器。
@export_range(0, 99, 1) var weapon_attack_bonus: int = 0
## 普攻造成伤害后自疗；仅武器。
@export_range(0, 99, 1) var weapon_lifesteal: int = 0
## 开战起叠乘缩短攻击间隔（百分比 3→×0.97）；仅武器。
@export_range(0, 95, 1) var weapon_haste_percent: int = 0
@export_range(0, 15, 1) var weapon_poison_stacks: int = 0
@export_range(0, 15, 1) var weapon_burn_stacks: int = 0
@export_range(0, 99, 1) var weapon_spawn_attack: int = 0
@export_range(0, 99, 1) var weapon_spawn_max_hp: int = 0


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return id if not id.is_empty() else "装备"


func get_icon() -> Texture2D:
	return icon


func get_armor_block() -> int:
	if is_weapon():
		return 0
	return maxi(0, armor_block)


func is_occupation_emblem() -> bool:
	return not get_granted_occupation().is_empty()


func is_weapon() -> bool:
	if is_occupation_emblem():
		return false
	if armor_block > 0:
		return false
	return _has_weapon_stats()


func is_armor_piece() -> bool:
	return not is_occupation_emblem() and armor_block > 0


func get_granted_occupation() -> String:
	return granted_occupation.strip_edges()


func _has_weapon_stats() -> bool:
	return (
		weapon_attack_bonus > 0
		or weapon_lifesteal > 0
		or weapon_haste_percent > 0
		or weapon_poison_stacks > 0
		or weapon_burn_stacks > 0
		or (weapon_spawn_attack > 0 and weapon_spawn_max_hp > 0)
	)


## 武器在战斗中经 EffectResolver 兑现的效果（普攻 / 开战）；副本供挂载。
func build_weapon_effect_specs() -> Array[EffectSpec]:
	var specs: Array[EffectSpec] = []
	if not is_weapon():
		return specs
	if weapon_lifesteal > 0:
		specs.append(_make_on_attack_heal_self(weapon_lifesteal))
	if weapon_poison_stacks > 0:
		specs.append(
			_make_on_attack_apply_status(CombatStatusStack.ID_POISON, weapon_poison_stacks)
		)
	if weapon_burn_stacks > 0:
		specs.append(_make_on_attack_apply_status(CombatStatusStack.ID_BURN, weapon_burn_stacks))
	if weapon_spawn_attack > 0 and weapon_spawn_max_hp > 0:
		specs.append(
			_make_on_attack_spawn_skeleton(weapon_spawn_attack, weapon_spawn_max_hp)
		)
	return specs


func get_weapon_description() -> String:
	if not is_weapon():
		return ""
	var parts: PackedStringArray = []
	if weapon_attack_bonus > 0:
		parts.append("普攻额外造成 %d 点伤害" % weapon_attack_bonus)
	if weapon_lifesteal > 0:
		parts.append("普攻后恢复自身 %d 点生命" % weapon_lifesteal)
	if weapon_haste_percent > 0:
		parts.append("攻击间隔缩短 %d%%" % weapon_haste_percent)
	if weapon_poison_stacks > 0:
		parts.append("普攻对目标施加中毒 %d 层" % weapon_poison_stacks)
	if weapon_burn_stacks > 0:
		parts.append("普攻对目标施加燃烧 %d 层" % weapon_burn_stacks)
	if weapon_spawn_attack > 0 and weapon_spawn_max_hp > 0:
		parts.append(
			"普攻后召唤骷髅（%d/%d）" % [weapon_spawn_attack, weapon_spawn_max_hp]
		)
	return "；".join(parts)


static func _make_on_attack_apply_status(status_id: StringName, stacks: int) -> EffectSpec:
	var act := EffectAction.new()
	act.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
	act.stat_name = status_id
	act.value = stacks
	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_DEAL_DAMAGE
	spec.target_selector = EffectSpec.TargetSelector.EVENT_TARGET
	spec.condition = EffectSpec.Condition.DEAL_FROM_ATTACK
	spec.actions = [act]
	return spec


static func _make_on_attack_heal_self(amount: int) -> EffectSpec:
	var act := EffectAction.new()
	act.action_type = EffectAction.Type.HEAL
	act.value = amount
	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_DEAL_DAMAGE
	spec.target_selector = EffectSpec.TargetSelector.SELF
	spec.condition = EffectSpec.Condition.DEAL_FROM_ATTACK
	spec.actions = [act]
	return spec


static func _make_on_attack_spawn_skeleton(atk: int, max_hp: int) -> EffectSpec:
	var token: UnitData = null
	if ResourceLoader.exists(TOKEN_SKELETON):
		token = load(TOKEN_SKELETON) as UnitData
	var act := EffectAction.new()
	act.action_type = EffectAction.Type.SPAWN_UNIT
	act.spawn_unit = token
	act.spawn_count = 1
	act.spawn_attack_override = atk
	act.spawn_hp_override = max_hp
	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_DEAL_DAMAGE
	spec.target_selector = EffectSpec.TargetSelector.EVENT_TARGET
	spec.condition = EffectSpec.Condition.DEAL_FROM_ATTACK
	spec.actions = [act]
	return spec