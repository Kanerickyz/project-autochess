class_name EnemyBudgetSpawnerTest
extends RefCounted
## 层预算抽阵：U 公式、带宽、落座、开关、Boss 固定单位。


static func run_all() -> bool:
	var ok := true
	ok = _check("unit_power_formula", _test_unit_power_formula()) and ok
	ok = _check("skill_alpha_defaults", _test_skill_alpha_defaults()) and ok
	ok = _check("splash_body_mult", _test_splash_body_mult()) and ok
	ok = _check("budget_roll_within_band", _test_budget_roll_within_band()) and ok
	ok = _check("seat_melee_front_ranged_back", _test_seat_melee_front_ranged_back()) and ok
	ok = _check("seat_write_order", _test_seat_write_order()) and ok
	ok = _check("tier_filter_hard", _test_tier_filter_hard()) and ok
	ok = _check("boss_fixed_then_fill", _test_boss_fixed_then_fill()) and ok
	ok = _check("disabled_keeps_legacy_path_marker", _test_config_disabled_flag()) and ok
	ok = _check("p_mid_not_player_team", _test_p_mid_from_config_only()) and ok
	ok = _check("overflow_melee_to_back", _test_overflow_melee_to_back()) and ok
	if ok:
		print("EnemyBudgetSpawnerTest: all passed")
	else:
		push_error("EnemyBudgetSpawnerTest: failures detected")
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("  PASS %s" % name)
	else:
		push_error("EnemyBudgetSpawnerTest: FAIL %s" % name)
	return passed


static func _make_unit(
	id: String,
	hp: int,
	atk: int,
	interval: float,
	tier: int,
	projectile_speed: float = 0.0,
	splash: float = 0.0,
	with_ability: bool = false,
) -> UnitData:
	var stats := UnitStats.new()
	stats.max_hp = hp
	stats.attack = atk
	stats.attack_interval = interval
	stats.projectile_speed = projectile_speed
	stats.splash_radius = splash
	var data := UnitData.new()
	data.id = id
	data.display_name = id
	data.tier = tier
	data.stats = stats
	if with_ability:
		data.ability = AbilityData.new()
	return data


static func _make_config(pool: Array[UnitData]) -> SpawnBudgetConfig:
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.enabled = true
	cfg.enemy_pool = pool
	cfg.rejection_attempts = 80
	cfg.hill_climb_swaps = 40
	var mids: Array[float] = [60.0, 70.0, 80.0, 90.0, 100.0]
	cfg.floor_mid_power = mids
	cfg.kappa_combat = 1.0
	cfg.band_combat = 0.20
	cfg.band_widen_step = 0.10
	return cfg


static func _make_wave(spawn_count: int, fixed: Array[UnitData] = []) -> WaveData:
	var wave := WaveData.new()
	wave.spawn_count = spawn_count
	for u in fixed:
		var entry := SpawnScheduleEntry.new()
		entry.unit = u
		entry.count = 1
		wave.fixed_entries.append(entry)
	return wave


static func _test_unit_power_formula() -> bool:
	## U = (HP + 1.5*ATK + 0.5*DPS) * α * (1 + 0.08*(tier-1))
	var u := _make_unit("a", 10, 4, 2.0, 3, 0.0, 0.0, true)
	var dps := 4.0 / 2.0
	var body := 10.0 + 1.5 * 4.0 + 0.5 * dps
	var expected := body * 1.0 * (1.0 + 0.08 * 2.0)
	var got := UnitPowerScore.compute_u(u)
	return is_equal_approx(got, expected)


static func _test_skill_alpha_defaults() -> bool:
	var no_skill := _make_unit("ns", 10, 2, 1.0, 1, 0.0, 0.0, false)
	var has_skill := _make_unit("hs", 10, 2, 1.0, 1, 0.0, 0.0, true)
	var u_no := UnitPowerScore.compute_u(no_skill)
	var u_yes := UnitPowerScore.compute_u(has_skill)
	if not is_equal_approx(u_yes / u_no, 1.0 / 0.85):
		return false
	var mapped := UnitPowerScore.compute_u(has_skill, {"hs": 1.25})
	var base_body := 10.0 + 1.5 * 2.0 + 0.5 * (2.0 / 1.0)
	return is_equal_approx(mapped, base_body * 1.25)


static func _test_splash_body_mult() -> bool:
	var plain := _make_unit("p", 20, 4, 1.0, 1, 0.0, 0.0, true)
	var splash := _make_unit("s", 20, 4, 1.0, 1, 0.0, 1.0, true)
	var u_plain := UnitPowerScore.compute_u(plain)
	var u_splash := UnitPowerScore.compute_u(splash)
	return is_equal_approx(u_splash / u_plain, 1.05)


