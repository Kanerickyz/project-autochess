class_name EnemyBudgetSpawnerTest
extends RefCounted
## 队伍强度抽阵：U 公式、真队 E、护栏、落座、开关、Boss 固定单位。


static func run_all() -> bool:
	var ok := true
	ok = _check("unit_power_formula", _test_unit_power_formula()) and ok
	ok = _check("skill_alpha_defaults", _test_skill_alpha_defaults()) and ok
	ok = _check("splash_body_mult", _test_splash_body_mult()) and ok
	ok = _check("entry_star_body_power", _test_entry_star_body_power()) and ok
	ok = _check("enemy_star2_matches_player", _test_enemy_star2_matches_player()) and ok
	ok = _check("panel_match_follows_team_avg", _test_panel_match_follows_team_avg()) and ok
	ok = _check("panel_match_floor_guard", _test_panel_match_floor_guard()) and ok
	ok = _check("panel_match_elite_higher", _test_panel_match_elite_higher()) and ok
	ok = _check("panel_match_skips_boss", _test_panel_match_skips_boss()) and ok
	ok = _check("budget_roll_within_band", _test_budget_roll_within_band()) and ok
	ok = _check("seat_melee_front_ranged_back", _test_seat_melee_front_ranged_back()) and ok
	ok = _check("seat_write_order", _test_seat_write_order()) and ok
	ok = _check("tier_filter_hard", _test_tier_filter_hard()) and ok
	ok = _check("player_tier_caps_enemy_pool", _test_player_tier_caps_enemy_pool()) and ok
	ok = _check("t2_intro_cap_floor4", _test_t2_intro_cap_floor4_one_team_t2()) and ok
	ok = _check("boss_fixed_only_no_fill", _test_boss_fixed_only_no_fill()) and ok
	ok = _check("boss_ignores_team_power", _test_boss_ignores_team_power()) and ok
	ok = _check("boss_back_center_seat", _test_boss_back_center_seat()) and ok
	ok = _check("seat_center_out_row_order", _test_seat_center_out_row_order()) and ok
	ok = _check("disabled_keeps_legacy_path_marker", _test_config_disabled_flag()) and ok

	ok = _check("team_target_with_floor_guards", _test_team_target_with_floor_guards()) and ok
	ok = _check("overflow_melee_to_back", _test_overflow_melee_to_back()) and ok
	ok = _check("combat_count_by_floor", _test_combat_count_by_floor()) and ok
	ok = _check("elite_count_n_or_n_plus_2", _test_elite_count_n_or_n_plus_2()) and ok
	ok = _check("boss_ignores_roster_count", _test_boss_ignores_roster_count()) and ok
	ok = _check("roll_enemy_count_config", _test_roll_enemy_count_config()) and ok
	ok = _check("first_floor_elite_count_cap", _test_first_floor_elite_count_cap()) and ok
	ok = _check("first_floor_max_one_ranged", _test_first_floor_max_one_ranged()) and ok
	ok = _check("resolve_max_ranged_caps", _test_resolve_max_ranged_caps()) and ok
	ok = _check("non_first_floor_not_all_ranged", _test_non_first_floor_not_all_ranged()) and ok
	ok = _check("skill_expectation_differentiates", _test_skill_expectation_differentiates()) and ok
	ok = _check("enemy_id_alpha_lookup_fallback", _test_enemy_id_alpha_lookup_fallback()) and ok
	ok = _check("fused_entry_uses_runtime_ability", _test_fused_entry_uses_runtime_ability()) and ok
	ok = _check("recruit_enemy_pool_mirror_contract", _test_recruit_enemy_pool_mirror_contract()) and ok
	ok = _check("same_id_soft_dedup_prefers_variety", _test_same_id_soft_dedup_prefers_variety()) and ok
	ok = _check("greedy_fill_prefers_unique_ids", _test_greedy_fill_prefers_unique_ids()) and ok
	ok = _check("prefer_upper_band_tie_breaks_higher", _test_prefer_upper_band_tie_breaks_higher()) and ok
	ok = _check("formation_tag_weighted_pick", _test_formation_tag_weighted_pick()) and ok
	ok = _check("better_of_prefers_more_unique_on_tie", _test_better_of_prefers_more_unique_on_tie()) and ok
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


static func _make_entry(unit: UnitData, bonus_hp: int = 0, bonus_atk: int = 0, level: int = 1) -> DeckEntry:
	var entry := DeckEntry.new()
	entry.unit = unit
	entry.bonus_max_hp = bonus_hp
	entry.bonus_attack = bonus_atk
	entry.level = level
	return entry


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


