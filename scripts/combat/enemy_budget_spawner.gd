class_name EnemyBudgetSpawner
extends RefCounted
## 队伍强度抽阵：普通/精英按整局队伍 S 定 E＝κ×S（层护栏夹紧）；
## 拒采样贴带宽 → 放宽一档 → 最近解爬山 → 贪心保底。禁止静默纯随机。
## Boss 不吃真队目标：只出固定位，不预算填杂兵。

const MAX_SEATS_HARD := 10


## 返回书写顺序（前排→后排，同行中心向外）的字典数组：
## { "unit_data": UnitData, "seat_index": int, "power_u": float }
## team_entries：进点瞬间 DeckState 成员快照（DeckEntry）；Boss 忽略强度。
## 普通/精英敌方 2★ 只数＝快照里展示为 2★ 的成员数（3★ 不计）。
## floor_count：地图普通层数；品阶解锁用，不决定敌方星级。
static func roll(
	wave: WaveData,
	config: SpawnBudgetConfig,
	fallback_pool: Array[UnitData],
	tier_index: int,
	floor_index: int,
	node_type: MapNodeType.Type,
	seat_rows: int,
	seat_cols: int,
	rng: RandomNumberGenerator,
	team_entries: Array = [],
	floor_count: int = 15,
) -> Array:
	if wave == null:
		return []
	if rng == null:
		push_error("EnemyBudgetSpawner.roll: rng is null")
		return []
	var cfg := config if config != null else SpawnBudgetConfig.make_code_defaults()
	var seat_count := maxi(1, seat_rows) * maxi(1, seat_cols)
	seat_count = mini(seat_count, MAX_SEATS_HARD)
	var cols := maxi(1, seat_cols)

	var pool := _resolve_pool(
		cfg, fallback_pool, tier_index, floor_index, team_entries, floor_count
	)
	if pool.is_empty():
		push_warning(
			"EnemyBudgetSpawner: filtered enemy pool empty (tier_index=%d floor=%d)"
			% [tier_index, floor_index]
		)
		return _seat_units(_collect_fixed_units(wave), cols, seat_count, cfg)

	var team_s := 0.0
	if node_type != MapNodeType.Type.BOSS:
		team_s = UnitPowerScore.team_power_from_entries(
			team_entries,
			cfg.skill_alpha_by_unit_id,
			cfg.skill_alpha_no_ability,
			cfg.skill_alpha_default,
		)
	var target_e := cfg.get_target_pressure(floor_index, node_type, team_s)
	var fixed_units := _collect_fixed_units(wave)
	## 人数不超过敌座：固定单位优先裁切。
	if fixed_units.size() > seat_count:
		push_warning(
			"EnemyBudgetSpawner: %d fixed enemies > %d seats; truncating"
			% [fixed_units.size(), seat_count]
		)
		var trimmed: Array[UnitData] = []
		for i in seat_count:
			trimmed.append(fixed_units[i])
		fixed_units = trimmed

	var fixed_u := UnitPowerScore.team_power(
		fixed_units,
		cfg.skill_alpha_by_unit_id,
		cfg.skill_alpha_no_ability,
		cfg.skill_alpha_default,
	)
	var remain_seats := seat_count - fixed_units.size()
	var remain_e := maxf(0.0, target_e - fixed_u)

	## Boss 节点：只出固定首领（及关卡写死的跟班若有），不预算填杂兵、不跟人数规则。
	var fill: Array[UnitData] = []
	var first_floor := SpawnBudgetConfig.is_first_floor(floor_index)
	var max_ranged := -1
	if node_type != MapNodeType.Type.BOSS:
		var player_n := _player_roster_count(team_entries)
		var target_total := cfg.roll_enemy_count(node_type, player_n, rng, floor_index)
		## 座位硬上限仍有效。
		target_total = clampi(target_total, 0, seat_count)
		## 第一关精英：人数仍不得超过 N。普通关改按层掷点，不再封顶到队伍人数。
		if first_floor and node_type == MapNodeType.Type.ELITE:
			target_total = mini(target_total, player_n)
			if fixed_units.size() > player_n:
				var trim_fixed: Array[UnitData] = []
				for i in player_n:
					trim_fixed.append(fixed_units[i])
				fixed_units = trim_fixed
				remain_seats = seat_count - fixed_units.size()
				fixed_u = UnitPowerScore.team_power(
					fixed_units,
					cfg.skill_alpha_by_unit_id,
					cfg.skill_alpha_no_ability,
					cfg.skill_alpha_default,
				)
				remain_e = maxf(0.0, target_e - fixed_u)
		## 远程上限：杜绝全远程阵；第一关最多 1，其后 ≤⌈0.4n⌉ 且至少留 1 近战。
		max_ranged = resolve_max_ranged(target_total, first_floor)
		var fill_n := clampi(target_total - fixed_units.size(), 0, remain_seats)
		var tier_caps := EnemyTierIntro.compute_effective_caps(
			floor_index, target_total, node_type, team_entries, floor_count
		)
		var t2_base := EnemyTierIntro.count_units_tier(fixed_units, 2)
		var t3_base := EnemyTierIntro.count_units_tier(fixed_units, 3)
		if remain_seats > 0 and fill_n > 0 and not pool.is_empty():
			## 人数硬约束优先：先定 fill_n，再在预算软约束下抽人。
			fill = _sample_fill(
				pool,
				remain_e if remain_e > 0.0 else target_e,
				fill_n,
				cfg,
				node_type,
				rng,
				max_ranged,
				tier_caps.x,
				tier_caps.y,
				t2_base,
				t3_base,
			)
		elif remain_seats > 0 and fill_n > 0 and remain_e <= 0.0 and fixed_units.is_empty():
			## 无固定且预算异常：仍按人数硬约束贪心填满。
			fill = _greedy_fill(
				pool, target_e, fill_n, cfg, true, tier_caps.x, tier_caps.y, t2_base, t3_base
			)
			fill = _enforce_max_ranged(fill, pool, max_ranged, target_e, cfg)

	var all_units: Array[UnitData] = []
	all_units.append_array(fixed_units)
	all_units.append_array(fill)
	if all_units.size() > seat_count:
		var capped: Array[UnitData] = []
		for i in seat_count:
			capped.append(all_units[i])
		all_units = capped
	if node_type != MapNodeType.Type.BOSS:
		## 第一关精英最终名单硬封顶 ≤ 队伍人数；普通关仅座位硬顶。
		if first_floor and node_type == MapNodeType.Type.ELITE:
			var player_cap := _player_roster_count(team_entries)
			if all_units.size() > player_cap:
				var capped_n: Array[UnitData] = []
				for i in player_cap:
					capped_n.append(all_units[i])
				all_units = capped_n
		if max_ranged >= 0:
			all_units = _enforce_max_ranged(all_units, pool, max_ranged, target_e, cfg)
		if node_type != MapNodeType.Type.BOSS:
			var caps_post := EnemyTierIntro.compute_effective_caps(
				floor_index, all_units.size(), node_type, team_entries, floor_count
			)
			all_units = _enforce_tier_caps(
				all_units,
				fixed_units.size(),
				pool,
				caps_post.x,
				caps_post.y,
				target_e,
				cfg,
			)
	if all_units.is_empty() and not pool.is_empty() and node_type != MapNodeType.Type.BOSS:
		## 极端保底：至少 1 个最接近 E 的单位。
		all_units.append(_pick_closest_unit(pool, target_e, cfg))

	var seated := _seat_units(all_units, cols, seat_count, cfg)
	_assign_enemy_star2_from_player(seated, node_type, rng, cfg, team_entries)
	return seated


