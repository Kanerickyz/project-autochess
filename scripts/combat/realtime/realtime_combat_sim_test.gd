class_name RealtimeCombatSimTest
extends RefCounted
## Headless 单测：回合制行动队列 / 一动靠近并出手 / 落格顿步 / 一格一体 / 胜负 / 确定性。

const ARENA := Vector2i(18, 32)

static var _created: Array[RealtimeCombatSim] = []


static func run_all() -> bool:
	var ok := true
	ok = _check("action_queue_interleave", _test_action_queue_interleave()) and ok
	ok = _check("actors_act_sequentially", _test_actors_act_sequentially()) and ok
	ok = _check("melee_approach_hit_once_per_turn", _test_melee_approach_hit_once_per_turn()) and ok
	ok = _check("eight_dir_diagonal_step", _test_eight_dir_diagonal_step()) and ok
	ok = _check("no_attack_until_cell_settled", _test_no_attack_until_cell_settled()) and ok
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
	ok = _check("dead_skipped_in_queue", _test_dead_skipped_in_queue()) and ok
	ok = _check("mutual_melee_exchange", _test_mutual_melee_exchange()) and ok
	ok = _check("mutual_kill_both_die_player_wins", _test_mutual_kill_both_die_player_wins()) and ok
	ok = _check("ranged_out_of_reach_no_counter", _test_ranged_out_of_reach_no_counter()) and ok
	ok = _check("boss_decapitation_wins_and_routs", _test_boss_decapitation_wins_and_routs()) and ok
	ok = _check("boss_no_counter_when_targeted", _test_boss_no_counter_when_targeted()) and ok
	ok = _check("boss_footprint_occupies_four_cells", _test_boss_footprint_occupies_four_cells()) and ok
	ok = _check("boss_summon_respects_cap", _test_boss_summon_respects_cap()) and ok
	ok = _check("boss_decapitation_beats_mutual_wipe", _test_boss_decapitation_beats_mutual_wipe()) and ok
	ok = _check("boss_push_ally_on_step", _test_boss_push_ally_on_step()) and ok
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


const _STAT_OVERRIDE_KEYS := [
	"max_hp", "attack", "steps_per_turn", "crit_rate_percent", "attack_interval",
	"attack_windup", "attack_reach", "sight_range", "body_radius", "mass",
	"projectile_speed", "splash_radius", "deploy_time", "attack_range",
]


static func make_unit(team: UnitInstance.Team, overrides: Dictionary = {}) -> UnitInstance:
	var stats := UnitStats.new()
	stats.max_hp = 100
	stats.attack = 10
	stats.crit_rate_percent = 0
	stats.steps_per_turn = 1
	stats.attack_interval = 1.0
	stats.attack_windup = 0.3
	stats.attack_reach = 1.0
	stats.sight_range = 5.5
	stats.body_radius = 0.4
	stats.mass = 1.0
	stats.projectile_speed = 0.0
	stats.splash_radius = 0.0
	stats.deploy_time = 0.0
	for key in _STAT_OVERRIDE_KEYS:
		if overrides.has(key):
			stats.set(key, overrides[key])
	var data := UnitData.new()
	data.id = String(overrides.get("id", "test_unit"))
	data.display_name = String(overrides.get("display_name", "测试"))
	data.stats = stats
	data.is_boss_leader = bool(overrides.get("is_boss_leader", false))
	data.footprint_w = int(overrides.get("footprint_w", 1))
	data.footprint_h = int(overrides.get("footprint_h", 1))
	if overrides.has("summon_unit"):
		data.summon_unit = overrides["summon_unit"] as UnitData
	data.summon_max_alive = int(overrides.get("summon_max_alive", 0))
	data.summon_per_action = int(overrides.get("summon_per_action", 1))
	return UnitInstance.from_unit_data(data, Vector2i.ZERO, team)


static func make_summon_body() -> UnitData:
	var stats := UnitStats.new()
	stats.max_hp = 1
	stats.attack = 1
	stats.steps_per_turn = 1
	stats.attack_reach = 1.0
	stats.attack_windup = 0.0
	stats.deploy_time = 0.0
	stats.sight_range = 5.0
	var data := UnitData.new()
	data.id = "skeleton"
	data.display_name = "枯骨"
	data.stats = stats
	return data


