extends SceneTree

var _failures := 0


func _initialize() -> void:
	_expect(EndlessLadderBalance.enemy_count_for_floor(1) == 1, "F1 count=1")
	_expect(EndlessLadderBalance.enemy_count_for_floor(2) == 1, "F2 count=1")
	_expect(EndlessLadderBalance.enemy_count_for_floor(10) == 1, "F10 count=1")
	_expect(EndlessLadderBalance.enemy_count_for_floor(11) == 1, "F11 count=1")
	_expect(EndlessLadderBalance.enemy_count_for_floor(0) == 1, "F0 count safe=1")
	_expect(EndlessLadderBalance.enemy_count_for_floor(-3) == 1, "negative count safe=1")
	_expect(EndlessLadderBalance.attack_for_floor(1) == 1, "F1 atk=1")
	_expect(EndlessLadderBalance.attack_for_floor(2) == 2, "F2 atk=2")
	_expect(EndlessLadderBalance.attack_for_floor(3) == 3, "F3 atk=3")
	_expect(EndlessLadderBalance.attack_for_floor(10) == 10, "F10 atk=10")
	_expect(EndlessLadderBalance.attack_for_floor(0) == 1, "F0 atk safe=1")
	_expect(EndlessLadderBalance.hp_for_floor(1) == 10, "F1 hp=10")
	_expect(EndlessLadderBalance.hp_for_floor(2) == 15, "F2 hp=15")
	_expect(EndlessLadderBalance.hp_for_floor(3) == 20, "F3 hp=20")
	_expect(EndlessLadderBalance.hp_for_floor(10) == 55, "F10 hp=55")
	_expect(EndlessLadderBalance.hp_for_floor(0) == 10, "F0 hp safe=10")
	_expect(EndlessLadderBalance.ENEMY_COUNT == 1, "enemy count const=1")
	_expect(EndlessLadderBalance.UNIT_ID == "enemy_endless_dev", "unit id")
	if ResourceLoader.exists("res://resources/units/enemies/enemy_endless_dev.tres"):
		var ud := load("res://resources/units/enemies/enemy_endless_dev.tres") as UnitData
		_expect(ud != null and ud.id == EndlessLadderBalance.UNIT_ID, "tres id matches")
		_expect(ud != null and ud.ability == null, "blank unit has no ability")
	else:
		_failures += 1
		push_error("EndlessLadderBalanceTest: missing enemy_endless_dev.tres")
	if _failures == 0:
		print("EndlessLadderBalanceTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_failures += 1
		push_error("EndlessLadderBalanceTest: %s" % msg)
