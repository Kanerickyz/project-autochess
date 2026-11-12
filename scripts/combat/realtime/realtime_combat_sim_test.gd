class_name RealtimeCombatSimTest
extends RefCounted
## Headless 单测：即时并行滑移 / 软碰撞 / 欧氏攻距 / 胜负 / 确定性。

const ARENA := Vector2i(18, 32)

static var _created: Array[RealtimeCombatSim] = []


static func run_all() -> bool:
	var ok := true
	ok = _check("parallel_lock_order_snapshot", _test_parallel_lock_order_snapshot()) and ok
	ok = _check("parallel_all_units_move", _test_parallel_all_units_move()) and ok
	ok = _check("melee_approach_hits_on_interval", _test_melee_approach_hits_on_interval()) and ok
	ok = _check("spawn_waits_full_attack_interval", _test_spawn_waits_full_attack_interval()) and ok
	ok = _check("continuous_slide_diagonal", _test_continuous_slide_diagonal()) and ok
	ok = _check("soft_collision_no_overlap", _test_soft_collision_no_overlap()) and ok
	ok = _check("euclidean_attack_reach", _test_euclidean_attack_reach()) and ok
	ok = _check("ally_blocker_steer_around_melee", _test_ally_blocker_steer_around_melee()) and ok
	ok = _check("ranged_damage_on_fire_projectile_visual", _test_ranged_damage_on_fire_projectile_visual()) and ok
	ok = _check("deploy_time_freezes", _test_deploy_time_freezes()) and ok
	ok = _check("deploy_after_begin_before_first_step", _test_deploy_after_begin_before_first_step()) and ok
	ok = _check("mid_combat_summon_acts_immediately", _test_mid_combat_summon_acts_immediately()) and ok
	ok = _check("one_unit_per_cell_on_spawn", _test_one_unit_per_cell_on_spawn()) and ok
	ok = _check("splash_hits_cluster", _test_splash_hits_cluster()) and ok
	ok = _check("spawn_occupancy_no_shared_cells", _test_occupancy_no_shared_cells()) and ok
	ok = _check("win_and_bus_death_events", _test_win_and_bus_death_events()) and ok
	ok = _check("lose_when_no_player_alive", _test_lose_when_no_player_alive()) and ok
	ok = _check("determinism_frame_rate_independent", _test_determinism_frame_rate_independent()) and ok
	ok = _check("projectile_vanishes_when_target_dead", _test_projectile_vanishes_when_target_dead()) and ok
	ok = _check("dead_units_stop_acting", _test_dead_units_stop_acting()) and ok
	ok = _check("melee_one_way_hit", _test_melee_one_way_hit()) and ok
	ok = _check("melee_one_way_kill_player_wins", _test_melee_one_way_kill_player_wins()) and ok
	ok = _check("ranged_out_of_reach_no_counter", _test_ranged_out_of_reach_no_counter()) and ok
	ok = _check("boss_decapitation_wins_and_routs", _test_boss_decapitation_wins_and_routs()) and ok
	ok = _check("boss_no_counter_when_targeted", _test_boss_no_counter_when_targeted()) and ok
	ok = _check("boss_footprint_occupies_four_cells", _test_boss_footprint_occupies_four_cells()) and ok
	ok = _check("boss_summon_respects_cap", _test_boss_summon_respects_cap()) and ok
	ok = _check("boss_summon_lifetime_total_cap", _test_boss_summon_lifetime_total_cap()) and ok
	ok = _check("giant_knight_summon_caps", _test_giant_knight_summon_caps()) and ok
	ok = _check("boss_summon_zero_caps_uncapped", _test_boss_summon_zero_caps_uncapped()) and ok
	ok = _check("boss_summon_respects_cooldown", _test_boss_summon_respects_cooldown()) and ok
	ok = _check("boss_decapitation_beats_mutual_wipe", _test_boss_decapitation_beats_mutual_wipe()) and ok
	ok = _check("boss_teleport_to_empty_cell", _test_boss_teleport_to_empty_cell()) and ok
	ok = _check("boss_parallel_with_allies", _test_boss_parallel_with_allies()) and ok
	ok = _check("boss_summon_minions_advance", _test_boss_summon_minions_advance()) and ok
	ok = _check("boss_footprint_horiz_centered", _test_boss_footprint_horiz_centered()) and ok
	ok = _check("boss_visual_centers_in_footprint", _test_boss_visual_centers_in_footprint()) and ok
	ok = _check("boss_low_hp_flees_threat", _test_boss_low_hp_flees_threat()) and ok
	ok = _check("boss_summon_sets_summoning_state", _test_boss_summon_sets_summoning_state()) and ok
	ok = _check("ranged_attack_reach_clamped_to_2", _test_ranged_attack_reach_clamped_to_2()) and ok
	ok = _check("acquire_prefers_closer_edge", _test_acquire_prefers_lane_on_chebyshev_tie()) and ok
	ok = _check("flanks_do_not_collapse_left", _test_flanks_do_not_collapse_left()) and ok
	ok = _check("attack_crit_doubles_and_marks", _test_attack_crit_doubles_and_marks()) and ok
	ok = _check("windup_advances_under_presentation_hold", _test_windup_advances_under_presentation_hold()) and ok
	ok = _check("step_breaks_on_pending_defer", _test_step_breaks_on_pending_defer()) and ok
	ok = _check("deferred_hit_keeps_chained_skill_batches", _test_deferred_hit_keeps_chained_skill_batches()) and ok
	ok = _check("deferred_hit_emits_unit_died_for_death_fx", _test_deferred_hit_emits_unit_died_for_death_fx()) and ok
	ok = _check(
		"deferred_lethal_keeps_unit_until_death_finalize",
		_test_deferred_lethal_keeps_unit_until_death_finalize(),
	) and ok
	ok = _check(
		"deferred_mirror_warden_convert_before_death_finalize",
		_test_deferred_mirror_warden_convert_before_death_finalize(),
	) and ok
	ok = _check(
		"defer_warden_convert_defers_player_wipe_loss",
		_test_defer_warden_convert_defers_player_wipe_loss(),
	) and ok

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
	"max_hp", "attack", "steps_per_turn", "move_speed", "attack_interval",
	"attack_windup", "attack_reach", "sight_range", "body_radius", "mass",
	"projectile_speed", "splash_radius", "deploy_time", "attack_range",
	"crit_chance", "crit_multiplier",
]


static func make_unit(team: UnitInstance.Team, overrides: Dictionary = {}) -> UnitInstance:
	var stats := UnitStats.new()
	stats.max_hp = 100
	stats.attack = 10
	stats.steps_per_turn = 1
	stats.attack_interval = 1.0
	stats.attack_windup = 0.3
	stats.attack_reach = 1.0
	## 测例默认关暴击，避免 5% 默认概率打乱精确扣血断言；需测暴击时显式覆盖。
	stats.crit_chance = 0.0
	stats.crit_multiplier = 2.0
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
	data.summon_max_total = int(overrides.get("summon_max_total", 0))
	data.summon_per_action = int(overrides.get("summon_per_action", 1))
	data.summon_cooldown_actions = int(overrides.get("summon_cooldown_actions", 0))
	var unit := UnitInstance.from_unit_data(data, Vector2i.ZERO, team)
	## 测例可显式覆盖攻距（绕过远程硬顶），专用 clamp 用例直接测 from_unit_data。
	if overrides.has("attack_range"):
		unit.stats.attack_range = int(overrides["attack_range"])
	if overrides.has("attack_reach"):
		unit.stats.attack_reach = float(overrides["attack_reach"])
	return unit



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


