class_name RealtimeCombatSim
extends RefCounted
## 即时并行滑移战纯逻辑模拟：全员同时索敌 → 绕障连续滑移 → 进距按攻击间隔出手。
## 移动圆裁剪 + 侧向转向；残余重叠由移动方退让（不推动静止单位）。
## 固定步长推进，结果与调用方帧率无关。坐标单位为格（连续）；时间单位为秒。

signal unit_added(unit: RtUnit)
signal unit_attacked(attacker: RtUnit, target: RtUnit)
signal unit_damaged(unit: RtUnit, amount: int)
signal unit_died(unit: RtUnit)
signal projectile_spawned(projectile: RtProjectile)
signal splash_triggered(center: Vector2, radius: float)
signal combat_finished(won: bool)
## 兼容旧 UI：并行下恒为 null。
signal current_actor_changed(actor: RtUnit)
## 约每 1s 战斗时钟脉冲一次（观战录音机 / 倒带游标兼容）。
signal actor_turn_ended(completed_turns: int)

const FIXED_STEPS_PER_SECOND := 30
const FIXED_DT := 1.0 / FIXED_STEPS_PER_SECOND
const SEPARATION_ITERATIONS := 4
const UNIT_PULSE_SECONDS := 1.0
const STEP_EPSILON := 0.000001
const EFFECT_DRAIN_GUARD := 64

var elapsed_seconds: float = 0.0
var fixed_step_count: int = 0

var _arena_size: Vector2 = Vector2(5, 4)
var _rng := RandomNumberGenerator.new()
var _bus: CombatEventBus
var _owns_bus: bool = false
var _pipeline: RealtimeDamagePipeline
var _effect_grid: BoardGrid
var _effect_pipeline: DamagePipeline
var _effect_resolver: EffectResolver
var _units: Array[RtUnit] = []
var _projectiles: Array[RtProjectile] = []
## 生成落点分散用；主路径移动不再硬阻挡。
var _occupancy: Dictionary = {}
var _input_seconds: float = 0.0
var _started: bool = false
var _finished: bool = false
var _player_won: bool = false
var _adding_effect_spawn: bool = false
## 表现层时停钩子：为 true 时 step 不再推进固定步。
var presentation_hold: bool = false
## 为 true 时：效果只入队不立刻排空（锁阵短串行；战斗中控制器应关掉）。
var defer_effect_resolve: bool = false
## 为 true 时：场上暂无友方也不判负（玩家仍有牌可出时由战斗控制器置位）。
var suppress_player_wipe_loss: bool = false

## 开战锁阵生成序（按 add_unit 先后）。
var _lock_spawn_order: Array[RtUnit] = []
## 兼容旧 API：并行下不再驱动主循环。
var _action_queue: Array[RtUnit] = []
var _queue_cursor: int = 0
var _round_index: int = 0
var _current_actor: RtUnit = null
var _actor_steps_left: int = 0
var _actor_has_attacked: bool = false
var _actor_turn_active: bool = false
## 本场出现过 Boss 首领 → 启用斩首胜负（非清波）。
var _had_boss_leader: bool = false
## 兼容续动武装（并行下普攻不交权；技能副作用仍可读）。
var _turn_refresh_armed_instance_id: int = -1
## 自开战起累计的 1s 脉冲次数（录音机倒带游标）。
var _completed_actor_turns: int = 0
var _tape_pulse_accum: float = 0.0
## begin_combat 后：开战技能排空且并行时钟已就绪。
var _combat_queue_seeded: bool = false


func _init(bus: CombatEventBus = null) -> void:
	if bus == null:
		bus = CombatEventBus.new()
		bus.name = "RealtimeCombatEventBus"
		_owns_bus = true
	_bus = bus
	_bus.combat_event.connect(_on_bus_event)
	_pipeline = RealtimeDamagePipeline.new(_bus, _rng)
	_setup_effect_resolver()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _owns_bus and is_instance_valid(_bus):
		_bus.free()


func configure(arena_size: Vector2i, rng_seed: int) -> void:
	_arena_size = Vector2(maxi(1, arena_size.x), maxi(1, arena_size.y))
	_rng.seed = rng_seed
	_pipeline.set_rng(_rng)
	_setup_effect_resolver()


## 战斗结束后调用：断开 bus 与所有观察者、打断单位间的目标引用环，并释放自建的 bus。
## 注入的 bus 由调用方负责释放。
func dispose() -> void:
	for sig in get_signal_list():
		for conn in get_signal_connection_list(sig["name"]):
			disconnect(sig["name"], conn["callable"])
	_break_reference_cycles()
	_units.clear()
	_projectiles.clear()
	_occupancy.clear()
	_lock_spawn_order.clear()
	_action_queue.clear()
	_current_actor = null
	_actor_turn_active = false
	_tape_pulse_accum = 0.0
	_had_boss_leader = false
	_teardown_effect_resolver()
	if _bus != null and is_instance_valid(_bus):
		if _bus.combat_event.is_connected(_on_bus_event):
			_bus.combat_event.disconnect(_on_bus_event)
		if _owns_bus:
			_bus.free()
	_bus = null
	_pipeline = RealtimeDamagePipeline.new(null, _rng)


func get_event_bus() -> CombatEventBus:
	return _bus


func get_effect_resolver() -> EffectResolver:
	return _effect_resolver


## 注入 Run 经济，供战斗内 GRANT_GOLD / 读金加身等效果使用。
func set_economy(economy: RunEconomy) -> void:
	if _effect_resolver != null:
		_effect_resolver.set_economy(economy)


## 注入本局牌库，供永久属性等写入 DeckEntry.bonus_*。
func set_deck_state(deck_state: DeckState) -> void:
	if _effect_resolver != null:
		_effect_resolver.set_deck_state(deck_state)


func get_arena_size() -> Vector2:
	return _arena_size