## 普通/精英：敌方 2★ 只数＝玩家队内展示为 2★ 的人数（不超过可升星座位）。
## 3★ 不计。Boss 节点不升星。只标 2★ 模板，不做敌方队伍内三合一。
static func _assign_enemy_star2_from_player(
	seated: Array,
	node_type: MapNodeType.Type,
	rng: RandomNumberGenerator,
	cfg: SpawnBudgetConfig,
	team_entries: Array,
) -> void:
	if node_type == MapNodeType.Type.BOSS or seated.is_empty():
		return
	var want := _count_player_star2(team_entries)
	if want <= 0:
		return
	var eligible: Array = []
	for item in seated:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var ud: UnitData = item.get("unit_data") as UnitData
		if ud != null and ud.is_boss_leader:
			item["level"] = 1
			continue
		eligible.append(item)
	if eligible.is_empty():
		return
	want = mini(want, eligible.size())
	if rng != null:
		for i in want:
			var j := rng.randi_range(i, eligible.size() - 1)
			var tmp: Variant = eligible[i]
			eligible[i] = eligible[j]
			eligible[j] = tmp
	for k in want:
		var picked: Dictionary = eligible[k]
		picked["level"] = 2
		var picked_ud: UnitData = picked.get("unit_data") as UnitData
		if cfg != null and picked_ud != null:
			picked["power_u"] = _unit_u(picked_ud, cfg) * 3.0


static func _count_player_star2(team_entries: Array) -> int:
	var n := 0
	for entry in team_entries:
		if entry is DeckEntry and (entry as DeckEntry).get_star_display_level() == 2:
			n += 1
	return n


static func _player_roster_count(team_entries: Array) -> int:
	var n := 0
	for entry in team_entries:
		if entry != null:
			n += 1
	return maxi(1, n)


## 远程人数硬顶：第一关 1；其后 ⌈0.4n⌉（至少 1）；n≥2 时至少留 1 近战。
static func resolve_max_ranged(enemy_count: int, first_floor: bool) -> int:
	var n := maxi(0, enemy_count)
	if n <= 0:
		return 0
	if first_floor:
		return mini(1, n)
	var cap := maxi(1, int(ceili(float(n) * 0.4)))
	if n >= 2:
		cap = mini(cap, n - 1)
	return mini(cap, n)


