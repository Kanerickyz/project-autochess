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
## 败局时正在打的战斗层号（商店不升层；无尽成绩用）。
var defeat_reached_floor: int = 0


func configure(config: RunMapConfig, seed: int = -1) -> void:
	map_config = config
	if seed >= 0:
		_rng.seed = seed
	else:
		_rng.randomize()
	run_state.rng_seed = _rng.seed


func is_endless() -> bool:
	return map_config != null and map_config.endless_mode


func start_run() -> void:
	run_state.reset_progress()
	defeat_reached_floor = 0
	if map_config == null:
		push_error("RunController: map_config is null")
		return
	if is_endless():
		run_state.map_state = EndlessMapGenerator.generate(map_config, _rng)
	else:
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
	## 无尽永不因 Boss 通关（且地图不生成 Boss）；主爬塔保留原逻辑。
	if node_type == MapNodeType.Type.BOSS and not is_endless():
		_pending_node = null
		_set_phase(RunPhase.RUN_COMPLETE)
		map_updated.emit()
		return
	_pending_node = null
	if is_endless():
		ensure_endless_map_ahead()
	_set_phase(RunPhase.MAP)
	map_updated.emit()


## 无尽：剩余线性战斗不足时续写下一段。
func ensure_endless_map_ahead() -> void:
	if not is_endless() or map_config == null or run_state.map_state == null:
		return
	var threshold := maxi(1, map_config.endless_append_threshold)
	var remaining := EndlessMapGenerator.count_remaining_combats(run_state.map_state)
	if remaining >= threshold:
		return
	var next_floor := EndlessMapGenerator.highest_combat_floor(run_state.map_state) + 1
	var chunk := maxi(1, map_config.endless_chunk_combats)
	EndlessMapGenerator.append_combat_chunk(
		run_state.map_state,
		map_config,
		_rng,
		next_floor,
		chunk,
		null,
	)


func register_shop_visit() -> void:
	run_state.shop_visit_count += 1


func get_shop_wave() -> int:
	return maxi(1, run_state.shop_visit_count)


func get_encounter_tier_index() -> int:
	return run_state.completed_encounter_count


func fail_run() -> void:
	## 先记下败局层深：正在打的战斗节点 floor（未打赢也记 N）。
	if _pending_node != null and MapNodeType.is_combat(_pending_node.get_effective_type()):
		defeat_reached_floor = maxi(1, _pending_node.get_floor())
	elif defeat_reached_floor <= 0:
		defeat_reached_floor = maxi(1, run_state.completed_encounter_count + 1)
	_pending_node = null
	run_state.reset_progress()
	if map_config != null:
		if is_endless():
			run_state.map_state = EndlessMapGenerator.generate(map_config, _rng)
		else:
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