func add_unit(unit: UnitInstance, position: Vector2) -> RtUnit:
	if unit == null:
		push_error("RealtimeCombatSim.add_unit: unit is null")
		return null
	if _finished:
		push_warning("RealtimeCombatSim.add_unit: combat already finished")
		return null
	var existing := _find_rt_for_unit(unit)
	if existing != null:
		return existing
	var preferred := _clamp_cell(Vector2i(floori(position.x), floori(position.y)))
	var fp := unit.get_footprint_size()
	var cell := Vector2i(-1, -1)
	if fp.x > 1 or fp.y > 1:
		cell = _find_free_footprint_origin(preferred, fp, unit.team)
		if cell == Vector2i(-1, -1):
			push_warning(
				"RealtimeCombatSim.add_unit: footprint %dx%d failed for %s; fallback 1x1"
				% [fp.x, fp.y, unit.id]
			)
			if unit.unit_data != null:
				var body := unit.unit_data.duplicate(true) as UnitData
				body.footprint_w = 1
				body.footprint_h = 1
				unit.unit_data = body
			fp = Vector2i(1, 1)
	if cell == Vector2i(-1, -1):
		cell = _find_free_cell(preferred)
	if cell == Vector2i(-1, -1):
		push_warning("RealtimeCombatSim.add_unit: arena full, cannot place %s" % unit.id)
		return null
	var rt := RtUnit.new(unit, RtUnit.cell_center(cell))
	rt.arena_size = Vector2i(maxi(1, int(_arena_size.x)), maxi(1, int(_arena_size.y)))
	## 半格按「当前格所属座位行」计算；寻路换行时 begin_step/_commit_step 会随目标格刷新。
	rt.snap_to_cell(cell)
	rt.spawn_time = elapsed_seconds
	## 入场默认不能出手：先走满一轮 attack_interval。
	rt.attack_timer = maxf(0.05, rt.get_stats().attack_interval)
	## 开战锁阵预置单位立刻可交战；战中补人才走 deploy_time。
	if not _started:
		rt.skip_deploy()
	unit.grid_pos = rt.get_cell()
	var index := 0
	while index < _units.size() and _units[index].get_id() < rt.get_id():
		index += 1
	_units.insert(index, rt)
	_occupy_footprint(rt, cell)
	_register_on_effect_grid(unit, rt.get_cell())
	if unit.is_boss_leader():
		_had_boss_leader = true
	## 开战前：记录锁阵生成序。开战中：立刻参与并行更新。
	if not _started:
		_lock_spawn_order.append(rt)
	else:
		rt.action_eligible_from_round = 0
		if unit.is_combat_summon:
			rt.skip_deploy()
		_insert_mid_combat_into_queue(rt)
	unit_added.emit(rt)
	## 锁阵生成与战中补人：每体生成当下发部署类事件并排空效果（开战事件仍由 begin_combat）。
	if not _adding_effect_spawn:
		_emit_spawn_events(unit, rt.get_cell())
		_drain_effects_unless_deferred()
	return rt


## 仅开战前允许（准备阶段收回）。
func remove_unit(rt: RtUnit) -> bool:
	if _started or rt == null:
		return false
	var index := _units.find(rt)
	if index < 0:
		return false
	_units.remove_at(index)
	var spawn_i := _lock_spawn_order.find(rt)
	if spawn_i >= 0:
		_lock_spawn_order.remove_at(spawn_i)
	rt.target = null
	_clear_occupancy_of(rt)
	if _effect_grid != null:
		_effect_grid.remove_unit(rt.unit)
	return true


## 场上单位（含部署中，不含已死亡），按 instance_id 升序。
func get_units() -> Array:
	return _units.duplicate()


func get_projectiles() -> Array:
	return _projectiles.duplicate()


## 表现层：按 UnitInstance 查找场上 RtUnit（含刚死亡、尚未 _remove_dead 的）。
func find_unit(unit: UnitInstance) -> RtUnit:
	return _find_rt_for_unit(unit)


func find_unit_by_deck_entry(entry_id: int) -> RtUnit:
	for rt in _units:
		if rt.is_player() and rt.unit.deck_entry_id == entry_id and rt.is_alive():
			return rt
	return null


func count_alive(team: UnitInstance.Team) -> int:
	var count := 0
	for rt in _units:
		if rt.get_team() == team and rt.is_alive():
			count += 1
	return count


func is_death_presentation_pending(rt: RtUnit) -> bool:
	return _pipeline != null and _pipeline.has_pending_death_presentation(rt)


## 占格查询（测试 / 调试）。
func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupancy_owner(cell) != null


func get_occupancy_owner(cell: Vector2i) -> RtUnit:
	return _occupancy_owner(cell)


## 测试/调试：尝试首领足迹刚性平移一步（含推开）。
func try_boss_step_for_test(rt: RtUnit, dir: Vector2i) -> bool:
	return _boss_try_step(rt, dir)


func try_boss_teleport_for_test(rt: RtUnit, origin: Vector2i) -> bool:
	return _boss_try_teleport(rt, origin)


## 标记开战：广播游戏开始 →（可选）排空开战技能 → 就绪并行时钟。
## defer_effect_resolve=true 时只入队开战技能，由控制器锁阵播报后再结算。
func begin_combat() -> void:
	if _started or _finished:
		return
	_started = true
	_completed_actor_turns = 0
	_tape_pulse_accum = 0.0
	_combat_queue_seeded = false
	_bus_emit(CombatEvents.ON_COMBAT_START, CombatEventPayload.new())
	if defer_effect_resolve:
		if not has_pending_effects():
			_seed_action_queue_if_ready()
		return
	_flush_combat_start_lock()


## 测试/倒带：无视 defer，立刻排空开战技能并就绪并行时钟。
func flush_combat_start_lock() -> void:
	_flush_combat_start_lock()


## Headless / 批跑：同步推进直到结束或步数上限；不依赖 presentation 时停。
func run_until_finished(max_steps: int = 500_000) -> Dictionary:
	var steps := 0
	while not _finished and steps < max_steps:
		if has_pending_effects():
			resolve_next_pending_effect()
			steps += 1
			continue
		if presentation_hold:
			release_presentation()
		if has_started() and not is_action_queue_seeded() and not has_pending_effects():
			try_seed_action_queue()
		var before := fixed_step_count
		advance_fixed_step()
		if fixed_step_count == before and not _finished:
			## 门闩无进展：避免忙等卡死。
			break
		steps += 1
	return {
		"finished": is_finished(),
		"won": did_player_win(),
		"steps": steps,
		"fixed_steps": fixed_step_count,
		"timed_out": not is_finished(),
	}


func try_seed_action_queue() -> void:
	_seed_action_queue_if_ready()


func is_action_queue_seeded() -> bool:
	return _combat_queue_seeded


func has_started() -> bool:
	return _started


func is_finished() -> bool:
	return _finished


func did_player_win() -> bool:
	return _finished and _player_won


## 并行下无「当前行动者」；恒为 null。
func get_current_actor() -> RtUnit:
	return null


## 并行下无一动交权；恒为 false（出击 tween 不应挡全场步进）。
func is_actor_turn_active() -> bool:
	return false


## 战斗时钟约秒序号（从 1 起）。
func get_round_index() -> int:
	return maxi(1, _round_index)


## 兼容旧 API：返回锁阵生成序快照（非行动队列）。
func get_action_queue() -> Array:
	if not _action_queue.is_empty():
		return _action_queue.duplicate()
	return _lock_spawn_order.duplicate()


func get_queue_cursor() -> int:
	return _queue_cursor


## 已累计的 1s 脉冲次数（开战锁阵后为 0）。
func get_completed_actor_turns() -> int:
	return _completed_actor_turns


## 按调用方 dt 推进；内部以 FIXED_DT 拆步，累计总输入时间决定步数，避免浮点累加误差导致步数漂移。
func step(dt: float) -> void:
	if _finished or dt <= 0.0 or presentation_hold:
		return
	_input_seconds += dt
	var target_steps := floori(_input_seconds * FIXED_STEPS_PER_SECOND + STEP_EPSILON)
	while fixed_step_count < target_steps and not _finished:
		if presentation_hold:
			## 时停切入：丢弃本帧尚未执行的步，避免恢复时瞬间追帧。
			_input_seconds = fixed_step_count * FIXED_DT
			return
		var steps_before := fixed_step_count
		advance_fixed_step()
		if fixed_step_count == steps_before and not _finished:
			## 待结算技能等门闩：本步无进展，勿同帧忙等（否则主线程卡死）。
			_input_seconds = fixed_step_count * FIXED_DT
			break


