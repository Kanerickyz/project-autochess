extends SceneTree
## 地图商店场景可实例化、服务可走通购买；轻量烟测。


func _initialize() -> void:
	var ok := true
	var packed := load("res://scenes/ui/map_shop/map_shop_screen.tscn")
	if packed == null:
		push_error("map shop scene missing")
		ok = false
	else:
		var screen: MapShopScreen = (packed as PackedScene).instantiate() as MapShopScreen
		if screen == null:
			push_error("map shop scene not MapShopScreen")
			ok = false
		else:
			root.add_child(screen)
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
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var svc := MapShopService.new()
			svc.configure(MapShopConfig.make_code_defaults(), econ, deck, rng)
			svc.open_shop()
			await screen.open_shop(svc, deck)
			if screen.get_node_or_null("%ConsumableRow") == null:
				push_error("map shop UI nodes missing")
				ok = false
			var seat_grid := screen.get_node_or_null("%SeatGrid") as GridContainer
			var found_card := false
			if seat_grid != null:
				for cell in seat_grid.get_children():
					if cell is PanelContainer and (cell as PanelContainer).has_meta("unit_card"):
						var card: Variant = (cell as PanelContainer).get_meta("unit_card")
						if card is UnitCardDisplay:
							found_card = true
							break
			if not found_card:
				push_error("map shop seat should show UnitCardDisplay for occupied seats")
				ok = false
			var entry := deck.get_entries()[0]
			## 确保有可买消耗品。
			svc._consumable_offers[0] = MapShopConfig._make_consumable("big_hp_potion", "大生命", 2, -1, 5)
			var buy := svc.try_buy_consumable_on_entry(0, entry.entry_id)
			if int(buy.get("result", -1)) != MapShopService.BuyResult.OK:
				push_error("map shop smoke buy failed")
				ok = false
			screen.hide_shop()
			svc.close_shop()
			screen.queue_free()
	if ok:
		print("MapShopScreenSmoke: OK")
	else:
		push_error("MapShopScreenSmoke: FAILED")
	quit(0 if ok else 1)