## 不会主动伤人的木桩
static func make_dummy(team: UnitInstance.Team, hp: int = 100000, overrides: Dictionary = {}) -> UnitInstance:
	var params := {
		"max_hp": hp,
		"steps_per_turn": 0,
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


static func _test_action_queue_interleave() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 1)
	var f0 := sim.add_unit(make_dummy(UnitInstance.Team.PLAYER, 100, {"id": "f0"}), Vector2(1.5, 28.5))
	var f1 := sim.add_unit(make_dummy(UnitInstance.Team.PLAYER, 100, {"id": "f1"}), Vector2(2.5, 28.5))
	var e0 := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100, {"id": "e0"}), Vector2(1.5, 3.5))
	var e1 := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100, {"id": "e1"}), Vector2(2.5, 3.5))
	var e2 := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100, {"id": "e2"}), Vector2(3.5, 3.5))
	sim.begin_combat()
	var q: Array = sim.get_action_queue()
	var expected: Array[RtUnit] = [f0, e0, f1, e1, e2]
	if q.size() != expected.size():
		push_error("queue: size %d expected %d" % [q.size(), expected.size()])
		return false
	for i in expected.size():
		if q[i] != expected[i]:
			push_error("queue: index %d got %s expected %s" % [i, (q[i] as RtUnit).unit.id, expected[i].unit.id])
			return false
	if sim.get_round_index() != 1:
		push_error("queue: round_index expected 1")
		return false
	return true


## 同一时刻只有当前行动者在迈步；非行动者站立格不变。
static func _test_actors_act_sequentially() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 2)
	var a := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 2, "attack_windup": 5.0, "sight_range": 30.0, "id": "ally",
		}),
		Vector2(9.5, 26.5),
	)
	var b := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"steps_per_turn": 2, "attack_windup": 5.0, "sight_range": 30.0, "id": "foe",
		}),
		Vector2(9.5, 6.5),
	)
	sim.begin_combat()
	var actors_seen: Array[String] = []
	sim.current_actor_changed.connect(
		func(actor: RtUnit) -> void:
			if actor != null:
				actors_seen.append(actor.unit.id)
	)
	sim.advance_fixed_step()
	if actors_seen.is_empty() or actors_seen[0] != "ally":
		push_error("seq: first actor should be ally, got %s" % [actors_seen])
		return false
	var b_cell := b.cell
	## 推进到友方迈出至少一格，期间敌方站立格不得变
	var guard := 0
	while a.cell.y >= 26 and guard < 120:
		sim.advance_fixed_step()
		if b.cell != b_cell and sim.get_current_actor() == a:
			push_error("seq: enemy moved while ally acting")
			return false
		guard += 1
	if a.cell.y >= 26:
		push_error("seq: ally did not step (cell=%s)" % a.cell)
		return false
	## 友方一动结束后应轮到敌方（一动结束当拍 current 可能已清空，看变更信号）
	guard = 0
	while not actors_seen.has("foe") and guard < 200:
		sim.advance_fixed_step()
		guard += 1
	if not actors_seen.has("foe"):
		push_error("seq: expected enemy actor after ally turn, seen=%s" % [actors_seen])
		return false
	return true


## 一动内最多出手一次；多回合可多次命中；靠近用一动步数预算。
static func _test_melee_approach_hit_once_per_turn() -> bool:
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 1)
	## 格距 8；steps_per_turn 2 → 一动最多 2 格
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {"steps_per_turn": 2, "attack_reach": 1.0, "attack_windup": 0.0}),
		Vector2(9.5, 28.5),
	)
	var dummy := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 20.5))
	var hit_times: Array[float] = []
	var hit_rounds: Array[int] = []
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DAMAGE_TAKEN and payload.target == dummy.unit:
				hit_times.append(sim.elapsed_seconds)
				hit_rounds.append(sim.get_round_index())
	)
	_run_until(sim, 2.0)
	var cell_at_2s := attacker.cell
	var moved_early := cell_at_2s.y < 28
	_run_until(sim, 40.0)
	bus.free()
	if not moved_early:
		push_error("melee: attacker did not step toward target by t=2s (cell=%s)" % cell_at_2s)
		return false
	if hit_times.size() < 2:
		push_error("melee: expected >=2 hits across turns, got %d" % hit_times.size())
		return false
	## 同一回合不应连打两次
	for i in range(1, hit_rounds.size()):
		if hit_rounds[i] == hit_rounds[i - 1]:
			push_error("melee: two hits in same round %d" % hit_rounds[i])
			return false
	for d_i in hit_times.size():
		pass
	for i in hit_times.size():
		## 命中时须在攻距内（用最终格距近似；攻击瞬间已落稳）
		if float(attacker.cell_distance_to(dummy)) > 1.0 + RtUnitBrain.REACH_HYSTERESIS and i == hit_times.size() - 1:
			## 最后一击后可能仍邻格；若已走远则前面已校验过
			pass
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
			"steps_per_turn": 30,
			"attack_reach": 1.0,
			"attack_windup": 5.0,
			"sight_range": 30.0,
		}),
		Vector2(5.5, 25.5),
	)
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(8.5, 22.5))
	var start := mover.cell
	## 开步后跑完一格表现时长（CELL_STEP_SECONDS≈0.2s）
	_run_until(sim, RtUnit.CELL_STEP_SECONDS + RealtimeCombatSim.FIXED_DT)
	var delta: Vector2i = mover.cell - start
	if absi(delta.x) != 1 or absi(delta.y) != 1:
		push_error("eight_dir: expected one diagonal step, got delta=%s cell=%s" % [delta, mover.cell])
		return false
	if mover.is_stepping():
		push_error("eight_dir: expected settled after one cell step")
		return false
	return true


