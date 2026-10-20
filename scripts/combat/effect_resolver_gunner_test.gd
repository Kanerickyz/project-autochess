class_name EffectResolverGunnerTest
extends RefCounted

const _EffectResolver := preload("res://scripts/combat/effects/effect_resolver.gd")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_hurt_permanent_crit_on_deck_entry()
	_test_crit_stacks_combat_modifier()
	_test_on_crit_event_emitted()
	if _failures == 0:
		print("EffectResolverGunnerTest: all tests passed")
	else:
		push_error("EffectResolverGunnerTest: %d failure(s)" % _failures)
	return _failures == 0


static func _dual_crit_ability() -> AbilityData:
	var ab := AbilityData.new()
	ab.id = "test_dual_crit"
	var act_perm := EffectAction.new()
	act_perm.action_type = EffectAction.Type.PERMANENT_DECK_STAT
	act_perm.stat_name = &"crit_rate_percent"
	act_perm.value = 5
	var spec_hurt := EffectSpec.new()
	spec_hurt.trigger = CombatEvents.ON_DAMAGE_TAKEN
	spec_hurt.actions = [act_perm]
	var act_crit := EffectAction.new()
	act_crit.action_type = EffectAction.Type.MODIFY_STAT
	act_crit.stat_name = &"crit_rate_percent"
	act_crit.value = 10
	var spec_crit := EffectSpec.new()
	spec_crit.trigger = CombatEvents.ON_CRIT
	spec_crit.actions = [act_crit]
	ab.effect_specs = [spec_hurt, spec_crit]
	return ab


static func _grid() -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	return grid


static func _gunner(cell: Vector2i, team: UnitInstance.Team, entry_id: int = 1) -> UnitInstance:
	var data := UnitData.new()
	data.id = "gunner"
	data.ability = _dual_crit_ability()
	data.stats = UnitStats.new()
	data.stats.attack = 3
	data.stats.max_hp = 4
	data.stats.crit_rate_percent = 10
	var unit := UnitInstance.from_unit_data(data, cell, team)
	unit.deck_entry_id = entry_id
	return unit


static func _deck_with_gunner(gunner: UnitInstance) -> DeckState:
	var config := DeckConfig.new()
	config.max_size = 20
	var deck := DeckState.new()
	deck.configure(config)
	var entry := deck.add_entry(gunner.unit_data)
	gunner.deck_entry_id = entry.entry_id
	return deck


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"EffectResolverGunnerTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _process_all(resolver: EffectResolver) -> void:
	while resolver.has_pending_steps():
		resolver.process_next_step()


static func _test_hurt_permanent_crit_on_deck_entry() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := _EffectResolver.new(grid, bus, pipeline)
	var gunner := _gunner(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	var deck := _deck_with_gunner(gunner)
	resolver.set_deck_state(deck)
	grid.place(gunner, Vector2i(1, 0))

	var attacker := UnitInstance.new("enemy", Vector2i(0, 0), UnitInstance.Team.ENEMY)
	attacker.stats = UnitStats.new()
	attacker.stats.attack = 1
	var payload := CombatEventPayload.new()
	payload.source = attacker
	payload.target = gunner
	payload.amount = 1
	resolver.on_event(CombatEvents.ON_DAMAGE_TAKEN, payload)
	_process_all(resolver)

	var entry := deck.get_entry(gunner.deck_entry_id)
	_assert_eq(entry.bonus_crit_rate_percent, 5, "hurt adds permanent crit to deck entry")
	_assert_eq(gunner.stats.crit_rate_percent, 15, "hurt adds crit to live unit stats")


static func _test_crit_stacks_combat_modifier() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	pipeline.set_rng(rng)
	var resolver := _EffectResolver.new(grid, bus, pipeline, rng)
	var gunner := _gunner(Vector2i(1, 0), UnitInstance.Team.PLAYER)
	gunner.stats.crit_rate_percent = 100
	grid.place(gunner, Vector2i(1, 0))
	var enemy := UnitInstance.new("enemy", Vector2i(2, 0), UnitInstance.Team.ENEMY)
	enemy.stats = UnitStats.new()
	enemy.stats.max_hp = 10
	enemy.current_hp = 10
	grid.place(enemy, Vector2i(2, 0))

	pipeline.apply_rolled_damage(gunner, enemy, gunner.get_effective_attack())
	_process_all(resolver)

	_assert_eq(
		gunner.stat_modifiers.get_flat_bonus(&"crit_rate_percent"),
		10,
		"crit hit adds combat crit modifier",
	)
	_assert_true(
		int(round(gunner.get_effective_crit_rate() * 100.0)) >= 100,
		"effective crit includes combat stack",
	)


static func _test_on_crit_event_emitted() -> void:
	var grid := _grid()
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	pipeline.set_rng(rng)
	var crit_count := [0]
	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_CRIT:
			crit_count[0] += 1
	)

	var attacker := _gunner(Vector2i(0, 0), UnitInstance.Team.PLAYER)
	attacker.stats.crit_rate_percent = 100
	grid.place(attacker, Vector2i(0, 0))
	var defender := UnitInstance.new("enemy", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	defender.stats = UnitStats.new()
	defender.stats.max_hp = 10
	defender.current_hp = 10
	grid.place(defender, Vector2i(1, 0))

	pipeline.apply_rolled_damage(attacker, defender, attacker.get_effective_attack())
	_assert_eq(crit_count[0], 1, "crit damage emits ON_CRIT")


static func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error("EffectResolverGunnerTest FAIL: %s" % message)
