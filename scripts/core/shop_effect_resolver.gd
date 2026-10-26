class_name ShopEffectResolver
extends RefCounted

var _deck: DeckState
var _shop: ShopService
var _economy: RunEconomy
var _rng: RandomNumberGenerator


func configure(
	deck: DeckState,
	shop: ShopService,
	economy: RunEconomy,
	rng: RandomNumberGenerator,
) -> void:
	_deck = deck
	_shop = shop
	_economy = economy
	_rng = rng


func resolve(trigger: StringName, owner_entry: DeckEntry) -> void:
	if owner_entry == null or owner_entry.unit == null or _deck == null:
		return
	var ability := owner_entry.unit.ability
	if ability == null:
		return
	for spec in ability.effect_specs:
		if spec == null or spec.trigger != trigger:
			continue
		_execute_spec(spec, owner_entry)


func _execute_spec(spec: EffectSpec, owner_entry: DeckEntry) -> void:
	if spec.target_selector == EffectSpec.TargetSelector.ALL_SHOP_CHARACTERS:
		for action in spec.actions:
			_execute_action(action, owner_entry, null)
		return

	if _actions_need_no_deck_target(spec):
		for action in spec.actions:
			_execute_action(action, owner_entry, null)
		return

	var targets := _pick_deck_targets(spec, owner_entry)
	if targets.is_empty():
		return
	for target in targets:
		for action in spec.actions:
			_execute_action(action, owner_entry, target)


func _actions_need_no_deck_target(spec: EffectSpec) -> bool:
	if spec.actions.is_empty():
		return true
	for action in spec.actions:
		if action == null:
			continue
		match action.action_type:
			EffectAction.Type.GRANT_GOLD, EffectAction.Type.STOCK_FREE_BUFF:
				continue
			_:
				return false
	return true


func _pick_deck_targets(spec: EffectSpec, owner_entry: DeckEntry) -> Array[DeckEntry]:
	var result: Array[DeckEntry] = []
	match spec.target_selector:
		EffectSpec.TargetSelector.RANDOM_DECK_ALLY:
			result = _pick_random_deck_allies(
				owner_entry,
				spec.exclude_owner,
				maxi(1, spec.target_count),
			)
	return result


func _pick_random_deck_allies(
	owner: DeckEntry,
	exclude_owner: bool,
	count: int,
) -> Array[DeckEntry]:
	var candidates: Array[DeckEntry] = []
	for entry in _deck.get_entries():
		if entry == null:
			continue
		if exclude_owner and owner != null and entry.entry_id == owner.entry_id:
			continue
		candidates.append(entry)
	if candidates.is_empty():
		return []

	if _rng != null:
		for i in range(candidates.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp := candidates[i]
			candidates[i] = candidates[j]
			candidates[j] = tmp
	else:
		candidates.shuffle()

	var picked: Array[DeckEntry] = []
	var take := mini(count, candidates.size())
	for i in take:
		picked.append(candidates[i])
	return picked


func _execute_action(
	action: EffectAction,
	owner_entry: DeckEntry,
	target_entry: DeckEntry,
) -> void:
	if action == null:
		return
	var owner_ability: AbilityData = (
		owner_entry.unit.ability
		if owner_entry != null and owner_entry.unit != null
		else null
	)
	var scale := UnitInstance.ability_value_multiplier_for(
		owner_ability,
		owner_entry.level if owner_entry != null else 1,
	)
	match action.action_type:
		EffectAction.Type.GRANT_GOLD:
			if _economy != null:
				_economy.grant(action.value * scale)
		EffectAction.Type.PERMANENT_DECK_STAT:
			if target_entry == null:
				return
			var stat_value := action.value * scale
			if action.stat_name == &"attack":
				target_entry.bonus_attack += stat_value
			elif action.stat_name == &"max_hp":
				_deck.add_bonus_max_hp(target_entry, stat_value)
			_deck.deck_changed.emit()
		EffectAction.Type.STOCK_FREE_BUFF:
			if _shop != null and action.buff_card != null:
				_shop.stock_free_buff(action.buff_card, action.value * scale)
		EffectAction.Type.SHOP_CHARACTER_BONUS_HP:
			if _shop != null:
				_shop.apply_shop_character_bonus_hp(action.value * scale)
