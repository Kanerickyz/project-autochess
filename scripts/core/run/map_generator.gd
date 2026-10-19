class_name MapGenerator
extends RefCounted

## 未定型连通节点的类型权重（其余填 COMBAT）。
const _WEIGHT_MYSTERY := 0.22
const _WEIGHT_ELITE := 0.08
const _WEIGHT_SHOP := 0.05
const _WEIGHT_EVENT := 0.10
const _WEIGHT_ENCHANT := 0.08

## 邻接/兄弟约束：这些类型不可与已连接父节点或同父兄弟相同。
const _UNIQUE_ADJ_TYPES: Array[MapNodeType.Type] = [
	MapNodeType.Type.ELITE,
	MapNodeType.Type.SHOP,
	MapNodeType.Type.ENCHANT,
]

const _MYSTERY_RESOLVE_TYPES: Array[MapNodeType.Type] = [
	MapNodeType.Type.COMBAT,
	MapNodeType.Type.EVENT,
	MapNodeType.Type.SHOP,
	MapNodeType.Type.ENCHANT,
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
	var start_data := _make_node(next_id, 0, config.column_count / 2, MapNodeType.Type.START)
	next_id += 1
	var start_node := MapNodeRuntime.new(start_data)
	state.nodes.append(start_node)
	state.start_node_id = start_node.get_id()
	floor_nodes.append([start_data])

	# Middle floors 1..floor_count：尖塔式不交叉上行路径，共享格合并。
	var path_result: Dictionary = _build_path_network(config, rng, next_id)
	next_id = int(path_result["next_id"])
	var middle_floors: Array = path_result["floor_nodes"]
	for floor_list in middle_floors:
		for node_data in floor_list:
			state.nodes.append(MapNodeRuntime.new(node_data))
		floor_nodes.append(floor_list)

	# Boss floor (top)
	var boss_floor := config.floor_count + 1
	var boss_data := _make_node(next_id, boss_floor, config.column_count / 2, MapNodeType.Type.BOSS)
	if config.boss_encounter != null:
		boss_data.encounter = config.boss_encounter
	next_id += 1
	var boss_node := MapNodeRuntime.new(boss_data)
	state.nodes.append(boss_node)
	state.boss_node_id = boss_node.get_id()
	floor_nodes.append([boss_data])

	_link_start_and_boss(floor_nodes)
	_assign_node_types(state, config, rng)
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
) -> MapNodeData:
	var node := MapNodeData.new()
	node.id = id
	node.floor = floor_index
	node.column = column
	node.node_type = node_type
	return node


static func _resolve_path_count(config: RunMapConfig) -> int:
	if config.path_count > 0:
		return clampi(config.path_count, 1, config.column_count)
	return mini(6, config.column_count)


static func _resolve_elite_min_floor(config: RunMapConfig) -> int:
	if config.elite_min_floor > 0:
		return config.elite_min_floor
	return maxi(4, int(config.floor_count / 3))


