class_name RealtimeCombatSimTest
extends RefCounted
## Headless 单测：八向格步 / 一格一体 / 切比雪夫出手 / 投射物 / 部署 / 溅射 / 胜负 / 确定性。

const ARENA := Vector2i(18, 32)

static var _created: Array[RealtimeCombatSim] = []


static func run_all() -> bool:
	var ok := true
	ok = _check("melee_approach_and_interval", _test_melee_approach_and_interval()) and ok
	ok = _check("eight_dir_diagonal_step", _test_eight_dir_diagonal_step()) and ok
	ok = _check("occupancy_blocks_or_detours", _test_occupancy_blocks_or_detours()) and ok
	ok = _check("chebyshev_attack_reach", _test_chebyshev_attack_reach()) and ok
	ok = _check("ally_blocker_melee_reach", _test_ally_blocker_melee_reach()) and ok
	ok = _check("ranged_projectile_delay", _test_ranged_projectile_delay()) and ok
	ok = _check("deploy_time_freezes", _test_deploy_time_freezes()) and ok
	ok = _check("deploy_after_begin_before_first_step", _test_deploy_after_begin_before_first_step()) and ok
	ok = _check("one_unit_per_cell_on_spawn", _test_one_unit_per_cell_on_spawn()) and ok
	ok = _check("splash_hits_cluster", _test_splash_hits_cluster()) and ok
	ok = _check("occupancy_no_shared_cells", _test_occupancy_no_shared_cells()) and ok
	ok = _check("win_and_bus_death_events", _test_win_and_bus_death_events()) and ok
	ok = _check("lose_when_no_player_alive", _test_lose_when_no_player_alive()) and ok
	ok = _check("determinism_frame_rate_independent", _test_determinism_frame_rate_independent()) and ok
	ok = _check("projectile_vanishes_when_target_dead", _test_projectile_vanishes_when_target_dead()) and ok
	for sim in _created:
		sim.dispose()
	_created.clear()
	if ok:
		print("RealtimeCombatSimTest: all passed")
	return ok


static func _new_sim(bus: CombatEventBus = null) -> RealtimeCombatSim:
	var sim := RealtimeCombatSim.new(bus)
	_created.append(sim)
	return sim


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("  PASS %s" % name)
	else:
		push_error("RealtimeCombatSimTest: FAIL %s" % name)
	return passed


static func make_unit(team: UnitInstance.Team, overrides: Dictionary = {}) -> UnitInstance:
	var stats := UnitStats.new()
	stats.max_hp = 100
	stats.attack = 10
	stats.crit_rate_percent = 0
	stats.move_speed = 1.0
	stats.attack_interval = 1.0
	stats.attack_windup = 0.3
	stats.attack_reach = 1.0
	stats.sight_range = 5.5
	stats.body_radius = 0.4
	stats.mass = 1.0
	stats.projectile_speed = 0.0
	stats.splash_radius = 0.0
	stats.deploy_time = 0.0
	for key in overrides.keys():
		stats.set(key, overrides[key])
	var data := UnitData.new()
	data.id = String(overrides.get("id", "test_unit"))
	data.display_name = String(overrides.get("display_name", "测试"))
	data.stats = stats
	return UnitInstance.from_unit_data(data, Vector2i.ZERO, team)


## 不会主动伤人的木桩
static func make_dummy(team: UnitInstance.Team, hp: int = 100000, overrides: Dictionary = {}) -> UnitInstance:
	var params := {
		"max_hp": hp,
		"move_speed": 0.0,
		"attack_windup": 5.0,
		"attack_interval": 10.0,
		"attack": 1,
		"sight_range": 0.0,
		"attack_reach": 0.0,
	}
	params.merge(overrides, true)
	return make_unit(team, params)


static func _run_until(sim: RealtimeCombatSim, seconds: float) -> void:
	while sim.elapsed_seconds < seconds - 0.0001 and not sim.is_finished():
		sim.advance_fixed_step()


