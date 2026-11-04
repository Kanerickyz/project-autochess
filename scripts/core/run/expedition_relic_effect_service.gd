class_name ExpeditionRelicEffectService
extends RefCounted

## 远征圣物经济聚合 + 战斗开战/触发挂载（走 EffectSpec → EffectResolver，禁止第二套 Buff）。

const ATTACHED_PREFIX := "expedition_relic_"


## --- 经济聚合 ---


static func sum_bonus_floor_gold(bag: ExpeditionRelicBag) -> int:
	var total := 0
	for r in _iter(bag):
		total += r.bonus_floor_gold
	return total


static func sum_map_shop_refresh_cost_delta(bag: ExpeditionRelicBag) -> int:
	var total := 0
	for r in _iter(bag):
		total += r.map_shop_refresh_cost_delta
	return total


static func resolve_min_refresh_cost(bag: ExpeditionRelicBag, fallback: int = 1) -> int:
	var floor_v := fallback
	var any := false
	for r in _iter(bag):
		if r.map_shop_refresh_cost_delta != 0 or r.min_refresh_cost > 0:
			any = true
			floor_v = maxi(floor_v, r.min_refresh_cost)
	return floor_v if any else fallback


static func sum_map_shop_price_delta(bag: ExpeditionRelicBag) -> int:
	var total := 0
	for r in _iter(bag):
		total += r.map_shop_price_delta
	return total


static func sum_sell_unit_bonus_gold(bag: ExpeditionRelicBag) -> int:
	var total := 0
	for r in _iter(bag):
		total += r.sell_unit_bonus_gold
	return total


static func resolve_refresh_cost(base_cost: int, bag: ExpeditionRelicBag) -> int:
	var delta := sum_map_shop_refresh_cost_delta(bag)
	var min_c := resolve_min_refresh_cost(bag, 1)
	return maxi(min_c, base_cost + delta)


static func resolve_shop_price(base_cost: int, bag: ExpeditionRelicBag) -> int:
	return maxi(0, base_cost + sum_map_shop_price_delta(bag))


## --- 战斗：开战前挂到友方 attached_abilities ---


## 在 begin_combat / OnCombatStart 之前调用；依赖 ThemeBondService 同口径读成形主题。
static func attach_combat_abilities(
	player_units: Array,
	bag: ExpeditionRelicBag,
	deck_state: DeckState = null,
	board_height: int = 8,
) -> void:
	_strip_previous_attachments(player_units)
	if bag == null or bag.get_count() <= 0:
		return
	var formed := ThemeBondService.list_formed_themes(player_units)
	var bench_count := 0
	if deck_state != null:
		bench_count = deck_state.get_bench_count()
	var front_ys := _front_two_row_ys(player_units, board_height)

	for relic in bag.get_relics():
		if relic == null:
			continue
		_attach_combat_start_for_relic(player_units, relic, formed, bench_count, front_ys)
		_attach_trigger_for_relic(player_units, relic)


