class_name CombatSettlementReel
extends RefCounted
## COMBAT_FEEDBACK §5.3：战斗技能介绍卡正文结算抖动（非脚下角标）。


static func play_intro(arena: RealtimeArenaView) -> void:
	if arena == null:
		return
	arena.play_combat_skill_info_reel_intro()


static func play_resolve(arena: RealtimeArenaView, payload: CombatEventPayload) -> void:
	if arena == null or payload == null:
		return
	arena.play_combat_skill_info_reel_resolve(payload)
