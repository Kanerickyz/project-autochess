class_name RealtimeCombatSim
extends RefCounted
## 皇室战争式实时战斗的纯逻辑模拟。固定步长推进，结果与调用方帧率无关。
## 坐标单位为格（arena 左上角为原点），时间单位为秒。
## 技能效果：镜像 BoardGrid + EffectResolver 订阅 CombatEventBus，固定步内排空 pending。

signal unit_added(unit: RtUnit)
signal unit_attacked(attacker: RtUnit, target: RtUnit)
signal unit_damaged(unit: RtUnit, amount: int)
signal unit_died(unit: RtUnit)
signal projectile_spawned(projectile: RtProjectile)
signal splash_triggered(center: Vector2, radius: float)
signal combat_finished(won: bool)

const FIXED_STEPS_PER_SECOND := 30
const FIXED_DT := 1.0 / FIXED_STEPS_PER_SECOND
const SEPARATION_ITERATIONS := 4
const STEP_EPSILON := 0.000001
const EFFECT_DRAIN_GUARD := 64

var elapsed_seconds: float = 0.0
var fixed_step_count: int = 0

var _arena_size: Vector2 = Vector2(18, 32)
var _rng := RandomNumberGenerator.new()
var _bus: CombatEventBus
var _owns_bus: bool = false
var _pipeline: RealtimeDamagePipeline
var _effect_grid: BoardGrid
var _effect_pipeline: DamagePipeline
var _effect_resolver: EffectResolver
var _units: Array[RtUnit] = []
var _projectiles: Array[RtProjectile] = []
var _input_seconds: float = 0.0
var _started: bool = false
var _finished: bool = false
var _player_won: bool = false
var _adding_effect_spawn: bool = false
## 为 true 时：场上暂无友方也不判负（玩家仍有牌可出时由战斗控制器置位）。
var suppress_player_wipe_loss: bool = false


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
	var rt := RtUnit.new(unit, position)
	rt.position = _clamp_to_arena(position, rt.get_radius())
	rt.spawn_time = elapsed_seconds
	if not _started:
		rt.skip_deploy()
	unit.grid_pos = rt.get_cell()
	var index := 0
	while index < _units.size() and _units[index].get_id() < rt.get_id():
		index += 1
	_units.insert(index, rt)
	_register_on_effect_grid(unit, rt.get_cell())
	unit_added.emit(rt)
	if _started and not _adding_effect_spawn:
		_emit_mid_combat_summon(unit, rt.get_cell())
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
	rt.target = null
	if _effect_grid != null:
		_effect_grid.remove_unit(rt.unit)
	return true


## 场上单位（含部署中，不含已死亡），按 instance_id 升序。
func get_units() -> Array:
	return _units.duplicate()


func get_projectiles() -> Array:
	return _projectiles.duplicate()


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


## 标记开战：此后 add_unit 的单位都要走部署时间。未显式调用时首个固定步会自动调用。
func begin_combat() -> void:
	if _started or _finished:
		return
	_started = true
	_bus_emit(CombatEvents.ON_COMBAT_START, CombatEventPayload.new())
	_drain_effects()


func has_started() -> bool:
	return _started


func is_finished() -> bool:
	return _finished


func did_player_win() -> bool:
	return _finished and _player_won


## 按调用方 dt 推进；内部以 FIXED_DT 拆步，累计总输入时间决定步数，避免浮点累加误差导致步数漂移。
func step(dt: float) -> void:
	if _finished or dt <= 0.0:
		return
	_input_seconds += dt
	var target_steps := floori(_input_seconds * FIXED_STEPS_PER_SECOND + STEP_EPSILON)
	while fixed_step_count < target_steps and not _finished:
		advance_fixed_step()


func advance_fixed_step() -> void:
	if _finished:
		return
	begin_combat()

	var decisions: Array[RtUnitBrain.Decision] = []
	for rt in _units:
		decisions.append(RtUnitBrain.decide(rt, _units, FIXED_DT))

	for i in _units.size():
		var rt := _units[i]
		if rt.is_alive() and decisions[i].move != Vector2.ZERO:
			rt.position = _clamp_to_arena(rt.position + decisions[i].move, rt.get_radius())

	for i in _units.size():
		var rt := _units[i]
		if decisions[i].fire and rt.is_alive() and rt.target != null and rt.target.is_alive():
			_fire(rt)

	_advance_projectiles()
	_resolve_separation()
	_drain_effects()
	_remove_dead()

	fixed_step_count += 1
	elapsed_seconds = fixed_step_count * FIXED_DT
	_check_finished()


func _fire(rt: RtUnit) -> void:
	var stats := rt.get_stats()
	var damage := rt.unit.get_effective_attack()
	rt.last_attack_time = elapsed_seconds
	unit_attacked.emit(rt, rt.target)
	if stats.projectile_speed <= 0.0:
		_resolve_hit(rt, rt.target, damage, stats.splash_radius)
		return
	var dir := rt.position.direction_to(rt.target.position)
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


func _resolve_separation() -> void:
	var count := _units.size()
	for _iter in SEPARATION_ITERATIONS:
		var moved := false
		for i in count:
			var a := _units[i]
			if not a.is_alive():
				continue
			for j in range(i + 1, count):
				var b := _units[j]
				if not b.is_alive():
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
				# 部署中的单位视为不可推动：重叠全由对方让开
				var a_share := b.get_mass() / (a.get_mass() + b.get_mass())
				if a.is_deploying() and b.is_deploying():
					continue
				elif a.is_deploying():
					a_share = 0.0
				elif b.is_deploying():
					a_share = 1.0
				a.position -= normal * overlap * a_share
				b.position += normal * overlap * (1.0 - a_share)
				moved = true
		for rt in _units:
			rt.position = _clamp_to_arena(rt.position, rt.get_radius())
		if not moved:
			break
	for rt in _units:
		rt.unit.grid_pos = rt.get_cell()


func _remove_dead() -> void:
	var alive: Array[RtUnit] = []
	for rt in _units:
		if rt.is_alive():
			alive.append(rt)
		else:
			rt.state = RtUnit.State.DEAD
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


func _clamp_to_arena(position: Vector2, radius: float) -> Vector2:
	var r := minf(radius, minf(_arena_size.x, _arena_size.y) * 0.5)
	return Vector2(
		clampf(position.x, r, _arena_size.x - r),
		clampf(position.y, r, _arena_size.y - r),
	)


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


func _emit_mid_combat_summon(unit: UnitInstance, cell: Vector2i) -> void:
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
		unit_died.emit(rt)


func _find_rt_for_unit(unit: UnitInstance) -> RtUnit:
	if unit == null:
		return null
	for rt in _units:
		if rt.unit == unit:
			return rt
	return null