## 锁阵生成序快照保留；并行下无行动队列交错。
static func _test_parallel_lock_order_snapshot() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 1)
	var f0 := sim.add_unit(make_dummy(UnitInstance.Team.PLAYER, 100, {"id": "f0"}), Vector2(1.5, 28.5))
	var f1 := sim.add_unit(make_dummy(UnitInstance.Team.PLAYER, 100, {"id": "f1"}), Vector2(2.5, 28.5))
	var e0 := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100, {"id": "e0"}), Vector2(1.5, 3.5))
	sim.begin_combat()
	var q: Array = sim.get_action_queue()
	if q.size() != 3 or q[0] != f0 or q[1] != f1 or q[2] != e0:
		push_error("lock_order: unexpected snapshot %s" % [q])
		return false
	if sim.get_current_actor() != null:
		push_error("lock_order: parallel has no current actor")
		return false
	if not sim.is_action_queue_seeded():
		push_error("lock_order: combat clock should be ready")
		return false
	return true


## 敌我同时朝对方滑移（无排队）。
static func _test_parallel_all_units_move() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 2)
	var a := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 2.0, "attack_windup": 5.0, "sight_range": 30.0, "id": "ally",
		}),
		Vector2(9.5, 26.5),
	)
	var b := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"move_speed": 2.0, "attack_windup": 5.0, "sight_range": 30.0, "id": "foe",
		}),
		Vector2(9.5, 6.5),
	)
	var a0 := a.position
	var b0 := b.position
	_run_until(sim, 0.5)
	if a.position.y >= a0.y - 0.05:
		push_error("parallel: ally did not slide up (pos=%s)" % a.position)
		return false
	if b.position.y <= b0.y + 0.05:
		push_error("parallel: foe did not slide down (pos=%s)" % b.position)
		return false
	return true


## 入场默认不能出手：贴身也须先走满一轮 attack_interval。
static func _test_spawn_waits_full_attack_interval() -> bool:
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 1)
	var interval := 1.0
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 0, "attack_reach": 1.0, "attack_windup": 0.0,
			"attack_interval": interval, "attack": 10,
		}),
		Vector2(9.5, 20.5),
	)
	var dummy := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 100000, {"body_radius": 0.4}),
		Vector2(9.5, 19.5),
	)
	if absf(attacker.attack_timer - interval) > 0.001:
		push_error(
			"spawn_gate: attack_timer should start at interval (got %.3f)"
			% attacker.attack_timer
		)
		bus.free()
		return false
	var hit_times: Array[float] = []
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DAMAGE_TAKEN and payload.target == dummy.unit:
				hit_times.append(sim.elapsed_seconds)
	)
	## 固定步长下首刀可早约 1 帧；0.85s 前绝不能出手。
	_run_until(sim, 0.85)
	if not hit_times.is_empty():
		push_error("spawn_gate: hit before interval at t=%.3f" % hit_times[0])
		bus.free()
		return false
	_run_until(sim, interval + 0.2)
	bus.free()
	if hit_times.is_empty():
		push_error("spawn_gate: expected first hit after interval")
		return false
	if hit_times[0] < 0.85 or hit_times[0] > interval + 0.15:
		push_error("spawn_gate: first hit out of window t=%.3f" % hit_times[0])
		return false
	return true


## 进距后按 attack_interval 连打；靠近用连续移速。
static func _test_melee_approach_hits_on_interval() -> bool:
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 1)
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 4.0, "attack_reach": 0.8, "attack_windup": 0.0, "attack_interval": 1.0,
		}),
		Vector2(9.5, 28.5),
	)
	var dummy := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 20.5))
	var hit_times: Array[float] = []
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DAMAGE_TAKEN and payload.target == dummy.unit:
				hit_times.append(sim.elapsed_seconds)
	)
	_run_until(sim, 2.0)
	var moved_early := attacker.position.y < 28.0
	_run_until(sim, 12.0)
	bus.free()
	if not moved_early:
		push_error("melee: attacker did not slide by t=2s (pos=%s)" % attacker.position)
		return false
	if hit_times.size() < 2:
		push_error("melee: expected >=2 interval hits, got %d" % hit_times.size())
		return false
	for i in range(1, hit_times.size()):
		var gap := hit_times[i] - hit_times[i - 1]
		if gap < 0.85 or gap > 1.25:
			push_error("melee: hit gap %.3f not ~1.0s" % gap)
			return false
	if dummy.unit.current_hp != 100000 - 10 * hit_times.size():
		push_error("melee: hp mismatch %d" % dummy.unit.current_hp)
		return false
	return true


## 对角目标时连续滑移同时减小 dx/dy。
static func _test_continuous_slide_diagonal() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 12)
	var mover := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 3.0,
			"attack_reach": 0.5,
			"attack_windup": 5.0,
			"sight_range": 30.0,
		}),
		Vector2(5.5, 25.5),
	)
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(8.5, 22.5))
	var start := mover.position
	_run_until(sim, 0.4)
	var delta: Vector2 = mover.position - start
	if delta.x <= 0.05 or delta.y >= -0.05:
		push_error("slide: expected diagonal toward foe, delta=%s" % delta)
		return false
	return true


## 软碰撞：圆心距不得小于 r1+r2（允许极小浮点误差）。
static func _test_soft_collision_no_overlap() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 13)
	var a := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 4.0, "body_radius": 0.5, "mass": 1.0,
			"attack_windup": 5.0, "sight_range": 30.0,
		}),
		Vector2(9.5, 22.5),
	)
	var b := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"move_speed": 4.0, "body_radius": 0.5, "mass": 1.0,
			"attack_windup": 5.0, "sight_range": 30.0,
		}),
		Vector2(9.5, 20.5),
	)
	_run_until(sim, 3.0)
	var min_dist := a.get_radius() + b.get_radius()
	var dist := a.position.distance_to(b.position)
	if dist + 0.02 < min_dist:
		push_error("soft: overlapped dist=%.3f min=%.3f" % [dist, min_dist])
		return false
	return true


