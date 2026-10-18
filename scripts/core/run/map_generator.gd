class_name MapGenerator
extends RefCounted

## 每一层（横向排布）最多节点数。
const MAX_NODES_PER_FLOOR := 3

## 每条 start→boss 路径必须覆盖的节点类型。
const _PATH_REQUIRED_TYPES: Array[MapNodeType.Type] = [
	MapNodeType.Type.ELITE,
	MapNodeType.Type.SHOP,
	MapNodeType.Type.EVENT,
]

const _MYSTERY_RESOLVE_TYPES: Array[MapNodeType.Type] = [
	MapNodeType.Type.COMBAT,
	MapNodeType.Type.EVENT,
	MapNodeType.Type.TREASURE,
]


static func generate(config: RunMapConfig, rng: RandomNumberGenerator) -> MapState:
	if config == null:
		push_error("MapGenerator: config is null")
		return MapState.new()
	if rng == null:
		push_error("MapGenerator: rng is null")
		return MapState.new()

	var state := MapState.new()
	var next_id := 0
	var floor_nodes: Array = []

	# Floor 0: START
	var start_data := _make_node(next_id, 0, config.column_count / 2, MapNodeType.Type.START, config, rng)
	next_id += 1
	var start_node := MapNodeRuntime.new(start_data)
	state.nodes.append(start_node)
	state.start_node_id = start_node.get_id()
	floor_nodes.append([start_data])

	# Middle floors
	for floor_index in range(1, config.floor_count + 1):
		var count := _pick_node_count(config, floor_index, rng)
		var columns := _pick_columns(config.column_count, count, rng)
		var floor_list: Array[MapNodeData] = []
		for column in columns:
			var node_type := _pick_node_type(config, floor_index, rng)
			var node_data := _make_node(next_id, floor_index, column, node_type, config, rng)
			next_id += 1
			state.nodes.append(MapNodeRuntime.new(node_data))
			floor_list.append(node_data)
		floor_nodes.append(floor_list)

	# Boss floor (top)
	var boss_floor := config.floor_count + 1
	var boss_data := _make_node(next_id, boss_floor, config.column_count / 2, MapNodeType.Type.BOSS, config, rng)
	if config.boss_encounter != null:
		boss_data.encounter = config.boss_encounter
	next_id += 1
	var boss_node := MapNodeRuntime.new(boss_data)
	state.nodes.append(boss_node)
	state.boss_node_id = boss_node.get_id()
	floor_nodes.append([boss_data])

	_connect_floors(floor_nodes, rng)
	_ensure_path_guarantees(state, config, rng)
	_assign_encounters(floor_nodes, config, rng)
	_assign_events(floor_nodes, config, rng)

	state.current_node_id = -1
	state.mark_current(-1)
	return state


static func resolve_mystery(node: MapNodeRuntime, rng: RandomNumberGenerator) -> void:
	if node == null or node.data == null or node.get_node_type() != MapNodeType.Type.MYSTERY:
		return
	var pick := _MYSTERY_RESOLVE_TYPES[rng.randi_range(0, _MYSTERY_RESOLVE_TYPES.size() - 1)]
	node.resolved_type = pick


static func finalize_mystery_node(
	node: MapNodeRuntime,
	config: RunMapConfig,
	rng: RandomNumberGenerator,
) -> void:
	resolve_mystery(node, rng)
	if node == null or node.data == null or config == null:
		return
	var effective := node.get_effective_type()
	if effective == MapNodeType.Type.EVENT and node.data.event_data == null and not config.event_pool.is_empty():
		node.data.event_data = config.event_pool[rng.randi_range(0, config.event_pool.size() - 1)]
	if MapNodeType.is_combat(effective) and node.data.encounter == null:
		node.data.encounter = _roll_encounter(config, effective, rng)


static func _make_node(
	id: int,
	floor_index: int,
	column: int,
	node_type: MapNodeType.Type,
	config: RunMapConfig,
	rng: RandomNumberGenerator,
) -> MapNodeData:
	var node := MapNodeData.new()
	node.id = id
	node.floor = floor_index
	node.column = column
	node.node_type = node_type
	if MapNodeType.is_combat(node_type) and node_type != MapNodeType.Type.BOSS:
		node.encounter = _roll_encounter(config, node_type, rng)
	return node


