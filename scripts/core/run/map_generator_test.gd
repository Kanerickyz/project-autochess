class_name MapGeneratorTest
extends RefCounted


static func run_all() -> bool:
	var passed := true
	passed = _test_boss_reachable() and passed
	passed = _test_all_floors_connected() and passed
	passed = _test_start_and_boss_unique() and passed
	passed = _test_mystery_resolves() and passed
	passed = _test_batch_generation() and passed
	passed = _test_only_v1_node_types() and passed
	passed = _test_max_nodes_per_floor() and passed
	passed = _test_sts_constraints() and passed
	passed = _test_edges_do_not_cross() and passed
	passed = _test_no_redundant_sibling_branches() and passed
	if passed:
		print("MapGeneratorTest: all passed")
	else:
		push_error("MapGeneratorTest: failures detected")
	return passed


static func _make_test_config() -> RunMapConfig:
	var config := RunMapConfig.new()
	config.floor_count = 10
	config.min_nodes_per_floor = 2
	config.max_nodes_per_floor = 7
	config.column_count = 7
	config.path_count = 6
	config.shop_min_floor = 4
	config.elite_min_floor = 6
	config.enchant_min_floor = 7
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

	var event := EventData.new()
	event.id = "test_event"
	config.event_pool = [event]
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
		if node.get_outgoing_ids().is_empty():
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
	var allowed: Array[MapNodeType.Type] = [
		MapNodeType.Type.COMBAT,
		MapNodeType.Type.EVENT,
		MapNodeType.Type.SHOP,
		MapNodeType.Type.ENCHANT,
	]
	if node.resolved_type not in allowed:
		push_error(
			"MapGeneratorTest: mystery resolved to disallowed type %s"
			% MapNodeType.display_name(node.resolved_type)
		)
		return false
	## 多样本：解析池不含 TREASURE / REST / ELITE / BOSS。
	for seed in 40:
		rng.seed = seed
		var sample := MapNodeRuntime.new(data.duplicate(true) as MapNodeData)
		sample.data.node_type = MapNodeType.Type.MYSTERY
		MapGenerator.resolve_mystery(sample, rng)
		if sample.resolved_type not in allowed:
			push_error(
				"MapGeneratorTest: seed %d mystery resolved to %s"
				% [seed, MapNodeType.display_name(sample.resolved_type)]
			)
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


static func _test_only_v1_node_types() -> bool:
	var allowed: Array[MapNodeType.Type] = [
		MapNodeType.Type.START,
		MapNodeType.Type.COMBAT,
		MapNodeType.Type.ELITE,
		MapNodeType.Type.BOSS,
		MapNodeType.Type.SHOP,
		MapNodeType.Type.EVENT,
		MapNodeType.Type.ENCHANT,
		MapNodeType.Type.MYSTERY,
	]
	var forbidden: Array[MapNodeType.Type] = [
		MapNodeType.Type.REST,
		MapNodeType.Type.TREASURE,
		MapNodeType.Type.SACRIFICE,
	]
	var config := _make_test_config()
	var seen: Dictionary = {}
	for seed in 100:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var state := MapGenerator.generate(config, rng)
		for node in state.nodes:
			var node_type := node.get_node_type()
			if node_type in forbidden or node_type not in allowed:
				push_error(
					"MapGeneratorTest: seed %d produced non-v1 node type %s"
					% [seed, MapNodeType.display_name(node_type)]
				)
				return false
			seen[node_type] = true
	if not seen.has(MapNodeType.Type.ENCHANT):
		push_error("MapGeneratorTest: enchant node never generated in 100 seeds")
		return false
	if not seen.has(MapNodeType.Type.MYSTERY):
		push_error("MapGeneratorTest: mystery node never generated in 100 seeds")
		return false
	return true


static func _test_max_nodes_per_floor() -> bool:
	var config := _make_test_config()
	## 路径合并后每层节点数不超过 column_count。
	config.max_nodes_per_floor = 9
	config.min_nodes_per_floor = 3
	config.path_count = 6
	for seed in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var state := MapGenerator.generate(config, rng)
		var by_floor: Dictionary = {}
		for node in state.nodes:
			var floor_index := node.get_floor()
			if floor_index == 0 or node.get_node_type() == MapNodeType.Type.BOSS:
				continue
			by_floor[floor_index] = int(by_floor.get(floor_index, 0)) + 1
		for floor_index in by_floor.keys():
			var count: int = int(by_floor[floor_index])
			if count > config.column_count:
				push_error(
					"MapGeneratorTest: seed %d floor %d has %d nodes (max %d)"
					% [seed, floor_index, count, config.column_count]
				)
				return false
	return true