## 出手认欧氏边缘距：贴身可打；拉开后 reach=0.5 不可打。
static func _test_euclidean_attack_reach() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 14)
	var a := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 0, "body_radius": 0.4, "attack_reach": 0.5,
			"attack_windup": 0.0, "attack_interval": 0.05,
		}),
		Vector2(9.5, 20.5),
	)
	var near := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 100000, {"body_radius": 0.4}),
		Vector2(9.5, 19.5),
	)
	## 入场须先走满 interval；短间隔下 0.2s 足够出首刀。
	_run_until(sim, 0.2)
	if near.unit.current_hp >= near.unit.get_effective_max_hp():
		push_error("euclid: near target should be in reach (edge=%.3f)" % a.edge_distance_to(near))
		return false

	var sim2 := _new_sim()
	sim2.configure(ARENA, 15)
	var b := sim2.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 0, "body_radius": 0.4, "attack_reach": 0.5,
			"attack_windup": 0.0, "attack_interval": 0.05,
		}),
		Vector2(9.5, 20.5),
	)
	var far := sim2.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 100000, {"body_radius": 0.4}),
		Vector2(9.5, 17.5),
	)
	_run_until(sim2, 0.4)
	if far.unit.current_hp != far.unit.get_effective_max_hp():
		push_error("euclid: far target should be out of reach (edge=%.3f)" % b.edge_distance_to(far))
		return false
	return true


## 友军挡路：绕行进距，且不把挡路友军顶走。
static func _test_ally_blocker_steer_around_melee() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 11)
	var attack_reach := 0.8
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"move_speed": 3.0,
			"attack_reach": attack_reach,
			"attack_windup": 5.0,
			"attack_interval": 10.0,
			"body_radius": 0.4,
			"sight_range": 20.0,
		}),
		Vector2(9.5, 28.5),
	)
	var ally := sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {"id": "ally_blocker", "body_radius": 0.4}),
		Vector2(9.5, 24.5),
	)
	var enemy := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 100000, {"id": "enemy_dummy", "body_radius": 0.4}),
		Vector2(9.5, 20.5),
	)
	var ally_home := ally.position
	var timeout := 40.0
	var reached := false
	while sim.elapsed_seconds < timeout - 0.0001 and not sim.is_finished():
		sim.advance_fixed_step()
		if ally.position.distance_to(ally_home) > 0.2:
			push_error(
				"ally_blocker: stationary ally was pushed (pos=%s home=%s)"
				% [ally.position, ally_home]
			)
			return false
		if attacker.edge_distance_to(enemy) <= attack_reach + RtUnitBrain.REACH_EPSILON:
			reached = true
			break
	if not reached:
		push_error(
			"ally_blocker: never entered attack reach (edge=%.3f pos=%s t=%.2f)"
			% [attacker.edge_distance_to(enemy), attacker.position, sim.elapsed_seconds]
		)
		return false
	return true


## 远程：出手瞬间扣血；投射物仅演出，advance 不再二次结算。
static func _test_ranged_damage_on_fire_projectile_visual() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 2)
	var shooter := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack": 7,
			"attack_reach": 2.0,
			"attack_windup": 0.0,
			"projectile_speed": 1.0,
			"steps_per_turn": 0,
			"sight_range": 20.0,
		}),
		Vector2(9.5, 24.5),
	)
	var dummy := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 100, {
			"steps_per_turn": 0, "sight_range": 0.0, "attack_reach": 0.0,
		}),
		Vector2(9.5, 22.5),
	)
	var full := dummy.unit.get_effective_max_hp()
	var guard := 0
	while sim.get_projectiles().is_empty() and guard < 120:
		sim.advance_fixed_step()
		guard += 1
	if sim.get_projectiles().is_empty():
		push_error("ranged_visual: projectile not spawned")
		return false
	var expected := full - shooter.unit.get_effective_attack()
	if dummy.unit.current_hp != expected:
		push_error(
			"ranged_visual: damage must apply on fire, hp=%d expected %d"
			% [dummy.unit.current_hp, expected]
		)
		return false
	var hp_mid := dummy.unit.current_hp
	for _i in 45:
		sim._advance_projectiles()
	if dummy.unit.current_hp != hp_mid:
		push_error(
			"ranged_visual: projectile advance must not deal damage (hp %d -> %d)"
			% [hp_mid, dummy.unit.current_hp]
		)
		return false
	return true


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
	## 射手放在同列远处，格距须落在 attack_reach 内；短 interval 以便部署窗内出首刀。
	var shooter := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"attack_reach": 20.0, "sight_range": 40.0, "attack_windup": 0.0,
			"attack_interval": 0.05, "projectile_speed": 0.0, "steps_per_turn": 0, "attack": 5,
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
	if deploying.position.y >= float(start_cell.y) + 0.45:
		push_error("deploy: unit did not slide after deploy_time (pos=%s)" % deploying.position)
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


## 战中召唤立刻参与并行（可跳过 deploy）。
static func _test_mid_combat_summon_acts_immediately() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 3)
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {"steps_per_turn": 0, "max_hp": 9999}),
		Vector2(9.5, 28.5),
	)
	sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"steps_per_turn": 0, "max_hp": 9999}),
		Vector2(9.5, 3.5),
	)
	sim.begin_combat()
	var late_unit := make_unit(UnitInstance.Team.PLAYER, {
		"id": "late_summon", "move_speed": 2.0, "deploy_time": 1.5, "attack_windup": 5.0,
		"sight_range": 40.0,
	})
	late_unit.is_combat_summon = true
	var late := sim.add_unit(late_unit, Vector2(8.5, 28.5))
	if late == null:
		push_error("mid_summon: add_unit failed")
		return false
	if late.is_deploying():
		push_error("mid_summon: combat summon must skip deploy wait")
		return false
	var y0 := late.position.y
	_run_until(sim, 0.5)
	if late.position.y >= y0 - 0.05:
		push_error("mid_summon: expected immediate slide (pos=%s)" % late.position)
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
	## 出手已结算；慢箭仍在飞时目标被置死，演出箭应消失且不再改血。
	sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack_reach": 2.0, "attack_windup": 0.0, "projectile_speed": 1.0, "steps_per_turn": 0, "attack": 3,
			"sight_range": 20.0,
		}),
		Vector2(9.5, 24.5),
	)
	var target := sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 100), Vector2(9.5, 22.5))
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY), Vector2(1.5, 1.5))
	var guard := 0
	while sim.get_projectiles().is_empty() and guard < 120:
		sim.advance_fixed_step()
		guard += 1
	if sim.get_projectiles().is_empty():
		push_error("vanish: projectile not spawned")
		return false
	var hp_after_fire := target.unit.current_hp
	target.unit.current_hp = 0
	guard = 0
	while not sim.get_projectiles().is_empty() and guard < 60:
		sim.advance_fixed_step()
		guard += 1
	if not sim.get_projectiles().is_empty():
		push_error("vanish: projectile to dead target should disappear")
		return false
	if hp_after_fire >= 100:
		push_error("vanish: expected damage on fire before visual flight")
		return false
	return true


