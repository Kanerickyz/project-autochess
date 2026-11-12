class_name DamagePipelineCritTest
extends RefCounted
## 普攻暴击：默认 5% 概率；测例用 0/1 固定掷骰。

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_roll_damage_no_crit_when_chance_zero()
	_test_roll_damage_always_crit_when_chance_one()
	_test_roll_damage_no_source()
	_test_apply_rolled_damage_crit_doubles()
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


static func _unit(attack: int, crit_chance: float = 0.0) -> UnitInstance:
	var unit := UnitInstance.new("test", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.attack = attack
	unit.stats.crit_chance = crit_chance
	unit.stats.crit_multiplier = 2.0
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


static func _test_roll_damage_no_crit_when_chance_zero() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var attacker := _unit(4, 0.0)
	var rolled: DamageRoll = pipeline.roll_damage(attacker, attacker.get_effective_attack())
	_assert_eq(rolled.amount, 4, "chance 0 stays at base 4")
	_assert_true(not rolled.is_crit, "chance 0 is not crit")


static func _test_roll_damage_always_crit_when_chance_one() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var attacker := _unit(4, 1.0)
	var rolled: DamageRoll = pipeline.roll_damage(attacker, attacker.get_effective_attack())
	_assert_eq(rolled.amount, 8, "chance 1 doubles to 8")
	_assert_true(rolled.is_crit, "chance 1 is crit")


static func _test_roll_damage_no_source() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var rolled: DamageRoll = pipeline.roll_damage(null, 5)
	_assert_eq(rolled.amount, 5, "null source damage unchanged")
	_assert_true(not rolled.is_crit, "null source not crit")


static func _test_apply_rolled_damage_crit_doubles() -> void:
	var grid := _grid()
	var bus := _bus()
	var pipeline := _pipeline(bus, grid)
	var attacker := _unit(2, 1.0)
	var defender := UnitInstance.new("defender", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	defender.stats = UnitStats.new()
	defender.stats.max_hp = 20
	defender.current_hp = 20
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
		_assert_eq(payload.amount, 4, "dealt crit 4")
		_assert_true(payload.is_crit, "payload marked crit")
		_assert_eq(defender.current_hp, 16, "defender hp after crit")