## 技能播报时停：打断后续固定步；队列清空后由控制器 release。
func hold_for_presentation() -> void:
	presentation_hold = true
	_input_seconds = fixed_step_count * FIXED_DT


func release_presentation() -> void:
	presentation_hold = false


func has_pending_effects() -> bool:
	return _effect_resolver != null and _effect_resolver.has_pending_steps()


## 结算前只读队首技能批次（展示介绍卡用）。
func peek_pending_effect_batch() -> QueuedEffectBatch:
	if _effect_resolver == null:
		return null
	return _effect_resolver.peek_next_batch()


## 执行队首一批技能（真值写入）；同步生成/死亡。供「先卡再结算」第二拍调用。
func resolve_next_pending_effect() -> bool:
	if _effect_resolver == null or not _effect_resolver.has_pending_steps():
		_seed_action_queue_if_ready()
		return false
	_sync_effect_grid_from_rt_positions()
	_effect_resolver.process_next_step()
	_sync_rt_positions_from_effect_grid()
	_sync_effect_spawns_from_grid()
	_flush_pending_death_presentations_if_queue_idle()
	_sync_deaths_from_hp()
	_seed_action_queue_if_ready()
	return true


func advance_fixed_step() -> void:
	if _finished:
		return
	begin_combat()
	if _started and not _combat_queue_seeded:
		if has_pending_effects():
			return
		_seed_action_queue_if_ready()
		if not _combat_queue_seeded:
			return

	## defer 时待结算技能未排空则不推进并行（锁阵/兼容测例）。
	if has_pending_effects() and defer_effect_resolve:
		return

	_tick_all_deploying()
	_tick_boss_cooldowns()
	_tick_unit_status_pulses()
	var movers := _advance_all_units_parallel()
	_resolve_separation(movers)
	_sync_cells_from_positions()

	## 投射物仅观战演出；伤害已在出手时结算。
	_advance_projectiles()
	_sync_unit_grid_pos()
	_drain_effects()
	if defer_effect_resolve:
		_flush_pending_death_presentations_if_queue_idle()
	_remove_dead()

	fixed_step_count += 1
	elapsed_seconds = fixed_step_count * FIXED_DT
	_round_index = maxi(1, floori(elapsed_seconds) + 1)
	_tape_pulse_accum += FIXED_DT
	while _tape_pulse_accum + STEP_EPSILON >= UNIT_PULSE_SECONDS:
		_tape_pulse_accum -= UNIT_PULSE_SECONDS
		_completed_actor_turns += 1
		actor_turn_ended.emit(_completed_actor_turns)
	_check_finished()


func _flush_combat_start_lock() -> void:
	_drain_effects(true)
	_seed_action_queue_if_ready()


func _seed_action_queue_if_ready() -> void:
	if _combat_queue_seeded or not _started or _finished:
		return
	if has_pending_effects():
		return
	_combat_queue_seeded = true
	_build_action_queue_from_lock_order()
	_queue_cursor = 0
	_round_index = 1
	_current_actor = null
	_actor_turn_active = false
	current_actor_changed.emit(null)


## 兼容旧 API：仍按锁阵序填 _action_queue 快照；不驱动主循环。
func _build_action_queue_from_lock_order() -> void:
	_action_queue.clear()
	for rt in _lock_spawn_order:
		if rt != null:
			_action_queue.append(rt)


## 中途召唤：记入快照；立刻可动。
func _insert_mid_combat_into_queue(rt: RtUnit) -> void:
	if rt == null:
		return
	_action_queue.append(rt)


func _tick_all_deploying() -> void:
	for rt in _units:
		if rt == null or not rt.is_alive():
			continue
		if rt.state != RtUnit.State.DEPLOYING:
			continue
		rt.deploy_remaining -= FIXED_DT
		if rt.deploy_remaining <= STEP_EPSILON:
			rt.deploy_remaining = 0.0
			rt.state = RtUnit.State.MOVING


func _tick_boss_cooldowns() -> void:
	for rt in _units:
		if rt == null or not rt.is_alive() or not rt.is_boss_leader():
			continue
		if rt.boss_summon_cooldown_left > 0.0:
			rt.boss_summon_cooldown_left = maxf(0.0, rt.boss_summon_cooldown_left - FIXED_DT)
		if rt.boss_teleport_cooldown_left > 0.0:
			rt.boss_teleport_cooldown_left = maxf(0.0, rt.boss_teleport_cooldown_left - FIXED_DT)


## 每单位 1.0s：中毒 tick →（仍存活）ON_ROUND_START 周期技能。
func _tick_unit_status_pulses() -> void:
	for rt in _units:
		if rt == null or not rt.is_alive() or rt.unit == null:
			continue
		if rt.state == RtUnit.State.DEPLOYING:
			continue
		rt.status_pulse_accum += FIXED_DT
		while rt.is_alive() and rt.status_pulse_accum + STEP_EPSILON >= UNIT_PULSE_SECONDS:
			rt.status_pulse_accum -= UNIT_PULSE_SECONDS
			if not _apply_poison_tick_before_round_start(rt):
				break
			_sync_effect_grid_from_rt_positions()
			var payload := CombatEventPayload.new()
			payload.source = rt.unit
			payload.target = rt.unit
			_bus_emit(CombatEvents.ON_ROUND_START, payload)
			_drain_effects()
			if has_pending_effects() and defer_effect_resolve:
				return


## 中毒在 ON_ROUND_START 之前；致死则本拍不进入回合开始技能。
func _apply_poison_tick_before_round_start(actor: RtUnit) -> bool:
	if actor == null or actor.unit == null or not actor.is_alive():
		return false
	var poison_stacks := actor.unit.combat_statuses.get_stacks(CombatStatusStack.ID_POISON)
	if poison_stacks <= 0:
		return true
	if _pipeline == null:
		return actor.is_alive()
	_pipeline.apply_direct_hp_loss(null, actor, poison_stacks)
	_sync_deaths_from_hp()
	return actor.is_alive()