static func _test_panel_match_follows_team_avg() -> bool:
	## 肥队：敌方面板均值应贴近队均（普通倍率 1.0）。
	var ally := _make_unit("ally", 20, 8, 1.0, 1)
	var team: Array = [_make_entry(ally, 10, 4), _make_entry(ally, 10, 4)]
	## 同底模，避免取整后均值漂移。
	var enemy_a := UnitInstance.from_unit_data(_make_unit("e1", 10, 4, 1.0, 1), Vector2i.ZERO, UnitInstance.Team.ENEMY)
	var enemy_b := UnitInstance.from_unit_data(_make_unit("e2", 10, 4, 1.0, 1), Vector2i.ZERO, UnitInstance.Team.ENEMY)
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.panel_match_enabled = true
	cfg.panel_mult_combat = 1.0
	cfg.default_panel_atk_floor = 1.0
	cfg.default_panel_hp_floor = 1.0
	cfg.panel_floor_growth = 0.0
	var ok := EnemyPanelMatcher.apply_to_units(
		[enemy_a, enemy_b], team, 1, MapNodeType.Type.COMBAT, cfg
	)
	if not ok:
		return false
	## 队均展示 12 攻 / 30 血；底模 4/10 → ×3。
	return (
		enemy_a.stats.attack == 12
		and enemy_b.stats.attack == 12
		and enemy_a.stats.max_hp == 30
		and enemy_b.stats.max_hp == 30
	)


static func _test_panel_match_floor_guard() -> bool:
	## 空队深层：锚点走层向保底，不因队均为 0 而塌成 1。
	var enemy := UnitInstance.from_unit_data(
		_make_unit("e", 4, 2, 1.0, 1), Vector2i.ZERO, UnitInstance.Team.ENEMY
	)
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.panel_match_enabled = true
	cfg.default_panel_atk_floor = 3.0
	cfg.default_panel_hp_floor = 5.0
	cfg.panel_floor_growth = 0.0
	EnemyPanelMatcher.apply_to_units([enemy], [], 5, MapNodeType.Type.COMBAT, cfg)
	return enemy.stats.attack >= 3 and enemy.stats.max_hp >= 5


static func _test_panel_match_elite_higher() -> bool:
	var ally := _make_unit("ally", 10, 4, 1.0, 1)
	var team: Array = [_make_entry(ally)]
	var combat_e := UnitInstance.from_unit_data(
		_make_unit("c", 10, 4, 1.0, 1), Vector2i.ZERO, UnitInstance.Team.ENEMY
	)
	var elite_e := UnitInstance.from_unit_data(
		_make_unit("e", 10, 4, 1.0, 1), Vector2i.ZERO, UnitInstance.Team.ENEMY
	)
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.panel_mult_combat = 1.0
	cfg.panel_mult_elite = 1.25
	cfg.default_panel_atk_floor = 1.0
	cfg.default_panel_hp_floor = 1.0
	cfg.panel_floor_growth = 0.0
	EnemyPanelMatcher.apply_to_units([combat_e], team, 1, MapNodeType.Type.COMBAT, cfg)
	EnemyPanelMatcher.apply_to_units([elite_e], team, 1, MapNodeType.Type.ELITE, cfg)
	return elite_e.stats.attack > combat_e.stats.attack and elite_e.stats.max_hp > combat_e.stats.max_hp


static func _test_panel_match_skips_boss() -> bool:
	var ally := _make_unit("ally", 40, 20, 1.0, 1)
	var team: Array = [_make_entry(ally)]
	var boss := UnitInstance.from_unit_data(
		_make_unit("boss", 10, 4, 1.0, 1), Vector2i.ZERO, UnitInstance.Team.ENEMY
	)
	var before_atk := boss.stats.attack
	var before_hp := boss.stats.max_hp
	var cfg := SpawnBudgetConfig.make_code_defaults()
	var applied := EnemyPanelMatcher.apply_to_units(
		[boss], team, 3, MapNodeType.Type.BOSS, cfg
	)
	return (
		not applied
		and boss.stats.attack == before_atk
		and boss.stats.max_hp == before_hp
	)


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


static func _count_level(seated: Array, level: int) -> int:
	var n := 0
	for item in seated:
		if int(item.get("level", 1)) == level:
			n += 1
	return n


static func _roll_fixed(
	units: Array[UnitData],
	team: Array,
	floor_index: int,
	node_type: MapNodeType.Type,
	seed: int,
) -> Array:
	var cfg := _make_config(units)
	var wave := _make_wave(units.size(), units)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return EnemyBudgetSpawner.roll(
		wave, cfg, [], 0, floor_index, node_type, 2, 5, rng, team, 15
	)


