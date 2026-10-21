class_name UnitInfoText
extends RefCounted

## 技能介绍卡内联攻/血图标占位；RichTextLabel 再换成脚下同款贴图。
const STAT_ICON_ATK := "⟦ATK⟧"
const STAT_ICON_HP := "⟦HP⟧"

const TRIGGER_LABELS := {
	CombatEvents.ON_COMBAT_START: "开战时",
	CombatEvents.ON_FRIEND_SUMMONED: "友方召唤时",
	CombatEvents.ON_SUMMONED: "被召唤时",
	CombatEvents.ON_FRIEND_DEATH: "友方死亡时",
	CombatEvents.ON_FRIEND_DAMAGE_TAKEN: "友方受伤时",
	CombatEvents.ON_ROUND_START: "自己回合开始时",
	CombatEvents.ON_DAMAGE_TAKEN: "受伤时",

	CombatEvents.ON_DEAL_DAMAGE: "造成伤害时",
	CombatEvents.ON_CRIT: "造成暴击时",
	CombatEvents.ON_KILL: "击杀时",
	CombatEvents.ON_DEATH: "死亡时",
	CombatEvents.ON_ATTACK_HIT: "受击前",
	CombatEvents.ON_MOVE: "移动时",
	ShopEvents.ON_BUY: "购买时",
	ShopEvents.ON_SELL: "出售时",
	ShopEvents.ON_LEVEL_UP: "升级时",
}


static func get_display_name(unit: UnitInstance) -> String:
	if unit == null:
		return "未知"
	if unit.unit_data != null and not unit.unit_data.display_name.is_empty():
		return unit.unit_data.display_name
	if not unit.id.is_empty():
		return unit.id
	return "未知"


static func get_stats_line(unit: UnitInstance) -> String:
	if unit == null or unit.stats == null:
		return "—"
	return "Lv.%d · %d/%d 生命 · %d 攻击 · %d%% 暴击" % [
		unit.level,
		unit.current_hp,
		unit.get_effective_max_hp(),
		unit.get_effective_attack(),
		int(round(unit.get_effective_crit_rate() * 100.0)),
	]


static func get_stats_line_from_entry(entry: DeckEntry) -> String:
	if entry == null or entry.unit == null or entry.unit.stats == null:
		return "—"
	var stats := entry.unit.stats
	var max_hp := stats.max_hp + entry.bonus_max_hp
	var attack := stats.attack + entry.bonus_attack
	var crit := stats.crit_rate_percent + entry.bonus_crit_rate_percent
	return "Lv.%d · %d/%d 生命 · %d 攻击 · %d%% 暴击" % [
		entry.level,
		max_hp,
		max_hp,
		attack,
		crit,
	]


static func get_stats_line_from_unit_data(data: UnitData) -> String:
	if data == null or data.stats == null:
		return "—"
	var stats := data.stats
	return "Lv.1 · %d/%d 生命 · %d 攻击 · %d%% 暴击" % [
		stats.max_hp,
		stats.max_hp,
		stats.attack,
		stats.crit_rate_percent,
	]


static func get_attack_value(unit: UnitInstance) -> int:
	if unit == null:
		return 0
	return unit.get_effective_attack()


static func get_hp_display(unit: UnitInstance) -> String:
	if unit == null:
		return "0"
	return str(unit.current_hp)


static func get_display_name_from_unit_data(data: UnitData) -> String:
	if data == null:
		return "未知"
	if not data.display_name.is_empty():
		return data.display_name
	if not data.id.is_empty():
		return data.id
	return "未知"


static func get_skills_block_from_unit_data(
	data: UnitData, level: int = 1, with_stat_icons: bool = false
) -> String:
	if data == null:
		return "无技能"
	var lines: PackedStringArray = []
	if data.ability != null:
		var scale := UnitInstance.ability_value_multiplier_for(data.ability, level)
		lines.append(format_ability("技能", data.ability, scale, with_stat_icons, level))
	for passive in data.passives:
		if passive != null:
			var pscale := UnitInstance.ability_value_multiplier_for(passive, level)
			lines.append(format_ability("被动", passive, pscale, with_stat_icons))
	if lines.is_empty():
		return "无技能"
	return "\n".join(lines)


