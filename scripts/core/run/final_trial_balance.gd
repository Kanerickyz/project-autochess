class_name FinalTrialBalance
extends RefCounted

## 试炼波次攻血：6→7→10→15→22 后按斐波那契递增（wave_index 从 0 起）。
const SEED_STATS: Array[int] = [6, 7, 10, 15, 22]
const ENEMY_COUNT := 10
const UNIT_ID := "enemy_final_trial_dev"
## 与地图 T2_FROM_FLOOR=4 对称：高层压力从该显示层起缓释接满（见 EnemyTierIntro._t2_layer）。
const HIGH_PRESSURE_FROM_LAYER := 10


static func stat_for_wave(wave_index: int) -> int:
	var idx := maxi(0, wave_index)
	if idx < SEED_STATS.size():
		return SEED_STATS[idx]
	var stat := SEED_STATS[SEED_STATS.size() - 1]
	var fib_prev2: int = SEED_STATS[SEED_STATS.size() - 2]
	var fib_prev1: int = SEED_STATS[SEED_STATS.size() - 1]
	for w in range(SEED_STATS.size(), idx + 1):
		var layer := w + 1
		var ideal := fib_prev2 + fib_prev1
		fib_prev2 = fib_prev1
		fib_prev1 = ideal
		if layer < HIGH_PRESSURE_FROM_LAYER:
			stat = ideal
			continue
		var ratio := _high_pressure_step_ratio(layer)
		var gap := ideal - stat
		if gap <= 0:
			stat = ideal
		else:
			stat += maxi(1, int(round(float(gap) * ratio)))
			stat = mini(stat, ideal)
	return stat


## 未缓释的纯斐波那契目标（测试 / 对比用）。
static func raw_fib_stat_for_wave(wave_index: int) -> int:
	var idx := maxi(0, wave_index)
	if idx < SEED_STATS.size():
		return SEED_STATS[idx]
	var prev2: int = SEED_STATS[SEED_STATS.size() - 2]
	var prev1: int = SEED_STATS[SEED_STATS.size() - 1]
	for _i in range(SEED_STATS.size(), idx + 1):
		var next := prev2 + prev1
		prev2 = prev1
		prev1 = next
	return prev1


## 对齐 EnemyTierIntro._t2_layer：首层少量、次层略增、再层半幅、之后渐近满额。
static func _high_pressure_step_ratio(layer: int) -> float:
	var f2 := HIGH_PRESSURE_FROM_LAYER
	if layer < f2:
		return 1.0
	if layer == f2:
		return 0.38
	if layer == f2 + 1:
		return 0.55
	if layer == f2 + 2:
		return 0.72
	return 0.88


static func display_layer_for_wave(wave_index: int) -> int:
	return maxi(1, wave_index + 1)
