class_name CombatSettlementReel
extends RefCounted
## COMBAT_FEEDBACK §5.3：结算拍角色 Reel + 词条抖动（纯表现）。

const PUNCH_OWNER := 1.0
const PUNCH_OTHER := 0.55


static func play_intro(
	motion: RealtimeUnitMotion,
	arena: RealtimeArenaView,
	owner: UnitInstance,
	sim: RealtimeCombatSim,
) -> void:
	if owner == null or motion == null or arena == null or sim == null:
		return
	var rt := sim.find_unit(owner)
	if rt == null or not rt.is_alive():
		return
	motion.play_settlement_intro(rt)
	arena.pulse_entry_chip(rt, CombatEntryStrip.CHIP_SKILL)


static func play_resolve(
	motion: RealtimeUnitMotion,
	arena: RealtimeArenaView,
	sim: RealtimeCombatSim,
	payload: CombatEventPayload,
) -> void:
	if payload == null or motion == null or arena == null or sim == null:
		return
	var owner: UnitInstance = payload.effect_owner
	if owner == null:
		owner = payload.source
	var owner_rt := sim.find_unit(owner) if owner != null else null
	if owner_rt != null and owner_rt.is_alive():
		motion.play_settlement_punch(owner_rt, PUNCH_OWNER)
		arena.pulse_entry_chip(owner_rt, CombatEntryStrip.CHIP_SKILL)
	if payload.effect_buff != null and owner_rt != null:
		arena.pulse_entry_chip(owner_rt, CombatEntryStrip.chip_key_for_buff(payload.effect_buff))
	var entries: Array = payload.effect_entries
	if entries.is_empty() and payload.effect_action != null:
		entries = [{"action": payload.effect_action, "target": payload.target}]
	var owner_id := owner.get_instance_id() if owner != null else -1
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var action: EffectAction = entry.get("action")
		var target: UnitInstance = entry.get("target")
		if action == null:
			continue
		var chip_key := CombatEntryStrip.chip_key_for_action(action)
		var target_rt := sim.find_unit(target) if target != null else null
		if target_rt != null and target_rt.is_alive():
			if target.get_instance_id() != owner_id:
				motion.play_settlement_punch(target_rt, PUNCH_OTHER)
			arena.pulse_entry_chip(target_rt, chip_key)
		elif owner_rt != null:
			arena.pulse_entry_chip(owner_rt, chip_key)
