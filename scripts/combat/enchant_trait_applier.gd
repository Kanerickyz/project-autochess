class_name EnchantTraitApplier
extends RefCounted

## 开战：把 Run 持久附魔写入单位战斗状态。


static func apply_combat_start_from_deck(
	deck: DeckState,
	allies: Array,
	resolver: EffectResolver,
) -> int:
	if deck == null or resolver == null:
		return 0
	var applied := 0
	for item in allies:
		var unit := item as UnitInstance
		if unit == null or not unit.is_alive() or unit.deck_entry_id < 0:
			continue
		var entry := deck.get_entry(unit.deck_entry_id)
		if entry == null:
			continue
		var status_id := entry.get_enchant_combat_status_id()
		var stacks := entry.get_enchant_status_stacks()
		if status_id == StringName() or stacks <= 0:
			continue
		if not CombatStatusStack.is_valid_id(status_id):
			continue
		var act := EffectAction.new()
		act.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
		act.stat_name = status_id
		act.value = stacks
		if resolver.apply_unscaled_action(act, unit):
			applied += 1
	return applied