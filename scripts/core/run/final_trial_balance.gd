class_name FinalTrialBalance
extends RefCounted

## 试炼波次攻血：6→7→10→15→22 后按斐波那契递增（wave_index 从 0 起）。
const SEED_STATS: Array[int] = [6, 7, 10, 15, 22]
const ENEMY_COUNT := 10
const UNIT_ID := "enemy_final_trial_dev"


static func stat_for_wave(wave_index: int) -> int:
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


static func display_layer_for_wave(wave_index: int) -> int:
	return maxi(1, wave_index + 1)