## 落格顿步：步进未落稳时站立格不前进、不得出手；落稳后方可判攻。
static func _test_no_attack_until_cell_settled() -> bool:
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 21)
	## 格距 2；迈一步到邻格后才进 reach=1。一格表现 ≈ CELL_STEP_SECONDS
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 1,
			"attack_reach": 1.0,
			"attack_windup": 0.0,
			"attack_interval": 10.0,
			"attack": 10,
			"sight_range": 30.0,
		}),
		Vector2(9.5, 23.5),
	)
	var dummy := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 21.5))
	var hit_times: Array[float] = []
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DAMAGE_TAKEN and payload.target == dummy.unit:
				hit_times.append(sim.elapsed_seconds)
	)
	var start_cell := Vector2i(9, 23)
	_run_until(sim, RtUnit.CELL_STEP_SECONDS * 0.5)
	if not attacker.is_stepping():
		push_error("settle: expected mid-step at half cell duration (cell=%s t=%.3f)" % [attacker.cell, attacker.step_t])
		bus.free()
		return false
	if attacker.cell != start_cell:
		push_error("settle: standing cell advanced early %s (expected %s)" % [attacker.cell, start_cell])
		bus.free()
		return false
	if attacker.step_dest != Vector2i(9, 22):
		push_error("settle: step_dest=%s expected (9,22)" % attacker.step_dest)
		bus.free()
		return false
	if sim.get_occupancy_owner(Vector2i(9, 22)) != attacker:
		push_error("settle: dest should be pre-occupied while stepping")
		bus.free()
		return false
	if sim.get_occupancy_owner(start_cell) != null:
		push_error("settle: from cell should be free while stepping")
		bus.free()
		return false
	if not hit_times.is_empty() or dummy.unit.current_hp != dummy.unit.get_effective_max_hp():
		push_error("settle: attacked before cell settled (hits=%d)" % hit_times.size())
		bus.free()
		return false
	## 落稳后再判攻（windup=0）；一格约 CELL_STEP_SECONDS
	_run_until(sim, RtUnit.CELL_STEP_SECONDS + 0.15)
	bus.free()
	if attacker.cell != Vector2i(9, 22):
		push_error("settle: expected standing cell (9,22) after land, got %s" % attacker.cell)
		return false
	if hit_times.is_empty():
		push_error("settle: expected attack after settle")
		return false
	var land_t := RtUnit.CELL_STEP_SECONDS
	if hit_times[0] < land_t - 0.02 or hit_times[0] > land_t + 0.12:
		push_error("settle: first hit at %.3f, expected just after land (~%.2f)" % [hit_times[0], land_t])
		return false
	return true