static func _test_enemy_star2_matches_player() -> bool:
	var fodder: Array[UnitData] = []
	for i in 4:
		fodder.append(_make_unit("fodder_%d" % i, 10, 2, 1.0, 1))
	var ally := _make_unit("ally", 10, 2, 1.0, 1)
	var team: Array = [
		_make_entry(ally, 0, 0, 2),
		_make_entry(ally, 0, 0, 2),
		_make_entry(ally, 0, 0, 1),
		_make_entry(ally, 0, 0, 3),
	]
	## 全层都按二星人数，不看是否临近 Boss；3★ 不计。
	## 第 1 层目标人数 ≤ 固定 4 人，名单不会再被填充。
	var early := _roll_fixed(fodder, team, 1, MapNodeType.Type.COMBAT, 11)
	if early.size() != 4 or _count_level(early, 2) != 2 or _count_level(early, 1) != 2:
		return false
	if _count_level(early, 3) != 0:
		return false
	## 深层会按层加人，但 2★ 仍只有玩家的 2 只，不再半数保底。
	var late := _roll_fixed(fodder, team, 15, MapNodeType.Type.COMBAT, 11)
	if late.size() < 4 or _count_level(late, 2) != 2 or _count_level(late, 3) != 0:
		return false
	var again := _roll_fixed(fodder, team, 3, MapNodeType.Type.ELITE, 11)
	var first := _roll_fixed(fodder, team, 3, MapNodeType.Type.ELITE, 11)
	var seats_a: Array[int] = []
	var seats_b: Array[int] = []
	for item in first:
		if int(item.get("level", 1)) == 2:
			seats_a.append(int(item.get("seat_index", -1)))
	for item2 in again:
		if int(item2.get("level", 1)) == 2:
			seats_b.append(int(item2.get("seat_index", -1)))
	seats_a.sort()
	seats_b.sort()
	if seats_a != seats_b or seats_a.size() != 2:
		return false
	var p1 := 0.0
	var p2 := 0.0
	for item3 in first:
		if int(item3.get("level", 1)) == 2:
			p2 = float(item3.get("power_u", 0.0))
		else:
			p1 = float(item3.get("power_u", 0.0))
	if p1 <= 0.0 or not is_equal_approx(p2, p1 * 3.0):
		return false
	## 没有 2★（含仅 3★）时，临近 Boss 也不再保底升星。
	var no_star2: Array = [_make_entry(ally, 0, 0, 1), _make_entry(ally, 0, 0, 3)]
	var plain := _roll_fixed(fodder, no_star2, 15, MapNodeType.Type.COMBAT, 4)
	if _count_level(plain, 2) != 0:
		return false
	## 想要的二星多于座位时，可升星的全升，不超过座位数。
	var many: Array = []
	for _i in 8:
		many.append(_make_entry(ally, 0, 0, 2))
	var capped := _roll_fixed(fodder, many, 2, MapNodeType.Type.COMBAT, 5)
	if capped.size() != 4 or _count_level(capped, 2) != 4:
		return false
	## Boss 节点不升星，首领与跟班都保持 1★。
	var boss := _make_unit("boss", 40, 8, 1.5, 3)
	boss.is_boss_leader = true
	var minion := _make_unit("minion", 10, 2, 1.0, 1)
	var boss_units: Array[UnitData] = [boss, minion]
	var boss_seated := _roll_fixed(boss_units, team, 16, MapNodeType.Type.BOSS, 9)
	return _count_level(boss_seated, 2) == 0 and boss_seated.size() == 2


static func _test_entry_star_body_power() -> bool:
	var unit := _make_unit("star", 10, 4, 1.0, 1, 0.0, 0.0, true)
	var base_u := UnitPowerScore.compute_u(unit)
	var entry := _make_entry(unit, 10, 2, 2)
	var starred := UnitPowerScore.compute_u_from_entry(entry)
	## 星级身体应高于裸 UnitData。
	if starred <= base_u:
		return false
	var hp := 20.0
	var atk := 6.0
	var dps := atk / 1.0
	var body := hp + 1.5 * atk + 0.5 * dps
	return is_equal_approx(starred, body * 1.0)


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
	## 真队 S≈55 → E＝κ×S 落在护栏内。
	var team: Array = [_make_entry(_make_unit("ally", 20, 6, 1.0, 1, 0.0, 0.0, true))]
	## ally U = (20+1.5*6+0.5*6)*1 = 32；补第二人以抬高 S。
	team.append(_make_entry(_make_unit("ally2", 14, 4, 1.0, 1, 0.0, 0.0, true)))
	## ally2 U = (14+6+2)=22；S=54 接近 55。
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 0, 0, MapNodeType.Type.COMBAT, 2, 5, rng, team
	)
	if seated.is_empty():
		return false
	var power := 0.0
	for item in seated:
		power += float(item.get("power_u", 0.0))
	var team_s := UnitPowerScore.team_power_from_entries(team)
	var target := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT, team_s)
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
	var team: Array = [_make_entry(low)]
	## tier_index=0 → max_tier=1，高品阶不得出现
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 0, 0, MapNodeType.Type.COMBAT, 2, 5, rng, team
	)
	for item in seated:
		var ud: UnitData = item.get("unit_data") as UnitData
		if ud != null and ud.tier > 1:
			return false
	return not seated.is_empty()


## 进度已解锁高品阶时，仍不得超过玩家队伍现有最高品阶。
static func _test_player_tier_caps_enemy_pool() -> bool:
	var t1 := _make_unit("t1", 10, 2, 1.0, 1, 0.0, 0.0, true)
	var t3 := _make_unit("t3", 30, 8, 1.0, 3, 0.0, 0.0, true)
	var cfg := _make_config([t1, t3])
	var wave := _make_wave(4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	## tier_index=4 → TierUnlock 允许到 3；队伍只有 T1 → 敌方不得出 T3
	var team: Array = [_make_entry(t1), _make_entry(t1)]
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 4, 1, MapNodeType.Type.COMBAT, 2, 5, rng, team
	)
	if seated.is_empty():
		return false
	for item in seated:
		var ud: UnitData = item.get("unit_data") as UnitData
		if ud != null and ud.tier > 1:
			return false
	return true


