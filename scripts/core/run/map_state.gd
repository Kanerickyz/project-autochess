class_name MapState
extends RefCounted

var nodes: Array[MapNodeRuntime] = []
var current_node_id: int = -1
var start_node_id: int = -1
var boss_node_id: int = -1


func get_node(node_id: int) -> MapNodeRuntime:
	for node in nodes:
		if node.get_id() == node_id:
			return node
	return null


func get_nodes_on_floor(floor_index: int) -> Array[MapNodeRuntime]:
	var result: Array[MapNodeRuntime] = []
	for node in nodes:
		if node.get_floor() == floor_index:
			result.append(node)
	result.sort_custom(func(a: MapNodeRuntime, b: MapNodeRuntime) -> bool:
		return a.get_column() < b.get_column()
	)
	return result


func get_available_nodes() -> Array[MapNodeRuntime]:
	var result: Array[MapNodeRuntime] = []
	for node in nodes:
		if node.available and not node.completed:
			result.append(node)
	return result


func get_outgoing_nodes(from_id: int) -> Array[MapNodeRuntime]:
	var from_node := get_node(from_id)
	if from_node == null:
		return []
	var result: Array[MapNodeRuntime] = []
	for outgoing_id in from_node.get_outgoing_ids():
		var outgoing := get_node(outgoing_id)
		if outgoing != null:
			result.append(outgoing)
	return result


func mark_current(node_id: int) -> void:
	current_node_id = node_id
	for node in nodes:
		node.visited = node.get_id() == node_id or node.completed
	_refresh_availability()


func complete_node(node_id: int) -> void:
	var node := get_node(node_id)
	if node == null:
		return
	node.completed = true
	node.available = false
	current_node_id = node_id
	_refresh_availability()


func _refresh_availability() -> void:
	for node in nodes:
		if node.completed:
			node.available = false
			continue
		if current_node_id < 0:
			node.available = node.get_id() == start_node_id
			continue
		if node.get_id() == current_node_id and not node.completed:
			node.available = false
			continue
		node.available = _is_reachable_from_current(node.get_id())


func _is_reachable_from_current(target_id: int) -> bool:
	if current_node_id < 0:
		return target_id == start_node_id
	var current := get_node(current_node_id)
	if current == null:
		return false
	if not current.completed:
		return false
	return target_id in current.get_outgoing_ids()


func duplicate_state() -> MapState:
	var copy := MapState.new()
	copy.current_node_id = current_node_id
	copy.start_node_id = start_node_id
	copy.boss_node_id = boss_node_id
	for node in nodes:
		copy.nodes.append(node.duplicate_runtime())
	return copy
