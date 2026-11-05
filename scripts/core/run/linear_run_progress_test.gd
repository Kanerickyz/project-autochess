class_name LinearRunProgressTest
extends RefCounted


static func run_all() -> bool:
	var passed := true
	passed = _test_elite_exactly_one_in_band() and passed
	passed = _test_boss_is_last_floor() and passed
	passed = _test_combat_floor_count_excludes_boss() and passed
	passed = _test_linear_chain_available() and passed
	if passed:
		print("LinearRunProgressTest: all tests passed")
	else:
		push_error("LinearRunProgressTest: failures detected")
	return passed


static func _make_config(floor_count: int = 15) -> RunMapConfig:
	var config := RunMapConfig.new()
	config.floor_count = floor_count
	config.column_count = 7
	var combat := EncounterData.new()
	combat.id = "t_combat"
	var elite := EncounterData.new()
	elite.id = "t_elite"
	var boss := EncounterData.new()
	boss.id = "t_boss"
	var combat_pool: Array[EncounterData] = []
	combat_pool.append(combat)
	var elite_pool: Array[EncounterData] = []
	elite_pool.append(elite)
	config.combat_pool = combat_pool
	config.elite_pool = elite_pool
	config.boss_encounter = boss
	return config


static func _test_elite_exactly_one_in_band() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seen: Dictionary = {}
	for _i in 40:
		var generated: Dictionary = LinearRunProgress.generate(_make_config(15), rng)
		var progress: LinearRunProgress = generated["progress"]
		var state: MapState = generated["map_state"]
		if progress.elite_floor < LinearRunProgress.ELITE_FLOOR_MIN \
				or progress.elite_floor > LinearRunProgress.ELITE_FLOOR_MAX:
			push_error(
				"LinearRunProgressTest: elite_floor %d out of [6,12]"
				% progress.elite_floor
			)
			return false
		seen[progress.elite_floor] = true
		var elite_nodes := 0
		for node in state.nodes:
			if node.get_effective_type() == MapNodeType.Type.ELITE:
				elite_nodes += 1
				if node.get_floor() != progress.elite_floor:
					push_error("LinearRunProgressTest: elite node floor mismatch")
					return false
		if elite_nodes != 1:
			push_error("LinearRunProgressTest: expected exactly 1 elite, got %d" % elite_nodes)
			return false
	if seen.size() < 3:
		push_error("LinearRunProgressTest: elite floor should vary across seeds")
		return false
	return true


static func _test_boss_is_last_floor() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var generated: Dictionary = LinearRunProgress.generate(_make_config(15), rng)
	var progress: LinearRunProgress = generated["progress"]
	var state: MapState = generated["map_state"]
	if progress.floor_count != 15:
		push_error("LinearRunProgressTest: floor_count should be 15")
		return false
	var boss := state.get_node(state.boss_node_id)
	if boss == null or boss.get_effective_type() != MapNodeType.Type.BOSS:
		push_error("LinearRunProgressTest: missing boss node")
		return false
	if boss.get_floor() != 15:
		push_error("LinearRunProgressTest: boss floor should be 15, got %d" % boss.get_floor())
		return false
	return true


static func _test_combat_floor_count_excludes_boss() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var generated: Dictionary = LinearRunProgress.generate(_make_config(15), rng)
	var progress: LinearRunProgress = generated["progress"]
	if progress.combat_floor_count != 14:
		push_error(
			"LinearRunProgressTest: combat_floor_count should be 14, got %d"
			% progress.combat_floor_count
		)
		return false
	## 倒数 6 层不含 Boss：第 9–14 层为晚段。
	if not TierUnlock.is_late_tier_band(9, progress.combat_floor_count):
		push_error("LinearRunProgressTest: floor 9/14 should be late band")
		return false
	if TierUnlock.is_late_tier_band(8, progress.combat_floor_count):
		push_error("LinearRunProgressTest: floor 8/14 should not be late band")
		return false
	return true


static func _test_linear_chain_available() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var generated: Dictionary = LinearRunProgress.generate(_make_config(15), rng)
	var state: MapState = generated["map_state"]
	state.complete_node(state.start_node_id)
	var first := LinearRunProgress.find_next_combat_node(state)
	if first == null or first.get_floor() != 1:
		push_error("LinearRunProgressTest: after START, next should be floor 1")
		return false
	## 无附魔/商店节点。
	for node in state.nodes:
		var t := node.get_effective_type()
		if (
			t == MapNodeType.Type.SHOP
			or t == MapNodeType.Type.EVENT
			or t == MapNodeType.Type.ENCHANT
		):
			push_error("LinearRunProgressTest: linear map must not contain shop/event/enchant")
			return false
	return true