static func _resolve_pool(
	cfg: SpawnBudgetConfig,
	fallback_pool: Array[UnitData],
	tier_index: int,
	floor_index: int,
	team_entries: Array = [],
	floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT,
) -> Array[UnitData]:
	var source: Array[UnitData] = []
	if cfg != null and not cfg.enemy_pool.is_empty():
		source = cfg.enemy_pool
	else:
		source = fallback_pool
		push_warning("EnemyBudgetSpawner: enemy budget pool empty; falling back to LevelData.enemy_pool")

	## 品阶硬过滤：地图层解锁 ∩ 玩家现有队伍最高品阶（有队伍时）。
	## 层号优先；层未知时回退遭遇序代理（tier_index+1）。
	var progress_key := floor_index if floor_index > 0 else tier_index + 1
	var progress_tier := TierUnlock.get_max_unlocked_tier(progress_key, floor_count)
	var max_tier := progress_tier
	var player_max := _player_roster_max_tier(team_entries)
	if player_max > 0:
		max_tier = mini(progress_tier, player_max)
	var filtered: Array = TierUnlock.filter_by_tier(source, _get_unit_tier, max_tier)
	var pool: Array[UnitData] = []
	for item in filtered:
		if item is UnitData and (item as UnitData).stats != null:
			pool.append(item as UnitData)
	return pool


static func _player_roster_max_tier(team_entries: Array) -> int:
	var max_tier := 0
	for entry in team_entries:
		if entry == null:
			continue
		var unit: UnitData = null
		if entry is DeckEntry:
			unit = (entry as DeckEntry).unit
		elif entry is UnitData:
			unit = entry as UnitData
		if unit == null:
			continue
		max_tier = maxi(max_tier, maxi(1, unit.tier))
	return max_tier


static func _get_unit_tier(item: Variant) -> int:
	if item is UnitData:
		return (item as UnitData).tier
	return 99


static func _collect_fixed_units(wave: WaveData) -> Array[UnitData]:
	var units: Array[UnitData] = []
	if wave == null:
		return units
	for entry in wave.fixed_entries:
		if entry == null or entry.unit == null:
			continue
		for _i in maxi(1, entry.count):
			units.append(entry.unit)
	return units


## exact_fill_n：人数硬约束下的填充只数（不含固定位）。
## max_ranged：≥0 时限制远程只数（第一关＝1）；＜0 不限。
static func _sample_fill(
	pool: Array[UnitData],
	target_e: float,
	exact_fill_n: int,
	cfg: SpawnBudgetConfig,
	node_type: MapNodeType.Type,
	rng: RandomNumberGenerator,
	max_ranged: int = -1,
	t2_cap: int = 9999,
	t3_cap: int = 9999,
	t2_base: int = 0,
	t3_base: int = 0,
) -> Array[UnitData]:
	var n := maxi(0, exact_fill_n)
	if n <= 0 or pool.is_empty():
		return []
	## 人数硬锁：n_min＝n_max＝center。
	var n_min := n
	var n_max := n
	var center := n
	var base_band := cfg.get_band(node_type)
	## 第一关限远程时避开「后排倒戈」标签，优先前排/散兵。
	var formation := cfg.pick_formation_tag(rng)
	if max_ranged >= 0 and max_ranged < n and formation == SpawnBudgetConfig.FormationTag.BACKLINE:
		formation = SpawnBudgetConfig.FormationTag.FRONTLINE

	## 第一档：带阵型标签
	var best := _rejection_search(
		pool,
		target_e,
		n_min,
		n_max,
		center,
		base_band,
		formation,
		true,
		cfg,
		rng,
		max_ranged,
		t2_cap,
		t3_cap,
		t2_base,
		t3_base,
	)
	if _within_band(best, target_e, base_band, cfg) and best.size() == n:
		return _enforce_max_ranged(best, pool, max_ranged, target_e, cfg)

	## 第二档：忽略标签，同带宽
	best = _better_of(
		best,
		_rejection_search(
			pool,
			target_e,
			n_min,
			n_max,
			center,
			base_band,
			formation,
			false,
			cfg,
			rng,
			max_ranged,
			t2_cap,
			t3_cap,
			t2_base,
			t3_base,
		),
		target_e,
		cfg,
	)
	if _within_band(best, target_e, base_band, cfg) and best.size() == n:
		return _enforce_max_ranged(best, pool, max_ranged, target_e, cfg)

	## 放宽一档（禁止再静默纯随机）
	var wide_band := base_band + maxf(0.0, cfg.band_widen_step)
	best = _better_of(
		best,
		_rejection_search(
			pool,
			target_e,
			n_min,
			n_max,
			center,
			wide_band,
			formation,
			false,
			cfg,
			rng,
			max_ranged,
			t2_cap,
			t3_cap,
			t2_base,
			t3_base,
		),
		target_e,
		cfg,
	)
	if _within_band(best, target_e, wide_band, cfg) and best.size() == n:
		return _enforce_max_ranged(best, pool, max_ranged, target_e, cfg)

	## 最近解 + 仅替换爬山（不改人数）
	if best.is_empty() or best.size() != n:
		best = _random_composition(
			pool, center, rng, max_ranged, cfg, t2_cap, t3_cap, t2_base, t3_base
		)
	best = _hill_climb(
		best, pool, target_e, cfg, rng, true, max_ranged, t2_cap, t3_cap, t2_base, t3_base
	)
	if _within_band(best, target_e, wide_band, cfg) and best.size() == n:
		return _enforce_max_ranged(best, pool, max_ranged, target_e, cfg)

	## 保底：按 U 贪心填满人数
	return _enforce_max_ranged(
		_greedy_fill(pool, target_e, n, cfg, true, t2_cap, t3_cap, t2_base, t3_base),
		pool,
		max_ranged,
		target_e,
		cfg,
	)


