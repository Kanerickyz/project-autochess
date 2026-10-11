class_name MapNodeData
extends Resource
## Authoritative map-node template. Runtime flags live on MapNodeRuntime.

@export var id: int = -1
@export var floor: int = 0
@export var column: int = 0
@export var node_type: MapNodeType.Type = MapNodeType.Type.COMBAT
@export var encounter: EncounterData
@export var event_data: EventData
@export var outgoing_ids: Array[int] = []


func is_combat_node() -> bool:
	return MapNodeType.is_combat(node_type)


func get_effective_type() -> MapNodeType.Type:
	return node_type


func to_runtime() -> MapNodeRuntime:
	return MapNodeRuntime.new(duplicate(true) as MapNodeData)
