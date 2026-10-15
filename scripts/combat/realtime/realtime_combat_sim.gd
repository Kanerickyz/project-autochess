class_name RealtimeCombatSim
extends RefCounted
## 回合制自动战纯逻辑模拟：敌我混排行动队列 + 一动靠近并出手 + 落格顿步。
## 固定步长只服务当前行动者一动内的格步/出手演出；结果与调用方帧率无关。
## 坐标单位为格；时间单位为秒（表现节拍，不改变行动序与已结算数值）。

signal unit_added(unit: RtUnit)
signal unit_attacked(attacker: RtUnit, target: RtUnit)
signal unit_damaged(unit: RtUnit, amount: int)
signal unit_died(unit: RtUnit)
signal projectile_spawned(projectile: RtProjectile)
signal splash_triggered(center: Vector2, radius: float)
signal combat_finished(won: bool)
## 当前行动者变更（含回合推进跳过阵亡后落到下一位）；UI 高亮用。
signal current_actor_changed(actor: RtUnit)

const FIXED_STEPS_PER_SECOND := 30
const FIXED_DT := 1.0 / FIXED_STEPS_PER_SECOND
const STEP_EPSILON := 0.000001
const EFFECT_DRAIN_GUARD := 64

var elapsed_seconds: float = 0.0
var fixed_step_count: int = 0

var _arena_size: Vector2 = Vector2(9, 16)
var _rng := RandomNumberGenerator.new()
var _bus: CombatEventBus
var _owns_bus: bool = false
var _pipeline: RealtimeDamagePipeline
var _effect_grid: BoardGrid
var _effect_pipeline: DamagePipeline
var _effect_resolver: EffectResolver
var _units: Array[RtUnit] = []
var _projectiles: Array[RtProjectile] = []
## 逻辑占格：一格一体（存活单位）
var _occupancy: Dictionary = {}
var _input_seconds: float = 0.0
var _started: bool = false
var _finished: bool = false
var _player_won: bool = false
var _adding_effect_spawn: bool = false
## 表现层时停兼容钩子：为 true 时 step 不再推进固定步（主通道已改为行动队列，不依赖时停）。
var presentation_hold: bool = false
## 为 true 时：场上暂无友方也不判负（玩家仍有牌可出时由战斗控制器置位）。
var suppress_player_wipe_loss: bool = false

## 开战锁阵生成序（友入座序 + 敌配置序，按 add_unit 先后）；用于交错混排。
var _lock_spawn_order: Array[RtUnit] = []
## 敌我混排固定行动队列（开战排一次；阵亡跳过；中途召唤插队见 add_unit）。
var _action_queue: Array[RtUnit] = []
var _queue_cursor: int = 0
var _round_index: int = 0
var _current_actor: RtUnit = null
var _actor_steps_left: int = 0
var _actor_has_attacked: bool = false
var _actor_turn_active: bool = false


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
	var cell := _find_free_cell(preferred)
	if cell == Vector2i(-1, -1):
		push_warning("RealtimeCombatSim.add_unit: arena full, cannot place %s" % unit.id)
		return null
	var rt := RtUnit.new(unit, RtUnit.cell_center(cell))
	rt.snap_to_cell(cell)
	rt.spawn_time = elapsed_seconds
	## 开战锁阵预置单位立刻可交战；战中补人才走 deploy_time。
	if not _started:
		rt.skip_deploy()
	unit.grid_pos = rt.get_cell()
	var index := 0
	while index < _units.size() and _units[index].get_id() < rt.get_id():
		index += 1
	_units.insert(index, rt)
	_set_occupancy(cell, rt)
	_register_on_effect_grid(unit, rt.get_cell())
	## 开战前：记录锁阵生成序。开战中：默认插到当前行动者之后（COMBAT §7.1 建议默认）。
	if not _started:
		_lock_spawn_order.append(rt)
	else:
		_insert_mid_combat_into_queue(rt)
	unit_added.emit(rt)
	## 锁阵生成与战中补人：每体生成当下发部署类事件并排空效果（开战事件仍由 begin_combat）。
	if not _adding_effect_spawn:
		_emit_spawn_events(unit, rt.get_cell())
		_drain_effects()
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


## 占格查询（测试 / 调试）。
func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupancy_owner(cell) != null


func get_occupancy_owner(cell: Vector2i) -> RtUnit:
	return _occupancy_owner(cell)