static func _test_sts_constraints() -> bool:
	var config := _make_test_config()
	var unique_types: Array[MapNodeType.Type] = [
		MapNodeType.Type.ELITE,
		MapNodeType.Type.SHOP,
		MapNodeType.Type.ENCHANT,
	]
	for seed in 80:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var state := MapGenerator.generate(config, rng)
		for node in state.nodes:
			var node_type := node.get_node_type()
			var floor_index := node.get_floor()
			if floor_index == 1 and node_type != MapNodeType.Type.COMBAT:
				push_error(
					"MapGeneratorTest: seed %d floor1 node %d is %s (expected COMBAT)"
					% [seed, node.get_id(), MapNodeType.display_name(node_type)]
				)
				return false
			if node_type == MapNodeType.Type.ELITE and floor_index < config.elite_min_floor:
				push_error(
					"MapGeneratorTest: seed %d elite on floor %d < elite_min %d"
					% [seed, floor_index, config.elite_min_floor]
				)
				return false
			if node_type == MapNodeType.Type.SHOP and floor_index < config.shop_min_floor:
				push_error(
					"MapGeneratorTest: seed %d shop on floor %d < shop_min %d"
					% [seed, floor_index, config.shop_min_floor]
				)
				return false
			if node_type == MapNodeType.Type.ENCHANT and floor_index < config.enchant_min_floor:
				push_error(
					"MapGeneratorTest: seed %d enchant on floor %d < enchant_min %d"
					% [seed, floor_index, config.enchant_min_floor]
				)
				return false
			if node_type not in unique_types:
				continue
			## 父节点不可同为 ELITE/SHOP/ENCHANT。
			for other in state.nodes:
				if node.get_id() not in other.get_outgoing_ids():
					continue
				if other.get_node_type() == node_type:
					push_error(
						"MapGeneratorTest: seed %d node %d type %s matches parent %d"
						% [seed, node.get_id(), MapNodeType.display_name(node_type), other.get_id()]
					)
					return false
				## 同父兄弟不可相同。
				for sibling_id in other.get_outgoing_ids():
					if sibling_id == node.get_id():
						continue
					var sibling := state.get_node(sibling_id)
					if sibling != null and sibling.get_node_type() == node_type:
						push_error(
							"MapGeneratorTest: seed %d siblings %d/%d share type %s"
							% [
								seed,
								node.get_id(),
								sibling_id,
								MapNodeType.display_name(node_type),
							]
						)
						return false
	return true


static func _test_edges_do_not_cross() -> bool:
	var config := _make_test_config()
	for seed in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var state := MapGenerator.generate(config, rng)
		## 按层收集出边 (from_col -> to_col)，同层边不可交叉。
		var edges_by_floor: Dictionary = {}
		for node in state.nodes:
			var from_floor := node.get_floor()
			if node.get_node_type() == MapNodeType.Type.BOSS:
				continue
			for outgoing_id in node.get_outgoing_ids():
				var target := state.get_node(outgoing_id)
				if target == null:
					continue
				if target.get_floor() != from_floor + 1:
					continue
				if not edges_by_floor.has(from_floor):
					edges_by_floor[from_floor] = []
				edges_by_floor[from_floor].append(
					Vector2i(node.get_column(), target.get_column())
				)
		for floor_index in edges_by_floor.keys():
			var edges: Array = edges_by_floor[floor_index]
			for i in edges.size():
				var a: Vector2i = edges[i]
				for j in range(i + 1, edges.size()):
					var b: Vector2i = edges[j]
					if a.x == b.x:
						continue
					if (a.x < b.x and a.y > b.y) or (a.x > b.x and a.y < b.y):
						push_error(
							"MapGeneratorTest: seed %d crossing edges on floor %d (%d→%d vs %d→%d)"
							% [seed, floor_index, a.x, a.y, b.x, b.y]
						)
						return false
	return true


static func _test_no_redundant_sibling_branches() -> bool:
	var config := _make_test_config()
	config.path_count = 5
	for seed in 80:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var state := MapGenerator.generate(config, rng)
		for parent in state.nodes:
			var child_ids := parent.get_outgoing_ids()
			if child_ids.size() < 2:
				continue
			for i in child_ids.size():
				var sig_a := MapGeneratorTest._forward_sig_for_test(state, int(child_ids[i]))
				for j in range(i + 1, child_ids.size()):
					var sig_b := MapGeneratorTest._forward_sig_for_test(state, int(child_ids[j]))
					if sig_a == sig_b:
						push_error(
							"MapGeneratorTest: seed %d parent %d siblings %d/%d share forward sig"
							% [seed, parent.get_id(), child_ids[i], child_ids[j]]
						)
						return false
	return true


static func _forward_sig_for_test(state: MapState, start_id: int) -> String:
	var horizon := 2
	var seen: Dictionary = {}
	var queue: Array = [[start_id, 0]]
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var node_id: int = int(item[0])
		var depth: int = int(item[1])
		if seen.has(node_id):
			continue
		if depth > horizon:
			continue
		seen[node_id] = true
		if depth >= horizon:
			continue
		var node := state.get_node(node_id)
		if node == null:
			continue
		for outgoing_id in node.get_outgoing_ids():
			queue.append([outgoing_id, depth + 1])
	var keys: Array = seen.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for key in keys:
		parts.append(str(int(key)))
	return ",".join(parts)


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
