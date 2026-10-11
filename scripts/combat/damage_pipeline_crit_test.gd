class_name DamagePipelineCritTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_roll_damage_full_crit_rate()
	_test_roll_damage_zero_crit_rate()
	_test_roll_damage_no_source()
	_test_apply_rolled_damage_emits_crit_flag()
	if _failures == 0:
		print("DamagePipelineCritTest: all tests passed")
	else:
		push_error("DamagePipelineCritTest: %d failure(s)" % _failures)
	return _failures == 0


static func _grid() -> BoardGrid:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	return grid


static func _bus() -> CombatEventBus:
	return CombatEventBus.new()


static func _pipeline(bus: CombatEventBus, grid: BoardGrid) -> DamagePipeline:
	var pipeline := DamagePipeline.new(bus, grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	pipeline.set_rng(rng)
	return pipeline


static func _unit(attack: int, crit_rate_percent: int) -> UnitInstance:
	var unit := UnitInstance.new("test", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.attack = attack
	unit.stats.crit_rate_percent = crit_rate_percent
	unit.current_hp = 10
	return unit


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"DamagePipelineCritTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures += 1
		push_error("DamagePipelineCritTest FAIL: %s" % message)


static func _test_roll_damage_full_crit_rate() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var attacker := _unit(4, 100)
	var rolled: DamageRoll = pipeline.roll_damage(attacker, attacker.get_effective_attack())
	_assert_true(rolled.is_crit, "100% crit rate should crit")
	_assert_eq(rolled.amount, 6, "crit damage 150% of 4")


static func _test_roll_damage_zero_crit_rate() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var attacker := _unit(4, 0)
	var rolled: DamageRoll = pipeline.roll_damage(attacker, attacker.get_effective_attack())
	_assert_eq(rolled.is_crit, false, "0% crit rate should not crit")
	_assert_eq(rolled.amount, 4, "non-crit damage unchanged")


static func _test_roll_damage_no_source() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var rolled: DamageRoll = pipeline.roll_damage(null, 5)
	_assert_eq(rolled.is_crit, false, "null source should not crit")
	_assert_eq(rolled.amount, 5, "null source damage unchanged")


static func _test_apply_rolled_damage_emits_crit_flag() -> void:
	var grid := _grid()
	var bus := _bus()
	var pipeline := _pipeline(bus, grid)
	var attacker := _unit(2, 100)
	var defender := UnitInstance.new("defender", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	defender.stats = UnitStats.new()
	defender.stats.max_hp = 10
	defender.current_hp = 10
	grid.place(defender, Vector2i(1, 0))

	var captured: Array = [null]
	bus.combat_event.connect(func(event_type: StringName, payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			captured[0] = payload
	)

	pipeline.apply_rolled_damage(attacker, defender, attacker.get_effective_attack())
	var payload: CombatEventPayload = captured[0]
	_assert_true(payload != null, "damage event emitted")
	if payload != null:
		_assert_true(payload.is_crit, "payload marks crit")
		_assert_eq(payload.amount, 3, "crit damage 150% of 2 rounded")