## 角色库预览：三合一后攻/血按三只同星加总（1★→×3，2★→×9）。
static func catalog_preview_stat_mult(level: int) -> int:
	var lv := clampi(level, 1, 3)
	var mult := 1
	for _i in range(lv - 1):
		mult *= 3
	return mult


static func get_skills_block_from_entry(entry: DeckEntry, with_stat_icons: bool = false) -> String:
	if entry == null or entry.unit == null:
		return "无技能"
	var lines: PackedStringArray = []
	var main_ab := entry.get_main_ability()
	if main_ab != null:
		var scale := 1
		if entry.get_star_display_level() > 0:
			scale = UnitInstance.ability_value_multiplier_for(main_ab, entry.level)
		lines.append(format_ability("技能", main_ab, scale, with_stat_icons, entry.level))
	for passive in entry.unit.passives:
		if passive != null:
			var pscale := UnitInstance.ability_value_multiplier_for(passive, entry.level)
			lines.append(format_ability("被动", passive, pscale, with_stat_icons))
	for attached in entry.attached_abilities:
		if attached != null:
			var ascale := UnitInstance.ability_value_multiplier_for(attached, entry.level)
			lines.append(format_ability("移植", attached, ascale, with_stat_icons))
	for buff in entry.attached_buffs:
		if buff != null:
			lines.append(format_buff(buff, with_stat_icons))
	if lines.is_empty():
		return "无技能"
	return "\n".join(lines)


static func get_skills_block(unit: UnitInstance, with_stat_icons: bool = false) -> String:
	if unit == null or unit.unit_data == null:
		return "无技能"

	var lines: PackedStringArray = []
	if unit.unit_data.ability != null:
		var scale := UnitInstance.ability_value_multiplier_for(unit.unit_data.ability, unit.level)
		lines.append(
			format_ability("技能", unit.unit_data.ability, scale, with_stat_icons, unit.level)
		)
	for passive in unit.unit_data.passives:
		if passive != null:
			var pscale := UnitInstance.ability_value_multiplier_for(passive, unit.level)
			lines.append(format_ability("被动", passive, pscale, with_stat_icons))
	for attached in unit.attached_abilities:
		if attached != null:
			var ascale := UnitInstance.ability_value_multiplier_for(attached, unit.level)
			lines.append(format_ability("移植", attached, ascale, with_stat_icons))
	if lines.is_empty():
		return "无技能"
	return "\n".join(lines)


static func format_buff(buff: BuffCardData, with_stat_icons: bool = false) -> String:
	var title: String = (
		buff.display_name if not buff.display_name.is_empty() else buff.id
	)
	var body := _buff_effect_description(buff, with_stat_icons)
	return "【增益】%s — %s" % [title, body]


static func _buff_effect_description(buff: BuffCardData, with_stat_icons: bool = false) -> String:
	if buff == null:
		return ""
	match buff.effect_type:
		BuffCardData.EffectType.PERMANENT_ATTACK:
			if with_stat_icons:
				return "永久 +%s%d" % [STAT_ICON_ATK, buff.value]
			return "永久 +%d 攻击" % buff.value
		BuffCardData.EffectType.PERMANENT_MAX_HP:
			if with_stat_icons:
				return "永久 +%s%d 生命上限" % [STAT_ICON_HP, buff.value]
			return "永久 +%d 生命上限" % buff.value
		BuffCardData.EffectType.CANNOT_MOVE:
			return "无法行走，仍可攻击"
		BuffCardData.EffectType.DEATH_GOLD:
			return "死亡时为 Run +%d 金" % buff.value
	return ""