static func _attach_combat_start_for_relic(
	player_units: Array,
	relic: ExpeditionRelicData,
	formed: Array[StringName],
	bench_count: int,
	front_ys: Dictionary,
) -> void:
	## 全体开战临时攻/血（含主题开关）。
	var all_atk := relic.combat_start_temp_attack
	var all_hp := relic.combat_start_temp_max_hp
	if relic.requires_any_theme_formed and formed.is_empty():
		all_atk = 0
		all_hp = 0
	## 八徽：每成形主题 +N 攻，硬顶。
	if relic.per_formed_theme_temp_attack != 0 and not formed.is_empty():
		var theme_bonus := formed.size() * relic.per_formed_theme_temp_attack
		if relic.relic_attack_bonus_cap > 0:
			theme_bonus = mini(theme_bonus, relic.relic_attack_bonus_cap)
		all_atk += theme_bonus
	## 空棺：备战供能（空备战则该字段不生效）。
	if relic.temp_attack_per_bench_unit != 0 and bench_count > 0:
		var bench_bonus := bench_count * relic.temp_attack_per_bench_unit
		if relic.relic_attack_bonus_cap > 0:
			bench_bonus = mini(bench_bonus, relic.relic_attack_bonus_cap)
		all_atk += bench_bonus

	if all_atk != 0:
		_attach_ability_to_carrier(
			player_units,
			"%s_start_atk" % relic.id,
			relic.display_name,
			[_mod_stat_spec(CombatEvents.ON_COMBAT_START, EffectSpec.TargetSelector.ALL_ALLIES, &"attack", all_atk)],
		)
	## 负生命上限：按单位 clamp，保证不低于 min_max_hp_after（默认 1）。
	if all_hp > 0:
		_attach_ability_to_carrier(
			player_units,
			"%s_start_hp" % relic.id,
			relic.display_name,
			[_mod_stat_spec(CombatEvents.ON_COMBAT_START, EffectSpec.TargetSelector.ALL_ALLIES, &"max_hp", all_hp)],
		)
	elif all_hp < 0:
		var floor_hp := maxi(1, relic.min_max_hp_after)
		for item_hp in player_units:
			var u_hp := item_hp as UnitInstance
			if u_hp == null or not u_hp.is_alive():
				continue
			var cur_max := u_hp.get_effective_max_hp()
			var target_max := maxi(floor_hp, cur_max + all_hp)
			var delta := target_max - cur_max
			if delta == 0:
				continue
			var hp_spec := _mod_stat_spec(
				CombatEvents.ON_COMBAT_START,
				EffectSpec.TargetSelector.SELF,
				&"max_hp",
				delta,
			)
			_attach_ability_to_unit(
				u_hp,
				"%s_start_hp_%d" % [relic.id, u_hp.instance_id],
				relic.display_name,
				[hp_spec],
			)

	## 前两排开战攻。
	if relic.front_two_rows_temp_attack != 0 and not front_ys.is_empty():
		for item in player_units:
			var unit := item as UnitInstance
			if unit == null or not unit.is_alive():
				continue
			if not front_ys.has(unit.grid_pos.y):
				continue
			var front_spec := _mod_stat_spec(
				CombatEvents.ON_COMBAT_START,
				EffectSpec.TargetSelector.SELF,
				&"attack",
				relic.front_two_rows_temp_attack,
			)
			_attach_ability_to_unit(
				unit,
				"%s_front_%d" % [relic.id, unit.instance_id],
				relic.display_name,
				[front_spec],
			)

	## 夹道刺篱：开战正交相邻友方，对正交邻敌造成伤害时追加点伤。
	if relic.ortho_pair_adjacent_enemy_damage_bonus != 0:
		for item in player_units:
			var unit2 := item as UnitInstance
			if unit2 == null or not unit2.is_alive():
				continue
			if not _has_ortho_ally_neighbor(unit2, player_units):
				continue
			var ortho_hit := EffectSpec.new()
			ortho_hit.trigger = CombatEvents.ON_DEAL_DAMAGE
			ortho_hit.target_selector = EffectSpec.TargetSelector.EVENT_TARGET
			ortho_hit.condition = EffectSpec.Condition.EVENT_TARGET_ORTHOGONAL_ADJACENT
			var odmg := EffectAction.new()
			odmg.action_type = EffectAction.Type.DEAL_DAMAGE
			odmg.value = relic.ortho_pair_adjacent_enemy_damage_bonus
			ortho_hit.actions = [odmg]
			_attach_ability_to_unit(
				unit2,
				"%s_ortho_%d" % [relic.id, unit2.instance_id],
				relic.display_name,
				[ortho_hit],
			)

	## 主题筛选：给带某主题（主/辅）的友方开战临时攻/血；可选要求该主题已成形。
	_attach_theme_filtered_start(player_units, relic, formed)