## 标记开战：广播游戏开始 → 排出敌我混排行动队列。未显式调用时首个固定步会自动调用。
func begin_combat() -> void:
	if _started or _finished:
		return
	_started = true
	_bus_emit(CombatEvents.ON_COMBAT_START, CombatEventPayload.new())
	_drain_effects()
	_build_action_queue_from_lock_order()
	_queue_cursor = 0
	_round_index = 1
	_current_actor = null
	_actor_turn_active = false


func has_started() -> bool:
	return _started


func is_finished() -> bool:
	return _finished


func did_player_win() -> bool:
	return _finished and _player_won


## 当前正在执行一动的单位；无人行动时为 null。
func get_current_actor() -> RtUnit:
	if not _actor_turn_active:
		return null
	return _current_actor


## 当前回合序号（从 1 起；开战排队列后尚未行动前亦为 1）。
func get_round_index() -> int:
	return _round_index


## 行动队列只读快照（含已阵亡占位，推进时跳过）。
func get_action_queue() -> Array:
	return _action_queue.duplicate()


func get_queue_cursor() -> int:
	return _queue_cursor


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
		advance_fixed_step()


## 技能播报时停：打断后续固定步；队列清空后由控制器 release。
func hold_for_presentation() -> void:
	presentation_hold = true
	_input_seconds = fixed_step_count * FIXED_DT


func release_presentation() -> void:
	presentation_hold = false


func advance_fixed_step() -> void:
	if _finished:
		return
	begin_combat()

	## 部署剩余用全局时钟推进（可被其他行动者在其回合攻击）；不占用行动队列并行移动。
	_tick_all_deploying()

	if not _actor_turn_active:
		_begin_next_actor_turn()

	if _actor_turn_active and _current_actor != null:
		_advance_current_actor()

	_advance_projectiles()
	_sync_unit_grid_pos()
	_drain_effects()
	_remove_dead()

	fixed_step_count += 1
	elapsed_seconds = fixed_step_count * FIXED_DT
	## 胜负在每一动结束后检查；若本步刚结束一动则此处已查过，再查一次无害。
	_check_finished()


## COMBAT §7.1：友入座序与敌配置序交错（友0敌0友1敌1…）；一侧用尽续另一侧。
func _build_action_queue_from_lock_order() -> void:
	var friends: Array[RtUnit] = []
	var enemies: Array[RtUnit] = []
	for rt in _lock_spawn_order:
		if rt == null:
			continue
		if rt.is_player():
			friends.append(rt)
		else:
			enemies.append(rt)
	_action_queue.clear()
	var i := 0
	while i < friends.size() or i < enemies.size():
		if i < friends.size():
			_action_queue.append(friends[i])
		if i < enemies.size():
			_action_queue.append(enemies[i])
		i += 1


## 中途召唤：插到当前行动者之后；无当前行动者则队尾。
func _insert_mid_combat_into_queue(rt: RtUnit) -> void:
	if rt == null:
		return
	if _action_queue.is_empty():
		_action_queue.append(rt)
		return
	var insert_at := _action_queue.size()
	if _actor_turn_active and _current_actor != null:
		var cur_i := _action_queue.find(_current_actor)
		if cur_i >= 0:
			insert_at = cur_i + 1
	elif _queue_cursor >= 0 and _queue_cursor < _action_queue.size():
		insert_at = _queue_cursor + 1
	_action_queue.insert(insert_at, rt)


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


func _begin_next_actor_turn() -> void:
	_current_actor = null
	_actor_turn_active = false
	_actor_has_attacked = false
	_actor_steps_left = 0
	if _action_queue.is_empty() or _finished:
		current_actor_changed.emit(null)
		return

	var scanned := 0
	while scanned < _action_queue.size():
		if _queue_cursor >= _action_queue.size():
			_queue_cursor = 0
			_round_index += 1
		var candidate := _action_queue[_queue_cursor]
		if candidate != null and candidate.is_alive() and _units.has(candidate):
			_current_actor = candidate
			_actor_turn_active = true
			_actor_has_attacked = false
			_actor_steps_left = RtUnitBrain.turn_step_budget(candidate.get_stats())
			## 自己回合开始（UNIT_ABILITIES §5.3）：payload.source = 行动者。
			var payload := CombatEventPayload.new()
			payload.source = candidate.unit
			payload.target = candidate.unit
			_bus_emit(CombatEvents.ON_ROUND_START, payload)
			_drain_effects()
			current_actor_changed.emit(candidate)
			return
		_queue_cursor += 1
		scanned += 1

	current_actor_changed.emit(null)