static func _rejection_search(
	pool: Array[UnitData],
	target_e: float,
	n_min: int,
	n_max: int,
	center: int,
	band: float,
	formation: SpawnBudgetConfig.FormationTag,
	require_formation: bool,
	cfg: SpawnBudgetConfig,
	rng: RandomNumberGenerator,
	max_ranged: int = -1,
	t2_cap: int = 9999,
	t3_cap: int = 9999,
	t2_base: int = 0,
	t3_base: int = 0,
) -> Array[UnitData]:
	var best: Array[UnitData] = []
	var best_err := INF
	var best_power := -INF
	var best_unique := -1
	var attempts := maxi(1, cfg.rejection_attempts)
	var prefer_upper := cfg != null and cfg.prefer_upper_band
	for _i in attempts:
		var n := _roll_n(center, n_min, n_max, rng)
		var comp := _random_composition(
			pool, n, rng, max_ranged, cfg, t2_cap, t3_cap, t2_base, t3_base
		)
		if require_formation and not _matches_formation(comp, formation):
			continue
		if max_ranged >= 0 and _count_ranged(comp) > max_ranged:
			continue
		if not EnemyTierIntro.fill_respects_caps(comp, t2_cap, t3_cap, t2_base, t3_base):
			continue
		var power := _power(comp, cfg)
		var err := absf(power - target_e)
		var unique_n := _unique_id_count(comp)
		if _is_better_composition(power, err, unique_n, best_power, best_err, best_unique, prefer_upper):
			best_err = err
			best_power = power
			best_unique = unique_n
			best = comp
		if _power_within(power, target_e, band):
			## 上沿偏好：带宽内仅当 ΣU≥E 时提前接受；下半带继续搜上沿。
			## 有重复面孔时不提前返回，继续搜更散的合法解。
			var all_unique := unique_n >= comp.size()
			if (not prefer_upper or power >= target_e) and all_unique:
				return comp
	return best


static func _roll_n(center: int, n_min: int, n_max: int, rng: RandomNumberGenerator) -> int:
	var delta := rng.randi_range(-1, 1)
	return clampi(center + delta, n_min, n_max)


static func _random_composition(
	pool: Array[UnitData],
	n: int,
	rng: RandomNumberGenerator,
	max_ranged: int = -1,
	cfg: SpawnBudgetConfig = null,
	t2_cap: int = 9999,
	t3_cap: int = 9999,
	t2_base: int = 0,
	t3_base: int = 0,
) -> Array[UnitData]:
	var result: Array[UnitData] = []
	if pool.is_empty() or n <= 0:
		return result
	var selected_ids: Dictionary = {}
	if max_ranged < 0:
		for _i in n:
			var pick_pool := EnemyTierIntro.filter_pool_for_add(
				pool, result, t2_cap, t3_cap, t2_base, t3_base
			)
			var picked := _pick_unit_soft_dedup(pick_pool, selected_ids, cfg, rng)
			if picked == null:
				break
			result.append(picked)
			_note_selected_id(selected_ids, picked)
		return result
	var melee_pool: Array[UnitData] = []
	var ranged_pool: Array[UnitData] = []
	for u in pool:
		if UnitPowerScore.is_ranged(u):
			ranged_pool.append(u)
		else:
			melee_pool.append(u)
	var ranged_n := 0
	if not ranged_pool.is_empty() and max_ranged > 0:
		var upper := mini(max_ranged, n)
		if melee_pool.is_empty():
			ranged_n = upper
		else:
			ranged_n = rng.randi_range(0, upper)
	for _r in ranged_n:
		var ranged_pick_pool := EnemyTierIntro.filter_pool_for_add(
			ranged_pool, result, t2_cap, t3_cap, t2_base, t3_base
		)
		var ranged_pick := _pick_unit_soft_dedup(ranged_pick_pool, selected_ids, cfg, rng)
		if ranged_pick == null:
			break
		result.append(ranged_pick)
		_note_selected_id(selected_ids, ranged_pick)
	var melee_needed := n - result.size()
	for _m in melee_needed:
		if not melee_pool.is_empty():
			var melee_pick_pool := EnemyTierIntro.filter_pool_for_add(
				melee_pool, result, t2_cap, t3_cap, t2_base, t3_base
			)
			var melee_pick := _pick_unit_soft_dedup(melee_pick_pool, selected_ids, cfg, rng)
			if melee_pick == null:
				break
			result.append(melee_pick)
			_note_selected_id(selected_ids, melee_pick)
		elif not ranged_pool.is_empty() and result.size() < maxi(1, max_ranged):
			## 近战池空且尚可再塞远程时补远程；否则重复已有远程以凑人数（再由 enforce 裁）。
			var ranged_fill_pool := EnemyTierIntro.filter_pool_for_add(
				ranged_pool, result, t2_cap, t3_cap, t2_base, t3_base
			)
			var ranged_fill := _pick_unit_soft_dedup(ranged_fill_pool, selected_ids, cfg, rng)
			if ranged_fill == null:
				break
			result.append(ranged_fill)
			_note_selected_id(selected_ids, ranged_fill)
		elif not pool.is_empty():
			var any_pick_pool := EnemyTierIntro.filter_pool_for_add(
				pool, result, t2_cap, t3_cap, t2_base, t3_base
			)
			var any_pick := _pick_unit_soft_dedup(any_pick_pool, selected_ids, cfg, rng)
			if any_pick == null:
				break
			result.append(any_pick)
			_note_selected_id(selected_ids, any_pick)
	return result