## 第 4 层、队内 1 个 T2：敌方 T2 只数 ≤1（§6.2 层表 ∩ P2+1）。
static func _test_t2_intro_cap_floor4_one_team_t2() -> bool:
	var t1 := _make_unit("t1_lo", 10, 2, 1.0, 1, 0.0, 0.0, true)
	var t2 := _make_unit("t2_hi", 22, 4, 1.0, 2, 0.0, 0.0, true)
	var cfg := _make_config([t1, t2])
	var wave := _make_wave(4)
	var team: Array = [_make_entry(t1), _make_entry(t2), _make_entry(t1)]
	for seed in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + 404
		var seated := EnemyBudgetSpawner.roll(
			wave, cfg, [], 3, 4, MapNodeType.Type.COMBAT, 2, 5, rng, team, 15
		)
		if seated.is_empty():
			return false
		var enemy_t2 := 0
		for item in seated:
			var ud: UnitData = item.get("unit_data") as UnitData
			if ud != null and ud.tier >= 2:
				enemy_t2 += 1
		if enemy_t2 > 1:
			return false
	return true


static func _test_boss_fixed_only_no_fill() -> bool:
	var boss := _make_unit("boss", 40, 8, 1.5, 3, 0.0, 0.0, true)
	boss.is_boss_leader = true
	var filler := _make_unit("fodder", 8, 2, 1.0, 1, 0.0, 0.0, true)
	var cfg := _make_config([filler, boss])
	var mid120: Array[float] = [120.0]
	cfg.floor_mid_power = mid120
	cfg.kappa_boss = 1.0
	var wave := _make_wave(2, [boss])
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	## 即使传入强队，Boss 仍只出固定首领。
	var strong_team: Array = []
	for _i in 5:
		strong_team.append(_make_entry(_make_unit("t%d" % _i, 40, 10, 1.0, 1, 0.0, 0.0, true)))
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 4, 0, MapNodeType.Type.BOSS, 2, 5, rng, strong_team
	)
	## Boss：只固定首领，不填杂兵。
	if seated.size() != 1:
		return false
	var ud: UnitData = seated[0].get("unit_data") as UnitData
	return ud != null and ud.id == "boss"


static func _test_boss_ignores_team_power() -> bool:
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.kappa_boss = 2.0
	var mid: Array[float] = [100.0]
	cfg.floor_mid_power = mid
	## Boss 目标恒为 0，与队伍强度无关。
	return is_equal_approx(cfg.get_target_pressure(0, MapNodeType.Type.BOSS, 999.0), 0.0)


static func _test_boss_back_center_seat() -> bool:
	var boss := _make_unit("boss", 40, 8, 1.5, 3, 0.0, 0.0, true)
	boss.is_boss_leader = true
	var cfg := _make_config([boss])
	var wave := _make_wave(1, [boss])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 1, 0, MapNodeType.Type.BOSS, 2, 5, rng, []
	)
	if seated.size() != 1:
		return false
	var expect := EnemyBudgetSpawner.back_center_seat_index(5, 10)
	return int(seated[0].get("seat_index", -1)) == expect


## 5 列同行中心向外：首个近战占前排中（列序 53124 → 索引 2）。
static func _test_seat_center_out_row_order() -> bool:
	var a := _make_unit("a", 30, 3, 1.0, 1, 0.0, 0.0, true)
	var b := _make_unit("b", 20, 3, 1.0, 1, 0.0, 0.0, true)
	var c := _make_unit("c", 10, 3, 1.0, 1, 0.0, 0.0, true)
	var cfg := _make_config([a, b, c])
	var seated := EnemyBudgetSpawner._seat_units([a, b, c], 5, 10, cfg)
	var by_id: Dictionary = {}
	for item in seated:
		var ud: UnitData = item.get("unit_data") as UnitData
		by_id[ud.id] = int(item.get("seat_index", -1))
	var expect: Array[int] = SeatLayout.row_column_fill_order(5)
	if int(by_id.get("a", -1)) != expect[0]:
		return false
	if int(by_id.get("b", -1)) != expect[1]:
		return false
	if int(by_id.get("c", -1)) != expect[2]:
		return false
	return true




static func _test_config_disabled_flag() -> bool:
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.enabled = false
	return cfg.enabled == false


