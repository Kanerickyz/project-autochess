extends SceneTree
## 地图商店 Arena 主路径烟测：enter_map_shop 走纸片半场，不依赖 UnitCardDisplay 座位。


func _initialize() -> void:
	var ok := true
	var battle_packed := load("res://scenes/combat/realtime/realtime_battle.tscn") as PackedScene
	if battle_packed == null:
		push_error("realtime_battle scene missing")
		ok = false
		quit(1)
		return
	var battle := battle_packed.instantiate() as RealtimeBattleController
	if battle == null:
		push_error("battle scene not RealtimeBattleController")
		ok = false
		quit(1)
		return
	root.add_child(battle)
	await process_frame

	var unit := UnitData.new()
	unit.id = "smoke_u"
	unit.display_name = "烟测"
	unit.stats = UnitStats.new()
	unit.stats.attack = 2
	unit.stats.max_hp = 8
	var config := DeckConfig.new()
	config.max_size = 5
	var deck := DeckState.new()
	deck.configure(config)
	var added := deck.add_entry(unit)
	if added != null:
		deck.assign_seat(added.entry_id, 0)
	var econ := RunEconomy.new()
	econ.reset()
	econ.grant(20)
	var level := LevelData.new()
	battle.setup(deck, econ, level)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var svc := MapShopService.new()
	svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
	svc.open_shop()

	await battle.enter_map_shop(svc, 0.0)
	if battle.get_phase() != RealtimeBattleController.Phase.MAP_SHOP:
		push_error("phase should be MAP_SHOP")
		ok = false
	var arena := battle.get_arena()
	if arena == null or not arena.map_shop_active:
		push_error("arena map_shop_active expected")
		ok = false
	if arena != null and arena.recruit_team_slots == null:
		push_error("map shop should sync recruit_team_slots for paper bodies")
		ok = false
	if arena != null and arena.map_shop_offers.is_empty():
		push_error("map shop offers should populate shelf")
		ok = false
	## 禁止再把 UnitCardDisplay 当作商店队伍半场主表现。
	if arena != null:
		for child in arena.find_children("*", "UnitCardDisplay", true, false):
			push_error("UnitCardDisplay must not be map shop team presentation")
			ok = false
			break

	## 货架物品与上半场角色均可长按 inspect（同信息卡路径）。
	if arena != null and not arena.map_shop_offers.is_empty():
		var offer0: Dictionary = arena.map_shop_offers[0]
		var offer_cell: Vector2i = offer0.get("cell", Vector2i(-1, -1))
		if offer0.get("item") != null and offer_cell.x >= 0:
			var offer_center := (
				arena.tile_to_local(Vector2(offer_cell) + Vector2(0.5, 0.5))
				+ Vector2(0.0, arena.ally_half_slide_y)
			)
			var offer_info := arena.inspect_at(offer_center)
			if offer_info.is_empty() or not bool(offer_info.get("is_item", false)):
				push_error("map shop offer should be inspectable as item")
				ok = false
		if arena.recruit_team_slots != null:
			var seat0 := arena.recruit_team_slots.get_entry(0)
			if seat0 != null:
				var team_cell := arena.recruit_team_slots.get_cell(0)
				var team_center := (
					arena.tile_to_local(Vector2(team_cell) + Vector2(0.5, 0.5))
					+ Vector2(0.0, arena.enemy_half_slide_y)
				)
				if arena.inspect_at(team_center).is_empty():
					push_error("map shop team unit should be inspectable")
					ok = false

	var entry := deck.get_entries()[0]
	svc._consumable_offers[0] = MapShopConfig._make_consumable("big_hp_potion", "大生命", 2, -1, 5)
	battle.on_map_shop_changed()
	var buy := svc.try_buy_consumable_on_entry(0, entry.entry_id)
	if int(buy.get("result", -1)) != MapShopService.BuyResult.OK:
		push_error("map shop smoke buy failed")
		ok = false
	battle.on_map_shop_changed()
	if arena != null and arena.map_shop_offers.size() > 0:
		var first: Dictionary = arena.map_shop_offers[0]
		if first.get("item") != null:
			push_error("bought consumable slot should clear in arena offers")
			ok = false

	battle.exit_map_shop()
	if battle.get_phase() != RealtimeBattleController.Phase.IDLE:
		push_error("IDLE after exit_map_shop")
		ok = false
	if arena != null and arena.map_shop_active:
		push_error("map_shop_active cleared after exit")
		ok = false
	svc.close_shop()
	battle.queue_free()

	if ok:
		print("MapShopArenaSmoke: OK")
	else:
		push_error("MapShopArenaSmoke: FAILED")
	quit(0 if ok else 1)