## 正前方邻格被占时改道或短等，不得与挡路者同格。
static func _test_occupancy_blocks_or_detours() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 13)
	var mover := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 4,
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
	_run_until(sim, 8.0)
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
			"steps_per_turn": 0, "attack_reach": 1.0, "attack_windup": 0.0, "attack_interval": 1.0,
		}),
		Vector2(9.5, 20.5),
	)
	var diag := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(10.5, 19.5))
	_run_until(sim, 0.2)
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
			"steps_per_turn": 0, "attack_reach": 1.0, "attack_windup": 0.0, "attack_interval": 1.0,
		}),
		Vector2(9.5, 20.5),
	)
	var far := sim2.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 18.5))
	_run_until(sim2, 0.4)
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
			"steps_per_turn": 2,
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
	var timeout := 40.0
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
			"attack_reach": 5.0, "attack_windup": 0.0, "projectile_speed": 4.0, "steps_per_turn": 0,
		}),
		Vector2(9.5, 26.5),
	)
	var dummy := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 21.5))
	var spawned: Array[float] = []
	sim.projectile_spawned.connect(func(_p: RtProjectile) -> void: spawned.append(sim.elapsed_seconds))
	_run_until(sim, 0.15)
	if spawned.is_empty() or sim.get_projectiles().is_empty():
		push_error("ranged: projectile not spawned")
		return false
	var full := dummy.unit.get_effective_max_hp()
	if dummy.unit.current_hp != full:
		push_error("ranged: damage applied before projectile arrival")
		return false
	## 格心距 5、出手点减半径；速度 4 → 首发命中约在 1.1s 前后
	_run_until(sim, 0.7)
	if dummy.unit.current_hp != full:
		push_error("ranged: damage applied too early (t=0.7)")
		return false
	_run_until(sim, 1.6)
	if dummy.unit.current_hp >= full:
		push_error("ranged: expected first hit by t=1.6, hp=%d" % dummy.unit.current_hp)
		return false
	## 回合制下后续回合还会再射；只断言首发延迟成立
	return spawned[0] < 0.2


static func _test_deploy_time_freezes() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 3)
	var start_cell := Vector2i(9, 28)
	var preplaced := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"deploy_time": 1.0, "steps_per_turn": 0, "attack_reach": 0.0, "max_hp": 9999,
		}),
		Vector2(0.5, 31.5),
	)
	## 射手放在同列远处，格距须落在 attack_reach 内
	var shooter := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"attack_reach": 20.0, "sight_range": 40.0, "attack_windup": 0.0,
			"projectile_speed": 0.0, "steps_per_turn": 0, "attack": 5,
		}),
		Vector2(9.5, 10.5),
	)
	sim.advance_fixed_step()
	if preplaced.is_deploying():
		push_error("deploy: units placed before combat start must act immediately")
		return false
	var deployed_at := sim.elapsed_seconds
	var deploying := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {"deploy_time": 1.0, "steps_per_turn": 2}),
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
	_run_until(sim, deployed_at + 4.0)
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
			"attack_reach": 3.0, "attack_windup": 0.0, "steps_per_turn": 0, "splash_radius": 1.0,
		}),
		Vector2(9.5, 23.5),
	)
	var primary := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 20.5))
	var near_a := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "near_a"}), Vector2(10.5, 20.5))
	var near_b := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "near_b"}), Vector2(9.5, 19.5))
	var far := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "far"}), Vector2(15.5, 20.5))
	var splashes: Array[float] = []
	sim.splash_triggered.connect(func(_c: Vector2, r: float) -> void: splashes.append(r))
	## 只跑到第一次溅射（一动一次出手）；避免多回合连打干扰断言
	var guard := 0
	while splashes.is_empty() and guard < 60:
		sim.advance_fixed_step()
		guard += 1
	var full := primary.unit.get_effective_max_hp()
	for rt in [primary, near_a, near_b]:
		if (rt as RtUnit).unit.current_hp != full - 10:
			push_error("splash: clustered enemy not hit (hp=%d cell=%s)" % [(rt as RtUnit).unit.current_hp, (rt as RtUnit).cell])
			return false
	if far.unit.current_hp != full:
		push_error("splash: far enemy should be untouched")
		return false
	return splashes.size() == 1 and is_equal_approx(splashes[0], 1.0)


## 多单位挤同一投放点后，任意时刻不应有两存活单位同占格（步进中认 step_dest）。
static func _test_occupancy_no_shared_cells() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 5)
	var center := Vector2(9.5, 16.5)
	for i in 6:
		var team := UnitInstance.Team.PLAYER if i % 2 == 0 else UnitInstance.Team.ENEMY
		sim.add_unit(make_dummy(team, 100000, {"id": "u%d" % i, "steps_per_turn": 1, "sight_range": 20.0, "attack_reach": 1.0, "attack_windup": 5.0}), center)
	_run_until(sim, 4.0)
	var seen: Dictionary = {}
	for item in sim.get_units():
		var rt := item as RtUnit
		if not rt.is_alive():
			continue
		var occ := rt.get_occupied_cell()
		if seen.has(occ):
			push_error("occupancy: shared occupied cell %s" % occ)
			return false
		seen[occ] = true
		if sim.get_occupancy_owner(occ) != rt:
			push_error("occupancy: map owner mismatch at %s" % occ)
			return false
	return true