static func _pick_node_count(config: RunMapConfig, _floor_index: int, rng: RandomNumberGenerator) -> int:
	var min_count := mini(config.min_nodes_per_floor, config.column_count)
	var max_count := mini(config.max_nodes_per_floor, config.column_count)
	min_count = clampi(min_count, 1, MAX_NODES_PER_FLOOR)
	max_count = clampi(max_count, min_count, MAX_NODES_PER_FLOOR)
	return rng.randi_range(min_count, max_count)


static func _pick_columns(column_count: int, node_count: int, rng: RandomNumberGenerator) -> Array[int]:
	var available: Array[int] = []
	for i in column_count:
		available.append(i)
	available.shuffle()
	var result: Array[int] = []
	for i in node_count:
		result.append(available[i])
	result.sort()
	return result


static func _pick_node_type(config: RunMapConfig, floor_index: int, rng: RandomNumberGenerator) -> MapNodeType.Type:
	if floor_index % config.elite_interval == 0:
		return MapNodeType.Type.ELITE if rng.randf() < 0.35 else MapNodeType.Type.COMBAT
	if floor_index >= config.shop_min_floor and rng.randf() < 0.12:
		return MapNodeType.Type.SHOP
	if rng.randf() < 0.14:
		return MapNodeType.Type.EVENT
	if rng.randf() < 0.10:
		return MapNodeType.Type.ENCHANT
	return MapNodeType.Type.COMBAT


static func _connect_floors(floor_nodes: Array, rng: RandomNumberGenerator) -> void:
	for floor_index in range(floor_nodes.size() - 1):
		var lower: Array = floor_nodes[floor_index]
		var upper: Array = floor_nodes[floor_index + 1]
		var incoming_counts: Dictionary = {}
		for upper_node in upper:
			incoming_counts[upper_node.id] = 0

		for lower_node in lower:
			var candidates: Array[MapNodeData] = []
			for upper_node in upper:
				if abs(upper_node.column - lower_node.column) <= 2:
					candidates.append(upper_node)
			if candidates.is_empty():
				var nearest := _nearest_node(lower_node, upper)
				if nearest != null:
					candidates.append(nearest)
			candidates.shuffle()
			var link_count := mini(2, candidates.size())
			for i in link_count:
				var target: MapNodeData = candidates[i]
				if target.id not in lower_node.outgoing_ids:
					lower_node.outgoing_ids.append(target.id)
					incoming_counts[target.id] = int(incoming_counts.get(target.id, 0)) + 1

		for upper_node in upper:
			if int(incoming_counts.get(upper_node.id, 0)) == 0:
				var source := _nearest_node(upper_node, lower)
				if source != null and upper_node.id not in source.outgoing_ids:
					source.outgoing_ids.append(upper_node.id)


static func _nearest_node(from_node: MapNodeData, candidates: Array) -> MapNodeData:
	var best: MapNodeData = null
	var best_dist := 999
	for item in candidates:
		var node := item as MapNodeData
		if node == null:
			continue
		var dist := absi(node.column - from_node.column)
		if dist < best_dist:
			best_dist = dist
			best = node
	return best


## 保证每条 start→boss 路至少含精英、商店、事件各一。
## 多轮修复：先改战斗/附魔；必要时才挤占其它类型，并在后续轮次补回。
static func _ensure_path_guarantees(
	state: MapState,
	config: RunMapConfig,
	rng: RandomNumberGenerator,
) -> void:
	if state == null or config == null or rng == null:
		return
	for _round in 24:
		var dirty := false
		for required in _PATH_REQUIRED_TYPES:
			var avoiding := _find_path_avoiding_type(state, required)
			if avoiding.is_empty():
				continue
			dirty = true
			if not _convert_node_on_path(state, avoiding, required, config, rng, true):
				if not _convert_node_on_path(state, avoiding, required, config, rng, false):
					push_warning(
						"MapGenerator: could not guarantee %s on all paths"
						% MapNodeType.display_name(required)
					)
					return
		if not dirty:
			return
	push_warning("MapGenerator: path guarantees did not fully converge")