static func _test_melee_approach_and_interval() -> bool:
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 1)
	## 格距 8；移速 2 格/秒 → 约 4s 贴邻格；+前摇 0.3
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {"move_speed": 2.0, "attack_reach": 1.0}),
		Vector2(9.5, 28.5),
	)
	var dummy := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 20.5))
	var hit_times: Array[float] = []
	var hit_dists: Array[int] = []
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DAMAGE_TAKEN and payload.target == dummy.unit:
				hit_times.append(sim.elapsed_seconds)
				hit_dists.append(attacker.cell_distance_to(dummy))
	)
	_run_until(sim, 1.0)
	var moved_early := attacker.cell.y <= 26
	_run_until(sim, 10.0)
	bus.free()
	if not moved_early:
		push_error("melee: attacker did not step toward target (cell=%s)" % attacker.cell)
		return false
	if hit_times.size() < 3:
		push_error("melee: expected >=3 hits, got %d" % hit_times.size())
		return false
	## 距 8→邻格约 7 步；移速 2 + 前摇 0.3，首击约 3~4s（衔步会略提前）
	if hit_times[0] < 2.8 or hit_times[0] > 4.2:
		push_error("melee: first hit at %.3f, expected ~3.1–3.8" % hit_times[0])
		return false
	for i in range(1, hit_times.size()):
		if absf(hit_times[i] - hit_times[i - 1] - 1.0) > 0.04:
			push_error("melee: interval %.3f != 1.0" % (hit_times[i] - hit_times[i - 1]))
			return false
	for d in hit_dists:
		if float(d) > 1.0 + RtUnitBrain.REACH_HYSTERESIS:
			push_error("melee: hit from cell distance %d" % d)
			return false
	if dummy.unit.current_hp != 100000 - 10 * hit_times.size():
		push_error("melee: hp mismatch %d" % dummy.unit.current_hp)
		return false
	return true


## 对角目标时第一步应走斜向邻格（八方向）。
static func _test_eight_dir_diagonal_step() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 12)
	var mover := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 30.0,
			"attack_reach": 1.0,
			"attack_windup": 5.0,
			"sight_range": 30.0,
		}),
		Vector2(5.5, 25.5),
	)
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(8.5, 22.5))
	var start := mover.cell
	## 单固定步：逻辑格应立刻斜向踏入一格（八方向）
	sim.advance_fixed_step()
	var delta: Vector2i = mover.cell - start
	if absi(delta.x) != 1 or absi(delta.y) != 1:
		push_error("eight_dir: expected one diagonal step, got delta=%s cell=%s" % [delta, mover.cell])
		return false
	return true


## 正前方邻格被占时改道或短等，不得与挡路者同格。
static func _test_occupancy_blocks_or_detours() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 13)
	var mover := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 4.0,
			"attack_reach": 1.0,
			"attack_windup": 5.0,
			"sight_range": 30.0,
		}),
		Vector2(9.5, 26.5),
	)
	var blocker := sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {"id": "blocker"}),
		Vector2(9.5, 25.5),
	)
	var enemy := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY),
		Vector2(9.5, 20.5),
	)
	_run_until(sim, 3.0)
	if mover.cell == blocker.cell:
		push_error("occupancy: mover shared cell with blocker %s" % mover.cell)
		return false
	## 应绕开并缩短与敌人的格距
	if mover.cell_distance_to(enemy) >= RtUnit.chebyshev(Vector2i(9, 26), enemy.cell):
		push_error("occupancy: mover did not approach (cell=%s dist=%d)" % [mover.cell, mover.cell_distance_to(enemy)])
		return false
	return true


## 出手只认切比雪夫：邻格可打，距 2 且 reach=1 不可打。
static func _test_chebyshev_attack_reach() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 14)
	## 对角邻格：欧氏 √2，切比雪夫 1 → 应能出手
	var a := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 0.0, "attack_reach": 1.0, "attack_windup": 0.0, "attack_interval": 1.0,
		}),
		Vector2(9.5, 20.5),
	)
	var diag := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(10.5, 19.5))
	_run_until(sim, 0.1)
	if a.cell_distance_to(diag) != 1:
		push_error("chebyshev: setup dist=%d" % a.cell_distance_to(diag))
		return false
	if diag.unit.current_hp >= diag.unit.get_effective_max_hp():
		push_error("chebyshev: diagonal adjacent should be in reach")
		return false

	var sim2 := _new_sim()
	sim2.configure(ARENA, 15)
	var b := sim2.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 0.0, "attack_reach": 1.0, "attack_windup": 0.0, "attack_interval": 1.0,
		}),
		Vector2(9.5, 20.5),
	)
	var far := sim2.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 18.5))
	_run_until(sim2, 0.2)
	if b.cell_distance_to(far) != 2:
		push_error("chebyshev: far setup dist=%d" % b.cell_distance_to(far))
		return false
	if far.unit.current_hp != far.unit.get_effective_max_hp():
		push_error("chebyshev: dist 2 should be out of reach 1")
		return false
	return true