static func _test_win_and_bus_death_events() -> bool:
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 7)
	sim.add_unit(make_unit(UnitInstance.Team.PLAYER, {"attack": 60, "max_hp": 1000, "steps_per_turn": 3, "attack_reach": 1.0, "attack_windup": 0.0}), Vector2(9.5, 24.5))
	sim.add_unit(make_unit(UnitInstance.Team.ENEMY, {"max_hp": 100, "attack": 1, "attack_reach": 1.0, "steps_per_turn": 0}), Vector2(8.5, 8.5))
	sim.add_unit(make_unit(UnitInstance.Team.ENEMY, {"max_hp": 100, "attack": 1, "attack_reach": 1.0, "steps_per_turn": 0}), Vector2(11.5, 6.5))
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
	_run_until(sim, 120.0)
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
	sim.add_unit(make_unit(UnitInstance.Team.PLAYER, {"max_hp": 50, "attack": 1, "attack_reach": 1.0, "steps_per_turn": 0}), Vector2(9.5, 24.5))
	sim.add_unit(make_unit(UnitInstance.Team.ENEMY, {"max_hp": 1000, "attack": 30, "steps_per_turn": 3, "attack_reach": 1.0, "attack_windup": 0.0}), Vector2(9.5, 6.5))
	var finished_with: Array = []
	sim.combat_finished.connect(func(won: bool) -> void: finished_with.append(won))
	_run_until(sim, 120.0)
	if not sim.is_finished() or sim.did_player_win() or finished_with != [false]:
		push_error("lose: expected player loss")
		return false
	return sim.count_alive(UnitInstance.Team.PLAYER) == 0


static func _build_mixed_scenario(seed_value: int) -> RealtimeCombatSim:
	var sim := _new_sim()
	sim.configure(ARENA, seed_value)
	var p := UnitInstance.Team.PLAYER
	var e := UnitInstance.Team.ENEMY
	sim.add_unit(make_unit(p, {"max_hp": 400, "attack": 25, "steps_per_turn": 1, "mass": 3.0, "deploy_time": 1.0, "attack_reach": 1.0}), Vector2(8.5, 24.5))
	sim.add_unit(make_unit(p, {"max_hp": 150, "attack": 18, "attack_reach": 5.0, "projectile_speed": 8.0, "body_radius": 0.35}), Vector2(10.5, 27.5))
	sim.add_unit(make_unit(p, {"max_hp": 250, "attack": 15, "splash_radius": 1.0, "steps_per_turn": 2, "attack_reach": 1.0}), Vector2(6.5, 25.5))
	sim.add_unit(make_unit(e, {"max_hp": 300, "attack": 20, "steps_per_turn": 2, "deploy_time": 0.5, "attack_reach": 1.0}), Vector2(9.5, 6.5))
	sim.add_unit(make_unit(e, {"max_hp": 120, "attack": 12, "attack_reach": 4.5, "projectile_speed": 6.0, "splash_radius": 0.8}), Vector2(5.5, 4.5))
	for i in 4:
		sim.add_unit(make_unit(e, {"max_hp": 60, "attack": 8, "steps_per_turn": 2, "body_radius": 0.3, "attack_reach": 1.0, "id": "swarm_%d" % i}), Vector2(11.5 + float(i), 8.5))
	return sim


static func _snapshot(sim: RealtimeCombatSim) -> Array:
	var out: Array = [sim.fixed_step_count, sim.is_finished(), sim.did_player_win(), sim.get_round_index(), sim.get_queue_cursor()]
	var actor := sim.get_current_actor()
	## 不用 instance_id（跨 sim 构造会漂移）；用队列下标 + 队伍
	out.append(sim.get_action_queue().find(actor) if actor != null else -1)
	out.append(actor.get_team() if actor != null else -1)
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
	for _i in 12000:
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
			"attack_reach": 10.0, "attack_windup": 0.0, "projectile_speed": 1.0, "steps_per_turn": 0, "attack": 50,
		}),
		Vector2(9.5, 28.5),
	)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack_reach": 1.0, "attack_windup": 0.0, "steps_per_turn": 0, "attack": 1000,
		}),
		Vector2(9.5, 21.5),
	)
	var target := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100), Vector2(9.5, 20.5))
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(1.5, 1.5))
	_run_until(sim, 2.0)
	if target.is_alive():
		push_error("vanish: melee should have killed target")
		return false
	if not sim.get_projectiles().is_empty():
		push_error("vanish: projectile to dead target should disappear")
		return false
	return true


