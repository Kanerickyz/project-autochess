class_name RunController
extends RefCounted

enum RunPhase { MAP, ENCOUNTER, RUN_COMPLETE, RUN_DEFEAT }

signal phase_changed(new_phase: RunPhase)
signal node_entered(node: MapNodeRuntime)
signal map_updated

var phase: RunPhase = RunPhase.MAP
var run_state: RunState = RunState.new()
var map_config: RunMapConfig
var _rng := RandomNumberGenerator.new()
var _pending_node: MapNodeRuntime


func configure(config: RunMapConfig, seed: int = -1) -> void:
	map_config = config
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	run_state.rng_seed = _rng.seed


func start_run() -> void:
	run_state.reset_progress()
	if map_config == null:
		push_error("RunController: map_config is null")
		return
	run_state.map_state = MapGenerator.generate(map_config, _rng)
	run_state.current_node_id = -1
	if run_state.map_state.start_node_id >= 0:
		run_state.map_state.complete_node(run_state.map_state.start_node_id)
	else:
		run_state.map_state.mark_current(-1)
	_set_phase(RunPhase.MAP)
	map_updated.emit()


func get_map_state() -> MapState:
	return run_state.map_state


func get_available_nodes() -> Array[MapNodeRuntime]:
	if run_state.map_state == null:
		return []
	return run_state.map_state.get_available_nodes()


func can_enter_node(node_id: int) -> bool:
	for node in get_available_nodes():
		if node.get_id() == node_id:
			return true
	return false


func enter_node(node_id: int) -> MapNodeRuntime:
	if not can_enter_node(node_id):
		return null
	var node := run_state.map_state.get_node(node_id)
	if node == null:
		return null
	if node.get_node_type() == MapNodeType.Type.MYSTERY:
		MapGenerator.finalize_mystery_node(node, map_config, _rng)
	_pending_node = node
	run_state.map_state.mark_current(node_id)
	run_state.current_node_id = node_id
	_set_phase(RunPhase.ENCOUNTER)
	node_entered.emit(node)
	return node


func get_pending_node() -> MapNodeRuntime:
	return _pending_node


func get_pending_node_type() -> MapNodeType.Type:
	if _pending_node == null:
		return MapNodeType.Type.COMBAT
	return _pending_node.get_effective_type()


func complete_encounter() -> void:
	if _pending_node == null:
		return
	var node_type := _pending_node.get_effective_type()
	run_state.map_state.complete_node(_pending_node.get_id())
	run_state.current_node_id = _pending_node.get_id()
	if MapNodeType.is_combat(node_type):
		run_state.completed_encounter_count += 1
	if node_type != MapNodeType.Type.SHOP:
		run_state.run_depth += 1
	if node_type == MapNodeType.Type.BOSS:
		_pending_node = null
		_set_phase(RunPhase.RUN_COMPLETE)
		map_updated.emit()
		return
	_pending_node = null
	_set_phase(RunPhase.MAP)
	map_updated.emit()


func register_shop_visit() -> void:
	run_state.shop_visit_count += 1


func get_shop_wave() -> int:
	return maxi(1, run_state.shop_visit_count)


func get_encounter_tier_index() -> int:
	return run_state.completed_encounter_count


func fail_run() -> void:
	_pending_node = null
	run_state.reset_progress()
	if map_config != null:
		run_state.map_state = MapGenerator.generate(map_config, _rng)
		run_state.map_state.mark_current(-1)
	_set_phase(RunPhase.RUN_DEFEAT)
	map_updated.emit()


func restart_run() -> void:
	start_run()


func get_board_defaults() -> LevelData:
	if map_config != null and map_config.board_defaults != null:
		return map_config.board_defaults
	return null


func _set_phase(new_phase: RunPhase) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	phase_changed.emit(new_phase)