static func get_ability_description(
	ability: AbilityData,
	value_scale: int = 1,
	with_stat_icons: bool = false,
	unit_level: int = 1,
) -> String:
	if ability == null:
		return ""
	if ability.id == "turn_start_strike_weakest":
		var dmg := _strike_weakest_skill_damage(unit_level)
		return (
			"自己回合开始时，瞬移至当前生命最低敌人邻格，造成 %d 点技能伤害"
			+ "（1★为 2；三合一升星后为 7，当前 %d）"
		) % [dmg, dmg]
	var parts: PackedStringArray = []
	for spec in ability.effect_specs:
		var line := format_effect_spec(spec, value_scale, with_stat_icons, ability, unit_level)
		if not line.is_empty():
			parts.append(line)
	if not parts.is_empty():
		return "；".join(parts)
	if not ability.display_name.is_empty():
		return ability.display_name
	return ability.id


static func format_ability(
	kind: String,
	ability: AbilityData,
	value_scale: int = 1,
	with_stat_icons: bool = false,
	unit_level: int = 1,
) -> String:
	var desc := get_ability_description(ability, value_scale, with_stat_icons, unit_level)
	if desc.is_empty():
		desc = "无效果描述"
	return "【%s】%s" % [kind, desc]


static func format_effect_spec(
	spec: EffectSpec,
	value_scale: int = 1,
	with_stat_icons: bool = false,
	ability: AbilityData = null,
	unit_level: int = 1,
) -> String:
	if spec == null:
		return ""
	var trigger: String = String(TRIGGER_LABELS.get(spec.trigger, String(spec.trigger)))
	## 条件收窄触发文案，避免「友方死亡」被读成含随从/代理。
	if (
		spec.trigger == CombatEvents.ON_FRIEND_DEATH
		and spec.condition == EffectSpec.Condition.EVENT_TARGET_IS_NOT_COMBAT_SUMMON
	):
		trigger = "友方角色死亡时"
	elif (
		spec.trigger == CombatEvents.ON_FRIEND_SUMMONED
		and spec.condition == EffectSpec.Condition.EVENT_TARGET_IS_COMBAT_SUMMON
	):
		trigger = "友方随从被召唤时"
	var target_text := _format_target(spec)
	var actions: PackedStringArray = []
	var has_spawn_or_split := false
	var has_other_action := false
	for action in spec.actions:
		if action == null:
			continue
		if (
			action.action_type == EffectAction.Type.SPAWN_UNIT
			or action.action_type == EffectAction.Type.SPLIT_SELF
		):
			has_spawn_or_split = true
		else:
			has_other_action = true
		var text: String = format_action(action, value_scale, with_stat_icons, ability, unit_level)
		if not text.is_empty():
			actions.append(text)
	## 生成/分裂不写「对自身/对事件目标」——目标选择器只服务批处理，不表示作用对象。
	if has_spawn_or_split and not has_other_action:
		target_text = ""
	var action_text: String = "，".join(actions) if not actions.is_empty() else ""
	if target_text.is_empty():
		if action_text.is_empty():
			return trigger
		return "%s %s" % [trigger, action_text]
	if action_text.is_empty():
		return "%s %s" % [trigger, target_text]
	return "%s %s %s" % [trigger, target_text, action_text]


