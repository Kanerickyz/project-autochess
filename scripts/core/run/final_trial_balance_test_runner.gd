extends SceneTree

var _failures := 0


func _initialize() -> void:
	_expect(FinalTrialBalance.stat_for_wave(0) == 6, "wave 0 = 6")
	_expect(FinalTrialBalance.stat_for_wave(4) == 22, "wave 4 = 22")
	_expect(FinalTrialBalance.stat_for_wave(5) == 37, "wave 5 = 37 (15+22)")
	_expect(FinalTrialBalance.stat_for_wave(6) == 59, "wave 6 = 59")
	var layer10 := FinalTrialBalance.stat_for_wave(9)
	var raw10 := FinalTrialBalance.raw_fib_stat_for_wave(9)
	_expect(layer10 == 191, "layer 10 softened stat = 191, got %d" % layer10)
	_expect(layer10 < raw10, "layer 10 softer than raw fib %d" % raw10)
	_expect(FinalTrialBalance.ENEMY_COUNT == 10, "10 enemies")
	if _failures == 0:
		print("FinalTrialBalanceTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_failures += 1
		push_error("FinalTrialBalanceTest: %s" % msg)