## 友军堵在正前方时，攻击者应绕行并最终进入攻距格。
static func _test_ally_blocker_melee_reach() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 11)
	var attack_reach := 1.0
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 2.5,
			"attack_reach": attack_reach,
			"attack_windup": 5.0,
			"attack_interval": 10.0,
			"attack": 1,
			"sight_range": 20.0,
		}),
		Vector2(9.5, 28.5),
	)
	sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {"id": "ally_blocker"}),
		Vector2(9.5, 24.5),
	)
	var enemy := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "enemy_dummy"}),
		Vector2(9.5, 20.5),
	)
	var timeout := 20.0
	var reached := false
	while sim.elapsed_seconds < timeout - 0.0001 and not sim.is_finished():
		sim.advance_fixed_step()
		if float(attacker.cell_distance_to(enemy)) <= attack_reach + RtUnitBrain.REACH_EPSILON:
			reached = true
			break
	if not reached:
		push_error(
			"ally_blocker: never entered attack reach (dist=%d cell=%s t=%.2f)"
			% [attacker.cell_distance_to(enemy), attacker.cell, sim.elapsed_seconds]
		)
		return false
	return true


static func _test_ranged_projectile_delay() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 2)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack_reach": 5.0, "attack_windup": 0.0, "projectile_speed": 4.0, "move_speed": 0.0,
		}),
		Vector2(9.5, 26.5),
	)
	var dummy := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 21.5))
	var spawned: Array[float] = []
	sim.projectile_spawned.connect(func(_p: RtProjectile) -> void: spawned.append(sim.elapsed_seconds))
	_run_until(sim, 0.1)
	if spawned.is_empty() or sim.get_projectiles().is_empty():
		push_error("ranged: projectile not spawned")
		return false
	if dummy.unit.current_hp != dummy.unit.get_effective_max_hp():
		push_error("ranged: damage applied before projectile arrival")
		return false
	## 格心距 5、出手点减半径；速度 4 → 命中约在 1.1s 前后
	_run_until(sim, 0.7)
	if dummy.unit.current_hp != dummy.unit.get_effective_max_hp():
		push_error("ranged: damage applied too early (t=0.7)")
		return false
	_run_until(sim, 1.5)
	if dummy.unit.current_hp != dummy.unit.get_effective_max_hp() - 10:
		push_error("ranged: expected one hit by t=1.5, hp=%d" % dummy.unit.current_hp)
		return false
	return true


static func _test_deploy_time_freezes() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 3)
	var start_cell := Vector2i(9, 28)
	var preplaced := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"deploy_time": 1.0, "move_speed": 0.0, "attack_reach": 0.0, "max_hp": 9999,
		}),
		Vector2(0.5, 31.5),
	)
	## 射手放在同列远处，格距须落在 attack_reach 内
	var shooter := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"attack_reach": 20.0, "sight_range": 40.0, "attack_windup": 0.0,
			"projectile_speed": 0.0, "move_speed": 0.0, "attack": 5,
		}),
		Vector2(9.5, 10.5),
	)
	sim.advance_fixed_step()
	if preplaced.is_deploying():
		push_error("deploy: units placed before combat start must act immediately")
		return false
	var deployed_at := sim.elapsed_seconds
	var deploying := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {"deploy_time": 1.0, "move_speed": 2.0}),
		RtUnit.cell_center(start_cell),
	)
	_run_until(sim, deployed_at + 0.9)
	if deploying.cell != start_cell or deploying.state != RtUnit.State.DEPLOYING:
		push_error("deploy: unit acted during deploy_time (cell=%s state=%d)" % [deploying.cell, deploying.state])
		return false
	if deploying.unit.current_hp >= deploying.unit.get_effective_max_hp():
		push_error(
			"deploy: deploying unit should be attackable (hp=%d dist=%d)"
			% [deploying.unit.current_hp, shooter.cell_distance_to(deploying)]
		)
		return false
	if sim.is_finished():
		push_error("deploy: deploying unit must count as present")
		return false
	_run_until(sim, deployed_at + 1.5)
	if deploying.cell.y >= start_cell.y:
		push_error("deploy: unit did not step after deploy_time (cell=%s)" % deploying.cell)
		return false
	return shooter.is_alive()


static func _test_deploy_after_begin_before_first_step() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 3)
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 3.5))
	sim.begin_combat()
	var late := sim.add_unit(make_unit(UnitInstance.Team.PLAYER, {"deploy_time": 1.0}), Vector2(9.5, 28.5))
	if not late.is_deploying():
		push_error("deploy: unit placed after begin_combat must wait deploy_time")
		return false
	return true