static func _format_target(spec: EffectSpec) -> String:
	match spec.target_selector:
		EffectSpec.TargetSelector.SELF:
			return "对自身"
		EffectSpec.TargetSelector.EVENT_TARGET:
			return "对事件目标"
		EffectSpec.TargetSelector.RANDOM_ALLY:
			if spec.exclude_owner:
				return "对随机其他队友"
			return "对随机队友"
		EffectSpec.TargetSelector.ALL_UNITS:
			return "对全场"
		EffectSpec.TargetSelector.RANDOM_ENEMY:
			return "对随机敌人"
		EffectSpec.TargetSelector.HEALTHIEST_ALLY:
			return "对最健康队友"
		EffectSpec.TargetSelector.RANDOM_DECK_ALLY:
			if spec.exclude_owner:
				if spec.target_count > 1:
					return "对 %d 名随机其他队友" % spec.target_count
				return "对随机其他队友"
			if spec.target_count > 1:
				return "对 %d 名随机队友" % spec.target_count
			return "对随机队友"
		EffectSpec.TargetSelector.ALL_SHOP_CHARACTERS:
			return "对商店角色"
		EffectSpec.TargetSelector.ALL_ALLIES:
			return "对全体队友"
		EffectSpec.TargetSelector.FIRST_ENEMY:
			return "对前排敌人"
		EffectSpec.TargetSelector.LAST_ENEMY:
			return "对后排敌人"
		EffectSpec.TargetSelector.NEAREST_ALLY_BEHIND:
			return "对身后最近队友"
		EffectSpec.TargetSelector.CELLS_AROUND_EVENT:
			return "对事件格周围"
		EffectSpec.TargetSelector.RANDOM_CELLS:
			if spec.target_count > 1:
				return "对 %d 个随机格子" % spec.target_count
			return "对随机格子"
		EffectSpec.TargetSelector.HIGHEST_CURRENT_HP_ALLY:
			if spec.exclude_owner:
				return "与当前血量最高的其他队友"
			return "与当前血量最高的队友"
		EffectSpec.TargetSelector.UNIT_AHEAD_OF_MOVE:
			return "对移动前方单位"
		EffectSpec.TargetSelector.ENEMIES_ADJACENT_TO_EVENT_TARGET:
			return "对目标邻格敌人"
		EffectSpec.TargetSelector.EVENT_SOURCE:
			return "对施害者"
		EffectSpec.TargetSelector.NEARBY_ALLIES:
			if spec.exclude_owner:
				return "对附近其他友方"
			return "对附近友方"
		EffectSpec.TargetSelector.LOWEST_CURRENT_HP_ALLY:
			if spec.exclude_owner:
				return "对当前生命最低的其他队友"
			return "对当前生命最低的队友"
		EffectSpec.TargetSelector.LOWEST_CURRENT_HP_NEARBY_ALLY:
			if spec.exclude_owner:
				return "对附近当前生命最低的其他队友"
			return "对附近当前生命最低的队友"
		EffectSpec.TargetSelector.LOWEST_CURRENT_HP_ENEMY:
			return "对当前生命最低的敌人"
	return ""


