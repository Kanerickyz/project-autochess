class_name LinearRunProgress
extends RefCounted
## 主模式线性远征层表：普通/精英战斗层 + Boss 终点；无分叉选路。
## 本幕恰好 1 精英，层号 ∈ [ELITE_FLOOR_MIN, ELITE_FLOOR_MAX] 均匀随机。

const ELITE_FLOOR_MIN := 6
const ELITE_FLOOR_MAX := 12

## 含 Boss 的总层数（末层为 Boss）。
var floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT
## 本局抽定的精英层号（1-based；∈[6,12] 且落在战斗带内）。
var elite_floor: int = ELITE_FLOOR_MIN
## 普通+精英战斗层数（不含 Boss）；品阶「倒数 6 层」用此尺。
var combat_floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT - 1


## 由 RunMapConfig 生成层表元数据并产出线性 MapState（START→战…→Boss）。
static func generate(config: RunMapConfig, rng: RandomNumberGenerator) -> Dictionary:
	var progress := LinearRunProgress.new()
	var state := MapState.new()
	if config == null or rng == null:
		push_error("LinearRunProgress.generate: config/rng missing")
		return {"progress": progress, "map_state": state}

	var total := maxi(3, config.floor_count)
	progress.floor_count = total
	progress.combat_floor_count = maxi(1, total - 1)
	progress.elite_floor = _roll_elite_floor(progress.combat_floor_count, rng)

	var next_id := 0
	var column := _center_column(config)

	var start_data := _make_node(next_id, 0, column, MapNodeType.Type.START)
	next_id += 1
	var start_node := MapNodeRuntime.new(start_data)
	state.nodes.append(start_node)
	state.start_node_id = start_node.get_id()
	state.current_node_id = -1
	state.mark_current(-1)

	var tip := start_data
	for floor_i in range(1, progress.combat_floor_count + 1):
		var kind := MapNodeType.Type.ELITE if floor_i == progress.elite_floor else MapNodeType.Type.COMBAT
		var combat_data := _make_node(next_id, floor_i, column, kind)
		combat_data.encounter = _roll_encounter(config, kind, rng)
		next_id += 1
		tip.outgoing_ids.append(combat_data.id)
		state.nodes.append(MapNodeRuntime.new(combat_data))
		tip = combat_data

	var boss_data := _make_node(next_id, total, column, MapNodeType.Type.BOSS)
	if config.boss_encounter != null:
		boss_data.encounter = config.boss_encounter
	else:
		boss_data.encounter = _roll_encounter(config, MapNodeType.Type.BOSS, rng)
	tip.outgoing_ids.append(boss_data.id)
	var boss_node := MapNodeRuntime.new(boss_data)
	state.nodes.append(boss_node)
	state.boss_node_id = boss_node.get_id()

	return {"progress": progress, "map_state": state}


static func _roll_elite_floor(combat_floors: int, rng: RandomNumberGenerator) -> int:
	var lo := ELITE_FLOOR_MIN
	var hi := mini(ELITE_FLOOR_MAX, maxi(1, combat_floors))
	if hi < lo:
		## 战斗层过短时夹到可出现范围。
		return clampi(lo, 1, maxi(1, combat_floors))
	return rng.randi_range(lo, hi)


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


## 线性图上唯一可进入的下一战斗节点（START/已完成后的出边）。
static func find_next_combat_node(state: MapState) -> MapNodeRuntime:
	if state == null:
		return null
	for node in state.get_available_nodes():
		if node != null and MapNodeType.is_combat(node.get_effective_type()):
			return node
	return null
