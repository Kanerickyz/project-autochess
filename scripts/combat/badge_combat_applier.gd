class_name BadgeCombatApplier
extends RefCounted
## 开战兑现已持有徽章（职业×N / 同盟放大）；命中加伤写入单位本场字段。
## 数值结算经 EffectResolver.apply_unscaled_action（与技能同源管线，不走升星倍率）。

## 近战 = 非远程投射（projectile_speed <= 0）。
static func is_melee_unit(unit: UnitInstance) -> bool:
	if unit == null or unit.stats == null:
		return true
	return unit.stats.projectile_speed <= 0.0


static func is_ranged_projectile_unit(unit: UnitInstance) -> bool:
	if unit == null or unit.stats == null:
		return false
	return unit.stats.projectile_speed > 0.0


## allies / enemies: Array[UnitInstance]（已入座开战实例）。
## owned_ids: 玩家本局持有徽章 id。
## 返回 Dictionary：applied_ids、amp、occupation_counts、ranged_hit_bonus_total。
static func apply_combat_start(
	owned_ids: PackedStringArray,
	allies: Array,
	enemies: Array,
	resolver: EffectResolver = null,
) -> Dictionary:
	var result := {
		"applied_ids": PackedStringArray(),
		"amp": 0,
		"occupation_counts": {},
		"ranged_hit_bonus_total": 0,
		## 本场被兑现效果触及的单位（开战 UI 放大缩小提示用）。
		"buffed_allies": [],
		"buffed_enemies": [],
	}
	var ally_units: Array[UnitInstance] = []
	for item in allies:
		var u := item as UnitInstance
		if u != null and u.is_alive() and u.team == UnitInstance.Team.PLAYER:
			ally_units.append(u)
	var enemy_units: Array[UnitInstance] = []
	for item in enemies:
		var u2 := item as UnitInstance
		if u2 != null and u2.is_alive() and u2.team == UnitInstance.Team.ENEMY:
			enemy_units.append(u2)

	## 含转职纹章附加职（经 DeckEntry.get_occupation_tags）；同 id 去重。
	var counts := SynergyOccupations.count_from_unit_instances(ally_units)
	result["occupation_counts"] = counts

	var badges := BadgeCatalog.resolve_owned(owned_ids)
	if badges.is_empty():
		return result

	var active_occupation: Array[BadgeData] = []
	var alliance: BadgeData = null
	for badge in badges:
		if badge == null:
			continue
		if badge.is_alliance_amplifier():
			alliance = badge
			continue
		if badge.matches_condition(counts):
			active_occupation.append(badge)

	var amp := 0
	if alliance != null and not active_occupation.is_empty():
		amp = 1
	result["amp"] = amp

	var applied: PackedStringArray = PackedStringArray()
	var ranged_bonus_total := 0
	var touched_allies: Dictionary = {}
	var touched_enemies: Dictionary = {}
	for badge in active_occupation:
		var points := badge.value + amp
		var points_sec := badge.value_secondary + amp
		_apply_badge_effect(
			badge,
			points,
			points_sec,
			ally_units,
			enemy_units,
			resolver,
			touched_allies,
			touched_enemies,
		)
		applied.append(badge.id)
		if badge.effect_kind == BadgeData.EffectKind.RANGED_HIT_BONUS:
			ranged_bonus_total += points
	if alliance != null and amp > 0:
		applied.append(alliance.id)
	result["applied_ids"] = applied
	result["ranged_hit_bonus_total"] = ranged_bonus_total
	var buffed_a: Array = []
	for k in touched_allies.keys():
		buffed_a.append(touched_allies[k])
	var buffed_e: Array = []
	for k2 in touched_enemies.keys():
		buffed_e.append(touched_enemies[k2])
	result["buffed_allies"] = buffed_a
	result["buffed_enemies"] = buffed_e
	return result