static func format_action(
	action: EffectAction,
	value_scale: int = 1,
	with_stat_icons: bool = false,
	ability: AbilityData = null,
	unit_level: int = 1,
) -> String:
	var scale := maxi(1, value_scale)
	var scaled_value := action.value * scale
	if action.action_type == EffectAction.Type.DEAL_DAMAGE:
		scaled_value = _display_damage_amount(action, ability, unit_level, scale)
	match action.action_type:
		EffectAction.Type.MODIFY_STAT:
			var stat: String = String(action.stat_name)
			var sign: String = "+" if scaled_value >= 0 else ""
			if with_stat_icons and stat == "attack":
				if scaled_value >= 0:
					return "+%s%d" % [STAT_ICON_ATK, scaled_value]
				return "-%s%d" % [STAT_ICON_ATK, absi(scaled_value)]
			if with_stat_icons and stat == "max_hp":
				if scaled_value >= 0:
					return "+%s%d 生命上限" % [STAT_ICON_HP, scaled_value]
				return "-%s%d 生命上限" % [STAT_ICON_HP, absi(scaled_value)]
			if stat == "attack":
				stat = "攻击"
			elif stat == "max_hp":
				stat = "生命上限"
			elif stat == "crit_rate_percent":
				stat = "暴击率"
			elif stat == "steps_per_turn":
				stat = "每回合步数"
			return "%s%s %s" % [sign, scaled_value, stat]
		EffectAction.Type.HEAL:
			if with_stat_icons:
				return "恢复 %s%d" % [STAT_ICON_HP, scaled_value]
			return "恢复 %d 生命" % scaled_value
		EffectAction.Type.SPAWN_UNIT:
			var spawn_name: String = "单位"
			if action.spawn_unit != null and not action.spawn_unit.display_name.is_empty():
				spawn_name = action.spawn_unit.display_name
			elif action.spawn_unit != null:
				spawn_name = action.spawn_unit.id
			var count := AllyDeathSpawnRules.merged_spawn_count(
				action.spawn_count, ability, unit_level
			)
			if action.spawn_owner_base_percent > 0:
				if count > 1:
					return "生成 %d×%s（死者基础身体 %d%%）" % [
						count, spawn_name, action.spawn_owner_base_percent
					]
				return "生成 %s（死者基础身体 %d%%）" % [spawn_name, action.spawn_owner_base_percent]
			if action.spawn_unit != null and action.spawn_unit.stats != null:
				var stats := action.spawn_unit.stats
				var atk := stats.attack
				var hp := stats.max_hp
				if action.spawn_hp_override > 0:
					hp = action.spawn_hp_override
				if count > 1:
					return "生成 %d×%s（%d/%d）" % [count, spawn_name, atk, hp]
				return "生成 %s（%d/%d）" % [spawn_name, atk, hp]
			if count > 1:
				return "生成 %d×%s" % [count, spawn_name]
			return "生成 %s" % spawn_name
		EffectAction.Type.SPLIT_SELF:
			var split_hp := maxi(1, action.spawn_hp_override if action.spawn_hp_override > 0 else 1)
			return "按当前生命分裂为等量分身（继承攻击，%d 血）" % split_hp
		EffectAction.Type.DEAL_DAMAGE:
			if action.damage_mode == EffectAction.DamageMode.OWNER_ATTACK_PERCENT:
				return "造成 %d%% 攻击力伤害" % action.percent
			return "造成 %d 点伤害" % scaled_value
		EffectAction.Type.SET_HP_FROM_ALLY_PERCENT:
			return "复制 %d%% 生命" % scaled_value
		EffectAction.Type.GRANT_GOLD:
			return "获得 +%d 金" % scaled_value
		EffectAction.Type.PERMANENT_DECK_STAT:
			var pstat: String = String(action.stat_name)
			if pstat == "attack":
				pstat = "攻击"
			elif pstat == "max_hp":
				pstat = "生命上限"
			elif pstat == "crit_rate_percent":
				pstat = "暴击率"
			return "永久 +%d %s" % [scaled_value, pstat]
		EffectAction.Type.STOCK_FREE_BUFF:
			var buff_name := "增益"
			if action.buff_card != null and not action.buff_card.display_name.is_empty():
				buff_name = action.buff_card.display_name
			return "补充免费 %s ×%d" % [buff_name, scaled_value]
		EffectAction.Type.SHOP_CHARACTER_BONUS_HP:
			return "商店角色 +%d 生命上限" % scaled_value
		EffectAction.Type.APPLY_CELL_EFFECT:
			var effect_name := "格子效果"
			if action.cell_effect != null and not action.cell_effect.display_name.is_empty():
				effect_name = action.cell_effect.display_name
			elif action.cell_effect != null:
				effect_name = action.cell_effect.id
			if action.radius > 0:
				return "施加 %s（半径 %d）" % [effect_name, action.radius]
			return "施加 %s" % effect_name
		EffectAction.Type.FRIENDS_HURT_AOE:
			var need := maxi(1, action.threshold)
			return "若本回合友方受伤≥%d 次，对全体敌人 %d 点伤害" % [need, scaled_value]
		EffectAction.Type.SWAP_POSITIONS:
			return "换位"
		EffectAction.Type.TELEPORT_ADJACENT_TO_TARGET:
			return "瞬移至目标邻格"
		EffectAction.Type.FUSE_EXPLODE:
			var round := maxi(1, action.threshold)
			return "第%d回合开始时，对剩余血量范围内敌人造成当前攻击伤害并自身死亡" % round
	return ""


static func _strike_weakest_skill_damage(unit_level: int) -> int:
	return 2 if unit_level <= 1 else 7


static func _display_damage_amount(
	action: EffectAction,
	ability: AbilityData,
	unit_level: int,
	value_scale: int,
) -> int:
	if ability != null and ability.id == "turn_start_strike_weakest":
		return _strike_weakest_skill_damage(unit_level)
	return action.value * maxi(1, value_scale)
