class_name EnemyBudgetSpawner
extends RefCounted
## 层预算抽阵：拒采样贴带宽 → 放宽一档 → 最近解爬山 → 贪心保底。禁止静默纯随机。

const MAX_SEATS_HARD := 10


## 返回书写顺序（前排左→右，再后排）的字典数组：
## { "unit_data": UnitData, "seat_index": int, "power_u": float }
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

	var pool := _resolve_pool(cfg, fallback_pool, tier_index)
	if pool.is_empty():
		push_warning("EnemyBudgetSpawner: filtered enemy pool empty (tier_index=%d)" % tier_index)
		return _seat_units(_collect_fixed_units(wave), cols, seat_count, cfg)

	var target_e := cfg.get_target_pressure(floor_index, node_type)
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

	## Boss 节点：只出固定首领（及关卡写死的跟班若有），不预算填杂兵。
	var fill: Array[UnitData] = []
	if node_type != MapNodeType.Type.BOSS:
		if remain_seats > 0 and remain_e > 0.0 and not pool.is_empty():
			fill = _sample_fill(
				pool,
				remain_e,
				remain_seats,
				wave.spawn_count,
				cfg,
				node_type,
				rng,
			)
		elif remain_seats > 0 and remain_e <= 0.0 and fixed_units.is_empty():
			## 无固定且预算异常：仍至少出 n_min，走保底贪心。
			fill = _greedy_fill(pool, target_e, remain_seats, cfg)

	var all_units: Array[UnitData] = []
	all_units.append_array(fixed_units)
	all_units.append_array(fill)
	if all_units.size() > seat_count:
		var capped: Array[UnitData] = []
		for i in seat_count:
			capped.append(all_units[i])
		all_units = capped
	if all_units.is_empty() and not pool.is_empty():
		## 极端保底：至少 1 个最接近 E 的单位。
		all_units.append(_pick_closest_unit(pool, target_e, cfg))

	return _seat_units(all_units, cols, seat_count, cfg)


static func _resolve_pool(
	cfg: SpawnBudgetConfig,
	fallback_pool: Array[UnitData],
	tier_index: int,
) -> Array[UnitData]:
	var source: Array[UnitData] = []
	if cfg != null and not cfg.enemy_pool.is_empty():
		source = cfg.enemy_pool
	else:
		source = fallback_pool
		push_warning("EnemyBudgetSpawner: enemy budget pool empty; falling back to LevelData.enemy_pool")

	var max_tier := TierUnlock.get_max_unlocked_tier(tier_index + 1)
	var filtered: Array = TierUnlock.filter_by_tier(source, _get_unit_tier, max_tier)
	var pool: Array[UnitData] = []
	for item in filtered:
		if item is UnitData and (item as UnitData).stats != null:
			pool.append(item as UnitData)
	return pool


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


static func _sample_fill(
	pool: Array[UnitData],
	target_e: float,
	remain_seats: int,
	spawn_count_hint: int,
	cfg: SpawnBudgetConfig,
	node_type: MapNodeType.Type,
	rng: RandomNumberGenerator,
) -> Array[UnitData]:
	var n_min := clampi(cfg.n_min, 1, remain_seats)
	var n_max := remain_seats
	var center := clampi(maxi(1, spawn_count_hint), n_min, n_max)
	var base_band := cfg.get_band(node_type)
	var formation := cfg.pick_formation_tag(rng)

	## 第一档：带阵型标签
	var best := _rejection_search(
		pool, target_e, n_min, n_max, center, base_band, formation, true, cfg, rng
	)
	if _within_band(best, target_e, base_band, cfg):
		return best

	## 第二档：忽略标签，同带宽
	best = _better_of(
		best,
		_rejection_search(pool, target_e, n_min, n_max, center, base_band, formation, false, cfg, rng),
		target_e,
		cfg,
	)
	if _within_band(best, target_e, base_band, cfg):
		return best

	## 放宽一档（禁止再静默纯随机）
	var wide_band := base_band + maxf(0.0, cfg.band_widen_step)
	best = _better_of(
		best,
		_rejection_search(pool, target_e, n_min, n_max, center, wide_band, formation, false, cfg, rng),
		target_e,
		cfg,
	)
	if _within_band(best, target_e, wide_band, cfg):
		return best

	## 最近解 + ±1 替换爬山
	if best.is_empty():
		best = _random_composition(pool, center, rng)
	best = _hill_climb(best, pool, target_e, cfg, rng)
	if _within_band(best, target_e, wide_band, cfg):
		return best

	## 保底：按 U 贪心填充到接近 E
	return _greedy_fill(pool, target_e, remain_seats, cfg)


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
) -> Array[UnitData]:
	var best: Array[UnitData] = []
	var best_err := INF
	var attempts := maxi(1, cfg.rejection_attempts)
	for _i in attempts:
		var n := _roll_n(center, n_min, n_max, rng)
		var comp := _random_composition(pool, n, rng)
		if require_formation and not _matches_formation(comp, formation):
			continue
		var power := _power(comp, cfg)
		var err := absf(power - target_e)
		if err < best_err:
			best_err = err
			best = comp
		if _power_within(power, target_e, band):
			return comp
	return best


static func _roll_n(center: int, n_min: int, n_max: int, rng: RandomNumberGenerator) -> int:
	var delta := rng.randi_range(-1, 1)
	return clampi(center + delta, n_min, n_max)