## 阵亡单位在队列中被跳过，下一存活者行动。
static func _test_dead_units_stop_acting() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 17)
	sim.add_unit(
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
	sim.begin_combat()
	var guard := 0
	while e0.is_alive() and guard < 60:
		sim.advance_fixed_step()
		guard += 1
	if e0.is_alive():
		push_error("dead_stop: victim should be dead")
		return false
	var pos_after := e0.position
	_run_until(sim, sim.elapsed_seconds + 0.5)
	if e0.position.distance_to(pos_after) > 0.01:
		push_error("dead_stop: dead unit kept moving")
		return false
	if not e1.is_alive():
		push_error("dead_stop: survivor should remain")
		return false
	return true


## 邻格近战出手：只单向扣血，被打方不反打。
static func _test_melee_one_way_hit() -> bool:
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
	while foe.unit.current_hp == 50 and guard < 40:
		sim.advance_fixed_step()
		guard += 1
	if foe.unit.current_hp != 50 - 7:
		push_error("one_way: foe hp=%d expected %d" % [foe.unit.current_hp, 50 - 7])
		return false
	if ally.unit.current_hp != 50:
		push_error("one_way: ally should take no counter (hp=%d)" % ally.unit.current_hp)
		return false
	if not ally.is_alive() or not foe.is_alive():
		push_error("one_way: both should still be alive")
		return false
	return true


## 近战单向击杀：敌死友存 → 清敌胜。
static func _test_melee_one_way_kill_player_wins() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 42)
	var ally := sim.add_unit(
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
		push_error("one_way_kill: combat should finish")
		return false
	if not sim.did_player_win():
		push_error("one_way_kill: player should win after killing foe")
		return false
	if sim.count_alive(UnitInstance.Team.ENEMY) != 0:
		push_error("one_way_kill: enemies should be empty")
		return false
	if ally == null or not ally.is_alive():
		push_error("one_way_kill: ally should survive (no counter)")
		return false
	return true


## 远程命中：目标不反打（单向出手）。
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


## 第一只：场上同时最多 5，整场累计最多生成 9。
static func _test_giant_knight_summon_caps() -> bool:
	var data := load("res://resources/units/realtime/giant_knight.tres") as UnitData
	if data == null:
		push_error("giant_knight: missing")
		return false
	if data.summon_max_alive != 5:
		push_error("giant_knight: summon_max_alive %d, expected 5" % data.summon_max_alive)
		return false
	if data.summon_max_total != 9:
		push_error("giant_knight: summon_max_total %d, expected 9" % data.summon_max_total)
		return false
	return true


## 整场战斗累计召唤上限（小兵死后不可再补员）。
static func _test_boss_summon_lifetime_total_cap() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 54)
	sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {
			"sight_range": 0.0, "attack_reach": 0.0, "id": "far_ally",
		}),
		Vector2(16.5, 30.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "attack": 1, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 0.0, "sight_range": 40.0, "id": "boss_total",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"summon_unit": make_summon_body(), "summon_max_alive": 3,
			"summon_max_total": 3, "summon_per_action": 1, "summon_cooldown_actions": 0,
		}),
		Vector2(4.5, 2.5),
	)
	if boss == null:
		push_error("summon_total: boss null")
		return false
	sim.begin_combat()
	var guard := 0
	while guard < 500 and boss.boss_summons_spawned_total < 3:
		sim.advance_fixed_step()
		guard += 1
	if boss.boss_summons_spawned_total < 3:
		push_error("summon_total: expected 3 spawns, got %d" % boss.boss_summons_spawned_total)
		return false
	for u in sim.get_units():
		var rt := u as RtUnit
		if rt == null or not rt.is_alive() or rt.unit == null:
			continue
		if rt.unit.is_combat_summon:
			rt.unit.current_hp = 0
			rt.state = RtUnit.State.DEAD
	for _i in 300:
		sim.advance_fixed_step()
	var alive_summons := 0
	for u2 in sim.get_units():
		var rt2 := u2 as RtUnit
		if rt2 != null and rt2.is_alive() and rt2.unit != null and rt2.unit.is_combat_summon:
			alive_summons += 1
	if alive_summons > 0:
		push_error("summon_total: respawned after cap (%d alive)" % alive_summons)
		return false
	if boss.boss_summons_spawned_total > 3:
		push_error("summon_total: spawned %d (max 3)" % boss.boss_summons_spawned_total)
		return false
	return true


## summon_max_alive/total = 0：无数量硬上限；小兵死后可补员且可超过原「3」档。
static func _test_boss_summon_zero_caps_uncapped() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 56)
	sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {
			"sight_range": 0.0, "attack_reach": 0.0, "id": "far_ally",
		}),
		Vector2(16.5, 30.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "attack": 1, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 0.0, "sight_range": 40.0, "id": "boss_uncap",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"summon_unit": make_summon_body(), "summon_max_alive": 0,
			"summon_max_total": 0, "summon_per_action": 1, "summon_cooldown_actions": 0,
		}),
		Vector2(4.5, 2.5),
	)
	if boss == null:
		push_error("summon_uncap: boss null")
		return false
	sim.begin_combat()
	var guard := 0
	while guard < 800 and boss.boss_summons_spawned_total < 4:
		sim.advance_fixed_step()
		guard += 1
	if boss.boss_summons_spawned_total < 4:
		push_error(
			"summon_uncap: expected >=4 spawns without cap, got %d"
			% boss.boss_summons_spawned_total
		)
		return false
	for u in sim.get_units():
		var rt := u as RtUnit
		if rt == null or not rt.is_alive() or rt.unit == null:
			continue
		if rt.unit.is_combat_summon:
			rt.unit.current_hp = 0
			rt.state = RtUnit.State.DEAD
	var before_total := boss.boss_summons_spawned_total
	for _i in 400:
		sim.advance_fixed_step()
	if boss.boss_summons_spawned_total <= before_total:
		push_error(
			"summon_uncap: expected refill after deaths (total %d → %d)"
			% [before_total, boss.boss_summons_spawned_total]
		)
		return false
	return true


## 召后冷却：成功召唤后进入冷却；冷却归零前不可再召。
static func _test_boss_summon_respects_cooldown() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 55)
	sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {
			"sight_range": 0.0, "attack_reach": 0.0, "id": "far_ally",
		}),
		Vector2(16.5, 30.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "attack": 1, "steps_per_turn": 0, "attack_reach": 1.0,
			"attack_windup": 0.0, "sight_range": 40.0, "id": "boss_cd",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"summon_unit": make_summon_body(), "summon_max_alive": 3, "summon_per_action": 1,
			"summon_cooldown_actions": 2,
		}),
		Vector2(4.5, 2.5),
	)
	if boss == null:
		push_error("summon_cd: boss null")
		return false
	if not sim._boss_can_summon(boss):
		push_error("summon_cd: expected can summon before first")
		return false
	sim._boss_perform_summon(boss)
	if not is_equal_approx(boss.boss_summon_cooldown_left, 2.0):
		push_error("summon_cd: expected cooldown 2.0s got %.3f" % boss.boss_summon_cooldown_left)
		return false
	if sim._boss_can_summon(boss):
		push_error("summon_cd: must not summon while cooling down")
		return false
	boss.boss_summon_cooldown_left = 0.0
	if not sim._boss_can_summon(boss):
		push_error("summon_cd: expected can summon after cooldown cleared")
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