## 同坐标投放：第二人应落到邻格，保持一格一体。
static func _test_one_unit_per_cell_on_spawn() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 3)
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(0.5, 0.5))
	var a := sim.add_unit(make_dummy(UnitInstance.Team.PLAYER), Vector2(9.5, 28.5))
	var b := sim.add_unit(make_dummy(UnitInstance.Team.PLAYER, 100000, {"id": "second"}), Vector2(9.5, 28.5))
	if a.cell == b.cell:
		push_error("spawn: two units share cell %s" % a.cell)
		return false
	if sim.get_occupancy_owner(a.cell) != a or sim.get_occupancy_owner(b.cell) != b:
		push_error("spawn: occupancy map mismatch")
		return false
	return true


static func _test_splash_hits_cluster() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 4)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack_reach": 3.0, "attack_windup": 0.0, "move_speed": 0.0, "splash_radius": 1.0,
		}),
		Vector2(9.5, 23.5),
	)
	var primary := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 20.5))
	var near_a := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "near_a"}), Vector2(10.5, 20.5))
	var near_b := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "near_b"}), Vector2(9.5, 19.5))
	var far := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "far"}), Vector2(15.5, 20.5))
	var splashes: Array[float] = []
	sim.splash_triggered.connect(func(_c: Vector2, r: float) -> void: splashes.append(r))
	_run_until(sim, 0.1)
	var full := primary.unit.get_effective_max_hp()
	for rt in [primary, near_a, near_b]:
		if (rt as RtUnit).unit.current_hp != full - 10:
			push_error("splash: clustered enemy not hit (hp=%d cell=%s)" % [(rt as RtUnit).unit.current_hp, (rt as RtUnit).cell])
			return false
	if far.unit.current_hp != full:
		push_error("splash: far enemy should be untouched")
		return false
	return splashes.size() == 1 and is_equal_approx(splashes[0], 1.0)


## 多单位挤同一投放点后，任意时刻不应有两存活单位同逻辑格。
static func _test_occupancy_no_shared_cells() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 5)
	var center := Vector2(9.5, 16.5)
	for i in 6:
		var team := UnitInstance.Team.PLAYER if i % 2 == 0 else UnitInstance.Team.ENEMY
		sim.add_unit(make_dummy(team, 100000, {"id": "u%d" % i}), center)
	_run_until(sim, 2.0)
	var seen: Dictionary = {}
	for item in sim.get_units():
		var rt := item as RtUnit
		if not rt.is_alive():
			continue
		if seen.has(rt.cell):
			push_error("occupancy: shared cell %s" % rt.cell)
			return false
		seen[rt.cell] = true
		if sim.get_occupancy_owner(rt.cell) != rt:
			push_error("occupancy: map owner mismatch at %s" % rt.cell)
			return false
	return true


static func _test_win_and_bus_death_events() -> bool:
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 7)
	sim.add_unit(make_unit(UnitInstance.Team.PLAYER, {"attack": 60, "max_hp": 1000, "move_speed": 3.0, "attack_reach": 1.0}), Vector2(9.5, 24.5))
	sim.add_unit(make_unit(UnitInstance.Team.ENEMY, {"max_hp": 100, "attack": 1, "attack_reach": 1.0}), Vector2(8.5, 8.5))
	sim.add_unit(make_unit(UnitInstance.Team.ENEMY, {"max_hp": 100, "attack": 1, "attack_reach": 1.0}), Vector2(11.5, 6.5))
	var deaths: Array[UnitInstance] = []
	var starts: Array[int] = [0]
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DEATH:
				deaths.append(payload.target)
			elif event_type == CombatEvents.ON_COMBAT_START:
				starts[0] += 1
	)
	var finished_with: Array = []
	sim.combat_finished.connect(func(won: bool) -> void: finished_with.append(won))
	_run_until(sim, 60.0)
	bus.free()
	if not sim.is_finished() or not sim.did_player_win():
		push_error("win: expected player win (finished=%s)" % sim.is_finished())
		return false
	if finished_with != [true]:
		push_error("win: combat_finished emitted %s" % [finished_with])
		return false
	if deaths.size() != 2:
		push_error("win: expected 2 ON_DEATH, got %d" % deaths.size())
		return false
	for dead in deaths:
		if dead.team != UnitInstance.Team.ENEMY:
			push_error("win: unexpected death team")
			return false
	return starts[0] == 1