static func _random_composition(
	pool: Array[UnitData],
	n: int,
	rng: RandomNumberGenerator,
) -> Array[UnitData]:
	var result: Array[UnitData] = []
	if pool.is_empty() or n <= 0:
		return result
	for _i in n:
		result.append(pool[rng.randi_range(0, pool.size() - 1)])
	return result


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
			if n == 1:
				return ranged_n == 1
			return float(ranged_n) / float(n) >= 0.6
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
	var err_a := absf(_power(a, cfg) - target_e)
	var err_b := absf(_power(b, cfg) - target_e)
	return a if err_a <= err_b else b


static func _hill_climb(
	seed_units: Array[UnitData],
	pool: Array[UnitData],
	target_e: float,
	cfg: SpawnBudgetConfig,
	rng: RandomNumberGenerator,
) -> Array[UnitData]:
	if seed_units.is_empty() or pool.is_empty():
		return seed_units
	var current: Array[UnitData] = seed_units.duplicate()
	var best_err := absf(_power(current, cfg) - target_e)
	var swaps := maxi(0, cfg.hill_climb_swaps)
	for _i in swaps:
		var idx := rng.randi_range(0, current.size() - 1)
		var replacement := pool[rng.randi_range(0, pool.size() - 1)]
		var trial: Array[UnitData] = current.duplicate()
		trial[idx] = replacement
		## 可选 ±1 人数：偶发尝试增删
		if rng.randf() < 0.25 and trial.size() > 1 and rng.randf() < 0.5:
			trial.remove_at(rng.randi_range(0, trial.size() - 1))
		elif rng.randf() < 0.25:
			trial.append(pool[rng.randi_range(0, pool.size() - 1)])
		var err := absf(_power(trial, cfg) - target_e)
		if err < best_err:
			best_err = err
			current = trial
	return current


static func _greedy_fill(
	pool: Array[UnitData],
	target_e: float,
	remain_seats: int,
	cfg: SpawnBudgetConfig,
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
	## 先尽量接近 E：每次选使 |new-E| 最小的单位。
	while result.size() < remain_seats:
		var best_unit: UnitData = null
		var best_err := INF
		for cand in sorted_pool:
			var trial := power + _unit_u(cand, cfg)
			var err := absf(trial - target_e)
			## 已超过且加人只会更差时跳过过大单位
			if power >= target_e and trial > power:
				continue
			if err < best_err - 0.0001:
				best_err = err
				best_unit = cand
			elif is_equal_approx(err, best_err) and best_unit != null:
				if _unit_id(cand) < _unit_id(best_unit):
					best_unit = cand
		if best_unit == null:
			break
		var next_power := power + _unit_u(best_unit, cfg)
		## 若已在带宽附近且再加会明显偏大，停止（至少 1 个）
		if not result.is_empty() and power >= target_e * 0.85 and next_power > target_e and absf(next_power - target_e) > absf(power - target_e):
			break
		result.append(best_unit)
		power = next_power
		if _power_within(power, target_e, 0.05):
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
	return maxi(1, cols) / 2


## 落座：近战→前排、远程→后排；同行 max_hp→U→id；溢出对向；书写序前排再后排。
## 首领（is_boss_leader）强制落在前排水平居中座。
static func _seat_units(
	units: Array[UnitData],
	cols: int,
	seat_count: int,
	cfg: SpawnBudgetConfig,
) -> Array:
	var front_cap := mini(cols, seat_count)
	var back_cap := maxi(0, seat_count - front_cap)
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
	## 前排满：近战溢后排；后排满：远程溢前排。
	var front_filled := 0
	var back_filled := 0
	var overflow_melee: Array[UnitData] = []
	while not front_q.is_empty():
		var u: UnitData = front_q.pop_front()
		if front_filled < front_cap:
			seats[front_filled] = u
			front_filled += 1
		else:
			overflow_melee.append(u)
	var overflow_ranged: Array[UnitData] = []
	while not back_q.is_empty():
		var u2: UnitData = back_q.pop_front()
		var back_index := front_cap + back_filled
		if back_filled < back_cap and back_index < seat_count:
			seats[back_index] = u2
			back_filled += 1
		else:
			overflow_ranged.append(u2)
	for u3 in overflow_melee:
		var back_index2 := front_cap + back_filled
		if back_filled < back_cap and back_index2 < seat_count:
			seats[back_index2] = u3
			back_filled += 1
	for u4 in overflow_ranged:
		if front_filled < front_cap:
			seats[front_filled] = u4
			front_filled += 1
		else:
			## 仍满则找任意空座
			for s in seat_count:
				if seats[s] == null:
					seats[s] = u4
					break

	_place_boss_leaders_front_center(seats, cols, front_cap)

	var result: Array = []
	for seat_i in seat_count:
		var unit: UnitData = seats[seat_i]
		if unit == null:
			continue
		result.append({
			"unit_data": unit,
			"seat_index": seat_i,
			"power_u": _unit_u(unit, cfg),
		})
	return result


## 将 is_boss_leader 与前排居中座交换（已在居中则不动）。
static func _place_boss_leaders_front_center(seats: Array, cols: int, front_cap: int) -> void:
	if seats.is_empty() or front_cap <= 0:
		return
	var center_i := front_center_seat_index(cols)
	if center_i < 0 or center_i >= front_cap or center_i >= seats.size():
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