## Boss 可瞬移到任意空足迹锚点；不可落到被占格。
static func _test_boss_teleport_to_empty_cell() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 55)
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 50, "attack": 1, "steps_per_turn": 0, "id": "blocker",
		}),
		Vector2(5.5, 5.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "steps_per_turn": 1, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(5.5, 3.5),
	)
	if ally == null or boss == null:
		push_error("teleport: place failed")
		return false
	if boss.cell != Vector2i(5, 3):
		push_error("teleport: unexpected boss origin %s" % str(boss.cell))
		return false
	## 空锚点 (1,1) 应可瞬移
	if not sim.try_boss_teleport_for_test(boss, Vector2i(1, 1)):
		push_error("teleport: expected empty-cell teleport to succeed")
		return false
	if boss.get_occupied_cell() != Vector2i(1, 1):
		push_error("teleport: boss dest %s expected (1,1)" % str(boss.get_occupied_cell()))
		return false
	## 落到友方占格应失败
	var blocked := sim.try_boss_teleport_for_test(boss, Vector2i(5, 5))
	if blocked:
		push_error("teleport: must not land on occupied cells")
		return false
	return true


## Boss 遭遇行动队列：友0、Boss、友1、Boss…
## 并行：Boss 与友方同时更新，无交错队列。
static func _test_boss_parallel_with_allies() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 57)
	var a0 := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 20, "attack": 1, "move_speed": 2.0, "attack_windup": 5.0, "id": "a0",
			"sight_range": 40.0,
		}),
		Vector2(1.5, 10.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 80, "attack": 1, "move_speed": 2.0, "attack_windup": 5.0,
			"sight_range": 40.0, "id": "boss",
			"is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(2.5, 2.5),
	)
	if a0 == null or boss == null:
		push_error("boss_parallel: place failed")
		return false
	sim.begin_combat()
	var a0y := a0.position.y
	var by := boss.position.y
	_run_until(sim, 0.4)
	if a0.position.y >= a0y - 0.02 and boss.position.y <= by + 0.02:
		## 至少一方应因索敌而动；Boss 也可能瞬移/滑移。
		push_error("boss_parallel: expected simultaneous activity (a0=%s boss=%s)" % [a0.position, boss.position])
		return false
	if sim.get_current_actor() != null:
		push_error("boss_parallel: should have no current actor")
		return false
	return true


## 首领召唤的枯骨代理须朝远离出生点的方向推进（不能卡死不动）。
static func _test_boss_summon_minions_advance() -> bool:
	var sim := _new_sim()
	## 召唤推进需要纵深；保留显式大盘，不跟主路径 5×8。
	sim.configure(ARENA, 61)
	var boss_data := load("res://resources/units/realtime/giant_knight.tres") as UnitData
	if boss_data == null or boss_data.summon_unit == null:
		push_error("summon_advance: giant_knight missing summon_unit")
		return false
	sim.add_unit(
		make_dummy(UnitInstance.Team.PLAYER, 100000, {
			"sight_range": 0.0, "attack_reach": 0.0, "id": "far_player",
			"steps_per_turn": 0,
		}),
		Vector2(4.5, 14.5),
	)
	var boss_u := UnitInstance.from_unit_data(boss_data, Vector2i(3, 1), UnitInstance.Team.ENEMY)
	var boss := sim.add_unit(boss_u, Vector2(3.5, 1.5))
	if boss == null:
		push_error("summon_advance: boss null")
		return false
	sim.begin_combat()
	var first_cell := Vector2i(-999, -999)
	var saw_move := false
	var guard := 0
	while guard < 500 and not sim.is_finished():
		sim.advance_fixed_step()
		guard += 1
		for item in sim.get_units():
			var rt := item as RtUnit
			if rt == null or not rt.is_alive() or rt.unit == null or not rt.unit.is_combat_summon:
				continue
			if rt.get_stats().steps_per_turn < 1:
				push_error("summon_advance: steps_per_turn<%d" % rt.get_stats().steps_per_turn)
				return false
			if rt.is_deploying():
				push_error("summon_advance: still deploying")
				return false
			if first_cell.x == -999:
				first_cell = rt.cell
			elif rt.cell != first_cell:
				## 须朝玩家半场推进（y 增大）或至少离开出生格
				if rt.cell.y > first_cell.y or rt.cell != first_cell:
					saw_move = true
					break
		if saw_move:
			break
	if not saw_move:
		push_error("summon_advance: minion never left spawn cell %s" % str(first_cell))
		return false
	return true


## 低血且受威胁：优先瞬移拉开，不贴脸出手。
static func _test_boss_low_hp_flees_threat() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 71)
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 50, "attack": 1, "steps_per_turn": 0, "attack_reach": 2.0, "id": "threat",
		}),
		Vector2(4.5, 5.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 100, "attack": 20, "steps_per_turn": 1, "attack_reach": 1.5,
			"id": "boss", "is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
		}),
		Vector2(4.5, 3.5),
	)
	if ally == null or boss == null:
		push_error("flee: place failed")
		return false
	boss.unit.current_hp = 30
	boss.skip_deploy()
	var can_summon := func(_actor: RtUnit) -> bool: return false
	var can_tp := func(actor: RtUnit, origin: Vector2i) -> bool:
		return sim._boss_can_teleport_to(actor, origin)

	var before := boss.cell
	var before_d := boss.cell_distance_to(ally)
	var decision := RtUnitBrain.decide_boss_leader_turn(
		boss, sim.get_units(), 0.05, 1, false, can_summon, can_tp
	)
	if decision.teleport_cell == Vector2i(-1, -1):
		push_error("flee: expected flee teleport")
		return false
	if decision.fire or decision.summon:
		push_error("flee: must not attack/summon while fleeing")
		return false
	## 目标锚点相对威胁的足迹距须严格变大（落格动画完成前 cell 仍为旧锚）。
	var planned_d := _footprint_chebyshev_between(boss, decision.teleport_cell, ally, ally.cell)
	if planned_d <= before_d:
		push_error(
			"flee: planned dist %d not > %d (from %s to %s)"
			% [planned_d, before_d, str(before), str(decision.teleport_cell)]
		)
		return false
	if not sim.try_boss_teleport_for_test(boss, decision.teleport_cell):
		push_error("flee: teleport apply failed")
		return false
	if boss.get_occupied_cell() != decision.teleport_cell:
		push_error("flee: occupied %s != %s" % [boss.get_occupied_cell(), decision.teleport_cell])
		return false
	if boss.state != RtUnit.State.MOVING:
		push_error("flee: expected MOVING state got %d" % boss.state)
		return false
	return true


static func _footprint_chebyshev_between(
	a: RtUnit, a_origin: Vector2i, b: RtUnit, b_origin: Vector2i
) -> int:
	var mine := a.get_footprint_cells(a_origin)
	var theirs := b.get_footprint_cells(b_origin)
	var best := 999999
	for c1 in mine:
		for c2 in theirs:
			best = mini(best, RtUnit.chebyshev(c1, c2))
	return best