## 优先从未选过的种类中等权抽取；仅当池内种类不够时才按 soft^次数 允许重复。
static func _pick_unit_soft_dedup(
	pool: Array[UnitData],
	selected_ids: Dictionary,
	cfg: SpawnBudgetConfig,
	rng: RandomNumberGenerator,
) -> UnitData:
	if pool.is_empty() or rng == null:
		return null
	var unused: Array[UnitData] = []
	for u in pool:
		if int(selected_ids.get(_unit_id(u), 0)) <= 0:
			unused.append(u)
	if not unused.is_empty():
		return unused[rng.randi_range(0, unused.size() - 1)]
	var soft := 1.0
	if cfg != null:
		soft = clampf(cfg.same_id_soft_dedup_weight, 0.0, 1.0)
	var weights: Array[float] = []
	var total := 0.0
	for u in pool:
		var count := int(selected_ids.get(_unit_id(u), 0))
		var w := 1.0
		if count > 0:
			w = pow(soft, float(count))
		weights.append(w)
		total += w
	if total <= 0.0000001:
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll := rng.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += weights[i]
		if roll <= acc:
			return pool[i]
	return pool[pool.size() - 1]


static func _note_selected_id(selected_ids: Dictionary, unit: UnitData) -> void:
	if unit == null:
		return
	var id := _unit_id(unit)
	selected_ids[id] = int(selected_ids.get(id, 0)) + 1


static func _selected_ids_excluding(units: Array[UnitData], skip_index: int) -> Dictionary:
	var ids: Dictionary = {}
	for i in units.size():
		if i == skip_index:
			continue
		_note_selected_id(ids, units[i])
	return ids


static func _unique_id_count(units: Array[UnitData]) -> int:
	var seen: Dictionary = {}
	for u in units:
		if u == null:
			continue
		seen[_unit_id(u)] = true
	return seen.size()


static func _count_ranged(units: Array[UnitData]) -> int:
	var n := 0
	for u in units:
		if UnitPowerScore.is_ranged(u):
			n += 1
	return n


## 远程替换后可能破坏品阶帽；在 fill 之后对整表再压一次（固定位前缀不替换）。
static func _enforce_tier_caps(
	units: Array[UnitData],
	fixed_prefix: int,
	pool: Array[UnitData],
	t2_cap: int,
	t3_cap: int,
	target_e: float,
	cfg: SpawnBudgetConfig,
) -> Array[UnitData]:
	if units.is_empty() or pool.is_empty():
		return units
	var result: Array[UnitData] = units.duplicate()
	for overflow_tier in [3, 2]:
		var cap := t3_cap if overflow_tier == 3 else t2_cap
		while EnemyTierIntro.count_units_tier(result, overflow_tier) > cap:
			var swapped := false
			for i in range(result.size() - 1, maxi(0, fixed_prefix) - 1, -1):
				var u: UnitData = result[i]
				if u == null or maxi(1, u.tier) != overflow_tier:
					continue
				var lower: Array[UnitData] = []
				for cand in pool:
					if cand != null and maxi(1, cand.tier) < overflow_tier:
						if EnemyTierIntro.can_add_unit(
							cand,
							_without_index(result, i),
							t2_cap,
							t3_cap,
							0,
							0,
						):
							lower.append(cand)
				if lower.is_empty():
					result.remove_at(i)
					swapped = true
					break
				result[i] = _pick_closest_unit(lower, target_e, cfg)
				swapped = true
				break
			if not swapped:
				break
	return result


