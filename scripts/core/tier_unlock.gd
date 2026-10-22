class_name TierUnlock
extends RefCounted

## 品阶硬解锁：以地图层号（1-based）为主尺。
## 【用户新共识】T2 自第 4 层起可刷到（敌我 / 商店波次代理同表）。
## 入参亦可为商店访问序 / 遭遇序代理（与层号同刻度使用本表）。


static func get_max_unlocked_tier(map_floor: int) -> int:
	var floor := maxi(1, map_floor)
	if floor < 4:
		return 1
	if floor < 8:
		return 2
	if floor < 12:
		return 3
	if floor < 16:
		return 4
	if floor < 20:
		return 5
	return 6


static func filter_by_tier(items: Array, get_tier: Callable, max_tier: int) -> Array:
	var filtered: Array = []
	for item in items:
		if item == null:
			continue
		var tier: int = int(get_tier.call(item))
		if tier <= max_tier:
			filtered.append(item)
	return filtered