## 召唤分支切到 SUMMONING 状态（与移动/攻击可区分）。
static func _test_boss_summon_sets_summoning_state() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 72)
	var body := make_summon_body()
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"max_hp": 50, "steps_per_turn": 0, "attack_reach": 0.0, "sight_range": 0.0, "id": "far",
		}),
		Vector2(16.5, 28.5),
	)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 100, "steps_per_turn": 1, "attack_reach": 1.0,
			"id": "boss", "is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"summon_unit": body, "summon_max_alive": 2, "summon_per_action": 1,
		}),
		Vector2(4.5, 3.5),
	)
	if ally == null or boss == null:
		push_error("summon_state: place failed")
		return false
	boss.skip_deploy()
	boss.unit.current_hp = 100
	var can_summon := func(actor: RtUnit) -> bool: return sim._boss_can_summon(actor)
	var can_tp := func(actor: RtUnit, origin: Vector2i) -> bool:
		return sim._boss_can_teleport_to(actor, origin)
	var decision := RtUnitBrain.decide_boss_leader_turn(
		boss, sim.get_units(), 0.05, 1, false, can_summon, can_tp
	)
	if not decision.summon:
		push_error("summon_state: expected summon decision (state=%d fire=%s tp=%s)" % [
			boss.state, decision.fire, str(decision.teleport_cell)
		])
		return false
	if boss.state != RtUnit.State.SUMMONING:
		push_error("summon_state: expected SUMMONING got %d" % boss.state)
		return false
	return true


## 远程单位 attack_range / attack_reach 硬顶 2 格。
static func _test_ranged_attack_reach_clamped_to_2() -> bool:
	var stats := UnitStats.new()
	stats.max_hp = 3
	stats.attack = 5
	stats.attack_range = 5
	stats.attack_reach = 5.0
	stats.projectile_speed = 12.0
	var data := UnitData.new()
	data.id = "longbow"
	data.stats = stats
	var unit := UnitInstance.from_unit_data(data, Vector2i.ZERO, UnitInstance.Team.PLAYER)
	if unit.stats.attack_range > 2 or unit.stats.attack_reach > 2.0 + 0.001:
		push_error(
			"ranged_clamp: range=%d reach=%s"
			% [unit.stats.attack_range, unit.stats.attack_reach]
		)
		return false
	return true


## 首领 2×2 足迹在 9 宽场上应水平居中（足迹中心贴近 board_cx=4）。
static func _test_boss_footprint_horiz_centered() -> bool:
	var sim := _new_sim()
	## 本断言依赖 9 宽；保留显式大盘，不跟主路径 5×8。
	sim.configure(Vector2i(9, 16), 62)
	## 敌方前排居中座约 (4,5)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"id": "boss", "is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"steps_per_turn": 0, "attack_reach": 1.0,
		}),
		Vector2(4.5, 5.5),
	)
	if boss == null:
		push_error("footprint_center: boss null")
		return false
	var cells := boss.get_footprint_cells(boss.cell)
	if cells.size() != 4:
		push_error("footprint_center: expected 4 cells")
		return false
	var sx := 0
	for c in cells:
		sx += c.x
	var fp_cx := float(sx) / float(cells.size())
	var board_cx := 4.0
	if absf(fp_cx - board_cx) > 0.51:
		push_error("footprint_center: fp_cx=%s not near board center" % fp_cx)
		return false
	return true


## 同列前方优先于左侧先生成单位（即使切比雪夫同距、左侧 id 更小）。
static func _test_acquire_prefers_lane_on_chebyshev_tie() -> bool:
	var sim := _new_sim()
	## 需要宽场验证左右分路；保留显式大盘。
	sim.configure(ARENA, 11)
	var p_right := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 0, "attack_reach": 1.0, "sight_range": 99.0,
		}),
		Vector2(8.5, 12.5),
	)
	## 先生成左侧敌人（更小 instance_id），再生成同列敌人；切比雪夫同为 9。
	var e_left := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"steps_per_turn": 0, "attack_reach": 1.0}),
		Vector2(0.5, 3.5),
	)
	var e_right := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"steps_per_turn": 0, "attack_reach": 1.0}),
		Vector2(8.5, 3.5),
	)
	if p_right.cell_distance_to(e_left) != p_right.cell_distance_to(e_right):
		push_error("lane_tie: expected equal chebyshev")
		return false
	if e_left.get_id() >= e_right.get_id():
		push_error("lane_tie: left enemy should have smaller id")
		return false
	var acquired := RtUnitBrain.acquire_target(p_right, sim.get_units())
	if acquired != e_right:
		push_error(
			"lane_tie: expected same-column enemy id=%d got id=%d cell=%s"
			% [e_right.get_id(), acquired.get_id() if acquired else -1, acquired.cell if acquired else Vector2i(-1, -1)]
		)
		return false
	return true


## 左右两路对位时，右路不应被索敌平局拖去左半场。
static func _test_flanks_do_not_collapse_left() -> bool:
	var sim := _new_sim()
	## 需要宽场验证左右分路；保留显式大盘。
	sim.configure(ARENA, 13)
	var p_left := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 2, "attack_reach": 1.0, "attack_windup": 0.0, "sight_range": 99.0,
		}),
		Vector2(0.5, 12.5),
	)
	var p_right := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"steps_per_turn": 2, "attack_reach": 1.0, "attack_windup": 0.0, "sight_range": 99.0,
		}),
		Vector2(8.5, 12.5),
	)
	var e_left := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"steps_per_turn": 2, "attack_reach": 1.0, "attack_windup": 0.0, "sight_range": 99.0,
		}),
		Vector2(0.5, 3.5),
	)
	var e_right := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"steps_per_turn": 2, "attack_reach": 1.0, "attack_windup": 0.0, "sight_range": 99.0,
		}),
		Vector2(8.5, 3.5),
	)
	for _i in 48:
		sim.step(0.25)
		if sim.is_finished():
			break
	## 右路单位应仍在右半（x>=5），证明未全体涌向左中。
	if p_right.is_alive() and p_right.cell.x < 5:
		push_error("flanks: player right collapsed left to %s" % p_right.cell)
		return false
	if e_right.is_alive() and e_right.cell.x < 5:
		push_error("flanks: enemy right collapsed left to %s" % e_right.cell)
		return false
	## 左路也不应跑到右半（对称健全性）。
	if p_left.is_alive() and p_left.cell.x > 3:
		push_error("flanks: player left drifted right to %s" % p_left.cell)
		return false
	if e_left.is_alive() and e_left.cell.x > 3:
		push_error("flanks: enemy left drifted right to %s" % e_left.cell)
		return false
	return true


