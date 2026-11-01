class_name EndlessLadderBalance
extends RefCounted

## 无尽同质白板敌压：第 F 场人数 min(F,10)，攻/血均为 F（F 从 1 起）。
const MAX_ENEMY_COUNT := 10
const UNIT_ID := "enemy_endless_dev"


static func enemy_count_for_floor(floor_index: int) -> int:
	var f := maxi(1, floor_index)
	return mini(f, MAX_ENEMY_COUNT)


static func stat_for_floor(floor_index: int) -> int:
	return maxi(1, floor_index)
