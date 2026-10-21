class_name RunState
extends RefCounted

var rng_seed: int = 0
var map_state: MapState = MapState.new()
var run_depth: int = 0
var shop_visit_count: int = 0
var completed_encounter_count: int = 0
var current_node_id: int = -1
## 本局各场战斗用时累计（秒）；由 RunGameController 在 combat_resolved 时写入。
var total_combat_seconds: float = 0.0


func reset_progress() -> void:
	run_depth = 0
	shop_visit_count = 0
	completed_encounter_count = 0
	current_node_id = -1
	total_combat_seconds = 0.0
	map_state = MapState.new()


func add_combat_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	total_combat_seconds += seconds
