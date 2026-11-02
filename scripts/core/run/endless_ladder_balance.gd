class_name EndlessLadderBalance
extends RefCounted

## 无尽同质白板敌压：第 F 场恒 1 敌；攻＝F，血＝5F＋5（F 从 1 起）。
## 例：F1→1攻10血；F2→2攻15血；F3→3攻20血。
const ENEMY_COUNT := 1
const UNIT_ID := "enemy_endless_dev"


static func enemy_count_for_floor(_floor_index: int) -> int:
	return ENEMY_COUNT


static func attack_for_floor(floor_index: int) -> int:
	return maxi(1, floor_index)


static func hp_for_floor(floor_index: int) -> int:
	var f := maxi(1, floor_index)
	return 5 * f + 5
