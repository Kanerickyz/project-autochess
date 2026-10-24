class_name EffectResolverGunnerTest
extends RefCounted
## 暴击已移除：直伤按基数结算。

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_rolled_damage_equals_base()
	if _failures == 0:
		print("EffectResolverGunnerTest: all tests passed")
	else:
		push_error("EffectResolverGunnerTest: %d failure(s)" % _failures)
	return _failures == 0


static func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures += 1
		push_error(
			"EffectResolverGunnerTest FAIL: %s (expected %s, got %s)"
			% [message, str(expected), str(actual)]
		)


static func _test_rolled_damage_equals_base() -> void:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	pipeline.set_rng(rng)
	var attacker := UnitInstance.new("gunner", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	attacker.stats = UnitStats.new()
	attacker.stats.attack = 3
	attacker.current_hp = 4
	grid.place(attacker, Vector2i(0, 0))
	var defender := UnitInstance.new("enemy", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	defender.stats = UnitStats.new()
	defender.stats.max_hp = 10
	defender.current_hp = 10
	grid.place(defender, Vector2i(1, 0))
	pipeline.apply_rolled_damage(attacker, defender, attacker.get_effective_attack())
	_assert_eq(defender.current_hp, 7, "dealt base attack 3")