static func _apply_badge_effect(
	badge: BadgeData,
	points: int,
	points_secondary: int,
	allies: Array[UnitInstance],
	enemies: Array[UnitInstance],
	resolver: EffectResolver,
	touched_allies: Dictionary = {},
	touched_enemies: Dictionary = {},
) -> void:
	if badge == null or points <= 0:
		return
	match badge.effect_kind:
		BadgeData.EffectKind.ALLY_MAX_HP:
			var act_hp := EffectAction.new()
			act_hp.action_type = EffectAction.Type.MODIFY_STAT
			act_hp.stat_name = &"max_hp"
			act_hp.value = points
			for ally in allies:
				_exec(resolver, act_hp, ally)
				_mark_touched(touched_allies, ally)
		BadgeData.EffectKind.ALLY_MELEE_ATTACK:
			var act_atk := EffectAction.new()
			act_atk.action_type = EffectAction.Type.MODIFY_STAT
			act_atk.stat_name = &"attack"
			act_atk.value = points
			for ally2 in allies:
				if is_melee_unit(ally2):
					_exec(resolver, act_atk, ally2)
					_mark_touched(touched_allies, ally2)
		BadgeData.EffectKind.RANGED_HIT_BONUS:
			for ally3 in allies:
				if is_ranged_projectile_unit(ally3):
					ally3.combat_ranged_hit_bonus += points
					_mark_touched(touched_allies, ally3)
		BadgeData.EffectKind.ALLY_TEMP_ARMOR:
			var act_armor := EffectAction.new()
			act_armor.action_type = EffectAction.Type.GRANT_COMBAT_ARMOR
			act_armor.value = points
			for ally4 in allies:
				_exec(resolver, act_armor, ally4)
				_mark_touched(touched_allies, ally4)
		BadgeData.EffectKind.ALLY_BERSERK:
			var act_rage := EffectAction.new()
			act_rage.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
			act_rage.stat_name = CombatStatusStack.ID_BERSERK
			act_rage.value = points
			for ally5 in allies:
				_exec(resolver, act_rage, ally5)
				_mark_touched(touched_allies, ally5)
		BadgeData.EffectKind.ENEMY_WEAK_AND_POISON:
			var weak_pts := maxi(0, points)
			var poison_pts := maxi(0, points_secondary if points_secondary > 0 else points)
			var act_weak := EffectAction.new()
			act_weak.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
			act_weak.stat_name = CombatStatusStack.ID_WEAK
			act_weak.value = weak_pts
			var act_poison := EffectAction.new()
			act_poison.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
			act_poison.stat_name = CombatStatusStack.ID_POISON
			act_poison.value = poison_pts
			for enemy in enemies:
				if weak_pts > 0:
					_exec(resolver, act_weak, enemy)
					_mark_touched(touched_enemies, enemy)
				if poison_pts > 0:
					_exec(resolver, act_poison, enemy)
					_mark_touched(touched_enemies, enemy)
		BadgeData.EffectKind.ALLIANCE_AMPLIFY:
			pass
		_:
			pass


static func _mark_touched(bucket: Dictionary, unit: UnitInstance) -> void:
	if unit == null:
		return
	bucket[unit.instance_id] = unit


static func _exec(resolver: EffectResolver, action: EffectAction, target: UnitInstance) -> void:
	if action == null or target == null:
		return
	if resolver != null:
		resolver.apply_unscaled_action(action, target)
		return
	## 无 resolver 时回退同口径直写（测试可省略 resolver）。
	match action.action_type:
		EffectAction.Type.MODIFY_STAT:
			target.stat_modifiers.add_flat(action.stat_name, action.value)
			if action.stat_name == &"max_hp" and action.value > 0:
				target.current_hp = mini(
					target.get_effective_max_hp(),
					target.current_hp + action.value,
				)
			else:
				target.current_hp = clampi(target.current_hp, 0, target.get_effective_max_hp())
		EffectAction.Type.GRANT_COMBAT_ARMOR:
			target.grant_combat_temp_armor(action.value)
		EffectAction.Type.APPLY_COMBAT_STATUS:
			target.combat_statuses.add_stacks(action.stat_name, action.value)
		_:
			pass