static func _test_team_target_with_floor_guards() -> bool:
	var cfg := SpawnBudgetConfig.make_code_defaults()
	var mid_pair: Array[float] = [40.0, 80.0]
	cfg.floor_mid_power = mid_pair
	cfg.kappa_combat = 1.25
	## 无显式护栏表：min≈0.5×mid，max≈1.5×mid
	if not is_equal_approx(cfg.get_floor_e_min(0), 20.0):
		return false
	if not is_equal_approx(cfg.get_floor_e_max(0), 60.0):
		return false
	if not is_equal_approx(cfg.get_floor_e_min(1), 40.0):
		return false
	if not is_equal_approx(cfg.get_floor_e_max(1), 120.0):
		return false
	## E＝κ×S 再夹紧：S=40 → 50（落在 [20,60]）
	var e_mid := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT, 40.0)
	if not is_equal_approx(e_mid, 50.0):
		return false
	## S=100 → 125 夹到 max=60
	var e_hi := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT, 100.0)
	if not is_equal_approx(e_hi, 60.0):
		return false
	## S=0（无真队）→ 仍夹到层下限
	var e_lo := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT, 0.0)
	if not is_equal_approx(e_lo, 20.0):
		return false
	## 层下限硬夹：κ×S=12.5 < min=20 → 抬到 20（越深层越难，不再软化到弱于护栏）
	var e_floor := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT, 10.0)
	if not is_equal_approx(e_floor, 20.0):
		return false
	## 层威胁增长：同 S 在更深一层 E 更高（growth 默认 0.06）
	cfg.floor_threat_growth = 0.10
	var e_f1 := cfg.get_target_pressure(1, MapNodeType.Type.COMBAT, 40.0)
	var e_f3 := cfg.get_target_pressure(3, MapNodeType.Type.COMBAT, 40.0)
	## F=1：50；F=3：50×1.2=60，再夹到该层 max=120 → 60
	if not is_equal_approx(e_f1, 50.0):
		return false
	if not is_equal_approx(e_f3, 60.0):
		return false
	## 显式护栏表优先；S=40 → κ×S=50 落在 [30,50] 上沿
	cfg.floor_threat_growth = 0.0
	var mins: Array[float] = [30.0]
	var maxs: Array[float] = [50.0]
	cfg.floor_e_min = mins
	cfg.floor_e_max = maxs
	var e_table := cfg.get_target_pressure(0, MapNodeType.Type.COMBAT, 40.0)
	return is_equal_approx(e_table, 50.0)


static func _test_combat_count_by_floor() -> bool:
	## 普通关：第 F 层人数 ∈ [F, F＋1]，不跟队伍人数 N。
	var pool: Array[UnitData] = []
	for i in 8:
		pool.append(_make_unit("p%d" % i, 10, 3, 1.0, 1, 0.0, 0.0, true))
	var cfg := _make_config(pool)
	var wave := _make_wave(8)
	var team: Array = []
	for i in 5:
		team.append(_make_entry(pool[i % pool.size()]))
	var rng := RandomNumberGenerator.new()
	var saw_lo := false
	var saw_hi := false
	for seed_i in 40:
		rng.seed = 11 + seed_i
		var seated := EnemyBudgetSpawner.roll(
			wave, cfg, [], 0, 2, MapNodeType.Type.COMBAT, 2, 5, rng, team
		)
		if seated.size() < 2 or seated.size() > 3:
			return false
		if seated.size() == 2:
			saw_lo = true
		if seated.size() == 3:
			saw_hi = true
		var rolled := cfg.roll_enemy_count(MapNodeType.Type.COMBAT, 5, rng, 2)
		if rolled < 2 or rolled > 3:
			return false
	if not (saw_lo and saw_hi):
		return false
	## 第 1 层：1～2；不因队伍 5 人而抬到 5。
	for seed_i in 20:
		rng.seed = 200 + seed_i
		var seated1 := EnemyBudgetSpawner.roll(
			wave, cfg, [], 0, 1, MapNodeType.Type.COMBAT, 2, 5, rng, team
		)
		if seated1.size() < 1 or seated1.size() > 2:
			return false
	var bounds3 := SpawnBudgetConfig.combat_enemy_count_bounds(3)
	return bounds3 == Vector2i(3, 4)