## 在 column_count × floor_count 格上画多条不交叉上行路径；共享格合并为同一节点。
static func _build_path_network(
	config: RunMapConfig,
	rng: RandomNumberGenerator,
	next_id: int,
) -> Dictionary:
	var column_count := config.column_count
	var floor_count := config.floor_count
	var path_count := _resolve_path_count(config)

	## key: Vector2i(floor, column) -> MapNodeData
	var cell_nodes: Dictionary = {}
	## floor -> Array[Vector2i(from_col, to_col)] 已画边，用于防交叉
	var edges_by_floor: Dictionary = {}

	var starts := _pick_path_start_columns(column_count, path_count, rng)
	for start_col in starts:
		var col: int = int(start_col)
		var prev: MapNodeData = null
		for floor_index in range(1, floor_count + 1):
			var key := Vector2i(floor_index, col)
			var node_data: MapNodeData
			if cell_nodes.has(key):
				node_data = cell_nodes[key]
			else:
				## 占位 COMBAT；类型在 _assign_node_types 中重写。
				node_data = _make_node(next_id, floor_index, col, MapNodeType.Type.COMBAT)
				next_id += 1
				cell_nodes[key] = node_data
			if prev != null and node_data.id not in prev.outgoing_ids:
				prev.outgoing_ids.append(node_data.id)
				var edge_floor := prev.floor
				if not edges_by_floor.has(edge_floor):
					edges_by_floor[edge_floor] = []
				edges_by_floor[edge_floor].append(Vector2i(prev.column, node_data.column))
			if floor_index < floor_count:
				col = _pick_next_column(
					col,
					column_count,
					edges_by_floor.get(floor_index, []),
					rng,
				)
			prev = node_data

	var floor_nodes: Array = []
	for floor_index in range(1, floor_count + 1):
		var floor_list: Array[MapNodeData] = []
		var cols: Array[int] = []
		for key in cell_nodes.keys():
			var cell: Vector2i = key
			if cell.x == floor_index:
				cols.append(cell.y)
		cols.sort()
		for c in cols:
			floor_list.append(cell_nodes[Vector2i(floor_index, c)])
		## 空层兜底：至少一格，避免断图。
		if floor_list.is_empty():
			var fallback_col := column_count / 2
			var fallback := _make_node(next_id, floor_index, fallback_col, MapNodeType.Type.COMBAT)
			next_id += 1
			cell_nodes[Vector2i(floor_index, fallback_col)] = fallback
			floor_list.append(fallback)
		floor_nodes.append(floor_list)

	return {"floor_nodes": floor_nodes, "next_id": next_id}


static func _pick_path_start_columns(
	column_count: int,
	path_count: int,
	rng: RandomNumberGenerator,
) -> Array[int]:
	var pool: Array[int] = []
	for c in column_count:
		pool.append(c)
	## 洗牌后取前 path_count；不足则允许重复随机列。
	for i in pool.size():
		var j := rng.randi_range(i, pool.size() - 1)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var starts: Array[int] = []
	for i in path_count:
		if i < pool.size():
			starts.append(pool[i])
		else:
			starts.append(rng.randi_range(0, column_count - 1))
	return starts


static func _pick_next_column(
	from_col: int,
	column_count: int,
	existing_edges: Array,
	rng: RandomNumberGenerator,
) -> int:
	var candidates: Array[int] = []
	for delta in [-1, 0, 1]:
		var to_col: int = from_col + int(delta)
		if to_col < 0 or to_col >= column_count:
			continue
		if _edge_would_cross(from_col, to_col, existing_edges):
			continue
		candidates.append(to_col)
	if candidates.is_empty():
		## 无合法候选时直行（钳制），避免断路。
		return clampi(from_col, 0, column_count - 1)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _edge_would_cross(from_col: int, to_col: int, existing_edges: Array) -> bool:
	for item in existing_edges:
		var edge: Vector2i = item
		var a := edge.x
		var b := edge.y
		if a == from_col:
			continue
		if (from_col < a and to_col > b) or (from_col > a and to_col < b):
			return true
	return false


static func _link_start_and_boss(floor_nodes: Array) -> void:
	if floor_nodes.size() < 3:
		return
	var start_list: Array = floor_nodes[0]
	var first_floor: Array = floor_nodes[1]
	var top_floor: Array = floor_nodes[floor_nodes.size() - 2]
	var boss_list: Array = floor_nodes[floor_nodes.size() - 1]
	if start_list.is_empty() or boss_list.is_empty():
		return
	var start_data: MapNodeData = start_list[0]
	var boss_data: MapNodeData = boss_list[0]
	for node in first_floor:
		var mid: MapNodeData = node
		if mid.id not in start_data.outgoing_ids:
			start_data.outgoing_ids.append(mid.id)
	for node in top_floor:
		var top: MapNodeData = node
		if boss_data.id not in top.outgoing_ids:
			top.outgoing_ids.append(boss_data.id)