## 推进并行决策与位移；返回本步有位移的单位 instance_id 集合。
func _advance_all_units_parallel() -> Dictionary:
	var movers: Dictionary = {}
	var can_summon_fn := func(actor: RtUnit) -> bool:
		return _boss_can_summon(actor)
	var can_boss_teleport_fn := func(actor: RtUnit, origin: Vector2i) -> bool:
		return _boss_can_teleport_to(actor, origin)
	var decisions: Array = []
	for rt in _units:
		if rt == null or not rt.is_alive():
			decisions.append(null)
			continue
		decisions.append(
			RtUnitBrain.decide(rt, _units, FIXED_DT, can_summon_fn, can_boss_teleport_fn)
		)

	for i in _units.size():
		var rt := _units[i]
		var decision: RtUnitBrain.Decision = decisions[i]
		if rt == null or not rt.is_alive() or decision == null:
			continue
		if decision.move != Vector2.ZERO:
			rt.position = _clamp_to_arena(rt.position + decision.move, rt.get_radius())
			movers[rt.get_instance_id()] = true

	for i in _units.size():
		var rt2 := _units[i]
		var decision2: RtUnitBrain.Decision = decisions[i]
		if rt2 == null or not rt2.is_alive() or decision2 == null:
			continue
		if decision2.summon:
			rt2.state = RtUnit.State.SUMMONING
			_boss_perform_summon(rt2)
			continue
		if decision2.teleport_cell != Vector2i(-1, -1) and rt2.is_boss_leader():
			if _boss_try_teleport(rt2, decision2.teleport_cell):
				rt2.boss_teleport_cooldown_left = RtUnitBrain.BOSS_TELEPORT_COOLDOWN_SECONDS
			continue
		if decision2.fire and rt2.target != null and rt2.target.is_alive():
			_fire(rt2)
			_consume_turn_refresh_armed(rt2)
	return movers


## 观战 hold 时仍推进全员攻击前摇/间隔，避免卡在蓄力姿。
func advance_attack_windup_under_hold(dt: float) -> void:
	if dt <= 0.0 or not presentation_hold:
		return
	for rt in _units:
		if rt == null or not rt.is_alive():
			continue
		if rt.state != RtUnit.State.ATTACKING:
			continue
		if rt.target == null or not rt.target.is_alive():
			continue
		if rt.attack_timer > RtUnitBrain.TIME_EPSILON:
			rt.attack_timer -= dt
		if rt.attack_timer <= RtUnitBrain.TIME_EPSILON:
			_fire(rt)
			rt.attack_timer += maxf(0.05, rt.get_stats().attack_interval)


func _fire(rt: RtUnit) -> void:
	if rt == null or not rt.is_alive():
		return
	var stats := rt.get_stats()
	var damage := rt.unit.get_effective_attack()
	var target := rt.target
	if target == null or not target.is_alive():
		return
	rt.last_attack_time = elapsed_seconds
	unit_attacked.emit(rt, target)
	## 出手瞬间结算单向伤害；投射物只是观战包装。
	_resolve_hit(rt, target, damage, stats.splash_radius)
	if stats.projectile_speed <= 0.0 or target == null:
		return
	var aim := target.position
	var dir := rt.position.direction_to(aim)
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var projectile := RtProjectile.new(
		rt,
		target,
		rt.position + dir * rt.get_radius(),
		stats.projectile_speed,
		damage,
		stats.splash_radius,
	)
	_projectiles.append(projectile)
	projectile_spawned.emit(projectile)


func _advance_projectiles() -> void:
	var remaining: Array[RtProjectile] = []
	for projectile in _projectiles:
		## 只推进演出位置；到达或目标已死则结束，不再二次结算伤害。
		projectile.advance(FIXED_DT)
		if not projectile.finished:
			remaining.append(projectile)
	_projectiles = remaining


func _resolve_hit(source: RtUnit, target: RtUnit, damage: int, splash_radius: float) -> void:
	if splash_radius > 0.0:
		splash_triggered.emit(target.position, splash_radius)
	_pipeline.resolve_hit(source, target, damage, splash_radius, _units)
	## defer 观战：命中触发的技能须入队，由控制器 FIFO「先卡再结算」；不可在此强排空。
	_drain_effects_unless_deferred()


func _move_unit_to_cell(rt: RtUnit, dest: Vector2i) -> void:
	_clear_occupancy_of(rt)
	rt.snap_to_cell(dest)
	_occupy_footprint(rt, dest)


func _sync_cells_from_positions() -> void:
	for rt in _units:
		if rt == null or not rt.is_alive():
			continue
		var prev := rt.cell
		rt.sync_cell_from_position()
		if rt.cell != prev:
			_clear_occupancy_of(rt)
			_occupy_footprint(rt, rt.cell)


func _sync_unit_grid_pos() -> void:
	for rt in _units:
		if rt.is_alive():
			rt.unit.grid_pos = rt.get_cell()


## 残余重叠分离：本步移动者优先退让；静止单位不被顶走。
func _resolve_separation(movers: Dictionary = {}) -> void:
	var count := _units.size()
	for _iter in SEPARATION_ITERATIONS:
		var moved := false
		for i in count:
			var a := _units[i]
			if a == null or not a.is_alive():
				continue
			for j in range(i + 1, count):
				var b := _units[j]
				if b == null or not b.is_alive():
					continue
				var delta := b.position - a.position
				var min_dist := a.get_radius() + b.get_radius()
				var dist_sq := delta.length_squared()
				if dist_sq >= min_dist * min_dist:
					continue
				var dist := sqrt(dist_sq)
				var normal: Vector2
				if dist > 0.00001:
					normal = delta / dist
				else:
					normal = Vector2.RIGHT.rotated(_rng.randf() * TAU)
				var overlap := min_dist - dist
				var a_moving := movers.has(a.get_instance_id())
				var b_moving := movers.has(b.get_instance_id())
				var a_share := 0.5
				if a.is_deploying() and b.is_deploying():
					continue
				elif a.is_deploying():
					a_share = 0.0
				elif b.is_deploying():
					a_share = 1.0
				elif a_moving and not b_moving:
					## 只有 A 在动：A 全部退让，不推动静止 B。
					a_share = 1.0
				elif b_moving and not a_moving:
					a_share = 0.0
				else:
					## 双方都动或都静：按质量分摊。
					a_share = b.get_mass() / (a.get_mass() + b.get_mass())
				a.position -= normal * overlap * a_share
				b.position += normal * overlap * (1.0 - a_share)
				moved = true
		for rt in _units:
			if rt != null and rt.is_alive():
				rt.position = _clamp_to_arena(rt.position, rt.get_radius())
		if not moved:
			break


func _clamp_to_arena(pos: Vector2, radius: float) -> Vector2:
	var r := minf(radius, minf(_arena_size.x, _arena_size.y) * 0.5)
	return Vector2(
		clampf(pos.x, r, _arena_size.x - r),
		clampf(pos.y, r, _arena_size.y - r),
	)


func _is_cell_free(cell: Vector2i) -> bool:
	if not _in_arena(cell):
		return false
	return _occupancy_owner(cell) == null


## 对 mover 而言 cell 是否可踏入（忽略自身足迹占格）。
func _is_cell_free_for(mover: RtUnit, cell: Vector2i) -> bool:
	if not _in_arena(cell):
		return false
	var owner := _occupancy_owner(cell)
	return owner == null or owner == mover


func _in_arena(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < int(_arena_size.x) and cell.y < int(_arena_size.y)


func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, int(_arena_size.x) - 1),
		clampi(cell.y, 0, int(_arena_size.y) - 1),
	)