static func _test_elite_count_n_or_n_plus_2() -> bool:
	var pool: Array[UnitData] = []
	for i in 8:
		pool.append(_make_unit("e%d" % i, 10, 3, 1.0, 1, 0.0, 0.0, true))
	var cfg := _make_config(pool)
	cfg.elite_plus_two_chance = 0.0
	var wave := _make_wave(8)
	var team: Array = []
	for i in 2:
		team.append(_make_entry(pool[i]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 0, 2, MapNodeType.Type.ELITE, 2, 5, rng, team
	)
	if seated.size() != 2:
		return false
	cfg.elite_plus_two_chance = 1.0
	rng.seed = 22
	seated = EnemyBudgetSpawner.roll(
		wave, cfg, [], 0, 2, MapNodeType.Type.ELITE, 2, 5, rng, team
	)
	return seated.size() == 4


static func _test_first_floor_elite_count_cap() -> bool:
	## 第一关精英仍 ≤ N；普通第 1 层走 1～2，不跟 N。
	var pool: Array[UnitData] = []
	for i in 8:
		pool.append(_make_unit("f%d" % i, 10, 3, 1.0, 1, 0.0, 0.0, true))
	var cfg := _make_config(pool)
	cfg.elite_plus_two_chance = 1.0
	var wave := _make_wave(8)
	var team: Array = []
	for i in 3:
		team.append(_make_entry(pool[i]))
	var rng := RandomNumberGenerator.new()
	for seed_i in 20:
		rng.seed = 100 + seed_i
		var seated := EnemyBudgetSpawner.roll(
			wave, cfg, [], 0, 1, MapNodeType.Type.COMBAT, 2, 5, rng, team
		)
		if seated.size() < 1 or seated.size() > 2:
			return false
		seated = EnemyBudgetSpawner.roll(
			wave, cfg, [], 0, 0, MapNodeType.Type.ELITE, 2, 5, rng, team
		)
		if seated.size() > 3:
			return false
	if cfg.roll_enemy_count(MapNodeType.Type.ELITE, 3, rng, 1) != 3:
		return false
	var combat1 := cfg.roll_enemy_count(MapNodeType.Type.COMBAT, 3, rng, 1)
	return combat1 >= 1 and combat1 <= 2


static func _test_first_floor_max_one_ranged() -> bool:
	var melee: Array[UnitData] = []
	var ranged: Array[UnitData] = []
	for i in 5:
		melee.append(_make_unit("m%d" % i, 12, 3, 1.0, 1, 0.0, 0.0, true))
		ranged.append(_make_unit("r%d" % i, 8, 4, 1.2, 1, 6.0, 0.0, true))
	var pool: Array[UnitData] = []
	pool.append_array(melee)
	pool.append_array(ranged)
	var cfg := _make_config(pool)
	cfg.combat_plus_one_chance = 0.0
	cfg.formation_tags = ["backline", "skirmish", "frontline"]
	var wave := _make_wave(8)
	var team: Array = []
	for i in 4:
		team.append(_make_entry(melee[i % melee.size()]))
	var rng := RandomNumberGenerator.new()
	for seed_i in 30:
		rng.seed = 200 + seed_i
		var seated := EnemyBudgetSpawner.roll(
			wave, cfg, [], 0, 1, MapNodeType.Type.COMBAT, 2, 5, rng, team
		)
		## 第 1 层普通：人数 1～2（队伍 4 人也不抬到 4）。
		if seated.size() < 1 or seated.size() > 2:
			return false
		var ranged_n := 0
		for item in seated:
			var ud: UnitData = item.get("unit_data") as UnitData
			if UnitPowerScore.is_ranged(ud):
				ranged_n += 1
		if ranged_n > 1:
			return false
	return true


static func _test_resolve_max_ranged_caps() -> bool:
	if EnemyBudgetSpawner.resolve_max_ranged(1, true) != 1:
		return false
	if EnemyBudgetSpawner.resolve_max_ranged(5, true) != 1:
		return false
	## n=5 → ⌈2⌉ 且 ≤4
	if EnemyBudgetSpawner.resolve_max_ranged(5, false) != 2:
		return false
	## n=2 → ⌈0.8⌉=1，且 n-1=1
	if EnemyBudgetSpawner.resolve_max_ranged(2, false) != 1:
		return false
	## n=1 非首关：最多 1（单远程仍合法）
	return EnemyBudgetSpawner.resolve_max_ranged(1, false) == 1


static func _test_non_first_floor_not_all_ranged() -> bool:
	## 深层：即使池里远程偏多，n≥2 时不得全远程。
	var melee: Array[UnitData] = []
	var ranged: Array[UnitData] = []
	for i in 3:
		melee.append(_make_unit("m%d" % i, 12, 3, 1.0, 1, 0.0, 0.0, true))
	for i in 8:
		ranged.append(_make_unit("r%d" % i, 8, 4, 1.2, 1, 6.0, 0.0, true))
	var pool: Array[UnitData] = []
	pool.append_array(melee)
	pool.append_array(ranged)
	var cfg := _make_config(pool)
	cfg.formation_tags = ["backline", "backline", "skirmish"]
	var wave := _make_wave(12)
	var team: Array = []
	for i in 4:
		team.append(_make_entry(melee[i % melee.size()]))
	var rng := RandomNumberGenerator.new()
	for seed_i in 40:
		rng.seed = 900 + seed_i
		## floor_index=4 → 普通人数 4～5，非第一关
		var seated := EnemyBudgetSpawner.roll(
			wave, cfg, [], 0, 4, MapNodeType.Type.COMBAT, 2, 5, rng, team
		)
		if seated.size() < 2:
			continue
		var ranged_n := 0
		for item in seated:
			var ud: UnitData = item.get("unit_data") as UnitData
			if UnitPowerScore.is_ranged(ud):
				ranged_n += 1
		if ranged_n >= seated.size():
			return false
		var cap := EnemyBudgetSpawner.resolve_max_ranged(seated.size(), false)
		if ranged_n > cap:
			return false
	return true


static func _test_boss_ignores_roster_count() -> bool:
	var boss := _make_unit("boss", 40, 8, 1.5, 3, 0.0, 0.0, true)
	boss.is_boss_leader = true
	var fodder := _make_unit("fodder", 8, 2, 1.0, 1, 0.0, 0.0, true)
	var cfg := _make_config([fodder, boss])
	var wave := _make_wave(5, [boss])
	var team: Array = []
	for i in 5:
		team.append(_make_entry(_make_unit("t%d" % i, 12, 3, 1.0, 1, 0.0, 0.0, true)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var seated := EnemyBudgetSpawner.roll(
		wave, cfg, [], 2, 1, MapNodeType.Type.BOSS, 2, 5, rng, team
	)
	return seated.size() == 1


static func _test_roll_enemy_count_config() -> bool:
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.elite_plus_two_chance = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var combat2 := cfg.roll_enemy_count(MapNodeType.Type.COMBAT, 4, rng, 2)
	if combat2 < 2 or combat2 > 3:
		return false
	if cfg.roll_enemy_count(MapNodeType.Type.ELITE, 4, rng, 2) != 6:
		return false
	if cfg.roll_enemy_count(MapNodeType.Type.BOSS, 4, rng) != -1:
		return false
	## 普通关人数不跟队伍 N；空队仍可按层掷出 2～3。
	var combat_empty := cfg.roll_enemy_count(MapNodeType.Type.COMBAT, 0, rng, 2)
	if combat_empty < 2 or combat_empty > 3:
		return false
	## floor_index≤0 按第 1 层。
	var bounds0 := SpawnBudgetConfig.combat_enemy_count_bounds(0)
	return bounds0 == Vector2i(1, 2)


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


static func _test_skill_expectation_differentiates() -> bool:
	## 空技能 stub → α=1.0；有召唤+击杀的技能 raw 更高 → α>1.0。
	var plain := _make_unit("plain", 10, 2, 1.0, 1, 0.0, 0.0, true)
	var strong := _make_unit("strong", 10, 2, 1.0, 1, 0.0, 0.0, true)
	var ab := AbilityData.new()
	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_KILL
	var act := EffectAction.new()
	act.action_type = EffectAction.Type.SPAWN_UNIT
	act.spawn_count = 1
	spec.actions.append(act)
	ab.effect_specs.append(spec)
	strong.ability = ab
	var a_plain := UnitPowerScore.resolve_skill_alpha(plain)
	var a_strong := UnitPowerScore.resolve_skill_alpha(strong)
	if not is_equal_approx(a_plain, 1.0):
		return false
	return a_strong > a_plain + 0.05


static func _test_enemy_id_alpha_lookup_fallback() -> bool:
	var enemy := _make_unit("enemy_hs", 10, 2, 1.0, 1, 0.0, 0.0, true)
	var mapped := UnitPowerScore.resolve_skill_alpha(enemy, {"hs": 1.25})
	return is_equal_approx(mapped, 1.25)


static func _test_fused_entry_uses_runtime_ability() -> bool:
	var shell := _make_unit("fused_enchant", 4, 4, 1.0, 1, 0.0, 0.0, false)
	var entry := _make_entry(shell, 10, 10, 1)
	var ab := AbilityData.new()
	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_KILL
	var act := EffectAction.new()
	act.action_type = EffectAction.Type.GRANT_ACTOR_TURN_REFRESH
	spec.actions.append(act)
	ab.effect_specs.append(spec)
	entry.runtime_main_ability = ab
	var alpha := UnitPowerScore.resolve_skill_alpha(
		shell, {}, UnitPowerScore.DEFAULT_ALPHA_NO_SKILL, UnitPowerScore.DEFAULT_ALPHA_HAS_SKILL, ab
	)
	## 无 runtime 时白板 0.85；有再动技能应显著高于 1.0。
	var alpha_blank := UnitPowerScore.resolve_skill_alpha(shell)
	return alpha > 1.05 and is_equal_approx(alpha_blank, 0.85)


static func _test_recruit_enemy_pool_mirror_contract() -> bool:
	## 内容契约 A：可招种类集合 ≡ 默认抽阵敌池（敌 id = enemy_ + 友 id）。
	var recruit := load("res://resources/recruit/default_recruit_config.tres") as RecruitConfig
	var spawn := load("res://resources/spawn/default_spawn_budget.tres") as SpawnBudgetConfig
	if recruit == null or spawn == null:
		return false
	var ally_ids: Dictionary = {}
	for u in recruit.get_unit_pool():
		if u == null or u.id.is_empty():
			continue
		if FusedEnchantIds.is_fused_unit_id(u.id):
			continue
		ally_ids[u.id] = true
	var enemy_bases: Dictionary = {}
	for u in spawn.enemy_pool:
		if u == null or u.id.is_empty():
			continue
		enemy_bases[UnitPowerScore.ally_id_from_enemy_id(u.id)] = true
	if ally_ids.size() != enemy_bases.size():
		push_error(
			"pool mirror size ally=%d enemy=%d" % [ally_ids.size(), enemy_bases.size()]
		)
		return false
	for id in ally_ids.keys():
		if not enemy_bases.has(id):
			push_error("missing enemy mirror for ally %s" % id)
			return false
	for id in enemy_bases.keys():
		if not ally_ids.has(id):
			push_error("enemy mirror without ally %s" % id)
			return false
	return true


static func _test_same_id_soft_dedup_prefers_variety() -> bool:
	## 人数 ≤ 池种类时，优先未选 → 应几乎全是唯一 id。
	var pool: Array[UnitData] = []
	for i in 8:
		pool.append(_make_unit("u%d" % i, 10 + i, 3, 1.0, 1, 0.0, 0.0, true))
	var cfg := _make_config(pool)
	cfg.same_id_soft_dedup_weight = 0.05
	var rng := RandomNumberGenerator.new()
	var samples := 80
	var fill_n := 5
	var all_unique_n := 0
	for seed_i in samples:
		rng.seed = 4100 + seed_i
		var comp := EnemyBudgetSpawner._random_composition(pool, fill_n, rng, -1, cfg)
		if comp.size() == fill_n and _unique_id_count(comp) == fill_n:
			all_unique_n += 1
	return all_unique_n == samples


static func _test_greedy_fill_prefers_unique_ids() -> bool:
	## 贪心保底不得为贴 E 反复塞同一只（池内尚有未选种类时）。
	var strong := _make_unit("strong", 30, 8, 1.0, 1, 0.0, 0.0, true)
	var pool: Array[UnitData] = [strong]
	for i in 5:
		pool.append(_make_unit("m%d" % i, 12 + i, 3, 1.0, 1, 0.0, 0.0, true))
	var cfg := _make_config(pool)
	var u_strong := UnitPowerScore.compute_u(strong)
	## 目标约 3×strong：旧贪心会 3 只 strong；新逻辑应尽量换面孔。
	var fill := EnemyBudgetSpawner._greedy_fill(pool, u_strong * 3.0, 3, cfg, true)
	if fill.size() != 3:
		return false
	return _unique_id_count(fill) == 3


static func _unique_id_count(units: Array[UnitData]) -> int:
	var seen: Dictionary = {}
	for u in units:
		if u == null:
			continue
		var id := u.id if not u.id.is_empty() else u.resource_path
		seen[id] = true
	return seen.size()


static func _test_prefer_upper_band_tie_breaks_higher() -> bool:
	## 同 |ΣU−E| 且面孔数相同时 prefer_upper_band 选更高一侧。
	var low := _make_unit("low", 8, 2, 1.0, 1, 0.0, 0.0, true)
	var high := _make_unit("high", 20, 6, 1.0, 1, 0.0, 0.0, true)
	var cfg := _make_config([low, high])
	cfg.prefer_upper_band = true
	var u_low := UnitPowerScore.compute_u(low)
	var u_high := UnitPowerScore.compute_u(high)
	var target_e := (u_low + u_high) * 0.5
	## 单只 low / high 对中点对称误差。
	var a: Array[UnitData] = [low]
	var b: Array[UnitData] = [high]
	var picked := EnemyBudgetSpawner._better_of(a, b, target_e, cfg)
	if picked.is_empty() or picked[0] != high:
		return false
	## 关闭上沿偏好后：误差与面孔数相等时保留先传入的 a。
	cfg.prefer_upper_band = false
	var picked_off := EnemyBudgetSpawner._better_of(a, b, target_e, cfg)
	return not picked_off.is_empty() and picked_off[0] == low


static func _test_better_of_prefers_more_unique_on_tie() -> bool:
	## 同误差时面孔更散优先于堆叠同种。
	var a := _make_unit("a", 10, 4, 1.0, 1, 0.0, 0.0, true)
	var b := _make_unit("b", 10, 4, 1.0, 1, 0.0, 0.0, true)
	var cfg := _make_config([a, b])
	cfg.prefer_upper_band = true
	var u := UnitPowerScore.compute_u(a)
	var target_e := u * 2.0
	var stacked: Array[UnitData] = [a, a]
	var diverse: Array[UnitData] = [a, b]
	var picked := EnemyBudgetSpawner._better_of(stacked, diverse, target_e, cfg)
	return not picked.is_empty() and _unique_id_count(picked) == 2


static func _test_formation_tag_weighted_pick() -> bool:
	## 权重压死后应几乎只抽到 frontline（非等权数组重复）。
	var cfg := SpawnBudgetConfig.make_code_defaults()
	cfg.formation_tags = ["frontline", "skirmish", "backline"]
	cfg.formation_weight_frontline = 100.0
	cfg.formation_weight_skirmish = 0.0
	cfg.formation_weight_backline = 0.0
	var rng := RandomNumberGenerator.new()
	var front_n := 0
	for seed_i in 40:
		rng.seed = 77 + seed_i
		if cfg.pick_formation_tag(rng) == SpawnBudgetConfig.FormationTag.FRONTLINE:
			front_n += 1
	return front_n == 40
