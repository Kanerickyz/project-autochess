class_name EndlessMapGenerator
extends RefCounted
## 无尽线性地图：START → 战斗1 → [可选商店] → 战斗2 → …（无精英/Boss/事件）。


static func generate(config: RunMapConfig, rng: RandomNumberGenerator) -> MapState:
	if config == null:
		push_error("EndlessMapGenerator: config is null")
		return MapState.new()
	if rng == null:
		push_error("EndlessMapGenerator: rng is null")
		return MapState.new()

	var state := MapState.new()
	var next_id := 0
	var column := _center_column(config)

	var start_data := _make_node(next_id, 0, column, MapNodeType.Type.START)
	next_id += 1
	var start_node := MapNodeRuntime.new(start_data)
	state.nodes.append(start_node)
	state.start_node_id = start_node.get_id()
	state.boss_node_id = -1
	state.current_node_id = -1
	state.mark_current(-1)

	var chunk := maxi(1, config.endless_chunk_combats)
	append_combat_chunk(state, config, rng, 1, chunk, start_data)
	return state


## 从 from_combat_floor 起追加 combat_count 场普通战，并按规则插商店；接到 tip_data 之后。
static func append_combat_chunk(
	state: MapState,
	config: RunMapConfig,
	rng: RandomNumberGenerator,
	from_combat_floor: int,
	combat_count: int,
	tip_data: MapNodeData = null,
) -> void:
	if state == null or config == null or rng == null:
		return
	var start_floor := maxi(1, from_combat_floor)
	var count := maxi(0, combat_count)
	if count <= 0:
		return

	var tip := tip_data
	if tip == null:
		tip = _find_linear_tip(state)
	if tip == null:
		push_error("EndlessMapGenerator.append_combat_chunk: no tip node")
		return

	var next_id := _next_node_id(state)
	var column := _center_column(config)
	var pure_floors := maxi(0, config.pure_combat_floors)
	var shop_every := maxi(1, config.shop_every_n_combats)

	for i in count:
		var combat_floor := start_floor + i
		## 商店夹在战斗之间：本场战斗之前、且不在纯战斗段内。
		if _should_insert_shop_before(combat_floor, pure_floors, shop_every):
			var shop_data := _make_node(next_id, combat_floor - 1, column, MapNodeType.Type.SHOP)
			next_id += 1
			tip.outgoing_ids.append(shop_data.id)
			state.nodes.append(MapNodeRuntime.new(shop_data))
			tip = shop_data

		var combat_data := _make_node(next_id, combat_floor, column, MapNodeType.Type.COMBAT)
		combat_data.encounter = _roll_combat(config, rng)
		next_id += 1
		tip.outgoing_ids.append(combat_data.id)
		state.nodes.append(MapNodeRuntime.new(combat_data))
		tip = combat_data

	if state.current_node_id >= 0:
		state.mark_current(state.current_node_id)
	else:
		state.mark_current(-1)


## 统计从当前已完成节点沿唯一出边还能走到的普通战斗数。
static func count_remaining_combats(state: MapState) -> int:
	if state == null:
		return 0
	var cursor_id := state.current_node_id
	if cursor_id < 0:
		cursor_id = state.start_node_id
	var cursor := state.get_node(cursor_id)
	if cursor == null:
		return 0
	## 若当前未完成，从它自己开始算（含本场）；已完成则从出边走。
	var remaining := 0
	var walk_ids: Array[int] = []
	if cursor.completed:
		walk_ids.assign(cursor.get_outgoing_ids())
	else:
		walk_ids = [cursor.get_id()]
	var guard := 0
	while not walk_ids.is_empty() and guard < 10000:
		guard += 1
		var nid: int = int(walk_ids[0])
		walk_ids.remove_at(0)
		var node := state.get_node(nid)
		if node == null:
			continue
		if node.get_effective_type() == MapNodeType.Type.COMBAT and not node.completed:
			remaining += 1
		for out_id in node.get_outgoing_ids():
			walk_ids.append(out_id)
	return remaining


static func highest_combat_floor(state: MapState) -> int:
	if state == null:
		return 0
	var best := 0
	for node in state.nodes:
		if node.get_effective_type() == MapNodeType.Type.COMBAT:
			best = maxi(best, node.get_floor())
	return best


static func _should_insert_shop_before(combat_floor: int, pure_floors: int, shop_every: int) -> bool:
	## 第 1 场前不插店；纯战斗段内不插；之后每 shop_every 场战斗之前插一座
	## （例 pure=3, every=3 → 在第 4、7、10… 场前插店）。
	if combat_floor <= 1:
		return false
	if combat_floor <= pure_floors:
		return false
	var since_pure := combat_floor - pure_floors
	return since_pure % shop_every == 1


static func _roll_combat(config: RunMapConfig, rng: RandomNumberGenerator) -> EncounterData:
	if config.combat_pool.is_empty():
		return null
	return config.combat_pool[rng.randi_range(0, config.combat_pool.size() - 1)]


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


static func _center_column(config: RunMapConfig) -> int:
	var cols := 7
	if config != null and config.column_count > 0:
		cols = config.column_count
	return cols / 2


static func _next_node_id(state: MapState) -> int:
	var best := 0
	for node in state.nodes:
		best = maxi(best, node.get_id() + 1)
	return best


static func _find_linear_tip(state: MapState) -> MapNodeData:
	## 出边为空的末节点（线性串唯一 tip）。
	for node in state.nodes:
		if node.data == null:
			continue
		if node.get_outgoing_ids().is_empty():
			return node.data
	return null
