class_name EncounterCombatDriver
extends RefCounted
## 无 UI 单场遭遇：抽敌、友方入座、RealtimeCombatSim 同步跑完。

const DEFAULT_SPAWN_BUDGET := preload("res://resources/spawn/default_spawn_budget.tres")


static func run_encounter(params: Dictionary) -> Dictionary:
	var encounter: EncounterData = params.get("encounter")
	var level: LevelData = params.get("level")
	var deck: DeckState = params.get("deck")
	var economy: RunEconomy = params.get("economy")
	var tier_index: int = int(params.get("tier_index", 0))
	var floor_index: int = int(params.get("floor_index", 1))
	var node_type: int = int(params.get("node_type", -1))
	var rng_seed: int = int(params.get("rng_seed", 1))
	var map_floor_count: int = int(params.get("map_floor_count", TierUnlock.DEFAULT_FLOOR_COUNT))
	var forward_tier_unlock: bool = bool(params.get("forward_tier_unlock", false))
	var budget_cfg: SpawnBudgetConfig = params.get("spawn_budget")
	if encounter == null or encounter.wave == null or level == null or deck == null:
		return {"ok": false, "won": false, "reason": "bad_params"}
	if budget_cfg == null:
		budget_cfg = DEFAULT_SPAWN_BUDGET

	var board_size: Vector2i = encounter.get_board_size(level.get_board_size())
	var resolved_type := _resolve_node_type(encounter, node_type)

	var ally_slots := PrepareSlotBoard.new()
	var enemy_slots := PrepareSlotBoard.new()
	var seat_rows := deck.get_config().get_seat_rows() if deck.get_config() != null else DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := deck.get_config().get_seat_cols() if deck.get_config() != null else DeckConfig.DEFAULT_SEAT_COLS
	ally_slots.configure_grid(seat_rows, seat_cols, board_size, false)
	enemy_slots.configure_grid(seat_rows, seat_cols, board_size, true)

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var spawns := _roll_enemy_spawns(
		encounter,
		level,
		deck,
		enemy_slots,
		budget_cfg,
		tier_index,
		floor_index,
		resolved_type,
		map_floor_count,
		forward_tier_unlock,
		rng,
	)
	if spawns.is_empty():
		return {"ok": false, "won": false, "reason": "no_enemies"}

	var sim := RealtimeCombatSim.new()
	sim.configure(board_size, rng_seed)
	if economy != null:
		sim.set_economy(economy)
	sim.set_deck_state(deck)
	sim.defer_effect_resolve = false

	for entry in deck.get_entries():
		if entry == null or entry.seat_index < 0:
			continue
		entry.refill_equipment_armor()
		var cell := ally_slots.get_cell(entry.seat_index)
		if cell == Vector2i(-1, -1):
			continue
		var unit := UnitInstance.from_deck_entry(entry, cell, UnitInstance.Team.PLAYER)
		if unit == null:
			continue
		if unit.stats != null:
			unit.stats.deploy_time = 0.0
		sim.add_unit(unit, Vector2(cell) + Vector2(0.5, 0.5))

	var player_count := sim.count_alive(UnitInstance.Team.PLAYER)
	if player_count <= 0:
		return {"ok": true, "won": false, "reason": "no_player_units", "steps": 0}

	for spawn in spawns:
		var place: Vector2 = spawn["position"]
		var seat_i: int = int(spawn.get("seat_index", -1))
		if seat_i >= 0:
			var seat_cell := enemy_slots.get_cell(seat_i)
			if seat_cell != Vector2i(-1, -1):
				place = Vector2(seat_cell) + Vector2(0.5, 0.5)
		var template: UnitInstance = spawn.get("unit") as UnitInstance
		var enemy := _fresh_enemy_from_template(template, place)
		if enemy == null:
			continue
		if enemy.stats != null:
			enemy.stats.deploy_time = 0.0
		sim.add_unit(enemy, place)

	sim.begin_combat()
	var outcome: Dictionary = sim.run_until_finished()
	outcome["ok"] = true
	return outcome


static func _resolve_node_type(encounter: EncounterData, node_type: int) -> MapNodeType.Type:
	if node_type >= 0:
		return node_type as MapNodeType.Type
	if encounter != null and encounter.is_boss:
		return MapNodeType.Type.BOSS
	if encounter != null and encounter.is_elite:
		return MapNodeType.Type.ELITE
	return MapNodeType.Type.COMBAT


static func _roll_enemy_spawns(
	encounter: EncounterData,
	level: LevelData,
	deck: DeckState,
	enemy_slots: PrepareSlotBoard,
	budget_cfg: SpawnBudgetConfig,
	tier_index: int,
	floor_index: int,
	node_type: MapNodeType.Type,
	map_floor_count: int,
	forward_tier_unlock: bool,
	rng: RandomNumberGenerator,
) -> Array:
	if budget_cfg != null and budget_cfg.enabled:
		return _roll_budget_spawns(
			encounter,
			level,
			deck,
			enemy_slots,
			budget_cfg,
			tier_index,
			floor_index,
			node_type,
			map_floor_count,
			forward_tier_unlock,
			rng,
		)
	return _roll_legacy_spawns(encounter, level, enemy_slots, tier_index, rng)


