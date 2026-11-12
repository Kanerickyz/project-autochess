class_name DamagePipelineCritTest
extends RefCounted
## 普攻暴击保底：标称 5% → 约每 20 次必出；倍率默认 1.5。

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_pity_interval_and_chance_curve()
	_test_roll_damage_no_crit_when_chance_zero()
	_test_roll_damage_always_crit_when_chance_one()
	_test_roll_damage_no_source()
	_test_miss_advances_streak()
	_test_pity_guarantees_on_twentieth()
	_test_apply_rolled_damage_crit_mult()
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


static func _pipeline(bus: CombatEventBus, grid: BoardGrid, seed: int = 12345) -> DamagePipeline:
	var pipeline := DamagePipeline.new(bus, grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	pipeline.set_rng(rng)
	return pipeline


static func _unit(attack: int, crit_chance: float = 0.0, crit_mult: float = 1.5) -> UnitInstance:
	var unit := UnitInstance.new("test", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.attack = attack
	unit.stats.crit_chance = crit_chance
	unit.stats.crit_multiplier = crit_mult
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


static func _assert_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures += 1
		push_error(
			"DamagePipelineCritTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _test_pity_interval_and_chance_curve() -> void:
	_assert_eq(CritRoll.pity_interval(0.05), 20, "5% → interval 20")
	_assert_approx(CritRoll.current_chance(0.05, 0), 0.05, "first swing 5%")
	_assert_approx(CritRoll.current_chance(0.05, 18), 0.5, "19th swing after 18 misses → 50%")
	_assert_approx(CritRoll.current_chance(0.05, 19), 1.0, "20th swing guaranteed")


static func _test_roll_damage_no_crit_when_chance_zero() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var attacker := _unit(4, 0.0)
	var rolled: DamageRoll = pipeline.roll_damage(attacker, attacker.get_effective_attack())
	_assert_eq(rolled.amount, 4, "chance 0 stays at base 4")
	_assert_true(not rolled.is_crit, "chance 0 is not crit")
	_assert_eq(attacker.crit_miss_streak, 0, "chance 0 does not advance streak")


static func _test_roll_damage_always_crit_when_chance_one() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var attacker := _unit(4, 1.0, 1.5)
	var rolled: DamageRoll = pipeline.roll_damage(attacker, attacker.get_effective_attack())
	_assert_eq(rolled.amount, 6, "chance 1 → 4×1.5=6")
	_assert_true(rolled.is_crit, "chance 1 is crit")
	_assert_eq(attacker.crit_miss_streak, 0, "crit resets streak")


static func _test_roll_damage_no_source() -> void:
	var pipeline := _pipeline(_bus(), _grid())
	var rolled: DamageRoll = pipeline.roll_damage(null, 5)
	_assert_eq(rolled.amount, 5, "null source damage unchanged")
	_assert_true(not rolled.is_crit, "null source not crit")


## 未中时推进保底计数。
static func _test_miss_advances_streak() -> void:
	var attacker := _unit(4, 0.05, 1.5)
	## seed 选得让首次 randf ≥ 0.05。
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var saw_miss := false
	for _i in 40:
		attacker.crit_miss_streak = 0
		var rolled := CritRoll.roll_attack(attacker, 4, rng)
		if not rolled.is_crit:
			_assert_eq(attacker.crit_miss_streak, 1, "miss advances streak to 1")
			saw_miss = true
			break
	_assert_true(saw_miss, "expected at least one miss in samples")


## 连续未中至第 19 次后，第 20 次必暴击。
static func _test_pity_guarantees_on_twentieth() -> void:
	var attacker := _unit(4, 0.05, 1.5)
	attacker.crit_miss_streak = 19
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var forced := CritRoll.roll_attack(attacker, 4, rng)
	_assert_true(forced.is_crit, "20th swing guaranteed")
	_assert_eq(forced.amount, 6, "guaranteed crit uses 1.5×")
	_assert_eq(attacker.crit_miss_streak, 0, "streak resets after crit")


static func _test_apply_rolled_damage_crit_mult() -> void:
	var grid := _grid()
	var bus := _bus()
	var pipeline := _pipeline(bus, grid)
	var attacker := _unit(4, 1.0, 1.5)
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
		_assert_eq(payload.amount, 6, "dealt crit 6")
		_assert_true(payload.is_crit, "payload marked crit")
		_assert_eq(defender.current_hp, 14, "defender hp after crit")