## 超限远程替换为池中近战（按贴近 target_e）；无近战可换则丢掉多余远程。
static func _enforce_max_ranged(
	units: Array[UnitData],
	pool: Array[UnitData],
	max_ranged: int,
	target_e: float,
	cfg: SpawnBudgetConfig,
) -> Array[UnitData]:
	if max_ranged < 0 or units.is_empty():
		return units
	var ranged_n := _count_ranged(units)
	if ranged_n <= max_ranged:
		return units
	var melee_pool: Array[UnitData] = []
	for u in pool:
		if u != null and UnitPowerScore.is_melee(u):
			melee_pool.append(u)
	var result: Array[UnitData] = units.duplicate()
	var kept_ranged := 0
	for i in result.size():
		if not UnitPowerScore.is_ranged(result[i]):
			continue
		if kept_ranged < max_ranged:
			kept_ranged += 1
			continue
		if melee_pool.is_empty():
			result[i] = null
			continue
		var best: UnitData = null
		var best_err := INF
		var current_power := _power(_without_index(result, i), cfg)
		var selected := _selected_ids_excluding(result, i)
		## 先在未选近战里贴 E；没有未选才允许重复面孔。
		for pass_i in 2:
			var require_unused := pass_i == 0
			for cand in melee_pool:
				var cand_id := _unit_id(cand)
				if require_unused and int(selected.get(cand_id, 0)) > 0:
					continue
				var err := absf(current_power + _unit_u(cand, cfg) - target_e)
				if err < best_err - 0.0001:
					best_err = err
					best = cand
				elif is_equal_approx(err, best_err) and best != null:
					if _unit_id(cand) < _unit_id(best):
						best = cand
			if best != null:
				break
		result[i] = best
	var cleaned: Array[UnitData] = []
	for u2 in result:
		if u2 != null:
			cleaned.append(u2)
	return cleaned


static func _without_index(units: Array[UnitData], skip: int) -> Array[UnitData]:
	var out: Array[UnitData] = []
	for i in units.size():
		if i == skip:
			continue
		if units[i] != null:
			out.append(units[i])
	return out


static func _matches_formation(units: Array[UnitData], tag: SpawnBudgetConfig.FormationTag) -> bool:
	var n := units.size()
	if n <= 0:
		return false
	var melee_n := 0
	for u in units:
		if UnitPowerScore.is_melee(u):
			melee_n += 1
	var ranged_n := n - melee_n
	match tag:
		SpawnBudgetConfig.FormationTag.FRONTLINE:
			if n == 1:
				return melee_n == 1
			return float(melee_n) / float(n) >= 0.6
		SpawnBudgetConfig.FormationTag.BACKLINE:
			## 后排偏好远程，但 n≥2 时禁止全远程（至少 1 近战前排）。
			if n == 1:
				return ranged_n == 1
			return melee_n >= 1 and float(ranged_n) / float(n) >= 0.4
		SpawnBudgetConfig.FormationTag.SKIRMISH:
			if n == 1:
				return true
			return melee_n >= 1 and ranged_n >= 1
		_:
			return true


static func _power(units: Array[UnitData], cfg: SpawnBudgetConfig) -> float:
	return UnitPowerScore.team_power(
		units,
		cfg.skill_alpha_by_unit_id,
		cfg.skill_alpha_no_ability,
		cfg.skill_alpha_default,
	)


static func _unit_u(unit: UnitData, cfg: SpawnBudgetConfig) -> float:
	return UnitPowerScore.compute_u(
		unit,
		cfg.skill_alpha_by_unit_id,
		cfg.skill_alpha_no_ability,
		cfg.skill_alpha_default,
	)


static func _power_within(power: float, target_e: float, band: float) -> bool:
	var lo := target_e * (1.0 - band)
	var hi := target_e * (1.0 + band)
	return power >= lo and power <= hi


static func _within_band(
	units: Array[UnitData],
	target_e: float,
	band: float,
	cfg: SpawnBudgetConfig,
) -> bool:
	if units.is_empty():
		return false
	return _power_within(_power(units, cfg), target_e, band)


static func _better_of(
	a: Array[UnitData],
	b: Array[UnitData],
	target_e: float,
	cfg: SpawnBudgetConfig,
) -> Array[UnitData]:
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	var power_a := _power(a, cfg)
	var power_b := _power(b, cfg)
	var err_a := absf(power_a - target_e)
	var err_b := absf(power_b - target_e)
	var prefer_upper := cfg != null and cfg.prefer_upper_band
	var unique_a := _unique_id_count(a)
	var unique_b := _unique_id_count(b)
	if _is_better_composition(power_b, err_b, unique_b, power_a, err_a, unique_a, prefer_upper):
		return b
	return a


## 更优候选：误差更小 → 同误差面孔更散 → 上沿偏好更高 ΣU。
static func _is_better_composition(
	power: float,
	err: float,
	unique_n: int,
	best_power: float,
	best_err: float,
	best_unique: int,
	prefer_upper: bool,
) -> bool:
	if err < best_err - 0.0001:
		return true
	if absf(err - best_err) <= 0.0001:
		if unique_n > best_unique:
			return true
		if unique_n < best_unique:
			return false
		if prefer_upper and power > best_power + 0.0001:
			return true
	return false