static func _assign_node_types(
	state: MapState,
	config: RunMapConfig,
	rng: RandomNumberGenerator,
) -> void:
	var elite_min := _resolve_elite_min_floor(config)
	## Floor 1：全部 COMBAT。
	for node in state.nodes:
		if node.data == null:
			continue
		if node.get_floor() == 1:
			node.data.node_type = MapNodeType.Type.COMBAT
			node.data.encounter = null
			node.data.event_data = null

	var assignable: Array[MapNodeData] = []
	for node in state.nodes:
		if node.data == null:
			continue
		var floor_index := node.get_floor()
		if floor_index < 2 or floor_index > config.floor_count:
			continue
		## 先清空为「未定型」，权重领取失败后再填 COMBAT。
		node.data.node_type = MapNodeType.Type.COMBAT
		node.data.encounter = null
		node.data.event_data = null
		assignable.append(node.data)

	assignable.sort_custom(func(a: MapNodeData, b: MapNodeData) -> bool:
		if a.floor != b.floor:
			return a.floor < b.floor
		return a.column < b.column
	)

	var bucket := _build_type_bucket(assignable.size(), rng)
	var pending: Array[MapNodeData] = []
	for data in assignable:
		var placed := false
		for i in bucket.size():
			var candidate: MapNodeType.Type = bucket[i]
			if _is_type_legal(state, data, candidate, config, elite_min):
				data.node_type = candidate
				bucket.remove_at(i)
				placed = true
				break
		if not placed:
			pending.append(data)

	for data in pending:
		data.node_type = MapNodeType.Type.COMBAT


static func _build_type_bucket(count: int, rng: RandomNumberGenerator) -> Array[MapNodeType.Type]:
	var result: Array[MapNodeType.Type] = []
	if count <= 0:
		return result
	var specs: Array[Dictionary] = [
		{"type": MapNodeType.Type.MYSTERY, "weight": _WEIGHT_MYSTERY},
		{"type": MapNodeType.Type.ELITE, "weight": _WEIGHT_ELITE},
		{"type": MapNodeType.Type.SHOP, "weight": _WEIGHT_SHOP},
		{"type": MapNodeType.Type.EVENT, "weight": _WEIGHT_EVENT},
		{"type": MapNodeType.Type.ENCHANT, "weight": _WEIGHT_ENCHANT},
	]
	for spec in specs:
		var n := int(round(float(count) * float(spec["weight"])))
		for _i in n:
			result.append(spec["type"])
	while result.size() < count:
		result.append(MapNodeType.Type.COMBAT)
	## 四舍五入可能超额：优先丢掉 COMBAT，再从末尾裁。
	while result.size() > count:
		var combat_i := result.rfind(MapNodeType.Type.COMBAT)
		if combat_i >= 0:
			result.remove_at(combat_i)
		else:
			result.pop_back()
	## 洗牌
	for i in result.size():
		var j := rng.randi_range(i, result.size() - 1)
		var tmp: MapNodeType.Type = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result


static func _is_type_legal(
	state: MapState,
	data: MapNodeData,
	node_type: MapNodeType.Type,
	config: RunMapConfig,
	elite_min: int,
) -> bool:
	if node_type == MapNodeType.Type.ELITE and data.floor < elite_min:
		return false
	if node_type == MapNodeType.Type.SHOP and data.floor < config.shop_min_floor:
		return false
	if node_type not in _UNIQUE_ADJ_TYPES:
		return true

	var parents := _parent_nodes(state, data.id)
	for parent in parents:
		if parent.get_node_type() == node_type:
			return false

	var siblings := _sibling_nodes(state, data.id, parents)
	for sibling in siblings:
		if sibling.get_id() == data.id:
			continue
		if sibling.get_node_type() == node_type:
			return false
	return true


static func _parent_nodes(state: MapState, node_id: int) -> Array[MapNodeRuntime]:
	var result: Array[MapNodeRuntime] = []
	for node in state.nodes:
		if node_id in node.get_outgoing_ids():
			result.append(node)
	return result


static func _sibling_nodes(
	state: MapState,
	node_id: int,
	parents: Array[MapNodeRuntime],
) -> Array[MapNodeRuntime]:
	var seen: Dictionary = {}
	var result: Array[MapNodeRuntime] = []
	for parent in parents:
		for outgoing_id in parent.get_outgoing_ids():
			if outgoing_id == node_id or seen.has(outgoing_id):
				continue
			var sibling := state.get_node(outgoing_id)
			if sibling == null:
				continue
			seen[outgoing_id] = true
			result.append(sibling)
	return result


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