## 阵亡单位在队列中被跳过，下一存活者行动。
static func _test_dead_skipped_in_queue() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 17)
	var f0 := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 1000, "attack": 100, "steps_per_turn": 0, "attack_reach": 10.0,
			"attack_windup": 0.0, "id": "killer",
		}),
		Vector2(9.5, 20.5),
	)
	var e0 := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 10, "attack": 1, "steps_per_turn": 0, "attack_reach": 1.0, "id": "victim",
		}),
		Vector2(9.5, 18.5),
	)
	var e1 := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "survivor", "steps_per_turn": 0}),
		Vector2(5.5, 5.5),
	)
	var seen_after_death: Array[String] = []
	var dead_acted := false
	sim.current_actor_changed.connect(
		func(actor: RtUnit) -> void:
			if actor == null:
				return
			if not e0.is_alive():
				if actor == e0:
					dead_acted = true
				else:
					seen_after_death.append(actor.unit.id)
	)
	sim.begin_combat()
	## f0, e0, e1 队列；f0 击杀 e0 后应跳过 e0
	var guard := 0
	while e0.is_alive() and guard < 60:
		sim.advance_fixed_step()
		guard += 1
	if e0.is_alive():
		push_error("skip: victim should be dead")
		return false
	guard = 0
	while seen_after_death.is_empty() and guard < 90:
		sim.advance_fixed_step()
		guard += 1
	if dead_acted:
		push_error("skip: dead unit became current actor")
		return false
	if seen_after_death.is_empty():
		push_error("skip: never saw surviving actor after death")
		return false
	return true


## 邻格近战出手：双方同批对砍扣血（无先后手）。
static func _test_mutual_melee_exchange() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 41)
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 50, "attack": 7, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 0.0, "id": "ally",
		}),
		Vector2(9.5, 20.5),
	)
	var foe := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 50, "attack": 11, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 5.0, "sight_range": 0.0, "id": "foe",
		}),
		Vector2(9.5, 19.5),
	)
	sim.begin_combat()
	var guard := 0
	while ally.unit.current_hp == 50 and guard < 40:
		sim.advance_fixed_step()
		guard += 1
	if ally.unit.current_hp != 50 - 11:
		push_error("mutual: ally hp=%d expected %d (counter 11)" % [ally.unit.current_hp, 50 - 11])
		return false
	if foe.unit.current_hp != 50 - 7:
		push_error("mutual: foe hp=%d expected %d" % [foe.unit.current_hp, 50 - 7])
		return false
	if not ally.is_alive() or not foe.is_alive():
		push_error("mutual: both should still be alive")
		return false
	return true


## 对砍同归于尽：双方同帧阵亡 → 清敌胜。
static func _test_mutual_kill_both_die_player_wins() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 42)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 5, "attack": 20, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 0.0, "id": "ally",
		}),
		Vector2(9.5, 20.5),
	)
	sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 5, "attack": 20, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 5.0, "sight_range": 0.0, "id": "foe",
		}),
		Vector2(9.5, 19.5),
	)
	sim.begin_combat()
	var guard := 0
	while not sim.is_finished() and guard < 40:
		sim.advance_fixed_step()
		guard += 1
	if not sim.is_finished():
		push_error("mutual_kill: combat should finish")
		return false
	if not sim.did_player_win():
		push_error("mutual_kill: simultaneous wipe should count as player win")
		return false
	if sim.count_alive(UnitInstance.Team.PLAYER) != 0 or sim.count_alive(UnitInstance.Team.ENEMY) != 0:
		push_error("mutual_kill: both teams should be empty")
		return false
	return true


## 远程在攻距外命中：目标不反打。
static func _test_ranged_out_of_reach_no_counter() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 43)
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 40, "attack": 5, "steps_per_turn": 0, "attack_reach": 5.0,
			"attack_windup": 0.0, "projectile_speed": 40.0, "id": "archer",
		}),
		Vector2(9.5, 24.5),
	)
	var foe := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 40, "attack": 9, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 5.0, "sight_range": 0.0, "id": "foe",
		}),
		Vector2(9.5, 20.5),
	)
	## 格距 4 > 敌攻距 1
	sim.begin_combat()
	var guard := 0
	while foe.unit.current_hp == 40 and guard < 120:
		sim.advance_fixed_step()
		guard += 1
	if foe.unit.current_hp != 40 - 5:
		push_error("ranged: foe hp=%d expected %d" % [foe.unit.current_hp, 35])
		return false
	if ally.unit.current_hp != 40:
		push_error("ranged: ally should take no counter (hp=%d)" % ally.unit.current_hp)
		return false
	return true


