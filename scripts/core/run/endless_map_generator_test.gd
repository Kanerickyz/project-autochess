class_name EndlessMapGeneratorTest
extends RefCounted


static func run_all() -> bool:
	var passed := true
	passed = _test_linear_no_elite_boss() and passed
	passed = _test_legacy_pure_combat_then_shops() and passed
	passed = _test_product_shop_every_4() and passed
	passed = _test_combat_floors_increment() and passed
	passed = _test_append_extends() and passed
	passed = _test_shop_does_not_own_new_floor() and passed
	if passed:
		print("EndlessMapGeneratorTest: all passed")
	else:
		push_error("EndlessMapGeneratorTest: failures detected")
	return passed


static func _make_config(pure_floors: int = 3, shop_every: int = 3) -> RunMapConfig:
	var config := RunMapConfig.new()
	config.endless_mode = true
	config.floor_count = 30
	config.column_count = 7
	config.pure_combat_floors = pure_floors
	config.shop_every_n_combats = shop_every
	config.endless_chunk_combats = 12
	config.endless_append_threshold = 4
	var wave := WaveData.new()
	wave.spawn_count = 2
	var combat := EncounterData.new()
	combat.id = "endless_test_combat"
	combat.wave = wave
	config.combat_pool = [combat]
	return config


static func _walk_types(state: MapState) -> Array[MapNodeType.Type]:
	var types: Array[MapNodeType.Type] = []
	var cursor := state.get_node(state.start_node_id)
	var guard := 0
	while cursor != null and guard < 100:
		guard += 1
		types.append(cursor.get_effective_type())
		var outs := cursor.get_outgoing_ids()
		if outs.is_empty():
			break
		cursor = state.get_node(outs[0])
	return types


static func _test_linear_no_elite_boss() -> bool:
	var config := _make_config(0, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var state := EndlessMapGenerator.generate(config, rng)
	if state.boss_node_id >= 0:
		push_error("EndlessMapGeneratorTest: boss_node_id should be -1")
		return false
	var combat_n := 0
	for node in state.nodes:
		var t := node.get_effective_type()
		if t == MapNodeType.Type.ELITE or t == MapNodeType.Type.BOSS \
				or t == MapNodeType.Type.EVENT or t == MapNodeType.Type.ENCHANT \
				or t == MapNodeType.Type.MYSTERY:
			push_error("EndlessMapGeneratorTest: forbidden node type %s" % MapNodeType.display_name(t))
			return false
		if t == MapNodeType.Type.COMBAT:
			combat_n += 1
		if node.get_outgoing_ids().size() > 1:
			push_error("EndlessMapGeneratorTest: branching outgoing on node %d" % node.get_id())
			return false
	if combat_n != config.endless_chunk_combats:
		push_error("EndlessMapGeneratorTest: expected %d combats, got %d" % [config.endless_chunk_combats, combat_n])
		return false
	return true


## 旧算法参数 pure=3/every=3：START, C1–C3, SHOP, C4…
static func _test_legacy_pure_combat_then_shops() -> bool:
	var config := _make_config(3, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var state := EndlessMapGenerator.generate(config, rng)
	var types := _walk_types(state)
	if types.size() < 8:
		push_error("EndlessMapGeneratorTest: legacy chain too short %d" % types.size())
		return false
	if types[0] != MapNodeType.Type.START:
		push_error("EndlessMapGeneratorTest: first should be START")
		return false
	if types[1] != MapNodeType.Type.COMBAT or types[2] != MapNodeType.Type.COMBAT \
			or types[3] != MapNodeType.Type.COMBAT:
		push_error("EndlessMapGeneratorTest: legacy first three after start must be combat")
		return false
	if types[4] != MapNodeType.Type.SHOP:
		push_error(
			"EndlessMapGeneratorTest: legacy shop expected after combat 3, got %s"
			% MapNodeType.display_name(types[4])
		)
		return false
	if types[5] != MapNodeType.Type.COMBAT:
		push_error("EndlessMapGeneratorTest: legacy combat 4 expected after first shop")
		return false
	return true


## 产品节拍 pure=0/every=4：战1–4 → 店 → 战5–8 → 店…
static func _test_product_shop_every_4() -> bool:
	var config := _make_config(0, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var state := EndlessMapGenerator.generate(config, rng)
	var types := _walk_types(state)
	## START + 4 combat + shop + 4 combat + shop …
	if types.size() < 11:
		push_error("EndlessMapGeneratorTest: product chain too short %d" % types.size())
		return false
	if types[0] != MapNodeType.Type.START:
		push_error("EndlessMapGeneratorTest: product first should be START")
		return false
	for i in range(1, 5):
		if types[i] != MapNodeType.Type.COMBAT:
			push_error(
				"EndlessMapGeneratorTest: product types[%d] should be COMBAT, got %s"
				% [i, MapNodeType.display_name(types[i])]
			)
			return false
	if types[5] != MapNodeType.Type.SHOP:
		push_error(
			"EndlessMapGeneratorTest: shop expected before combat 5, got %s"
			% MapNodeType.display_name(types[5])
		)
		return false
	for i in range(6, 10):
		if types[i] != MapNodeType.Type.COMBAT:
			push_error(
				"EndlessMapGeneratorTest: product types[%d] should be COMBAT, got %s"
				% [i, MapNodeType.display_name(types[i])]
			)
			return false
	if types[10] != MapNodeType.Type.SHOP:
		push_error(
			"EndlessMapGeneratorTest: shop expected before combat 9, got %s"
			% MapNodeType.display_name(types[10])
		)
		return false
	## 直接断言插入规则：第 5、9、13 场前插店。
	if not EndlessMapGenerator._should_insert_shop_before(5, 0, 4):
		push_error("EndlessMapGeneratorTest: should insert shop before F5")
		return false
	if EndlessMapGenerator._should_insert_shop_before(4, 0, 4):
		push_error("EndlessMapGeneratorTest: must not insert shop before F4")
		return false
	if not EndlessMapGenerator._should_insert_shop_before(9, 0, 4):
		push_error("EndlessMapGeneratorTest: should insert shop before F9")
		return false
	return true


static func _test_combat_floors_increment() -> bool:
	var config := _make_config(0, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var state := EndlessMapGenerator.generate(config, rng)
	var expected := 1
	for node in state.nodes:
		if node.get_effective_type() != MapNodeType.Type.COMBAT:
			continue
		if node.get_floor() != expected:
			push_error(
				"EndlessMapGeneratorTest: combat floor %d expected %d"
				% [node.get_floor(), expected]
			)
			return false
		expected += 1
	return true


static func _test_append_extends() -> bool:
	var config := _make_config(0, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var state := EndlessMapGenerator.generate(config, rng)
	var before := EndlessMapGenerator.highest_combat_floor(state)
	EndlessMapGenerator.append_combat_chunk(state, config, rng, before + 1, 6, null)
	var after := EndlessMapGenerator.highest_combat_floor(state)
	if after != before + 6:
		push_error("EndlessMapGeneratorTest: append expected %d got %d" % [before + 6, after])
		return false
	return true


static func _test_shop_does_not_own_new_floor() -> bool:
	var config := _make_config(0, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var state := EndlessMapGenerator.generate(config, rng)
	for node in state.nodes:
		if node.get_effective_type() != MapNodeType.Type.SHOP:
			continue
		## 商店夹在战斗 F-1 与 F 之间，floor 记为上一战斗层。
		if node.get_floor() < 1:
			push_error("EndlessMapGeneratorTest: shop floor should track prior combat")
			return false
	return true