static func _attach_trigger_for_relic(player_units: Array, relic: ExpeditionRelicData) -> void:
	var specs: Array[EffectSpec] = []
	## 鼓点 / 邻旗 / 铁扉 → ExpeditionRelicCombatHooks（非纯 EffectSpec）。

	## 猎号：友方击杀 → 随机另一友方临时攻。
	if relic.kill_spread_temp_attack != 0:
		var kill_spread := _mod_stat_spec(
			CombatEvents.ON_FRIEND_KILL,
			EffectSpec.TargetSelector.RANDOM_ALLY,
			&"attack",
			relic.kill_spread_temp_attack,
		)
		kill_spread.exclude_owner = true
		if relic.cap_per_combat > 0:
			kill_spread.max_triggers_per_combat = relic.cap_per_combat
		specs.append(kill_spread)

	## 葬铃：死者 OnDeath → 周围友方加攻。
	if relic.death_nearby_temp_attack != 0:
		for item in player_units:
			var u := item as UnitInstance
			if u == null:
				continue
			var death_near := _mod_stat_spec(
				CombatEvents.ON_DEATH,
				EffectSpec.TargetSelector.NEARBY_ALLIES,
				&"attack",
				relic.death_nearby_temp_attack,
			)
			death_near.exclude_owner = true
			_attach_ability_to_unit(
				u,
				"%s_death_near_%d" % [relic.id, u.instance_id],
				relic.display_name,
				[death_near],
			)

	## 绝阵：友方死亡 → 全体临时攻。
	if relic.death_team_temp_attack != 0:
		var death_team := _mod_stat_spec(
			CombatEvents.ON_FRIEND_DEATH,
			EffectSpec.TargetSelector.ALL_ALLIES,
			&"attack",
			relic.death_team_temp_attack,
		)
		if relic.cap_triggers_per_combat > 0:
			death_team.max_triggers_per_combat = relic.cap_triggers_per_combat
		specs.append(death_team)

	## 血宴 / 盾回 → ExpeditionRelicCombatHooks（每友方每回合顶需运行时计数）。

	## 殉道：死亡 → 打杀者 + 附近敌反伤层。
	if relic.death_damage_to_killer != 0 or relic.nearby_enemy_thorns != 0:
		for item4 in player_units:
			var martyr := item4 as UnitInstance
			if martyr == null:
				continue
			var martyr_specs: Array[EffectSpec] = []
			if relic.death_damage_to_killer != 0:
				var death_hit := EffectSpec.new()
				death_hit.trigger = CombatEvents.ON_DEATH
				death_hit.target_selector = EffectSpec.TargetSelector.EVENT_SOURCE
				if relic.cap_death_triggers_per_combat > 0:
					death_hit.max_triggers_per_combat = relic.cap_death_triggers_per_combat
				var kdmg := EffectAction.new()
				kdmg.action_type = EffectAction.Type.DEAL_DAMAGE
				kdmg.value = relic.death_damage_to_killer
				death_hit.actions = [kdmg]
				martyr_specs.append(death_hit)
			if relic.nearby_enemy_thorns != 0:
				var thorns := EffectSpec.new()
				thorns.trigger = CombatEvents.ON_DEATH
				thorns.target_selector = EffectSpec.TargetSelector.NEARBY_ENEMIES
				if relic.cap_death_triggers_per_combat > 0:
					thorns.max_triggers_per_combat = relic.cap_death_triggers_per_combat
				var t_act := EffectAction.new()
				t_act.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
				t_act.stat_name = CombatStatusStack.ID_THORNS
				t_act.value = relic.nearby_enemy_thorns
				thorns.actions = [t_act]
				martyr_specs.append(thorns)
			_attach_ability_to_unit(
				martyr,
				"%s_martyr_%d" % [relic.id, martyr.instance_id],
				relic.display_name,
				martyr_specs,
			)

	## 苦修：受伤后若已半血 → 临时攻（每单位每场一次）。
	if relic.half_hp_temp_attack != 0:
		for item5 in player_units:
			var ascetic := item5 as UnitInstance
			if ascetic == null:
				continue
			var half := _mod_stat_spec(
				CombatEvents.ON_DAMAGE_TAKEN,
				EffectSpec.TargetSelector.SELF,
				&"attack",
				relic.half_hp_temp_attack,
			)
			half.condition = EffectSpec.Condition.OWNER_AT_OR_BELOW_HALF_HP
			half.max_triggers_per_combat = 1
			_attach_ability_to_unit(
				ascetic,
				"%s_half_%d" % [relic.id, ascetic.instance_id],
				relic.display_name,
				[half],
			)

	if not specs.is_empty():
		_attach_ability_to_carrier(player_units, "%s_triggers" % relic.id, relic.display_name, specs)


## 事件失金减免（赊账羊皮）；返回实际扣金与是否碎裂圣物。
static func apply_event_gold_loss(
	bag: ExpeditionRelicBag,
	requested_loss: int,
) -> Dictionary:
	var loss := maxi(0, requested_loss)
	var shattered: ExpeditionRelicData = null
	if bag == null or loss <= 0:
		return {"loss": loss, "shattered": shattered}
	for i in bag.get_count():
		var relic := bag.get_at(i)
		if relic == null or relic.event_gold_cost_reduction <= 0:
			continue
		var reduced := maxi(0, loss - relic.event_gold_cost_reduction)
		if reduced < loss and relic.shatter_after_first_real_save:
			shattered = bag.try_remove_at(i)
		loss = reduced
		break
	return {"loss": loss, "shattered": shattered}