static func _hill_climb(
	seed_units: Array[UnitData],
	pool: Array[UnitData],
	target_e: float,
	cfg: SpawnBudgetConfig,
	rng: RandomNumberGenerator,
	lock_count: bool = false,
	max_ranged: int = -1,
	t2_cap: int = 9999,
	t3_cap: int = 9999,
	t2_base: int = 0,
	t3_base: int = 0,
) -> Array[UnitData]:
	if seed_units.is_empty() or pool.is_empty():
		return seed_units
	var current: Array[UnitData] = seed_units.duplicate()
	var best_power := _power(current, cfg)
	var best_err := absf(best_power - target_e)
	var best_unique := _unique_id_count(current)
	var prefer_upper := cfg != null and cfg.prefer_upper_band
	var swaps := maxi(0, cfg.hill_climb_swaps)
	for _i in swaps:
		var idx := rng.randi_range(0, current.size() - 1)
		var selected_ids := _selected_ids_excluding(current, idx)
		var comp_no_slot := _without_index(current, idx)
		var pick_pool := EnemyTierIntro.filter_pool_for_add(
			pool, comp_no_slot, t2_cap, t3_cap, t2_base, t3_base
		)
		var replacement := _pick_unit_soft_dedup(pick_pool, selected_ids, cfg, rng)
		if replacement == null:
			continue
		var trial: Array[UnitData] = current.duplicate()
		trial[idx] = replacement
		## 人数硬锁时禁止 ±1；否则偶发尝试增删。
		if not lock_count:
			if rng.randf() < 0.25 and trial.size() > 1 and rng.randf() < 0.5:
				trial.remove_at(rng.randi_range(0, trial.size() - 1))
			elif rng.randf() < 0.25:
				var append_ids := _selected_ids_excluding(trial, -1)
				var append_pool := EnemyTierIntro.filter_pool_for_add(
					pool, trial, t2_cap, t3_cap, t2_base, t3_base
				)
				var append_u := _pick_unit_soft_dedup(append_pool, append_ids, cfg, rng)
				if append_u != null:
					trial.append(append_u)
		if max_ranged >= 0 and _count_ranged(trial) > max_ranged:
			continue
		if not EnemyTierIntro.fill_respects_caps(trial, t2_cap, t3_cap, t2_base, t3_base):
			continue
		var power := _power(trial, cfg)
		var err := absf(power - target_e)
		var unique_n := _unique_id_count(trial)
		if _is_better_composition(power, err, unique_n, best_power, best_err, best_unique, prefer_upper):
			best_err = err
			best_power = power
			best_unique = unique_n
			current = trial
	return current


static func _greedy_fill(
	pool: Array[UnitData],
	target_e: float,
	remain_seats: int,
	cfg: SpawnBudgetConfig,
	exact_count: bool = false,
	t2_cap: int = 9999,
	t3_cap: int = 9999,
	t2_base: int = 0,
	t3_base: int = 0,
) -> Array[UnitData]:
	var result: Array[UnitData] = []
	if pool.is_empty() or remain_seats <= 0:
		return result
	var sorted_pool: Array[UnitData] = pool.duplicate()
	sorted_pool.sort_custom(func(a: UnitData, b: UnitData) -> bool:
		var ua := _unit_u(a, cfg)
		var ub := _unit_u(b, cfg)
		if not is_equal_approx(ua, ub):
			return ua > ub
		return _unit_id(a) < _unit_id(b)
	)
	var power := 0.0
	var selected_ids: Dictionary = {}
	## 先尽量接近 E；优先未选种类，种类不够填满人数时才允许重复。
	while result.size() < remain_seats:
		var best_unit: UnitData = null
		var best_err := INF
		for pass_i in 2:
			var require_unused := pass_i == 0
			best_unit = null
			best_err = INF
			for cand in sorted_pool:
				var cand_id := _unit_id(cand)
				if require_unused and int(selected_ids.get(cand_id, 0)) > 0:
					continue
				if not EnemyTierIntro.can_add_unit(
					cand, result, t2_cap, t3_cap, t2_base, t3_base
				):
					continue
				var trial := power + _unit_u(cand, cfg)
				var err := absf(trial - target_e)
				## 非精确人数时：已超过且加人只会更差则跳过过大单位
				if not exact_count and power >= target_e and trial > power:
					continue
				if err < best_err - 0.0001:
					best_err = err
					best_unit = cand
				elif is_equal_approx(err, best_err) and best_unit != null:
					if _unit_id(cand) < _unit_id(best_unit):
						best_unit = cand
			if best_unit != null:
				break
		if best_unit == null:
			## 精确人数：仍须填满，取池中任意合法单位。
			if exact_count and not sorted_pool.is_empty():
				best_unit = sorted_pool[result.size() % sorted_pool.size()]
			else:
				break
		var next_power := power + _unit_u(best_unit, cfg)
		## 非精确人数：若已在带宽附近且再加会明显偏大，停止（至少 1 个）
		if (
			not exact_count
			and not result.is_empty()
			and power >= target_e * 0.85
			and next_power > target_e
			and absf(next_power - target_e) > absf(power - target_e)
		):
			break
		result.append(best_unit)
		_note_selected_id(selected_ids, best_unit)
		power = next_power
		if not exact_count and _power_within(power, target_e, 0.05):
			break
	if result.is_empty():
		result.append(_pick_closest_unit(pool, target_e, cfg))
	return result