func _occupancy_owner(cell: Vector2i) -> RtUnit:
	if not _occupancy.has(cell):
		return null
	var owner: RtUnit = _occupancy[cell]
	if owner == null or not owner.is_alive():
		_occupancy.erase(cell)
		return null
	return owner


func _set_occupancy(cell: Vector2i, rt: RtUnit) -> void:
	_occupancy[cell] = rt


func _occupy_footprint(rt: RtUnit, origin: Vector2i) -> void:
	for cell in rt.get_footprint_cells(origin):
		_set_occupancy(cell, rt)


func _clear_occupancy_of(rt: RtUnit) -> void:
	if rt == null:
		return
	var keys: Array = _occupancy.keys()
	for key in keys:
		if _occupancy[key] == rt:
			_occupancy.erase(key)


func _find_free_cell(origin: Vector2i) -> Vector2i:
	var start := _clamp_cell(origin)
	if _is_cell_free(start):
		return start
	var max_r := maxi(int(_arena_size.x), int(_arena_size.y))
	for radius in range(1, max_r + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cand := Vector2i(start.x + dx, start.y + dy)
				if _is_cell_free(cand):
					return cand
	return Vector2i(-1, -1)


## 2×2 等足迹：锚座为角，优先水平居中 + 向中线/场内展开；失败返回 (-1,-1)。
func _find_free_footprint_origin(
	preferred: Vector2i,
	size: Vector2i,
	team: UnitInstance.Team,
) -> Vector2i:
	return pick_footprint_origin(
		preferred,
		size,
		_arena_size,
		team,
		func(origin: Vector2i, sz: Vector2i) -> bool: return _footprint_fits(origin, sz, null),
	)


## 空场选足迹锚（准备预览用）：仅校验界内，不查占格。
static func pick_empty_footprint_origin(
	preferred: Vector2i,
	size: Vector2i,
	arena: Vector2i,
	team: UnitInstance.Team,
) -> Vector2i:
	return pick_footprint_origin(
		preferred,
		size,
		arena,
		team,
		func(origin: Vector2i, sz: Vector2i) -> bool: return _footprint_in_bounds(origin, sz, arena),
	)


static func pick_footprint_origin(
	preferred: Vector2i,
	size: Vector2i,
	arena: Vector2i,
	team: UnitInstance.Team,
	fits: Callable,
) -> Vector2i:
	var start := Vector2i(
		clampi(preferred.x, 0, maxi(0, arena.x - 1)),
		clampi(preferred.y, 0, maxi(0, arena.y - 1)),
	)
	var w := maxi(1, size.x)
	var h := maxi(1, size.y)
	var candidates: Array[Vector2i] = [
		start,
		start - Vector2i(w - 1, 0),
		start - Vector2i(0, h - 1),
		start - Vector2i(w - 1, h - 1),
	]
	var mid_y := BoardHalf.midline_row(int(arena.y))
	## 与 footprint_center 一致：连续几何中心（宽 9 → 4.5）。
	var board_cx := float(arena.x) * 0.5
	var best := Vector2i(-1, -1)
	var best_score := -999999.0
	for origin in candidates:
		if not bool(fits.call(origin, Vector2i(w, h))):
			continue
		var score := score_footprint_origin(origin, Vector2i(w, h), team, mid_y, board_cx)
		if score > best_score:
			best_score = score
			best = origin
	if best != Vector2i(-1, -1):
		return best
	var max_r := maxi(int(arena.x), int(arena.y))
	for radius in range(0, max_r + 1):
		var ring_best := Vector2i(-1, -1)
		var ring_score := -999999.0
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius > 0 and maxi(absi(dx), absi(dy)) != radius:
					continue
				var origin2 := Vector2i(start.x + dx, start.y + dy)
				if not bool(fits.call(origin2, Vector2i(w, h))):
					continue
				var sc2 := score_footprint_origin(origin2, Vector2i(w, h), team, mid_y, board_cx)
				if sc2 > ring_score:
					ring_score = sc2
					ring_best = origin2
		if ring_best != Vector2i(-1, -1):
			return ring_best
	return Vector2i(-1, -1)


static func score_footprint_origin(
	origin: Vector2i,
	size: Vector2i,
	team: UnitInstance.Team,
	mid_y: int,
	board_cx: float,
) -> float:
	var score := 0.0
	var fp_cx := float(origin.x) + float(size.x) * 0.5
	var fp_cy := float(origin.y) + float(size.y) * 0.5
	## 水平局中权重最高；垂直亦略拉向足迹几何中心可读。
	score -= absf(fp_cx - board_cx) * 20.0
	for dy in size.y:
		for dx in size.x:
			var c := origin + Vector2i(dx, dy)
			if team == UnitInstance.Team.ENEMY:
				score += float(c.y)
			else:
				score -= float(c.y)
			score -= float(absi(c.y - mid_y)) * 0.5
	score -= absf(fp_cy - float(mid_y)) * 0.25
	return score


static func _footprint_in_bounds(origin: Vector2i, size: Vector2i, arena: Vector2i) -> bool:
	for dy in size.y:
		for dx in size.x:
			var c := origin + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= arena.x or c.y >= arena.y:
				return false
	return true


func _footprint_fits(origin: Vector2i, size: Vector2i, ignore: RtUnit) -> bool:
	if not _footprint_in_bounds(origin, size, _arena_size):
		return false
	for dy in size.y:
		for dx in size.x:
			var c := origin + Vector2i(dx, dy)
			var owner := _occupancy_owner(c)
			if owner != null and owner != ignore:
				return false
	return true


func _remove_dead() -> void:
	var alive: Array[RtUnit] = []
	for rt in _units:
		if rt.is_alive() or is_death_presentation_pending(rt):
			alive.append(rt)
		else:
			rt.state = RtUnit.State.DEAD
			_clear_occupancy_of(rt)
			if _effect_grid != null:
				_effect_grid.remove_unit(rt.unit)
	_units = alive


func _check_finished() -> void:
	if _finished:
		return
	## Boss 斩首：首领死 → 胜 + 溃散其余敌方（优先于己方全灭）。
	if _had_boss_leader:
		if not _has_alive_boss_leader():
			_rout_non_leader_enemies()
			_finish(true)
			return
		if count_alive(UnitInstance.Team.PLAYER) == 0 and not suppress_player_wipe_loss:
			if not _defer_wipe_check_for_pending_effects():
				_finish(false)
		return
	var player_alive := count_alive(UnitInstance.Team.PLAYER)
	var enemy_alive := count_alive(UnitInstance.Team.ENEMY)
	## 同帧双方清空（技能等）→ 清敌胜（见 COMBAT §7.2）
	if enemy_alive == 0 and player_alive == 0:
		if not _defer_wipe_check_for_pending_effects():
			_finish(true)
		return
	if player_alive == 0:
		if not suppress_player_wipe_loss:
			if not _defer_wipe_check_for_pending_effects():
				_finish(false)
	elif enemy_alive == 0:
		_finish(true)


## defer 观战：队首仍有待结算技能（如禁卫 OnKill 策反）时勿判胜负。
func _defer_wipe_check_for_pending_effects() -> bool:
	return has_pending_effects()


func _has_alive_boss_leader() -> bool:
	for rt in _units:
		if rt != null and rt.is_alive() and rt.is_boss_leader():
			return true
	return false


## 溃散：移除非首领敌方；不发死亡/击杀事件、不掉金。
func _rout_non_leader_enemies() -> void:
	var kept: Array[RtUnit] = []
	for rt in _units:
		if rt == null:
			continue
		if (
			rt.get_team() == UnitInstance.Team.ENEMY
			and not rt.is_boss_leader()
			and rt.is_alive()
		):
			rt.target = null
			_clear_occupancy_of(rt)
			if _effect_grid != null:
				_effect_grid.remove_unit(rt.unit)
			## 不标 DEAD、不 emit ON_DEATH / unit_died
			continue
		kept.append(rt)
	_units = kept


func _boss_summon_total_budget_left(actor: RtUnit) -> int:
	if actor == null or actor.unit == null or actor.unit.unit_data == null:
		return 0
	var total_cap := maxi(0, actor.unit.unit_data.summon_max_total)
	if total_cap <= 0:
		return 999999
	return maxi(0, total_cap - actor.boss_summons_spawned_total)


func _count_alive_boss_summons() -> int:
	var n := 0
	for rt in _units:
		if rt == null or not rt.is_alive():
			continue
		if rt.get_team() != UnitInstance.Team.ENEMY:
			continue
		if rt.unit != null and rt.unit.is_combat_summon:
			n += 1
	return n


func _boss_can_summon(actor: RtUnit) -> bool:
	if actor == null or not actor.is_boss_leader() or not actor.is_alive():
		return false
	if actor.boss_summon_cooldown_left > 0:
		return false
	var data := actor.unit.unit_data if actor.unit != null else null
	if data == null or data.pick_summon_unit(_rng) == null:
		return false
	if not _boss_has_alive_summon_room(data):
		return false
	if _boss_summon_total_budget_left(actor) <= 0:
		return false
	return _find_boss_summon_cell(actor) != Vector2i(-1, -1)


## summon_max_alive <= 0：无场上存活数量上限。
func _boss_has_alive_summon_room(data: UnitData) -> bool:
	if data == null:
		return false
	var cap := data.summon_max_alive
	if cap <= 0:
		return true
	return _count_alive_boss_summons() < cap


func _boss_perform_summon(actor: RtUnit) -> void:
	if not _boss_can_summon(actor):
		return
	var data := actor.unit.unit_data
	var per := maxi(1, data.summon_per_action)
	var spawned := 0
	while spawned < per and _boss_has_alive_summon_room(data) and _boss_summon_total_budget_left(actor) > 0:
		var cell := _find_boss_summon_cell(actor)
		if cell == Vector2i(-1, -1):
			break
		var template := data.pick_summon_unit(_rng)
		if template == null:
			break
		var minion := UnitInstance.from_unit_data(template, cell, UnitInstance.Team.ENEMY)
		## 衍生小兵：保留主技能；禁止再当首领/再召唤；保证可立即接敌。
		if minion.unit_data != null:
			var body := minion.unit_data.duplicate(true) as UnitData
			body.is_boss_leader = false
			body.summon_unit = null
			body.summon_pool = []
			body.summon_max_alive = 0
			body.summon_per_action = 0
			body.summon_cooldown_actions = 0
			minion.unit_data = body
		minion.is_combat_summon = true
		minion.cannot_move = false
		if minion.stats != null:
			minion.stats.deploy_time = 0.0
			minion.stats.steps_per_turn = maxi(2, minion.stats.steps_per_turn)
			minion.stats.attack_reach = maxf(1.0, minion.stats.attack_reach)
			minion.stats.sight_range = maxf(8.0, minion.stats.sight_range)
		var rt := add_unit(minion, Vector2(cell) + Vector2(0.5, 0.5))
		if rt == null:
			break
		rt.skip_deploy()
		if rt.state == RtUnit.State.DEPLOYING:
			rt.state = RtUnit.State.MOVING
		spawned += 1
		actor.boss_summons_spawned_total += 1
	if spawned > 0:
		## 并行下按秒解释 summon_cooldown_actions。
		actor.boss_summon_cooldown_left = float(maxi(0, data.summon_cooldown_actions))


## 足迹邻格空位优先 → 再敌半场空格。
func _find_boss_summon_cell(actor: RtUnit) -> Vector2i:
	if actor == null:
		return Vector2i(-1, -1)
	var footprint := actor.get_footprint_cells(actor.cell)
	var neighbor_set: Dictionary = {}
	for c in footprint:
		for dir in RtUnitBrain.DIR8:
			var n: Vector2i = c + dir
			if footprint.has(n):
				continue
			neighbor_set[n] = true
	var neighbors: Array[Vector2i] = []
	for key in neighbor_set.keys():
		neighbors.append(key as Vector2i)
	neighbors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	for n2 in neighbors:
		if _is_cell_free(n2):
			return n2
	var height := int(_arena_size.y)
	var half: Array[Vector2i] = []
	for y in height:
		for x in int(_arena_size.x):
			var cell := Vector2i(x, y)
			if BoardHalf.is_enemy_spawn_cell(cell, height) and _is_cell_free(cell):
				half.append(cell)
	half.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := RtUnit.chebyshev(a, actor.cell)
		var db := RtUnit.chebyshev(b, actor.cell)
		if da != db:
			return da < db
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	if half.is_empty():
		return Vector2i(-1, -1)
	return half[0]


## 足迹锚点瞬移：目标足迹全在界内且对首领为空（可覆盖自身旧足迹）。
func _boss_can_teleport_to(actor: RtUnit, origin: Vector2i) -> bool:
	if actor == null or not actor.is_alive():
		return false
	if origin == actor.cell:
		return false
	var cells: Array[Vector2i] = actor.get_footprint_cells(origin)
	if cells.is_empty():
		return false
	for c in cells:
		if not _in_arena(c):
			return false
		if not _is_cell_free_for(actor, c):
			return false
	return true


func _boss_try_teleport(actor: RtUnit, origin: Vector2i) -> bool:
	if not _boss_can_teleport_to(actor, origin):
		return false
	_move_unit_to_cell(actor, origin)
	return true


func _boss_can_step(actor: RtUnit, dir: Vector2i) -> bool:
	return not _plan_boss_step(actor, dir).is_empty()


func _boss_try_step(actor: RtUnit, dir: Vector2i) -> bool:
	var plan := _plan_boss_step(actor, dir)
	if plan.is_empty():
		return false
	var pushes: Array = plan.get("pushes", [])
	for entry in pushes:
		var victim: RtUnit = entry["unit"]
		var dest: Vector2i = entry["dest"]
		if victim == null or not victim.is_alive():
			return false
		_move_unit_to_cell(victim, dest)
	var new_origin: Vector2i = plan["origin"]
	_move_unit_to_cell(actor, new_origin)
	return true


## 成功返回 { "origin": Vector2i, "pushes": [{unit, dest}] }；失败返回 {}。
func _plan_boss_step(actor: RtUnit, dir: Vector2i) -> Dictionary:
	var empty := {}
	if actor == null or not actor.is_alive() or dir == Vector2i.ZERO:
		return empty
	var new_origin: Vector2i = actor.cell + dir
	var new_cells: Array[Vector2i] = actor.get_footprint_cells(new_origin)
	for c in new_cells:
		if not _in_arena(c):
			return empty
	var push_targets: Array[RtUnit] = []
	var seen: Dictionary = {}
	for c2 in new_cells:
		var owner := _occupancy_owner(c2)
		if owner == null or owner == actor:
			continue
		if owner.get_team() != UnitInstance.Team.PLAYER:
			return empty
		if not seen.has(owner.get_id()):
			seen[owner.get_id()] = true
			push_targets.append(owner)
	push_targets.sort_custom(func(a: RtUnit, b: RtUnit) -> bool:
		return a.get_id() < b.get_id()
	)
	var vacated: Dictionary = {}
	for c3 in actor.get_footprint_cells(actor.cell):
		vacated[c3] = true
	var claimed: Dictionary = {}
	var pushes: Array = []
	for victim in push_targets:
		for vc in victim.get_footprint_cells(victim.cell):
			vacated[vc] = true
		var dest := _find_push_dest(victim, dir, new_cells, vacated, claimed, actor)
		if dest == Vector2i(-1, -1):
			return empty
		claimed[dest] = true
		pushes.append({"unit": victim, "dest": dest})
	for c4 in new_cells:
		if claimed.has(c4):
			return empty
		var owner2 := _occupancy_owner(c4)
		if owner2 == null or owner2 == actor:
			continue
		var pushed_away := false
		for p in pushes:
			if p["unit"] == owner2:
				pushed_away = true
				break
		if not pushed_away:
			return empty
	return {"origin": new_origin, "pushes": pushes}


func _find_push_dest(
	victim: RtUnit,
	dir: Vector2i,
	boss_new_cells: Array[Vector2i],
	vacated: Dictionary,
	claimed: Dictionary,
	boss: RtUnit,
) -> Vector2i:
	## 优先正前，其次斜前。
	var options: Array[Vector2i] = [dir]
	if dir.x != 0 and dir.y != 0:
		options.append(Vector2i(dir.x, 0))
		options.append(Vector2i(0, dir.y))
	else:
		if dir.x != 0:
			options.append(Vector2i(dir.x, 1))
			options.append(Vector2i(dir.x, -1))
		if dir.y != 0:
			options.append(Vector2i(1, dir.y))
			options.append(Vector2i(-1, dir.y))
	var from := victim.cell
	for d in options:
		var dest: Vector2i = from + d
		if not _in_arena(dest):
			continue
		if boss_new_cells.has(dest):
			continue
		if claimed.has(dest):
			continue
		var owner := _occupancy_owner(dest)
		if owner != null and owner != victim and owner != boss and not vacated.has(dest):
			continue
		return dest
	return Vector2i(-1, -1)


func _finish(won: bool) -> void:
	if _finished:
		return
	## 先标结束，避免「战斗结束」技能结算再次走进胜负。
	_finished = true
	_player_won = won
	## 只把当时仍存活的单位留在效果格上，再发战斗结束。
	_sync_effect_grid_from_rt_positions()
	_bus_emit(CombatEvents.ON_COMBAT_END, CombatEventPayload.new())
	_drain_effects(true)
	_projectiles.clear()
	_break_reference_cycles()
	combat_finished.emit(won)


func _break_reference_cycles() -> void:
	for rt in _units:
		rt.target = null


func _bus_emit(event_type: StringName, payload: CombatEventPayload) -> void:
	if _bus != null and is_instance_valid(_bus):
		_bus.emit_event(event_type, payload)


func _on_bus_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if event_type == CombatEvents.ON_ACTOR_TURN_REFRESH:
		if payload != null and payload.source != null:
			_apply_actor_turn_refresh(payload.source)
		return
	## ON_DEAL_DAMAGE 覆盖非致死与致死；ON_DAMAGE_TAKEN 仅非致死（致死不发）。
	if (
		event_type != CombatEvents.ON_DEAL_DAMAGE
		and event_type != CombatEvents.ON_DAMAGE_TAKEN
	):
		return
	if payload == null or payload.target == null:
		return
	for rt in _units:
		if rt.unit == payload.target:
			rt.last_hit_time = elapsed_seconds
			rt.last_hit_amount = maxi(0, payload.amount)
			rt.last_hit_was_crit = payload.is_crit
			if event_type == CombatEvents.ON_DAMAGE_TAKEN:
				unit_damaged.emit(rt, payload.amount)
			return


func _apply_actor_turn_refresh(unit: UnitInstance) -> void:
	var rt := _find_rt_for_unit(unit)
	if rt == null or not rt.is_alive():
		return
	## 并行：武装下一次出手立刻可打（清空攻击间隔）。
	_turn_refresh_armed_instance_id = unit.instance_id
	rt.attack_timer = 0.0
	if rt.state != RtUnit.State.ATTACKING and rt.target != null:
		rt.state = RtUnit.State.ATTACKING


func _consume_turn_refresh_armed(rt: RtUnit) -> bool:
	if rt == null or rt.unit == null:
		return false
	if _turn_refresh_armed_instance_id != rt.unit.instance_id:
		return false
	_turn_refresh_armed_instance_id = -1
	## 已出手；下一击仍按 attack_interval（decide 内 refill）。
	return true


func _setup_effect_resolver() -> void:
	_teardown_effect_resolver()
	if _bus == null or not is_instance_valid(_bus):
		return
	_effect_grid = BoardGrid.new()
	_effect_grid.configure(Vector2i(int(_arena_size.x), int(_arena_size.y)))
	_effect_pipeline = DamagePipeline.new(_bus, _effect_grid)
	_effect_pipeline.set_rng(_rng)
	_effect_pipeline.defer_death_removal = true
	_effect_resolver = EffectResolver.new(_effect_grid, _bus, _effect_pipeline, _rng)
	_effect_resolver.set_battle_convert_handler(_battle_convert_kill_target)
	_bus.combat_event.connect(_effect_resolver.on_event)
	## economy 由外部 set_economy 注入；重建 resolver 后需再调一次。
	for rt in _units:
		if rt != null and rt.unit != null and rt.is_alive():
			_register_on_effect_grid(rt.unit, rt.get_cell())


func _teardown_effect_resolver() -> void:
	if (
		_bus != null
		and is_instance_valid(_bus)
		and _effect_resolver != null
		and _bus.combat_event.is_connected(_effect_resolver.on_event)
	):
		_bus.combat_event.disconnect(_effect_resolver.on_event)
	if _effect_resolver != null:
		_effect_resolver.clear_pending()
	_effect_resolver = null
	_effect_pipeline = null
	_effect_grid = null


func _register_on_effect_grid(unit: UnitInstance, preferred_cell: Vector2i) -> void:
	if _effect_grid == null or unit == null:
		return
	if _effect_grid.find_cell_of(unit) != Vector2i(-1, -1):
		return
	var cell := preferred_cell
	if not _effect_grid.can_place_at(cell):
		cell = _find_free_effect_cell(preferred_cell)
	if cell == Vector2i(-1, -1):
		push_warning("RealtimeCombatSim: effect grid full, unit %s not registered" % unit.id)
		return
	_effect_grid.place(unit, cell)


func _find_free_effect_cell(origin: Vector2i) -> Vector2i:
	if _effect_grid == null:
		return Vector2i(-1, -1)
	if _effect_grid.can_place_at(origin):
		return origin
	var empty := _effect_grid.get_empty_cells()
	if empty.is_empty():
		return Vector2i(-1, -1)
	empty.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return _effect_grid.path_cost(origin, a) < _effect_grid.path_cost(origin, b)
	)
	return empty[0]