static func _test_lose_when_no_player_alive() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 8)
	sim.add_unit(make_unit(UnitInstance.Team.PLAYER, {"max_hp": 50, "attack": 1, "attack_reach": 1.0}), Vector2(9.5, 24.5))
	sim.add_unit(make_unit(UnitInstance.Team.ENEMY, {"max_hp": 1000, "attack": 30, "move_speed": 3.0, "attack_reach": 1.0}), Vector2(9.5, 6.5))
	var finished_with: Array = []
	sim.combat_finished.connect(func(won: bool) -> void: finished_with.append(won))
	_run_until(sim, 60.0)
	if not sim.is_finished() or sim.did_player_win() or finished_with != [false]:
		push_error("lose: expected player loss")
		return false
	return sim.count_alive(UnitInstance.Team.PLAYER) == 0


static func _build_mixed_scenario(seed_value: int) -> RealtimeCombatSim:
	var sim := _new_sim()
	sim.configure(ARENA, seed_value)
	var p := UnitInstance.Team.PLAYER
	var e := UnitInstance.Team.ENEMY
	sim.add_unit(make_unit(p, {"max_hp": 400, "attack": 25, "move_speed": 1.2, "mass": 3.0, "deploy_time": 1.0, "attack_reach": 1.0}), Vector2(8.5, 24.5))
	sim.add_unit(make_unit(p, {"max_hp": 150, "attack": 18, "attack_reach": 5.0, "projectile_speed": 8.0, "body_radius": 0.35}), Vector2(10.5, 27.5))
	sim.add_unit(make_unit(p, {"max_hp": 250, "attack": 15, "splash_radius": 1.0, "move_speed": 1.5, "attack_reach": 1.0}), Vector2(6.5, 25.5))
	sim.add_unit(make_unit(e, {"max_hp": 300, "attack": 20, "move_speed": 1.5, "deploy_time": 0.5, "attack_reach": 1.0}), Vector2(9.5, 6.5))
	sim.add_unit(make_unit(e, {"max_hp": 120, "attack": 12, "attack_reach": 4.5, "projectile_speed": 6.0, "splash_radius": 0.8}), Vector2(5.5, 4.5))
	for i in 4:
		sim.add_unit(make_unit(e, {"max_hp": 60, "attack": 8, "move_speed": 2.0, "body_radius": 0.3, "attack_reach": 1.0, "id": "swarm_%d" % i}), Vector2(11.5 + float(i), 8.5))
	return sim


static func _snapshot(sim: RealtimeCombatSim) -> Array:
	var out: Array = [sim.fixed_step_count, sim.is_finished(), sim.did_player_win()]
	for item in sim.get_units():
		var rt := item as RtUnit
		out.append([rt.unit.id, rt.unit.team, rt.cell, rt.unit.current_hp, rt.state])
	for item in sim.get_projectiles():
		var proj := item as RtProjectile
		out.append([proj.position, proj.damage])
	return out


static func _test_determinism_frame_rate_independent() -> bool:
	var a := _build_mixed_scenario(99)
	var b := _build_mixed_scenario(99)
	for _i in 720:
		a.step(1.0 / 60.0)
	for _i in 84:
		b.step(1.0 / 7.0)
	if a.fixed_step_count != 360:
		push_error("determinism: expected 360 fixed steps, got %d" % a.fixed_step_count)
		return false
	var snap_a := _snapshot(a)
	var snap_b := _snapshot(b)
	if snap_a != snap_b:
		push_error("determinism: mid-combat snapshots differ\n%s\n%s" % [snap_a, snap_b])
		return false
	if snap_a.size() <= 3:
		push_error("determinism: scenario ended too early to be meaningful")
		return false
	for _i in 6000:
		a.step(1.0 / 60.0)
		b.step(1.0 / 7.0)
		if a.is_finished() and b.is_finished():
			break
	if not a.is_finished() or not b.is_finished():
		push_error("determinism: scenario did not finish")
		return false
	if a.did_player_win() != b.did_player_win():
		push_error("determinism: different winners")
		return false
	return true


static func _test_projectile_vanishes_when_target_dead() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 10)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack_reach": 10.0, "attack_windup": 0.0, "projectile_speed": 1.0, "move_speed": 0.0, "attack": 50,
		}),
		Vector2(9.5, 28.5),
	)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack_reach": 1.0, "attack_windup": 0.0, "move_speed": 0.0, "attack": 1000,
		}),
		Vector2(9.5, 21.5),
	)
	var target := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100), Vector2(9.5, 20.5))
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(1.5, 1.5))
	_run_until(sim, 0.2)
	if target.is_alive():
		push_error("vanish: melee should have killed target")
		return false
	if not sim.get_projectiles().is_empty():
		push_error("vanish: projectile to dead target should disappear")
		return false
	return true