static func _pick_closest_unit(
	pool: Array[UnitData],
	target_e: float,
	cfg: SpawnBudgetConfig,
) -> UnitData:
	var best: UnitData = pool[0]
	var best_err := absf(_unit_u(best, cfg) - target_e)
	for i in range(1, pool.size()):
		var err := absf(_unit_u(pool[i], cfg) - target_e)
		if err < best_err - 0.0001:
			best_err = err
			best = pool[i]
		elif is_equal_approx(err, best_err) and _unit_id(pool[i]) < _unit_id(best):
			best = pool[i]
	return best


## 敌方前排水平居中座位索引（5 列 → 2）。
static func front_center_seat_index(cols: int) -> int:
	return SeatLayout.front_center_seat_index(cols)


## 敌方最后一排水平居中（Boss 落点；5 列 × 满座 → 后排中）。
static func back_center_seat_index(cols: int, seat_count: int) -> int:
	return SeatLayout.back_center_seat_index(cols, seat_count)


## 落座：近战→前排、远程→后排；同行 max_hp→U→id、中心向外（53124）；溢出对向。
## 首领（is_boss_leader）强制落在最后一排水平居中座。
static func _seat_units(
	units: Array[UnitData],
	cols: int,
	seat_count: int,
	cfg: SpawnBudgetConfig,
) -> Array:
	var front_cap := mini(cols, seat_count)
	var back_cap := maxi(0, seat_count - front_cap)
	var col_order := SeatLayout.row_column_fill_order(cols)
	var melee: Array[UnitData] = []
	var ranged: Array[UnitData] = []
	for u in units:
		if UnitPowerScore.is_ranged(u):
			ranged.append(u)
		else:
			melee.append(u)
	_sort_for_seat(melee, cfg)
	_sort_for_seat(ranged, cfg)

	var seats: Array = []
	seats.resize(seat_count)
	for i in seat_count:
		seats[i] = null

	var front_q: Array[UnitData] = melee.duplicate()
	var back_q: Array[UnitData] = ranged.duplicate()
	## 前排满：近战溢后排；后排满：远程溢前排。同行按中心向外填列。
	var front_filled := 0
	var back_filled := 0
	var overflow_melee: Array[UnitData] = []
	while not front_q.is_empty():
		var u: UnitData = front_q.pop_front()
		if front_filled < front_cap:
			var front_seat := col_order[front_filled]
			seats[front_seat] = u
			front_filled += 1
		else:
			overflow_melee.append(u)
	var overflow_ranged: Array[UnitData] = []
	while not back_q.is_empty():
		var u2: UnitData = back_q.pop_front()
		if back_filled < back_cap:
			var back_seat := front_cap + col_order[back_filled]
			if back_seat < seat_count:
				seats[back_seat] = u2
				back_filled += 1
			else:
				overflow_ranged.append(u2)
		else:
			overflow_ranged.append(u2)
	for u3 in overflow_melee:
		if back_filled < back_cap:
			var back_seat2 := front_cap + col_order[back_filled]
			if back_seat2 < seat_count:
				seats[back_seat2] = u3
				back_filled += 1
	for u4 in overflow_ranged:
		if front_filled < front_cap:
			var front_seat2 := col_order[front_filled]
			seats[front_seat2] = u4
			front_filled += 1
		else:
			## 仍满则找任意空座
			for s in seat_count:
				if seats[s] == null:
					seats[s] = u4
					break

	_place_boss_leaders_back_center(seats, cols, seat_count)

	var result: Array = []
	for seat_i in seat_count:
		var unit: UnitData = seats[seat_i]
		if unit == null:
			continue
		result.append({
			"unit_data": unit,
			"seat_index": seat_i,
			"power_u": _unit_u(unit, cfg),
			"level": 1,
		})
	return result


## 将 is_boss_leader 与后排居中座交换（已在居中则不动）。
static func _place_boss_leaders_back_center(seats: Array, cols: int, seat_count: int) -> void:
	if seats.is_empty() or seat_count <= 0:
		return
	var center_i := back_center_seat_index(cols, seat_count)
	if center_i < 0 or center_i >= seats.size():
		return
	for s in seats.size():
		var u: UnitData = seats[s] as UnitData
		if u == null or not u.is_boss_leader:
			continue
		if s == center_i:
			return
		var displaced: UnitData = seats[center_i] as UnitData
		seats[center_i] = u
		seats[s] = displaced
		return



static func _sort_for_seat(units: Array[UnitData], cfg: SpawnBudgetConfig) -> void:
	units.sort_custom(func(a: UnitData, b: UnitData) -> bool:
		var hp_a := a.stats.max_hp if a != null and a.stats != null else 0
		var hp_b := b.stats.max_hp if b != null and b.stats != null else 0
		if hp_a != hp_b:
			return hp_a > hp_b
		var ua := _unit_u(a, cfg)
		var ub := _unit_u(b, cfg)
		if not is_equal_approx(ua, ub):
			return ua > ub
		return _unit_id(a) < _unit_id(b)
	)


static func _unit_id(unit: UnitData) -> String:
	if unit == null:
		return ""
	if not unit.id.is_empty():
		return unit.id
	return unit.resource_path