func _emit_spawn_events(unit: UnitInstance, cell: Vector2i) -> void:
	var payload := CombatEventPayload.new()
	payload.target = unit
	payload.to_cell = cell
	_bus_emit(CombatEvents.ON_FRIEND_SUMMONED, payload)
	_bus_emit(CombatEvents.ON_SUMMONED, payload)


## 命中/召唤等路径：defer 时只入队，留给观战逐条播报。
func _drain_effects_unless_deferred() -> void:
	if defer_effect_resolve:
		return
	_drain_effects(true)


## force=true：无视 defer（锁阵生成 / 开战广播须当下排空）。
func _drain_effects(force: bool = false) -> void:
	if _effect_resolver == null:
		return
	if defer_effect_resolve and not force:
		return
	var outer := 8
	while outer > 0:
		outer -= 1
		var guard := EFFECT_DRAIN_GUARD
		while _effect_resolver.has_pending_steps() and guard > 0:
			_sync_effect_grid_from_rt_positions()
			_effect_resolver.process_next_step()
			_sync_rt_positions_from_effect_grid()
			_sync_effect_spawns_from_grid()
			_sync_deaths_from_hp()
			guard -= 1
		if not _finalize_pending_deaths():
			break


## 观战 defer：待结算队列为空后再 finalize 死亡（OnKill 策反等可先撤销致死）。
func flush_idle_death_presentations() -> void:
	if not defer_effect_resolve:
		return
	_flush_pending_death_presentations_if_queue_idle()


