extends SceneTree

var _failures := 0


func _initialize() -> void:
	_expect(EndlessLadderBalance.enemy_count_for_floor(1) == 1, "F1 count=1")
	_expect(EndlessLadderBalance.enemy_count_for_floor(2) == 2, "F2 count=2")
	_expect(EndlessLadderBalance.enemy_count_for_floor(6) == 6, "F6 count=6")
	_expect(EndlessLadderBalance.enemy_count_for_floor(7) == 6, "F7 count=6")
	_expect(EndlessLadderBalance.enemy_count_for_floor(11) == 6, "F11 count=6")
	_expect(EndlessLadderBalance.enemy_count_for_floor(0) == 1, "F0 count safe=1")
	_expect(EndlessLadderBalance.enemy_count_for_floor(-3) == 1, "negative count safe=1")
	_expect(EndlessLadderBalance.stat_for_floor(1) == 1, "F1 stat=1")
	_expect(EndlessLadderBalance.stat_for_floor(6) == 6, "F6 stat=6")
	_expect(EndlessLadderBalance.stat_for_floor(7) == 8, "F7 stat=8")
	_expect(EndlessLadderBalance.stat_for_floor(11) == 16, "F11 stat=16")
	_expect(EndlessLadderBalance.stat_for_floor(15) == 24, "F15 stat=24")
	_expect(EndlessLadderBalance.stat_for_floor(0) == 1, "F0 stat safe=1")
	_expect(EndlessLadderBalance.MAX_ENEMY_COUNT == 6, "max count=6")
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
