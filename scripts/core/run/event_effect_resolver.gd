class_name EventEffectResolver
extends RefCounted

static func apply_choice(
	choice: EventChoice,
	deck_state: DeckState,
	run_economy: RunEconomy,
	buff_pool: Array[BuffCardData],
	rng: RandomNumberGenerator,
) -> String:
	if choice == null:
		return "无事发生"
	match choice.effect_type:
		EventChoice.EffectType.GRANT_GOLD:
			run_economy.grant(maxi(0, choice.value))
			return "获得 %d 金币" % choice.value
		EventChoice.EffectType.LOSE_GOLD:
			var amount := mini(run_economy.gold, maxi(0, choice.value))
			run_economy.spend(amount)
			return "失去 %d 金币" % amount
		EventChoice.EffectType.HEAL_ALL_UNITS:
			return "恢复了队伍生命（下一场战斗生效）"
		EventChoice.EffectType.REMOVE_RANDOM_DECK_ENTRY:
			return _remove_random_entry(deck_state, rng)
		EventChoice.EffectType.GRANT_RANDOM_BUFF:
			return _grant_random_buff(deck_state, buff_pool, rng)
		_:
			return "你离开了"


static func _remove_random_entry(deck_state: DeckState, rng: RandomNumberGenerator) -> String:
	var entries := deck_state.get_entries()
	if entries.is_empty():
		return "牌库为空，无事发生"
	var pick: DeckEntry = entries[rng.randi_range(0, entries.size() - 1)]
	var unit_name: String = pick.unit_data.display_name if pick.unit_data != null else "角色"
	deck_state.remove_entry(pick.entry_id)
	return "移除了 %s" % unit_name


static func _grant_random_buff(
	deck_state: DeckState,
	buff_pool: Array[BuffCardData],
	rng: RandomNumberGenerator,
) -> String:
	if buff_pool.is_empty():
		return "没有可用的增益"
	var entries := deck_state.get_entries()
	if entries.is_empty():
		return "牌库为空，无法附加增益"
	var buff: BuffCardData = buff_pool[rng.randi_range(0, buff_pool.size() - 1)]
	var entry: DeckEntry = entries[rng.randi_range(0, entries.size() - 1)]
	deck_state.attach_buff(entry.entry_id, buff)
	var entry_name: String = entry.unit_data.display_name if entry.unit_data != null else "角色"
	var buff_name: String = buff.display_name if buff != null else "增益"
	return "为 %s 附加了 %s" % [entry_name, buff_name]
