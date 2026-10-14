class_name RealtimeEffectFeedback
extends RefCounted
## 将 ON_EFFECT_RESOLVED 映射为战场结果数字 / 短提示（Features/COMBAT_FEEDBACK）。
## 仅表现层映射；实时战斗内是否时停由 RealtimeBattleController 播报队列决定。
## 高频也入队时停；短提示可从简。不读普攻 ON_DAMAGE_TAKEN。

const KIND_DAMAGE := &"damage"
const KIND_HEAL := &"heal"
const KIND_STAT := &"stat"
const KIND_LABEL := &"label"

## 高频触发：结果数字为主、短提示从简；仍须入队时停（控制器处理）。
const HIGH_FREQ_TRIGGERS := {
	&"OnDamageTaken": true,
	&"OnDealDamage": true,
	&"OnAttackHit": true,
	&"OnCrit": true,
}


## 返回 Array[Dictionary]：{kind, text, amount, target, is_player, merge_key, show_tip}
static func build_popups(payload: CombatEventPayload) -> Array:
	var result: Array = []
	if payload == null:
		return result
	var owner := payload.effect_owner if payload.effect_owner != null else payload.source
	var entries: Array = payload.effect_entries
	if entries.is_empty() and payload.effect_action != null:
		entries = [{"action": payload.effect_action, "target": payload.target}]
	var tip := _ability_short_tip(owner)
	var rare_tip := not _is_high_freq(payload.effect_spec)
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var action: EffectAction = entry.get("action")
		var target: UnitInstance = entry.get("target")
		if action == null:
			continue
		var popup := _map_action(action, target, owner, tip, rare_tip)
		if not popup.is_empty():
			result.append(popup)
	return result


static func _map_action(
	action: EffectAction,
	target: UnitInstance,
	owner: UnitInstance,
	tip: String,
	rare_tip: bool,
) -> Dictionary:
	var anchor := target if target != null else owner
	var is_player := true
	if anchor != null:
		is_player = anchor.team == UnitInstance.Team.PLAYER
	elif owner != null:
		is_player = owner.team == UnitInstance.Team.PLAYER
	var unit_id := anchor.instance_id if anchor != null else -1

	match action.action_type:
		EffectAction.Type.DEAL_DAMAGE, EffectAction.Type.FRIENDS_HURT_AOE:
			var dmg := _resolve_damage_amount(owner, action)
			if dmg <= 0:
				return {}
			return {
				"kind": KIND_DAMAGE,
				"text": "-%d" % dmg,
				"amount": dmg,
				"target": anchor,
				"is_player": is_player,
				"unit_id": unit_id,
				"merge_key": "%d|damage" % unit_id,
				"show_tip": false,
				"tip": "",
			}
		EffectAction.Type.HEAL:
			var heal := _scaled_value(owner, action.value)
			if heal == 0:
				return {}
			var heal_text := "+%d" % heal if heal > 0 else "%d" % heal
			return {
				"kind": KIND_HEAL,
				"text": heal_text,
				"amount": heal,
				"target": anchor,
				"is_player": is_player,
				"unit_id": unit_id,
				"merge_key": "%d|heal" % unit_id,
				"show_tip": false,
				"tip": "",
			}
		EffectAction.Type.MODIFY_STAT, EffectAction.Type.PERMANENT_DECK_STAT:
			var delta := _scaled_value(owner, action.value)
			if delta == 0:
				return {}
			var stat_label := _stat_short_label(action.stat_name)
			var sign := "+" if delta > 0 else ""
			## 结果数字为主；低频也不叠技能全名，避免与 +攻 重复刷屏。
			return {
				"kind": KIND_STAT,
				"text": "%s%d%s" % [sign, delta, stat_label],
				"amount": delta,
				"target": anchor,
				"is_player": is_player,
				"unit_id": unit_id,
				"merge_key": "%d|stat|%s" % [unit_id, String(action.stat_name)],
				"show_tip": false,
				"tip": "",
			}
		EffectAction.Type.SPAWN_UNIT, EffectAction.Type.SPLIT_SELF:
			var spawn_text := tip
			if spawn_text.is_empty():
				spawn_text = "生成" if action.action_type == EffectAction.Type.SPAWN_UNIT else "分裂"
			return {
				"kind": KIND_LABEL,
				"text": _shorten(spawn_text, 10),
				"amount": 0,
				"target": anchor,
				"is_player": is_player,
				"unit_id": unit_id,
				"merge_key": "%d|label|spawn" % unit_id,
				"show_tip": false,
				"tip": "",
			}
		EffectAction.Type.SWAP_POSITIONS:
			var swap_text := tip if not tip.is_empty() else "换位"
			return {
				"kind": KIND_LABEL,
				"text": _shorten(swap_text, 8),
				"amount": 0,
				"target": anchor,
				"is_player": is_player,
				"unit_id": unit_id,
				"merge_key": "%d|label|swap" % unit_id,
				"show_tip": false,
				"tip": "",
			}
		EffectAction.Type.FUSE_EXPLODE:
			return {
				"kind": KIND_LABEL,
				"text": _shorten(tip if not tip.is_empty() else "引爆", 8),
				"amount": 0,
				"target": anchor,
				"is_player": is_player,
				"unit_id": unit_id,
				"merge_key": "%d|label|fuse" % unit_id,
				"show_tip": false,
				"tip": "",
			}
		_:
			## 非数字且无专用短标：低频时用技能名；高频跳过以免刷屏。
			if not rare_tip or tip.is_empty():
				return {}
			return {
				"kind": KIND_LABEL,
				"text": _shorten(tip, 10),
				"amount": 0,
				"target": anchor,
				"is_player": is_player,
				"unit_id": unit_id,
				"merge_key": "%d|label|other" % unit_id,
				"show_tip": false,
				"tip": "",
			}


static func _is_high_freq(spec: EffectSpec) -> bool:
	if spec == null:
		return false
	return HIGH_FREQ_TRIGGERS.get(spec.trigger, false)


static func _ability_short_tip(owner: UnitInstance) -> String:
	if owner == null or owner.unit_data == null:
		return ""
	var ability: AbilityData = owner.unit_data.ability
	if ability == null:
		return ""
	if not ability.display_name.is_empty():
		return ability.display_name
	return ability.id


static func _stat_short_label(stat_name: StringName) -> String:
	match stat_name:
		&"attack":
			return "攻"
		&"max_hp":
			return "生命"
		&"crit_rate_percent":
			return "暴"
		&"attack_range":
			return "射程"
		&"move_range":
			return "移"
		_:
			return String(stat_name)


static func _scaled_value(owner: UnitInstance, value: int) -> int:
	if owner == null:
		return value
	return value * maxi(1, owner.level)


static func _resolve_damage_amount(owner: UnitInstance, action: EffectAction) -> int:
	if action.damage_mode == EffectAction.DamageMode.OWNER_ATTACK_PERCENT:
		if owner == null:
			return 0
		return maxi(1, owner.get_effective_attack() * action.percent / 100)
	return _scaled_value(owner, action.value)


static func _shorten(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, max_chars)
