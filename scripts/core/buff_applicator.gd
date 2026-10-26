class_name BuffApplicator
extends RefCounted


static func apply_on_attach(entry: DeckEntry, buff: BuffCardData, deck: DeckState = null) -> void:
	if entry == null or buff == null:
		return
	match buff.effect_type:
		BuffCardData.EffectType.PERMANENT_ATTACK:
			entry.bonus_attack += buff.value
		BuffCardData.EffectType.PERMANENT_MAX_HP:
			if deck != null:
				deck.add_bonus_max_hp(entry, buff.value)
			else:
				entry.bonus_max_hp += buff.value
		BuffCardData.EffectType.CANNOT_MOVE:
			entry.rule_flags["cannot_move"] = true
		BuffCardData.EffectType.DEATH_GOLD:
			pass