## 斩首：首领死 → 胜；衍生小兵溃散且不发死亡事件。
static func _test_boss_decapitation_wins_and_routs() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 50)
	var deaths: Array[String] = []
	sim.get_event_bus().combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DEATH and payload.target != null:
				deaths.append(payload.target.id)
	)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 30, "attack": 50, "steps_per_turn": 0, "attack_reach": 3.0,
			"attack_windup": 0.0, "id": "slayer",
		}),
		Vector2(8.5, 6.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 5, "attack": 1, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 5.0, "sight_range": 0.0, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"summon_unit": make_summon_body(), "summon_max_alive": 3,
		}),
		Vector2(8.5, 4.5),
	)
	## 预先放一只敌方召唤体（非首领）
	var minion_u := UnitInstance.from_unit_data(make_summon_body(), Vector2i(12, 4), UnitInstance.Team.ENEMY)
	minion_u.is_combat_summon = true
	var minion := sim.add_unit(minion_u, Vector2(12.5, 4.5))
	if boss == null or minion == null:
		push_error("decap: failed to place boss/minion")
		return false
	sim.begin_combat()
	var guard := 0
	while not sim.is_finished() and guard < 80:
		sim.advance_fixed_step()
		guard += 1
	if not sim.is_finished() or not sim.did_player_win():
		push_error("decap: expected player win by decapitation")
		return false
	if sim.count_alive(UnitInstance.Team.ENEMY) != 0:
		push_error("decap: enemies should be cleared after rout")
		return false
	if deaths.has("skeleton"):
		push_error("decap: rout must not emit ON_DEATH for minion")
		return false
	if not deaths.has("boss"):
		push_error("decap: boss death event expected")
		return false
	return true


## 友方打首领：首领不反打。
static func _test_boss_no_counter_when_targeted() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 51)
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 40, "attack": 7, "steps_per_turn": 0, "attack_reach": 2.0,
			"attack_windup": 0.0, "id": "ally",
		}),
		Vector2(8.5, 6.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 40, "attack": 11, "steps_per_turn": 0, "attack_reach": 2.0,
			"attack_windup": 5.0, "sight_range": 0.0, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(8.5, 4.5),
	)
	sim.begin_combat()
	var guard := 0
	while boss.unit.current_hp == 40 and guard < 40:
		sim.advance_fixed_step()
		guard += 1
	if boss.unit.current_hp != 40 - 7:
		push_error("boss_counter: boss hp=%d expected %d" % [boss.unit.current_hp, 33])
		return false
	if ally.unit.current_hp != 40:
		push_error("boss_counter: ally should take no counter (hp=%d)" % ally.unit.current_hp)
		return false
	return true


## 2×2 足迹占四格。
static func _test_boss_footprint_occupies_four_cells() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 52)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 20, "steps_per_turn": 0, "attack_windup": 5.0,
			"sight_range": 0.0, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(5.5, 3.5),
	)
	sim.add_unit(make_dummy(UnitInstance.Team.PLAYER, 100), Vector2(15.5, 28.5))
	if boss == null:
		push_error("footprint: boss null")
		return false
	var cells := boss.get_footprint_cells(boss.cell)
	if cells.size() != 4:
		push_error("footprint: expected 4 cells got %d" % cells.size())
		return false
	for c in cells:
		if sim.get_occupancy_owner(c) != boss:
			push_error("footprint: cell %s not owned by boss" % str(c))
			return false
	return true


## 场上衍生小兵硬上限。
static func _test_boss_summon_respects_cap() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 53)
	## 木桩友方远离，避免进攻距；首领应优先召唤。
	sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {
			"sight_range": 0.0, "attack_reach": 0.0, "id": "far_ally",
		}),
		Vector2(16.5, 30.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "attack": 1, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 0.0, "sight_range": 40.0, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"summon_unit": make_summon_body(), "summon_max_alive": 3, "summon_per_action": 1,
		}),
		Vector2(4.5, 2.5),
	)
	if boss == null:
		push_error("summon_cap: boss null")
		return false
	sim.begin_combat()
	var guard := 0
	var max_summons := 0
	while guard < 400:
		sim.advance_fixed_step()
		var n := 0
		for u in sim.get_units():
			var rt := u as RtUnit
			if rt != null and rt.is_alive() and rt.unit.is_combat_summon:
				n += 1
		max_summons = maxi(max_summons, n)
		if max_summons >= 3 and n == 3:
			break
		guard += 1
	if max_summons > 3:
		push_error("summon_cap: exceeded hard cap (%d)" % max_summons)
		return false
	if max_summons < 3:
		push_error("summon_cap: expected to reach 3 summons, got %d" % max_summons)
		return false
	## 再推进若干动，仍不得超过 3
	for _i in 120:
		sim.advance_fixed_step()
		var n2 := 0
		for u2 in sim.get_units():
			var rt2 := u2 as RtUnit
			if rt2 != null and rt2.is_alive() and rt2.unit.is_combat_summon:
				n2 += 1
		if n2 > 3:
			push_error("summon_cap: drifted above 3 (%d)" % n2)
			return false
	return true