static func _attach_theme_filtered_start(
	player_units: Array,
	relic: ExpeditionRelicData,
	formed: Array[StringName],
) -> void:
	if relic == null or not UnitTheme.is_valid_id(relic.theme_filter):
		return
	var t_atk := relic.theme_combat_start_temp_attack
	var t_hp := relic.theme_combat_start_temp_max_hp
	if t_atk == 0 and t_hp == 0:
		return
	if relic.theme_requires_formed and relic.theme_filter not in formed:
		return
	var specs: Array[EffectSpec] = []
	if t_atk != 0:
		specs.append(
			_mod_stat_spec(
				CombatEvents.ON_COMBAT_START,
				EffectSpec.TargetSelector.ALL_ALLIES,
				&"attack",
				t_atk,
				relic.theme_filter,
			)
		)
	if t_hp != 0:
		specs.append(
			_mod_stat_spec(
				CombatEvents.ON_COMBAT_START,
				EffectSpec.TargetSelector.ALL_ALLIES,
				&"max_hp",
				t_hp,
				relic.theme_filter,
			)
		)
	_attach_ability_to_carrier(
		player_units,
		"%s_theme_%s" % [relic.id, String(relic.theme_filter)],
		relic.display_name,
		specs,
	)


static func _mod_stat_spec(
	trigger: StringName,
	selector: EffectSpec.TargetSelector,
	stat: StringName,
	value: int,
	require_theme: StringName = &"",
) -> EffectSpec:
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.MODIFY_STAT
	action.stat_name = stat
	action.value = value
	var spec := EffectSpec.new()
	spec.trigger = trigger
	spec.target_selector = selector
	spec.require_theme = require_theme
	spec.actions = [action]
	return spec


static func _attach_ability_to_carrier(
	player_units: Array,
	ability_id: String,
	display: String,
	specs: Array,
) -> void:
	var carrier := _pick_carrier(player_units)
	if carrier == null:
		return
	var typed: Array[EffectSpec] = []
	for s in specs:
		if s is EffectSpec:
			typed.append(s as EffectSpec)
	_attach_ability_to_unit(carrier, ability_id, display, typed)


static func _attach_ability_to_unit(
	unit: UnitInstance,
	ability_id: String,
	display: String,
	specs: Array,
) -> void:
	if unit == null or specs.is_empty():
		return
	var ab := AbilityData.new()
	ab.id = "%s%s" % [ATTACHED_PREFIX, ability_id]
	ab.display_name = "远征圣物·%s" % display
	ab.can_normal_attack = true
	ab.merge_value_mult = 1
	var typed: Array[EffectSpec] = []
	for s in specs:
		if s is EffectSpec:
			typed.append(s as EffectSpec)
	ab.effect_specs = typed
	unit.attached_abilities.append(ab)


static func _pick_carrier(units: Array) -> UnitInstance:
	for item in units:
		var unit := item as UnitInstance
		if unit != null and unit.is_alive() and not unit.is_combat_summon:
			return unit
	return null


static func _strip_previous_attachments(units: Array) -> void:
	for item in units:
		var unit := item as UnitInstance
		if unit == null or unit.attached_abilities.is_empty():
			continue
		var kept: Array[AbilityData] = []
		for ab in unit.attached_abilities:
			if ab == null:
				continue
			if String(ab.id).begins_with(ATTACHED_PREFIX):
				continue
			kept.append(ab)
		unit.attached_abilities = kept


## 友方半场更靠中线的两行 y（前排）；Dictionary 作 set。
static func _front_two_row_ys(player_units: Array, board_height: int) -> Dictionary:
	var mid := BoardHalf.midline_row(maxi(1, board_height))
	var ys: Array[int] = []
	for item in player_units:
		var unit := item as UnitInstance
		if unit == null:
			continue
		var y := unit.grid_pos.y
		if y < mid:
			continue
		if y not in ys:
			ys.append(y)
	ys.sort()
	var out := {}
	for i in mini(2, ys.size()):
		out[ys[i]] = true
	return out


static func _has_ortho_ally_neighbor(unit: UnitInstance, player_units: Array) -> bool:
	if unit == null:
		return false
	for item in player_units:
		var other := item as UnitInstance
		if other == null or other == unit or not other.is_alive():
			continue
		var d: Vector2i = other.grid_pos - unit.grid_pos
		if absi(d.x) + absi(d.y) == 1:
			return true
	return false


static func _iter(bag: ExpeditionRelicBag) -> Array[ExpeditionRelicData]:
	var out: Array[ExpeditionRelicData] = []
	if bag == null:
		return out
	for r in bag.get_relics():
		if r != null:
			out.append(r as ExpeditionRelicData)
	return out