func _end_current_actor_turn() -> void:
	if not _actor_turn_active:
		return
	_actor_turn_active = false
	_current_actor = null
	_actor_has_attacked = false
	_actor_steps_left = 0
	_queue_cursor += 1
	current_actor_changed.emit(null)
	_check_finished()


func _advance_current_actor() -> void:
	var rt := _current_actor
	if rt == null or not rt.is_alive():
		_end_current_actor_turn()
		return

	## 落格顿步：先推进当前行动者步进插值；本拍落稳则停，下拍再判攻/再迈。
	if rt.is_stepping():
		rt.advance_step_visual(FIXED_DT)
		return

	var free_fn := func(cell: Vector2i) -> bool:
		return _is_cell_free(cell)
	var decision := RtUnitBrain.decide_turn(
		rt, _units, FIXED_DT, free_fn, _actor_steps_left, _actor_has_attacked
	)

	if (
		decision.fire
		and not rt.is_stepping()
		and rt.is_alive()
		and rt.target != null
		and rt.target.is_alive()
	):
		_fire(rt)
		_actor_has_attacked = true
		_end_current_actor_turn()
		return

	if decision.step != Vector2i.ZERO and _actor_steps_left > 0:
		var dest: Vector2i = rt.cell + decision.step
		if _is_cell_free(dest) and maxf(0.0, rt.get_stats().move_speed) > 0.0:
			_move_unit_to_cell(rt, dest)
			_actor_steps_left -= 1
			return

	if decision.turn_done:
		_end_current_actor_turn()
		return

	## 前摇中：继续耗时，不交权。
	if rt.state == RtUnit.State.ATTACKING and not _actor_has_attacked:
		return

	_end_current_actor_turn()


func _fire(rt: RtUnit) -> void:
	var stats := rt.get_stats()
	var damage := rt.unit.get_effective_attack()
	rt.last_attack_time = elapsed_seconds
	unit_attacked.emit(rt, rt.target)
	if stats.projectile_speed <= 0.0:
		_resolve_hit(rt, rt.target, damage, stats.splash_radius)
		return
	var dir := rt.position.direction_to(rt.target.position)
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	var projectile := RtProjectile.new(
		rt,
		rt.target,
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
		if projectile.advance(FIXED_DT):
			_resolve_hit(projectile.source, projectile.target, projectile.damage, projectile.splash_radius)
		if not projectile.finished:
			remaining.append(projectile)
	_projectiles = remaining


func _resolve_hit(source: RtUnit, target: RtUnit, damage: int, splash_radius: float) -> void:
	if splash_radius > 0.0:
		splash_triggered.emit(target.position, splash_radius)
	var killed := _pipeline.resolve_hit(source, target, damage, splash_radius, _units)
	for rt in killed:
		unit_died.emit(rt)
	_drain_effects()


func _move_unit_to_cell(rt: RtUnit, dest: Vector2i) -> void:
	var from_cell := rt.cell
	_clear_occupancy_of(rt)
	rt.begin_step(from_cell, dest)
	## 一格一体：迈步即预占 dest、释放 from；站立格待落稳后由 advance_step_visual 提交
	_set_occupancy(dest, rt)


func _sync_unit_grid_pos() -> void:
	for rt in _units:
		if rt.is_alive():
			rt.unit.grid_pos = rt.get_cell()


func _is_cell_free(cell: Vector2i) -> bool:
	if not _in_arena(cell):
		return false
	return _occupancy_owner(cell) == null


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


func _remove_dead() -> void:
	var alive: Array[RtUnit] = []
	for rt in _units:
		if rt.is_alive():
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
	if count_alive(UnitInstance.Team.PLAYER) == 0:
		if not suppress_player_wipe_loss:
			_finish(false)
	elif count_alive(UnitInstance.Team.ENEMY) == 0:
		_finish(true)


func _finish(won: bool) -> void:
	_finished = true
	_player_won = won
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
	if event_type != CombatEvents.ON_DAMAGE_TAKEN or payload.target == null:
		return
	for rt in _units:
		if rt.unit == payload.target:
			rt.last_hit_time = elapsed_seconds
			unit_damaged.emit(rt, payload.amount)
			return


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
	_bus.combat_event.connect(_effect_resolver.on_event)
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


func _drain_effects() -> void:
	if _effect_resolver == null:
		return
	var guard := EFFECT_DRAIN_GUARD
	while _effect_resolver.has_pending_steps() and guard > 0:
		_effect_resolver.process_next_step()
		_sync_effect_spawns_from_grid()
		_sync_deaths_from_hp()
		guard -= 1


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
