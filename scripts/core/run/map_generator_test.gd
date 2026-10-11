class_name MapGeneratorTest
extends RefCounted


static func run_all() -> bool:
	var passed := true
	passed = _test_boss_reachable() and passed
	passed = _test_all_floors_connected() and passed
	passed = _test_start_and_boss_unique() and passed
	passed = _test_mystery_resolves() and passed
	passed = _test_batch_generation() and passed
	if passed:
		print("MapGeneratorTest: all passed")
	else:
		push_error("MapGeneratorTest: failures detected")
	return passed


static func _make_test_config() -> RunMapConfig:
	var config := RunMapConfig.new()
	config.floor_count = 10
	config.min_nodes_per_floor = 3
	config.max_nodes_per_floor = 5
	config.column_count = 7
	config.shop_min_floor = 4
	config.elite_interval = 3

	var wave := WaveData.new()
	wave.spawn_count = 2

	var combat := EncounterData.new()
	combat.id = "test_combat"
	combat.wave = wave
	config.combat_pool = [combat]

	var elite := EncounterData.new()
	elite.id = "test_elite"
	elite.wave = wave
	elite.is_elite = true
	config.elite_pool = [elite]

	var boss := EncounterData.new()
	boss.id = "test_boss"
	boss.wave = wave
	boss.is_boss = true
	config.boss_encounter = boss
	return config


static func _test_boss_reachable() -> bool:
	var config := _make_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var state := MapGenerator.generate(config, rng)
	if not _can_reach_boss(state):
		push_error("MapGeneratorTest: boss not reachable from start")
		return false
	return true


static func _test_all_floors_connected() -> bool:
	var config := _make_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var state := MapGenerator.generate(config, rng)
	for node in state.nodes:
		if node.get_node_type() == MapNodeType.Type.BOSS:
			continue
		if node.get_outgoing_ids().is_empty() and node.get_node_type() != MapNodeType.Type.BOSS:
			push_error("MapGeneratorTest: node %d has no outgoing edges" % node.get_id())
			return false
	return true


static func _test_start_and_boss_unique() -> bool:
	var config := _make_test_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var state := MapGenerator.generate(config, rng)
	var start_count := 0
	var boss_count := 0
	for node in state.nodes:
		if node.get_node_type() == MapNodeType.Type.START:
			start_count += 1
		if node.get_node_type() == MapNodeType.Type.BOSS:
			boss_count += 1
	if start_count != 1 or boss_count != 1:
		push_error("MapGeneratorTest: expected 1 start and 1 boss")
		return false
	return true


static func _test_mystery_resolves() -> bool:
	var data := MapNodeData.new()
	data.node_type = MapNodeType.Type.MYSTERY
	var node := MapNodeRuntime.new(data)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	MapGenerator.resolve_mystery(node, rng)
	if node.resolved_type == MapNodeType.Type.MYSTERY:
		push_error("MapGeneratorTest: mystery did not resolve")
		return false
	return true


static func _test_batch_generation() -> bool:
	var config := _make_test_config()
	for seed in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var state := MapGenerator.generate(config, rng)
		if not _can_reach_boss(state):
			push_error("MapGeneratorTest: seed %d boss unreachable" % seed)
			return false
	return true


static func _can_reach_boss(state: MapState) -> bool:
	if state.start_node_id < 0 or state.boss_node_id < 0:
		return false
	var visited: Dictionary = {}
	var queue: Array[int] = [state.start_node_id]
	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		if current_id in visited:
			continue
		visited[current_id] = true
		if current_id == state.boss_node_id:
			return true
		var node := state.get_node(current_id)
		if node == null:
			continue
		for outgoing_id in node.get_outgoing_ids():
			if outgoing_id not in visited:
				queue.append(outgoing_id)
	return false