## 普攻暴击：100% 暴击率时伤害翻倍，并标记 last_hit_was_crit。
static func _test_attack_crit_doubles_and_marks() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 77)
	var attacker := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {
			"attack": 5,
			"crit_chance": 1.0,
			"crit_multiplier": 2.0,
			"steps_per_turn": 0,
			"attack_windup": 0.0,
			"attack_interval": 0.5,
			"attack_reach": 1.5,
		}),
		Vector2(8.5, 12.5),
	)
	var defender := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"max_hp": 40,
			"steps_per_turn": 0,
			"attack_reach": 0.0,
		}),
		Vector2(8.5, 11.5),
	)
	sim._pipeline.resolve_hit(attacker, defender, 5, 0.0, sim.get_units())
	if defender.unit.current_hp != 30:
		push_error(
			"crit: expected hp 30 after 2x5 hit, got %d"
			% defender.unit.current_hp
		)
		return false
	if not defender.last_hit_was_crit:
		push_error("crit: last_hit_was_crit should be true")
		return false
	if defender.last_hit_amount != 10:
		push_error("crit: last_hit_amount expected 10 got %d" % defender.last_hit_amount)
		return false
	return true


## 表现锚应落在 2×2 四格几何正中（非锚点格心）。
static func _test_boss_visual_centers_in_footprint() -> bool:
	var mid := RtUnit.footprint_center_for(Vector2i(3, 4), Vector2i(2, 2))
	if mid != Vector2(4.0, 5.0):
		push_error("visual_center: static mid=%s want (4,5)" % mid)
		return false
	var sim := _new_sim()
	## 足迹中心断言与 9 宽场配套；锚点避开默认 2×5 座位行，以免半格 bias 掺入。
	sim.configure(Vector2i(9, 16), 62)
	var boss := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {
			"id": "boss", "is_boss_leader": true, "footprint_w": 2, "footprint_h": 2,
			"steps_per_turn": 0, "attack_reach": 1.0,
		}),
		Vector2(4.5, 3.5),
	)
	if boss == null:
		push_error("visual_center: boss null")
		return false
	var expect := RtUnit.footprint_center_for(boss.cell, boss.get_footprint_size())
	if boss.position.distance_to(expect) > 0.001:
		push_error("visual_center: pos=%s expect=%s (anchor=%s)" % [boss.position, expect, boss.cell])
		return false
	## 不应停在锚点格心。
	var anchor_center := RtUnit.cell_center(boss.cell)
	if boss.position.distance_to(anchor_center) < 0.25:
		push_error("visual_center: still at anchor cell center %s" % boss.position)
		return false
	return true


## 观战时停 hold 固定步时，当前行动者攻击前摇仍应走完并出手（弩手等远程蓄力）。
static func _test_windup_advances_under_presentation_hold() -> bool:
	var bow_data := load("res://resources/units/realtime/crossbow.tres") as UnitData
	if bow_data == null:
		push_error("windup hold: crossbow data missing")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 880)
	var bow := sim.add_unit(
		UnitInstance.from_unit_data(bow_data, Vector2i(9, 20), UnitInstance.Team.PLAYER),
		Vector2(9.5, 20.5),
	)
	var foe := sim.add_unit(
		make_dummy(UnitInstance.Team.ENEMY, 500, {"id": "foe", "steps_per_turn": 0, "attack_reach": 1.0}),
		Vector2(9.5, 18.5),
	)
	sim.begin_combat()
	var found_windup := false
	for _i in 500:
		sim.advance_fixed_step()
		if bow.state == RtUnit.State.ATTACKING and bow.attack_timer > 0.02:
			found_windup = true
			break
	if not found_windup:
		push_error("windup hold: crossbow never entered attack windup")
		return false
	var atk_before := bow.last_attack_time
	sim.hold_for_presentation()
	var guard := 0
	while bow.attack_timer > RtUnitBrain.TIME_EPSILON and guard < 80:
		sim.advance_attack_windup_under_hold(0.05)
		guard += 1
	if bow.last_attack_time == atk_before:
		push_error("windup hold: expected ranged fire while presentation held")
		return false
	sim.release_presentation()
	return true


## defer + 待结算技能：step 不得同帧追帧忙等（实战卡死回归）。
static func _test_step_breaks_on_pending_defer() -> bool:
	var data := load("res://resources/units/realtime/shinobi.tres") as UnitData
	if data == null:
		push_error("step_pending: shinobi data missing")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 881)
	sim.defer_effect_resolve = true
	var shinobi_rt := sim.add_unit(
		UnitInstance.from_unit_data(data, Vector2i(2, 26), UnitInstance.Team.PLAYER),
		Vector2(2.5, 26.5),
	)
	shinobi_rt.unit.level = 2
	shinobi_rt.unit.stats.steps_per_turn = 0
	sim.add_unit(make_dummy(UnitInstance.Team.ENEMY, 20), Vector2(14.5, 8.5))
	sim.begin_combat()
	var payload := CombatEventPayload.new()
	payload.source = shinobi_rt.unit
	payload.target = shinobi_rt.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ROUND_START, payload)
	if not sim.has_pending_effects():
		push_error("step_pending: expected pending skill batch after ON_ROUND_START")
		return false
	var steps_before := sim.fixed_step_count
	sim.presentation_hold = false
	sim.step(2.0)
	var progressed := sim.fixed_step_count - steps_before
	if progressed >= 30:
		push_error(
			"step_pending: step(2s) progressed %d fixed steps while blocked (busy loop?)"
			% progressed
		)
		return false
	return true


## defer 观战：命中后不得强排空队，否则「A 击杀触发 B 技能」会跟 A 同帧结算且跳过 B 的介绍卡。
static func _test_deferred_hit_keeps_chained_skill_batches() -> bool:
	var ash_data := load("res://resources/units/realtime/aftershock.tres") as UnitData
	var scatter_data := load("res://resources/units/realtime/scatter_hex.tres") as UnitData
	if ash_data == null or scatter_data == null:
		push_error("defer_hit: unit data missing")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 994)
	sim.defer_effect_resolve = true
	var killer_rt := sim.add_unit(
		UnitInstance.from_unit_data(ash_data, Vector2i(9, 20), UnitInstance.Team.PLAYER),
		Vector2(9.5, 20.5),
	)
	sim.add_unit(
		UnitInstance.from_unit_data(scatter_data, Vector2i(10, 20), UnitInstance.Team.PLAYER),
		Vector2(10.5, 20.5),
	)
	var foe_rt := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"max_hp": 1, "attack": 0, "id": "fodder"}),
		Vector2(9.5, 10.5),
	)
	sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"max_hp": 20, "attack": 0, "id": "fodder_b"}),
		Vector2(11.5, 10.5),
	)
	sim.begin_combat()
	var drain_guard := 0
	while sim.has_pending_effects() and drain_guard < 48:
		sim.resolve_next_pending_effect()
		drain_guard += 1
	if killer_rt == null or foe_rt == null:
		push_error("defer_hit: missing rt")
		return false
	sim._resolve_hit(killer_rt, foe_rt, 5, 0.0)
	if not sim.has_pending_effects():
		push_error("defer_hit: expected pending batches after lethal hit")
		return false
	var first := sim.peek_pending_effect_batch()
	if first == null or first.owner != killer_rt.unit:
		push_error("defer_hit: first batch should be killer on-kill")
		return false
	sim.resolve_next_pending_effect()
	if not sim.has_pending_effects():
		push_error("defer_hit: expected ally trigger batch still queued")
		return false
	var second := sim.peek_pending_effect_batch()
	if second == null or second.owner == killer_rt.unit:
		push_error("defer_hit: second batch should be another ally's skill")
		return false
	return true


