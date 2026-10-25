class_name CombatLogText
extends RefCounted

const COLOR_PLAYER := "#6eb5ff"
const COLOR_ENEMY := "#ff6b6b"
const COLOR_SYSTEM := "#aaaaaa"
const COLOR_DAMAGE := "#ffb347"

const SKIP_TYPES := {
	CombatEvents.ON_DEAL_DAMAGE: true,
	CombatEvents.ON_FRIEND_DEATH: true,
	CombatEvents.ON_ENEMY_DEATH: true,
	CombatEvents.ON_MOVE: true,
	CombatEvents.ON_COMBAT_START: true,
	CombatEvents.ON_COMBAT_END: true,
	CombatEvents.ON_SUMMONED: true,
	CombatEvents.ON_FRIEND_SUMMONED: true,
	CombatEvents.ON_LEVEL_UP: true,
}


static func format_event(event_type: StringName, payload: CombatEventPayload) -> String:
	if SKIP_TYPES.get(event_type, false):
		return ""
	if payload == null:
		return ""
	match event_type:
		CombatEvents.ON_ROUND_START:
			return system_line("— 第 %d 回合 —" % payload.amount)
		CombatEvents.ON_ATTACK_HIT:
			if payload.source == null or payload.target == null:
				return ""
			return "%s 攻击 %s" % [
				_color_name(payload.source),
				_color_name(payload.target),
			]
		CombatEvents.ON_DAMAGE_TAKEN:
			if payload.target == null:
				return ""
			var dmg := "[color=%s]%d[/color]" % [COLOR_DAMAGE, payload.amount]
			if payload.source == null:
				return "%s 受到格子效果 %s 伤害" % [_color_name(payload.target), dmg]
			return "%s 对 %s 造成 %s 伤害" % [
				_color_name(payload.source),
				_color_name(payload.target),
				dmg,
			]
		CombatEvents.ON_KILL:
			if payload.source == null or payload.target == null:
				return ""
			return "%s 击杀了 %s" % [
				_color_name(payload.source),
				_color_name(payload.target),
			]
		CombatEvents.ON_DEATH:
			if payload.target == null or payload.source != null:
				return ""
			return "%s 阵亡" % _color_name(payload.target)
		CombatEvents.ON_EFFECT_RESOLVED:
			var owner := (
				payload.effect_owner
				if payload.effect_owner != null
				else payload.source
			)
			if owner == null:
				return ""
			if payload.effect_entries.size() > 1:
				if payload.effect_spec == null:
					return ""
				var spec_text := UnitInfoText.format_effect_spec(payload.effect_spec)
				if spec_text.is_empty():
					return ""
				return "%s 触发：%s" % [_color_name(owner), spec_text]
			if payload.effect_action == null:
				return ""
			var action_text := UnitInfoText.format_action(payload.effect_action)
			if action_text.is_empty():
				return ""
			return "%s 触发：%s" % [_color_name(owner), action_text]
	return ""


static func system_line(text: String) -> String:
	return "[color=%s]%s[/color]" % [COLOR_SYSTEM, text]


static func _color_name(unit: UnitInstance) -> String:
	var display_name := UnitInfoText.get_display_name(unit)
	var color := COLOR_PLAYER if unit.team == UnitInstance.Team.PLAYER else COLOR_ENEMY
	return "[color=%s]%s[/color]" % [color, display_name]