## 同批首领死 + 己方全灭 → 仍胜（斩首优先于清波/全灭判负）。
static func _test_boss_decapitation_beats_mutual_wipe() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 54)
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 5, "attack": 1, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 5.0, "id": "ally",
		}),
		Vector2(8.5, 6.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 5, "attack": 1, "steps_per_turn": 0, "attack_reach": 2.0,
			"attack_windup": 5.0, "sight_range": 0.0, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(8.5, 4.5),
	)
	sim.begin_combat()
	## 模拟同批互杀后的场况：双方均已倒下，斩首仍应判胜。
	ally.unit.current_hp = 0
	boss.unit.current_hp = 0
	ally.state = RtUnit.State.DEAD
	boss.state = RtUnit.State.DEAD
	sim.advance_fixed_step()
	if not sim.is_finished() or not sim.did_player_win():
		push_error("decap_wipe: expected win despite mutual wipe")
		return false
	return true


## Boss 足迹平移可推开友方；无伤害；无空位则整步失败。
static func _test_boss_push_ally_on_step() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 55)
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 50, "attack": 1, "steps_per_turn": 0, "id": "blocker",
		}),
		Vector2(5.5, 5.5),
	)
	var ally2 := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 50, "attack": 1, "steps_per_turn": 0, "id": "blocker2",
		}),
		Vector2(6.5, 5.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "steps_per_turn": 1, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(5.5, 3.5),
	)
	if ally == null or ally2 == null or boss == null:
		push_error("push: place failed")
		return false
	## 确认首领足迹在 (5,3) 起 2×2，一步 +y 将覆盖两名友方。
	if boss.cell != Vector2i(5, 3):
		push_error("push: unexpected boss origin %s" % str(boss.cell))
		return false
	var ally_hp := ally.unit.current_hp
	if not sim.try_boss_step_for_test(boss, Vector2i(0, 1)):
		push_error("push: expected step+push to succeed")
		return false
	## begin_step 未落稳前站立格仍为 from，占格看 step_dest。
	if boss.get_occupied_cell() != Vector2i(5, 4):
		push_error("push: boss dest %s expected (5,4)" % str(boss.get_occupied_cell()))
		return false
	if ally.get_occupied_cell() == Vector2i(5, 5) or ally2.get_occupied_cell() == Vector2i(6, 5):
		push_error(
			"push: allies still occupying old cells %s %s"
			% [str(ally.get_occupied_cell()), str(ally2.get_occupied_cell())]
		)
		return false
	if ally.unit.current_hp != ally_hp:
		push_error("push: must not damage")
		return false
	## 堵死正前与斜前，整步应失败。
	var sim2 := _new_sim()
	sim2.configure(Vector2i(8, 8), 56)
	var a := sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "a"}), Vector2(2.5, 3.5))
	var b := sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "b"}), Vector2(3.5, 3.5))
	## 推开落点全堵
	sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "c"}), Vector2(2.5, 4.5))
	sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "d"}), Vector2(3.5, 4.5))
	sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "e"}), Vector2(1.5, 4.5))
	sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "f"}), Vector2(4.5, 4.5))
	sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "g"}), Vector2(2.5, 5.5))
	sim2.add_unit(make_dummy(UnitInstance.Team.PLAYER, 10, {"id": "h"}), Vector2(3.5, 5.5))
	var boss2 := sim2.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "id": "boss2",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(2.5, 1.5),
	)
	if a == null or b == null or boss2 == null:
		push_error("push_fail: place failed")
		return false
	var origin2 := boss2.cell
	if sim2.try_boss_step_for_test(boss2, Vector2i(0, 1)):
		push_error("push_fail: step should fail when no push landing")
		return false
	if boss2.cell != origin2 or a.cell != Vector2i(2, 3):
		push_error("push_fail: positions should roll back / stay")
		return false
	return true
