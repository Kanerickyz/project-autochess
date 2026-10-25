class_name CombatTickScheduler
extends Node

signal action_finished
signal round_finished
signal combat_finished(won: bool)
signal turn_order_changed(snapshot: Dictionary)

enum RoundPhase { ACTIVE, DONE }

@export var action_interval: float = 0.5
@export var pace_config: CombatPaceConfig

var combat_tick: int = -1
var presentation: CombatPresentation = null

var _grid: BoardGrid
var _pipeline: DamagePipeline
var _event_bus: CombatEventBus
var _spawn_controller: WaveSpawnController
var _effect_resolver: EffectResolver
var _timer: float = 0.0
var _running: bool = false
var _waiting_presentation: bool = false
var _unit_queue: Array[UnitInstance] = []
var _round_active: bool = false
var _round_phase: RoundPhase = RoundPhase.DONE
var _act_index: int = 0
var _paused: bool = false
var _combat_end_emitted: bool = false


func configure(
	grid: BoardGrid,
	pipeline: DamagePipeline,
	event_bus: CombatEventBus = null,
	spawn_controller: WaveSpawnController = null,
	effect_resolver: EffectResolver = null,
) -> void:
	_grid = grid
	_pipeline = pipeline
	_event_bus = event_bus
	_spawn_controller = spawn_controller
	_effect_resolver = effect_resolver
	if _pipeline != null and _effect_resolver != null:
		_pipeline.set_effect_resolver(_effect_resolver)
	_update_death_deferral()


func start_combat() -> void:
	_running = true
	_combat_end_emitted = false
	_timer = 0.0
	_waiting_presentation = false
	_paused = false
	combat_tick = -1
	_unit_queue.clear()
	_round_active = false
	_round_phase = RoundPhase.DONE
	_act_index = 0
	_update_death_deferral()
	_emit_turn_order_changed()


func stop_combat() -> void:
	_running = false
	_round_active = false
	_round_phase = RoundPhase.DONE
	_waiting_presentation = false
	_paused = false
	_unit_queue.clear()
	_act_index = 0
	if _effect_resolver != null:
		_effect_resolver.clear_pending()
	_disconnect_presentation()
	_emit_turn_order_changed()


func is_running() -> bool:
	return _running


func set_paused(paused: bool) -> void:
	_paused = paused


func is_paused() -> bool:
	return _paused


func get_turn_order_snapshot() -> Dictionary:
	return {
		"combat_tick": combat_tick,
		"queue": _unit_queue.duplicate(),
		"act_index": _act_index,
		"round_active": _round_active,
	}


func toggle_paused() -> bool:
	_paused = not _paused
	return _paused


func _process(delta: float) -> void:
	if not _running or _waiting_presentation:
		return
	if _paused:
		return

	_timer += delta
	var effective_interval := action_interval
	if pace_config != null:
		effective_interval = pace_config.scaled_duration(action_interval, combat_tick)
	if _timer < effective_interval:
		return
	_timer = 0.0
	_process_one_step()


func _process_one_step() -> void:
	if _effect_resolver != null and _effect_resolver.has_pending_steps():
		_effect_resolver.process_next_step()
		_finish_logic_step()
		return

	if not _round_active:
		_begin_round()
		if _unit_queue.is_empty():
			_try_finish_round()
			return
		if _effect_resolver != null and _effect_resolver.has_pending_steps():
			return

	match _round_phase:
		RoundPhase.ACTIVE:
			_process_unit_turn()
		RoundPhase.DONE:
			_try_finish_round()


func _process_unit_turn() -> void:
	while _act_index < _unit_queue.size():
		var unit: UnitInstance = _unit_queue[_act_index]
		_act_index += 1
		if unit == null or not unit.is_alive():
			continue

		var action := UnitBrain.decide(_grid, unit)
		if action.type == UnitBrain.ActionType.LINE_ATTACK:
			_pipeline.apply_line_attack(
				unit,
				action.line_axis,
				unit.get_line_attack_damage(),
			)
			break

		var did_move := false
		if action.type == UnitBrain.ActionType.MOVE:
			did_move = true
			for to_cell in action.move_path:
				var from_cell := _grid.find_cell_of(unit)
				if _grid.move_unit_for(unit, to_cell):
					_emit_move(unit, from_cell, to_cell)
				else:
					break
		elif action.type == UnitBrain.ActionType.BUMP:
			_emit_move(unit, action.bump_from, action.bump_to)

		if not unit.is_alive():
			break

		var skip_follow_up := did_move and unit.skips_attack_after_move()
		if not skip_follow_up:
			if unit.can_perform_normal_attack():
				action = UnitBrain.decide(_grid, unit)
				if (
					action.type == UnitBrain.ActionType.ATTACK
					and action.attack_target != null
					and action.attack_target.is_alive()
				):
					_pipeline.apply_attack_exchange(unit, action.attack_target)
			elif unit.uses_line_attack():
				action = UnitBrain.decide(_grid, unit)
				if action.type == UnitBrain.ActionType.LINE_ATTACK:
					_pipeline.apply_line_attack(
						unit,
						action.line_axis,
						unit.get_line_attack_damage(),
					)
		break

	if _act_index >= _unit_queue.size():
		_round_phase = RoundPhase.DONE

	_finish_logic_step()


