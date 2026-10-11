class_name MapNodeRuntime
extends RefCounted
## Runtime map-node state. Authority data stays on MapNodeData (no runtime fields).

var data: MapNodeData
var visited: bool = false
var available: bool = false
var completed: bool = false
## MYSTERY node resolved type for this run
var resolved_type: MapNodeType.Type = MapNodeType.Type.MYSTERY


func _init(node_data: MapNodeData = null) -> void:
	data = node_data


func get_id() -> int:
	return data.id if data != null else -1


func get_floor() -> int:
	return data.floor if data != null else 0


func get_column() -> int:
	return data.column if data != null else 0


func get_node_type() -> MapNodeType.Type:
	return data.node_type if data != null else MapNodeType.Type.COMBAT


func get_encounter() -> EncounterData:
	return data.encounter if data != null else null


func get_event_data() -> EventData:
	return data.event_data if data != null else null


func get_outgoing_ids() -> Array[int]:
	if data == null:
		var empty: Array[int] = []
		return empty
	return data.outgoing_ids


func is_combat_node() -> bool:
	return MapNodeType.is_combat(get_effective_type())


func get_effective_type() -> MapNodeType.Type:
	var base := get_node_type()
	if base == MapNodeType.Type.MYSTERY and resolved_type != MapNodeType.Type.MYSTERY:
		return resolved_type
	return base


func duplicate_runtime() -> MapNodeRuntime:
	var copy := MapNodeRuntime.new(data.duplicate(true) as MapNodeData if data != null else null)
	copy.visited = visited
	copy.available = available
	copy.completed = completed
	copy.resolved_type = resolved_type
	return copy