static func _test_deferred_lethal_keeps_unit_until_death_finalize() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 994)
	sim.defer_effect_resolve = true
	var ally := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {"max_hp": 6, "attack": 9, "id": "striker"}),
		Vector2(4.5, 20.5),
	)
	var foe := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"max_hp": 3, "attack": 0, "id": "fodder"}),
		Vector2(4.5, 10.5),
	)
	sim.begin_combat()
	var guard := 0
	while sim.has_pending_effects() and guard < 48:
		sim.resolve_next_pending_effect()
		guard += 1
	sim._resolve_hit(ally, foe, ally.get_effective_attack(), 0.0)
	if not sim.is_death_presentation_pending(foe):
		push_error("defer_draw: foe should await death finalize")
		return false
	var still_listed := false
	for rt in sim.get_units():
		if rt == foe:
			still_listed = true
			break
	if not still_listed:
		push_error("defer_draw: foe must stay in unit list until finalize")
		return false
	sim._remove_dead()
	for rt in sim.get_units():
		if rt == foe:
			still_listed = true
	if not still_listed:
		push_error("defer_draw: remove_dead must keep pending presentation unit")
		return false
	sim.flush_idle_death_presentations()
	if sim.is_death_presentation_pending(foe):
		push_error("defer_draw: pending should clear after flush")
		return false
	return true


static func _test_deferred_hit_emits_unit_died_for_death_fx() -> bool:
	var sim := _new_sim()
	sim.configure(ARENA, 995)
	sim.defer_effect_resolve = true
	var killer_rt := sim.add_unit(
		make_unit(UnitInstance.Team.PLAYER, {"attack": 5, "id": "atk"}),
		Vector2(9.5, 20.5),
	)
	var foe_rt := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"max_hp": 1, "attack": 0, "id": "fodder"}),
		Vector2(9.5, 10.5),
	)
	sim.begin_combat()
	var drain_guard := 0
	while sim.has_pending_effects() and drain_guard < 48:
		sim.resolve_next_pending_effect()
		drain_guard += 1
	var died: Array[int] = [0]
	sim.unit_died.connect(func(_rt: RtUnit) -> void: died[0] += 1)
	sim._resolve_hit(killer_rt, foe_rt, 5, 0.0)
	if foe_rt.unit.current_hp > 0:
		push_error("defer_death_fx: hit should kill fodder")
		return false
	if died[0] != 0:
		push_error("defer_death_fx: unit_died must wait until skill queue idle")
		return false
	sim.flush_idle_death_presentations()
	if died[0] != 1:
		push_error("defer_death_fx: expected unit_died after idle flush, got %d" % died[0])
		return false
	return true


static func _test_deferred_mirror_warden_convert_before_death_finalize() -> bool:
	var data := load("res://resources/units/realtime/mirror_warden.tres") as UnitData
	if data == null:
		push_error("defer_warden: data")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 996)
	sim.defer_effect_resolve = true
	var warden := sim.add_unit(
		UnitInstance.from_unit_data(data, Vector2i(9, 20), UnitInstance.Team.PLAYER),
		Vector2(9.5, 20.5),
	)
	var foe := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"max_hp": 4, "attack": 0, "id": "fodder"}),
		Vector2(9.5, 10.5),
	)
	sim.begin_combat()
	var drain_guard := 0
	while sim.has_pending_effects() and drain_guard < 48:
		sim.resolve_next_pending_effect()
		drain_guard += 1
	var died: Array[int] = [0]
	sim.unit_died.connect(func(_rt: RtUnit) -> void: died[0] += 1)
	## 确保致死以触发 OnKill 策反（禁卫基础攻可能 < 4）。
	sim._resolve_hit(warden, foe, maxi(4, warden.get_effective_attack()), 0.0)
	if not sim.has_pending_effects():
		push_error("defer_warden: convert batch should be queued")
		return false
	sim.flush_idle_death_presentations()
	if died[0] != 0:
		push_error("defer_warden: must not finalize death before convert")
		return false
	sim.resolve_next_pending_effect()
	if not foe.is_alive() or foe.get_team() != UnitInstance.Team.PLAYER:
		push_error("defer_warden: convert failed under defer")
		return false
	sim.flush_idle_death_presentations()
	if died[0] != 0:
		push_error("defer_warden: converted unit must not emit unit_died")
		return false
	return true


static func _test_defer_warden_convert_defers_player_wipe_loss() -> bool:
	var data := load("res://resources/units/realtime/mirror_warden.tres") as UnitData
	if data == null:
		push_error("warden_wipe: data")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 995)
	sim.defer_effect_resolve = true
	var warden := sim.add_unit(
		UnitInstance.from_unit_data(data, Vector2i(4, 20), UnitInstance.Team.PLAYER),
		Vector2(4.5, 20.5),
	)
	warden.unit.current_hp = 3
	var victim := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"max_hp": 4, "attack": 0, "id": "victim"}),
		Vector2(4.5, 10.5),
	)
	var bystander := sim.add_unit(
		make_unit(UnitInstance.Team.ENEMY, {"max_hp": 8, "attack": 0, "id": "bystander"}),
		Vector2(2.5, 10.5),
	)
	sim.begin_combat()
	var guard := 0
	while sim.has_pending_effects() and guard < 48:
		sim.resolve_next_pending_effect()
		guard += 1
	sim._resolve_hit(warden, victim, maxi(4, warden.get_effective_attack()), 0.0)
	if not sim.has_pending_effects():
		push_error("warden_wipe: convert should be queued")
		return false
	## 模拟禁卫已阵亡、策反尚未结算（defer 队列仍挂着 OnKill）。
	warden.unit.current_hp = 0
	warden.state = RtUnit.State.DEAD
	if sim.count_alive(UnitInstance.Team.PLAYER) != 0:
		push_error("warden_wipe: setup player wipe before convert")
		return false
	sim._check_finished()
	if sim.is_finished():
		push_error("warden_wipe: must not lose before convert resolves")
		return false
	var resolve_guard := 0
	while sim.has_pending_effects() and resolve_guard < 48:
		sim.resolve_next_pending_effect()
		resolve_guard += 1
	sim.flush_idle_death_presentations()
	if sim.count_alive(UnitInstance.Team.PLAYER) != 1:
		push_error("warden_wipe: converted ally should be sole player survivor")
		return false
	if warden.is_alive():
		push_error("warden_wipe: warden should stay dead after convert")
		return false
	if victim.get_team() != UnitInstance.Team.PLAYER:
		push_error("warden_wipe: victim team")
		return false
	sim._check_finished()
	if sim.is_finished():
		push_error("warden_wipe: fight should continue with enemy bystander")
		return false
	if sim.count_alive(UnitInstance.Team.ENEMY) != 1:
		push_error("warden_wipe: bystander enemy expected")
		return false
	return true