static func _find_path_avoiding_type(
	state: MapState,
	avoided: MapNodeType.Type,
) -> Array[int]:
	## DFS：找一条不含 avoided 类型的 start→boss 路径（起点/Boss 除外）。
	var path: Array[int] = []
	var visiting: Dictionary = {}
	if _dfs_avoiding(state, state.start_node_id, state.boss_node_id, avoided, path, visiting):
		return path
	return []


static func _dfs_avoiding(
	state: MapState,
	current_id: int,
	boss_id: int,
	avoided: MapNodeType.Type,
	path: Array[int],
	visiting: Dictionary,
) -> bool:
	if current_id in visiting:
		return false
	var node := state.get_node(current_id)
	if node == null:
		return false
	var node_type := node.get_node_type()
	if (
		node_type == avoided
		and node_type != MapNodeType.Type.START
		and node_type != MapNodeType.Type.BOSS
	):
		return false
	visiting[current_id] = true
	path.append(current_id)
	if current_id == boss_id:
		return true
	for outgoing_id in node.get_outgoing_ids():
		if _dfs_avoiding(state, outgoing_id, boss_id, avoided, path, visiting):
			return true
	path.pop_back()
	visiting.erase(current_id)
	return false


static func _convert_node_on_path(
	state: MapState,
	path: Array[int],
	required: MapNodeType.Type,
	config: RunMapConfig,
	rng: RandomNumberGenerator,
	combat_only: bool,
) -> bool:
	var candidates: Array[MapNodeRuntime] = []
	for node_id in path:
		var runtime := state.get_node(node_id)
		if runtime == null or runtime.data == null:
			continue
		var node_type := runtime.get_node_type()
		if node_type == MapNodeType.Type.START or node_type == MapNodeType.Type.BOSS:
			continue
		if node_type == required:
			continue
		if combat_only:
			if node_type == MapNodeType.Type.COMBAT or node_type == MapNodeType.Type.ENCHANT:
				candidates.append(runtime)
		else:
			candidates.append(runtime)
	if candidates.is_empty():
		return false
	var pick := candidates[rng.randi_range(0, candidates.size() - 1)]
	_retype_node(pick.data, required, config, rng)
	return true


static func _retype_node(
	data: MapNodeData,
	new_type: MapNodeType.Type,
	config: RunMapConfig,
	rng: RandomNumberGenerator,
) -> void:
	if data == null:
		return
	data.node_type = new_type
	data.encounter = null
	data.event_data = null
	if MapNodeType.is_combat(new_type) and new_type != MapNodeType.Type.BOSS:
		data.encounter = _roll_encounter(config, new_type, rng)
	elif new_type == MapNodeType.Type.EVENT and not config.event_pool.is_empty():
		data.event_data = config.event_pool[rng.randi_range(0, config.event_pool.size() - 1)]


static func _assign_encounters(floor_nodes: Array, config: RunMapConfig, rng: RandomNumberGenerator) -> void:
	for floor in floor_nodes:
		for node in floor:
			if not MapNodeType.is_combat(node.node_type):
				continue
			if node.node_type == MapNodeType.Type.BOSS:
				if config.boss_encounter != null:
					node.encounter = config.boss_encounter
				continue
			if node.encounter == null:
				node.encounter = _roll_encounter(config, node.node_type, rng)


static func _assign_events(floor_nodes: Array, config: RunMapConfig, rng: RandomNumberGenerator) -> void:
	if config.event_pool.is_empty():
		return
	for floor in floor_nodes:
		for node in floor:
			if node.node_type != MapNodeType.Type.EVENT:
				continue
			if node.event_data == null:
				node.event_data = config.event_pool[rng.randi_range(0, config.event_pool.size() - 1)]


static func _roll_encounter(
	config: RunMapConfig,
	node_type: MapNodeType.Type,
	rng: RandomNumberGenerator,
) -> EncounterData:
	var pool: Array[EncounterData] = []
	if node_type == MapNodeType.Type.ELITE:
		pool = config.elite_pool
	elif node_type == MapNodeType.Type.BOSS:
		if config.boss_encounter != null:
			return config.boss_encounter
		pool = config.elite_pool if not config.elite_pool.is_empty() else config.combat_pool
	else:
		pool = config.combat_pool
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]