static func _roll_budget_spawns(
	encounter: EncounterData,
	level: LevelData,
	deck: DeckState,
	enemy_slots: PrepareSlotBoard,
	budget_cfg: SpawnBudgetConfig,
	tier_index: int,
	floor_index: int,
	node_type: MapNodeType.Type,
	map_floor_count: int,
	forward_tier_unlock: bool,
	rng: RandomNumberGenerator,
) -> Array:
	var fallback: Array[UnitData] = level.enemy_pool if level != null else []
	var team_snap: Array = deck.get_entries() if deck != null else []
	var seated := EnemyBudgetSpawner.roll(
		encounter.wave,
		budget_cfg,
		fallback,
		tier_index,
		floor_index,
		node_type,
		enemy_slots.seat_rows,
		enemy_slots.seat_cols,
		rng,
		team_snap,
		map_floor_count,
		forward_tier_unlock,
	)
	var result: Array = []
	var board_size := encounter.get_board_size(level.get_board_size())
	for item in seated:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var unit_data: UnitData = item.get("unit_data") as UnitData
		if unit_data == null:
			continue
		var seat_i: int = int(item.get("seat_index", -1))
		if seat_i < 0 or seat_i >= enemy_slots.slot_count:
			continue
		var cell := enemy_slots.get_cell(seat_i)
		var unit := UnitInstance.from_unit_data(unit_data, cell, UnitInstance.Team.ENEMY)
		var star_lv := clampi(int(item.get("level", 1)), 1, 3)
		_apply_enemy_star_level(unit, star_lv)
		result.append({
			"unit": unit,
			"position": _enemy_spawn_position(unit, cell, board_size),
			"seat_index": seat_i,
		})
	var panel_units: Array = []
	for spawn in result:
		panel_units.append(spawn.get("unit"))
	EnemyPanelMatcher.apply_to_units(
		panel_units,
		team_snap,
		floor_index,
		node_type,
		budget_cfg,
	)
	EnemyPanelMatcher.apply_floor_flat_to_units(panel_units, floor_index, budget_cfg)
	return result


static func _roll_legacy_spawns(
	encounter: EncounterData,
	level: LevelData,
	enemy_slots: PrepareSlotBoard,
	tier_index: int,
	rng: RandomNumberGenerator,
) -> Array:
	var entries := encounter.wave.roll_spawn_entries(level.enemy_pool, tier_index, rng)
	var units: Array[UnitData] = []
	for entry in entries:
		if entry == null or entry.unit == null:
			continue
		for _i in maxi(1, entry.count):
			units.append(entry.unit)
	var seat_count := enemy_slots.slot_count
	var boss_seat := EnemyBudgetSpawner.back_center_seat_index(enemy_slots.seat_cols, seat_count)
	var seat_fill := SeatLayout.iter_seats_center_out(enemy_slots.seat_rows, enemy_slots.seat_cols)
	var taken: Dictionary = {}
	var result: Array = []
	var board_size := encounter.get_board_size(level.get_board_size())
	for i in mini(units.size(), seat_count):
		var ud: UnitData = units[i]
		var seat_i: int
		var want_center := (ud != null and ud.is_boss_leader) or (
			encounter != null and encounter.is_boss and units.size() == 1
		)
		if want_center and not taken.has(boss_seat):
			seat_i = boss_seat
		else:
			seat_i = -1
			for s in seat_fill:
				if taken.has(s):
					continue
				seat_i = s
				break
			if seat_i < 0:
				for s2 in seat_count:
					if not taken.has(s2):
						seat_i = s2
						break
		if seat_i < 0:
			break
		taken[seat_i] = true
		var cell := enemy_slots.get_cell(seat_i)
		var unit := UnitInstance.from_unit_data(ud, cell, UnitInstance.Team.ENEMY)
		result.append({
			"unit": unit,
			"position": _enemy_spawn_position(unit, cell, board_size),
			"seat_index": seat_i,
		})
	return result


static func _apply_enemy_star_level(unit: UnitInstance, level: int) -> void:
	if unit == null:
		return
	var lv := clampi(level, 1, 3)
	unit.level = lv
	if lv <= 1 or unit.stats == null:
		return
	var body_mult := 1
	for _i in range(lv - 1):
		body_mult *= 3
	if body_mult <= 1:
		return
	unit.stats.attack = maxi(1, unit.stats.attack * body_mult)
	unit.stats.max_hp = maxi(1, unit.stats.max_hp * body_mult)
	unit.current_hp = unit.stats.max_hp


static func _enemy_spawn_position(unit: UnitInstance, seat_cell: Vector2i, board_size: Vector2i) -> Vector2:
	var size := Vector2i(1, 1)
	if unit != null:
		size = unit.get_footprint_size()
	if size.x <= 1 and size.y <= 1:
		return Vector2(seat_cell) + Vector2(0.5, 0.5)
	var origin := RealtimeCombatSim.pick_empty_footprint_origin(
		seat_cell, size, board_size, UnitInstance.Team.ENEMY
	)
	if origin == Vector2i(-1, -1):
		origin = seat_cell
	return RtUnit.footprint_center_for(origin, size)


static func _fresh_enemy_from_template(template: UnitInstance, place: Vector2) -> UnitInstance:
	if template == null or template.unit_data == null:
		return null
	var cell := Vector2i(floori(place.x), floori(place.y))
	var unit := UnitInstance.from_unit_data(template.unit_data, cell, UnitInstance.Team.ENEMY)
	if unit == null:
		return null
	unit.level = clampi(template.level, 1, 3)
	if template.stats != null and unit.stats != null:
		unit.stats.attack = maxi(1, template.stats.attack)
		unit.stats.max_hp = maxi(1, template.stats.max_hp)
	unit.current_hp = unit.get_effective_max_hp()
	return unit
