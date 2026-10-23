class_name CombatArena
extends Node

signal combat_started
signal combat_ended(won: bool)
signal combat_tick_processed
signal pause_changed(is_paused: bool)
signal turn_order_changed(snapshot: Dictionary)

@onready var _scheduler: CombatTickScheduler = $CombatTickScheduler

const DEFAULT_PACE_CONFIG := preload("res://resources/combat/default_combat_pace.tres")

@export var pace_config: CombatPaceConfig

var event_bus: CombatEventBus
var damage_pipeline: DamagePipeline
var effect_resolver: EffectResolver

var _grid: BoardGrid
var _presentation: CombatPresentation
var _rng := RandomNumberGenerator.new()
var _spawn_controller: WaveSpawnController = WaveSpawnController.new()


func _ready() -> void:
	_rng.randomize()
	if _scheduler:
		_scheduler.combat_finished.connect(_on_combat_finished)
		_scheduler.action_finished.connect(_on_action_finished)
		_scheduler.turn_order_changed.connect(_on_turn_order_changed)


func set_presentation(presentation: CombatPresentation) -> void:
	_presentation = presentation


func start_combat(
	grid: BoardGrid,
	wave: WaveData,
	wave_index: int = 0,
	enemy_pool: Array[UnitData] = [],
	pre_rolled_entries: Array[SpawnScheduleEntry] = [],
	fixed_placements: Array = [],
	deck_state: DeckState = null,
) -> void:
	_grid = grid
	_teardown_bus()

	event_bus = CombatEventBus.new()
	event_bus.name = "CombatEventBus"
	add_child(event_bus)
	event_bus.combat_event.connect(_on_combat_event)

	damage_pipeline = DamagePipeline.new(event_bus, grid)
	damage_pipeline.set_rng(_rng)
	effect_resolver = EffectResolver.new(grid, event_bus, damage_pipeline, _rng)
	effect_resolver.set_deck_state(deck_state)
	## 旧网格环若注入经济可再调 set_economy；主路径走 RealtimeCombatSim。
	damage_pipeline.set_effect_resolver(effect_resolver)
	event_bus.combat_event.connect(effect_resolver.on_event)

	_spawn_controller.setup(
		grid,
		wave,
		wave_index,
		enemy_pool,
		_rng,
		pre_rolled_entries,
		fixed_placements,
	)
	var active_pace := pace_config if pace_config != null else DEFAULT_PACE_CONFIG
	_scheduler.pace_config = active_pace
	_scheduler.configure(
		grid,
		damage_pipeline,
		event_bus,
		_spawn_controller,
		effect_resolver,
	)
	_scheduler.presentation = _presentation
	_scheduler.update_presentation_binding()
	_spawn_controller.spawn_wave_enemies()
	if _presentation != null:
		_presentation.pace_config = active_pace
		_presentation.bind_event_bus(event_bus)
		_presentation.begin_combat()
		_presentation.set_paused(false)

	var start_payload := CombatEventPayload.new()
	event_bus.emit_event(CombatEvents.ON_COMBAT_START, start_payload)

	_scheduler.start_combat()
	combat_started.emit()


func stop_combat() -> void:
	if _scheduler:
		_scheduler.set_paused(false)
		_scheduler.presentation = null
		_scheduler.stop_combat()
	if _presentation != null:
		_presentation.set_paused(false)
		_presentation.end_combat()
		_presentation.bind_event_bus(null)
	_teardown_bus()


func is_running() -> bool:
	return _scheduler != null and _scheduler.is_running()


func toggle_pause() -> bool:
	if not is_running():
		return false
	var paused := _scheduler.toggle_paused()
	if _presentation != null:
		_presentation.set_paused(paused)
	pause_changed.emit(paused)
	return paused


func is_paused() -> bool:
	return _scheduler != null and _scheduler.is_paused()


func get_turn_order_snapshot() -> Dictionary:
	if _scheduler == null:
		return {}
	return _scheduler.get_turn_order_snapshot()


func _teardown_bus() -> void:
	if event_bus != null and is_instance_valid(event_bus):
		event_bus.queue_free()
	if effect_resolver != null:
		effect_resolver = null
	event_bus = null
	damage_pipeline = null


func _on_combat_finished(won: bool) -> void:
	if _presentation != null:
		_presentation.end_combat()
	combat_ended.emit(won)


func _on_action_finished() -> void:
	combat_tick_processed.emit()


func _on_turn_order_changed(snapshot: Dictionary) -> void:
	turn_order_changed.emit(snapshot)


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if event_type == CombatEvents.ON_DAMAGE_TAKEN and payload.target != null:
		print(
			"[Combat] %s took %d dmg (hp=%d)"
			% [payload.target.id, payload.amount, payload.target.current_hp]
		)
