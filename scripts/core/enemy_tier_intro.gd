class_name EnemyTierIntro
extends RefCounted

## 敌方 T2/T3 缓释只数帽（ENEMY_SPAWN_BUDGET §6.2）。层表 + 有队时 ∩ 玩家同档人数+1。


static func tier3_first_floor(floor_count: int, forward_only: bool = false) -> int:
	if forward_only:
		return TierUnlock.FORWARD_T3_FROM_FLOOR
	var total := maxi(1, floor_count)
	return total - (TierUnlock.LATE_BAND_FLOORS - 1)


static func count_roster_tier(team_entries: Array, tier: int) -> int:
	var want := maxi(1, tier)
	var n := 0
	for entry in team_entries:
		if entry == null:
			continue
		var unit: UnitData = null
		if entry is DeckEntry:
			unit = (entry as DeckEntry).unit
		elif entry is UnitData:
			unit = entry as UnitData
		if unit != null and maxi(1, unit.tier) == want:
			n += 1
	return n


static func count_units_tier(units: Array, tier: int) -> int:
	var want := maxi(1, tier)
	var n := 0
	for u in units:
		if u is UnitData and maxi(1, (u as UnitData).tier) == want:
			n += 1
	return n


static func compute_effective_caps(
	floor_index: int,
	enemy_n: int,
	node_type: MapNodeType.Type,
	team_entries: Array,
	floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT,
	forward_only: bool = false,
) -> Vector2i:
	## x = t2_cap, y = t3_cap
	var n := maxi(0, enemy_n)
	var f := maxi(1, floor_index)
	if SpawnBudgetConfig.is_first_floor(floor_index):
		return Vector2i(0, 0)

	var f2 := TierUnlock.T2_FROM_FLOOR
	var f3 := tier3_first_floor(floor_count, forward_only)
	var t2_layer := _t2_layer(f, n, f2, f3)
	var t3_layer := _t3_layer(f, n, f3)

	var elite := node_type == MapNodeType.Type.ELITE
	if elite:
		t2_layer = mini(t2_layer + 1, n)
		t3_layer = mini(t3_layer + 1, n)

	var has_roster := _roster_has_member(team_entries)
	var p2 := count_roster_tier(team_entries, 2)
	var p3 := count_roster_tier(team_entries, 3)
	var t2_cap := t2_layer
	var t3_cap := t3_layer
	if has_roster:
		t2_cap = mini(t2_layer, p2 + 1)
		t3_cap = mini(t3_layer, p3 + 1)
	return Vector2i(t2_cap, t3_cap)


static func _roster_has_member(team_entries: Array) -> bool:
	for entry in team_entries:
		if entry == null:
			continue
		if entry is DeckEntry and (entry as DeckEntry).unit != null:
			return true
		if entry is UnitData:
			return true
	return false


static func _t2_layer(f: int, n: int, f2: int, f3: int) -> int:
	if f < f2:
		return 0
	if f >= f3:
		return n
	if f == f2:
		return mini(1, n)
	if f == f2 + 1:
		return mini(2, n)
	if f == f2 + 2:
		if n < 2:
			return n
		return mini(int(ceili(float(n) / 2.0)), n - 1)
	return mini(int(ceili(0.75 * float(n))), n)


static func _t3_layer(f: int, n: int, f3: int) -> int:
	if f < f3:
		return 0
	if f == f3:
		return mini(1, n)
	if f == f3 + 1:
		return mini(2, n)
	if f == f3 + 2:
		if n < 2:
			return n
		return mini(int(ceili(float(n) / 2.0)), n - 1)
	return mini(int(ceili(0.75 * float(n))), n)


## 再选一只 u 加入 comp 时是否仍满足只数帽（base 为固定位已占用的同档数）。
static func can_add_unit(
	unit: UnitData,
	composition: Array,
	t2_cap: int,
	t3_cap: int,
	t2_base: int = 0,
	t3_base: int = 0,
) -> bool:
	if unit == null:
		return false
	var t2_used := t2_base + count_units_tier(composition, 2)
	var t3_used := t3_base + count_units_tier(composition, 3)
	var tier := maxi(1, unit.tier)
	if tier == 2 and t2_used >= t2_cap:
		return false
	if tier == 3 and t3_used >= t3_cap:
		return false
	return true


static func filter_pool_for_add(
	pool: Array[UnitData],
	composition: Array,
	t2_cap: int,
	t3_cap: int,
	t2_base: int = 0,
	t3_base: int = 0,
) -> Array[UnitData]:
	var out: Array[UnitData] = []
	for u in pool:
		if can_add_unit(u, composition, t2_cap, t3_cap, t2_base, t3_base):
			out.append(u)
	return out


static func composition_within_caps(
	units: Array,
	t2_cap: int,
	t3_cap: int,
) -> bool:
	return (
		count_units_tier(units, 2) <= t2_cap
		and count_units_tier(units, 3) <= t3_cap
	)


## 填充段 comp 与固定位 base 合计是否未超帽。
static func fill_respects_caps(
	fill: Array,
	t2_cap: int,
	t3_cap: int,
	t2_base: int = 0,
	t3_base: int = 0,
) -> bool:
	return (
		count_units_tier(fill, 2) + t2_base <= t2_cap
		and count_units_tier(fill, 3) + t3_base <= t3_cap
	)