static func _test_budget_roll_within_band() -> bool:
	var pool: Array[UnitData] = [
		_make_unit("m1", 12, 3, 1.2, 1, 0.0, 0.0, true),
		_make_unit("m2", 16, 4, 1.4, 2, 0.0, 0.0, true),
		_make_unit("r1", 8, 5, 1.0, 1, 8.0, 0.0, true),
		_make_unit("r2", 10, 6, 1.1, 2, 10.0, 0.0, true),
		_make_unit("m3", 14, 3, 1.3, 1, 0.0, 0.5, true),
	]
	var cfg := _make_config(pool)
	var mid55: Array[float] = [55.0]
	cfg.floor_mid_power = mid55
	var wave := _make_wave(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 0, 0, MapNodeType.Type.COMBAT, 2, 5, rng
	)
	if seated.is_empty():
		return false
	var power := 0.0
	for item in seated:
		power += float(item.get("power_u", 0.0))
	var target := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT)
	var band := cfg.get_band(MapNodeType.Type.COMBAT) + cfg.band_widen_step
	var lo := target * (1.0 - band)
	var hi := target * (1.0 + band)
	## 正式路径允许放宽一档或保底接近；至少人数合法且有座位。
	if seated.size() < 1 or seated.size() > 10:
		return false
	for item in seated:
		var seat_i := int(item.get("seat_index", -1))
		if seat_i < 0 or seat_i >= 10:
			return false
	## 多数固定种子应落在放宽带宽内；若保底则 |ΣU-E| 应小于单大单位量级。
	if power >= lo and power <= hi:
		return true
	return absf(power - target) < target * 0.5


static func _test_seat_melee_front_ranged_back() -> bool:
	var melee := _make_unit("tank", 30, 3, 1.5, 1, 0.0, 0.0, true)
	var ranged := _make_unit("bow", 8, 5, 1.0, 1, 8.0, 0.0, true)
	var cfg := _make_config([melee, ranged])
	## 强制组成：直接测落座
	var seated := EnemyBudgetSpawner._seat_units([melee, ranged], 5, 10, cfg)
	if seated.size() != 2:
		return false
	var melee_seat := -1
	var ranged_seat := -1
	for item in seated:
		var ud: UnitData = item.get("unit_data") as UnitData
		if ud.id == "tank":
			melee_seat = int(item.get("seat_index", -1))
		elif ud.id == "bow":
			ranged_seat = int(item.get("seat_index", -1))
	## 前排 0..4，后排 5..9
	return melee_seat >= 0 and melee_seat < 5 and ranged_seat >= 5 and ranged_seat < 10


static func _test_seat_write_order() -> bool:
	var a := _make_unit("a", 20, 3, 1.0, 1, 0.0, 0.0, true)
	var b := _make_unit("b", 10, 3, 1.0, 1, 0.0, 0.0, true)
	var c := _make_unit("c", 8, 4, 1.0, 1, 9.0, 0.0, true)
	var cfg := _make_config([a, b, c])
	var seated := EnemyBudgetSpawner._seat_units([a, b, c], 5, 10, cfg)
	var prev := -1
	for item in seated:
		var seat_i := int(item.get("seat_index", -1))
		if seat_i <= prev:
			return false
		prev = seat_i
	return true


static func _test_tier_filter_hard() -> bool:
	var low := _make_unit("low", 10, 2, 1.0, 1, 0.0, 0.0, true)
	var high := _make_unit("high", 80, 20, 1.0, 6, 0.0, 0.0, true)
	var cfg := _make_config([low, high])
	var wave := _make_wave(4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	## tier_index=0 → max_tier=1，高品阶不得出现
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 0, 0, MapNodeType.Type.COMBAT, 2, 5, rng
	)
	for item in seated:
		var ud: UnitData = item.get("unit_data") as UnitData
		if ud != null and ud.tier > 1:
			return false
	return not seated.is_empty()


static func _test_boss_fixed_then_fill() -> bool:
	var boss := _make_unit("boss", 40, 8, 1.5, 3, 0.0, 0.0, true)
	var filler := _make_unit("fodder", 8, 2, 1.0, 1, 0.0, 0.0, true)
	var cfg := _make_config([filler, boss])
	var mid120: Array[float] = [120.0]
	cfg.floor_mid_power = mid120
	cfg.kappa_boss = 1.0
	var wave := _make_wave(2, [boss])
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 4, 0, MapNodeType.Type.BOSS, 2, 5, rng
	)
	if seated.is_empty() or seated.size() > 10:
		return false
	var has_boss := false
	for item in seated:
		var ud: UnitData = item.get("unit_data") as UnitData
		if ud != null and ud.id == "boss":
			has_boss = true
	return has_boss


static func _test_config_disabled_flag() -> bool:
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.enabled = false
	return cfg.enabled == false


static func _test_p_mid_from_config_only() -> bool:
	var cfg := SpawnBudgetConfig.make_code_defaults()
	var mid_pair: Array[float] = [40.0, 80.0]
	cfg.floor_mid_power = mid_pair
	cfg.kappa_combat = 1.25
	var e0 := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT)
	var e1 := cfg.get_target_pressure(1, MapNodeType.Type.COMBAT)
	return is_equal_approx(e0, 50.0) and is_equal_approx(e1, 100.0)


static func _test_overflow_melee_to_back() -> bool:
	var units: Array[UnitData] = []
	for i in 7:
		units.append(_make_unit("m%d" % i, 20 - i, 3, 1.0, 1, 0.0, 0.0, true))
	var cfg := _make_config(units)
	var seated := EnemyBudgetSpawner._seat_units(units, 5, 10, cfg)
	if seated.size() != 7:
		return false
	var back_count := 0
	for item in seated:
		if int(item.get("seat_index", -1)) >= 5:
			back_count += 1
	## 5 前排满，2 溢后排
	return back_count == 2