func _flush_pending_death_presentations_if_queue_idle() -> void:
	if _effect_resolver != null and _effect_resolver.has_pending_steps():
		return
	_flush_pending_death_presentations()


func _flush_pending_death_presentations() -> void:
	while _finalize_pending_deaths():
		pass


func _finalize_pending_deaths() -> bool:
	if _pipeline == null:
		return false
	var entries := _pipeline.take_pending_death_finalizations()
	if entries.is_empty():
		return false
	for entry in entries:
		var rt: RtUnit = entry.get("target")
		if rt != null and rt.is_alive():
			continue
		_pipeline.emit_post_kill_death_events(entry)
		if rt != null:
			unit_died.emit(rt)
	return true


func _battle_convert_kill_target(owner: UnitInstance, target: UnitInstance) -> bool:
	if owner == null or target == null or target.is_boss_leader():
		return false
	if owner.team == target.team:
		return false
	var rt := _find_rt_for_unit(target)
	if rt == null:
		return false
	target.team = owner.team
	target.deck_entry_id = -1
	target.is_battle_converted = true
	target.combat_statuses.clear()
	target.current_hp = target.get_effective_max_hp()
	rt.state = RtUnit.State.MOVING
	rt.target = null
	rt.skip_deploy()
	var cell := rt.get_cell()
	_occupy_footprint(rt, cell)
	target.grid_pos = cell
	_register_on_effect_grid(target, cell)
	var payload := CombatEventPayload.new()
	payload.source = owner
	payload.target = target
	payload.to_cell = cell
	_bus_emit(CombatEvents.ON_FRIEND_SUMMONED, payload)
	_bus_emit(CombatEvents.ON_SUMMONED, payload)
	return true