func _finish_logic_step() -> void:
	if presentation == null:
		action_finished.emit()
		_check_combat_end()
		return
	_waiting_presentation = true
	if presentation != null:
		presentation.set_combat_tick(combat_tick)
	if not presentation.step_presentation_finished.is_connected(_on_presentation_finished):
		presentation.step_presentation_finished.connect(_on_presentation_finished, CONNECT_ONE_SHOT)
	presentation.play_step()


func _on_presentation_finished() -> void:
	_waiting_presentation = false
	_timer = 0.0
	action_finished.emit()
	_check_combat_end()


func _disconnect_presentation() -> void:
	if presentation == null:
		return
	if presentation.step_presentation_finished.is_connected(_on_presentation_finished):
		presentation.step_presentation_finished.disconnect(_on_presentation_finished)


func _update_death_deferral() -> void:
	if _pipeline == null:
		return
	_pipeline.defer_death_removal = presentation != null


func update_presentation_binding() -> void:
	_update_death_deferral()


func _try_finish_round() -> void:
	if _effect_resolver != null and _effect_resolver.has_pending_steps():
		return
	_finish_round()
	if not _waiting_presentation:
		_check_combat_end()


func _begin_round() -> void:
	combat_tick += 1
	if _spawn_controller != null:
		_spawn_controller.process_tick(combat_tick)
	if _grid != null and _grid.cell_effects != null and _pipeline != null:
		_grid.cell_effects.apply_stand_damage(_grid, _pipeline)
		_grid.cell_effects.tick_round_end()

	_unit_queue = _get_sorted_alive_units()
	_round_active = true
	_round_phase = RoundPhase.ACTIVE
	_act_index = 0
	_emit_round_start()
	_emit_turn_order_changed()


func _finish_round() -> void:
	if not _round_active:
		return
	_round_active = false
	_round_phase = RoundPhase.DONE
	round_finished.emit()


func _check_combat_end() -> void:
	if not _running:
		return
	if _waiting_presentation:
		return
	if _effect_resolver != null and _effect_resolver.has_pending_steps() and not _combat_end_emitted:
		return
	var enemies := _grid.get_units_by_team(UnitInstance.Team.ENEMY, true)
	var players := _grid.get_units_by_team(UnitInstance.Team.PLAYER, true)
	var ending := false
	var won := false
	if enemies.is_empty():
		if _spawn_controller != null and _spawn_controller.has_pending_spawn():
			return
		ending = true
		won = true
	elif players.is_empty():
		ending = true
		won = false
	if not ending:
		return
	if not _combat_end_emitted and _event_bus != null:
		_combat_end_emitted = true
		_event_bus.emit_event(CombatEvents.ON_COMBAT_END, CombatEventPayload.new())
		if _effect_resolver != null and _effect_resolver.has_pending_steps():
			return
	if _effect_resolver != null and _effect_resolver.has_pending_steps():
		return
	_running = false
	_waiting_presentation = false
	combat_finished.emit(won)


func _get_sorted_alive_units() -> Array[UnitInstance]:
	var units := _grid.get_alive_units()
	for unit in units:
		_grid.sync_unit_grid_pos(unit)
	units.sort_custom(_sort_units_for_tick)
	return units


static func _sort_units_for_tick(a: UnitInstance, b: UnitInstance) -> bool:
	if a.team != b.team:
		return a.team == UnitInstance.Team.PLAYER
	if a.grid_pos.y != b.grid_pos.y:
		return a.grid_pos.y < b.grid_pos.y
	if a.grid_pos.x != b.grid_pos.x:
		return a.grid_pos.x < b.grid_pos.x
	return a.instance_id < b.instance_id


func _emit_round_start() -> void:
	if _event_bus == null:
		return
	var payload := CombatEventPayload.new()
	payload.amount = combat_tick
	_event_bus.emit_event(CombatEvents.ON_ROUND_START, payload)


func _emit_move(unit: UnitInstance, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if _event_bus == null:
		return
	var payload := CombatEventPayload.new()
	payload.source = unit
	payload.target = unit
	payload.from_cell = from_cell
	payload.to_cell = to_cell
	_event_bus.emit_event(CombatEvents.ON_MOVE, payload)


func _emit_turn_order_changed() -> void:
	turn_order_changed.emit(get_turn_order_snapshot())
