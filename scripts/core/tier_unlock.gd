class_name TierUnlock
extends RefCounted

## 品阶硬解锁：以地图层号（1-based）为主尺，并参照本幕 `floor_count`。
## - T2：自第 4 层起
## - T3：自倒数 6 层起（含）；同时招募池最低品阶升为 T2（T1 不再出现）
## 入参亦可为商店访问序 / 遭遇序代理（与层号同刻度使用本表）。

const T2_FROM_FLOOR := 4
## 倒数 N 层开放 T3，并踢出 T1（招募）。
const LATE_BAND_FLOORS := 6
const DEFAULT_FLOOR_COUNT := 15


static func is_late_tier_band(map_floor: int, floor_count: int = DEFAULT_FLOOR_COUNT) -> bool:
	var floor := maxi(1, map_floor)
	var total := maxi(1, floor_count)
	## 例：floor_count=15 → 第 10–15 层。
	return floor >= total - (LATE_BAND_FLOORS - 1)


static func get_max_unlocked_tier(
	map_floor: int,
	floor_count: int = DEFAULT_FLOOR_COUNT,
) -> int:
	var floor := maxi(1, map_floor)
	if is_late_tier_band(floor, floor_count):
		return 3
	if floor >= T2_FROM_FLOOR:
		return 2
	return 1


## 招募可抽最低品阶：倒数 6 层起为 2（不再出 T1）；此前为 1。
static func get_min_unlocked_tier(
	map_floor: int,
	floor_count: int = DEFAULT_FLOOR_COUNT,
) -> int:
	if is_late_tier_band(map_floor, floor_count):
		return 2
	return 1


static func filter_by_tier(
	items: Array,
	get_tier: Callable,
	max_tier: int,
	min_tier: int = 1,
) -> Array:
	var filtered: Array = []
	var lo := maxi(1, min_tier)
	var hi := maxi(lo, max_tier)
	for item in items:
		if item == null:
			continue
		var tier: int = int(get_tier.call(item))
		if tier >= lo and tier <= hi:
			filtered.append(item)
	return filtered
