class_name EnchantPricing
extends RefCounted

const MIN_PRICE := 2
const MAX_PRICE := 24
const BASE_PRICE := 2


static func compute_expected_price(material_a: DeckEntry, material_b: DeckEntry) -> int:
	if material_a == null or material_b == null:
		return MIN_PRICE
	var ability_a := material_a.get_main_ability()
	var ability_b := material_b.get_main_ability()
	var spec_a := AbilityComposer.get_single_effect_spec(ability_a)
	var spec_b := AbilityComposer.get_single_effect_spec(ability_b)
	if spec_a == null or spec_b == null:
		return MIN_PRICE
	var timing := _timing_tier_gold(spec_a)
	var effect := _effect_tier_gold(spec_b)
	var panel := _panel_tier_gold(material_a, material_b)
	var total := BASE_PRICE + timing + effect + panel
	return clampi(total, MIN_PRICE, MAX_PRICE)


static func compute_success_percent(gold_invested: int, expected_price: int) -> float:
	if expected_price <= 0:
		return 100.0 if gold_invested > 0 else 10.0
	if gold_invested >= expected_price:
		return 100.0
	if gold_invested <= 0:
		return 10.0
	return 10.0 + 90.0 * (float(gold_invested) / float(expected_price))


static func roll_succeeds(gold_invested: int, expected_price: int, unit_roll: float) -> bool:
	var rate := compute_success_percent(gold_invested, expected_price)
	return unit_roll < rate / 100.0


static func _timing_tier_gold(spec: EffectSpec) -> int:
	var trig := spec.trigger
	if trig in [
		CombatEvents.ON_ATTACK_HIT,
		CombatEvents.ON_DEAL_DAMAGE,
		CombatEvents.ON_LINE_ATTACK,
		CombatEvents.ON_ROUND_START,
	]:
		return 1
	if trig in [
		CombatEvents.ON_DAMAGE_TAKEN,
		CombatEvents.ON_FRIEND_DAMAGE_TAKEN,
		CombatEvents.ON_CRIT,
		CombatEvents.ON_KILL,
		CombatEvents.ON_MOVE,
	]:
		return 2
	return 3


static func _effect_tier_gold(spec: EffectSpec) -> int:
	var score := 0
	for action in spec.actions:
		if action == null:
			continue
		match action.action_type:
			EffectAction.Type.SPAWN_UNIT:
				score += 4 + maxi(0, action.spawn_count - 1)
			EffectAction.Type.DEAL_DAMAGE:
				score += 2 + mini(4, action.value / 4)
			EffectAction.Type.HEAL:
				score += 2 + mini(3, action.value / 5)
			EffectAction.Type.MODIFY_STAT:
				score += 1 + mini(2, absi(action.value) / 3)
			_:
				score += 1
	if spec.target_selector in [
		EffectSpec.TargetSelector.ALL_ALLIES,
		EffectSpec.TargetSelector.ALL_UNITS,
		EffectSpec.TargetSelector.RANDOM_CELLS,
	]:
		score += 1
	if spec.max_triggers_per_combat == 0:
		score += 1
	return score


static func _panel_tier_gold(a: DeckEntry, b: DeckEntry) -> int:
	var atk := DeckUpgradeService.get_display_attack(a) + DeckUpgradeService.get_display_attack(b)
	var hp := DeckUpgradeService.get_display_max_hp(a) + DeckUpgradeService.get_display_max_hp(b)
	return mini(6, (atk + hp) / 8)