## 实时战场走位后，效果格仍可能是开战落点；技能选目标/瞬移前须与 RtUnit 对齐。
func _sync_effect_grid_from_rt_positions() -> void:
	if _effect_grid == null:
		return
	var placements: Array[Dictionary] = []
	for rt in _units:
		if rt == null or rt.unit == null or not rt.is_alive():
			continue
		placements.append({"unit": rt.unit, "cell": rt.get_cell()})
	for rt in _units:
		if rt == null or rt.unit == null:
			continue
		_effect_grid.remove_unit(rt.unit)
	for entry in placements:
		var unit: UnitInstance = entry["unit"]
		var cell: Vector2i = entry["cell"]
		if unit == null or not unit.is_alive():
			continue
		var dest := cell
		if not _effect_grid.can_place_at(dest):
			dest = _find_free_effect_cell(dest)
		if dest == Vector2i(-1, -1):
			push_warning("RealtimeCombatSim: effect grid sync failed for %s" % unit.id)
			continue
		_effect_grid.place(unit, dest)
		unit.grid_pos = dest


func _sync_rt_positions_from_effect_grid() -> void:
	if _effect_grid == null:
		return
	for rt in _units:
		if rt == null or rt.unit == null or not rt.is_alive():
			continue
		var cell := _effect_grid.find_cell_of(rt.unit)
		if cell == Vector2i(-1, -1):
			continue
		if cell == rt.cell and not rt.is_stepping():
			continue
		_clear_occupancy_of(rt)
		rt.cell = cell
		rt.step_dest = cell
		rt.step_t = 1.0
		rt.refresh_visual_bias(cell)
		rt.position = rt.standing_visual_at(cell)
		_occupy_footprint(rt, cell)
		rt.unit.grid_pos = cell


func _sync_effect_spawns_from_grid() -> void:
	if _effect_grid == null:
		return
	for item in _effect_grid.get_all_units():
		var unit := item as UnitInstance
		if unit == null or not unit.is_alive():
			continue
		if _find_rt_for_unit(unit) != null:
			continue
		_adding_effect_spawn = true
		var spawn_pos := Vector2(unit.grid_pos) + Vector2(0.5, 0.5)
		add_unit(unit, spawn_pos)
		_adding_effect_spawn = false


func _sync_deaths_from_hp() -> void:
	for rt in _units:
		if rt == null or rt.unit == null:
			continue
		if rt.state == RtUnit.State.DEAD:
			continue
		if rt.unit.is_alive():
			continue
		if is_death_presentation_pending(rt):
			continue
		rt.state = RtUnit.State.DEAD
		rt.target = null
		_clear_occupancy_of(rt)
		unit_died.emit(rt)


func _find_rt_for_unit(unit: UnitInstance) -> RtUnit:
	if unit == null:
		return null
	for rt in _units:
		if rt.unit == unit:
			return rt
	return null
