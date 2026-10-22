class_name MapShopBattleExtension
extends RefCounted
## 地图商店：Arena 上队伍 / 下货架 + 底栏（刷新消耗品 / 离开）。


var _battle: RealtimeBattleController
var _service: MapShopService
var _hud: Control
var _stats_label: Label
var _hint_label: Label
var _btn_refresh: Button
var _btn_leave: Button
var _team_slots: PrepareSlotBoard = PrepareSlotBoard.new()
var _animating: bool = false


func setup(battle: RealtimeBattleController) -> void:
	_battle = battle
	_ensure_hud()


func set_service(service: MapShopService) -> void:
	if _service != null and _service.shop_changed.is_connected(_on_shop_changed):
		_service.shop_changed.disconnect(_on_shop_changed)
	_service = service
	if _service != null and not _service.shop_changed.is_connected(_on_shop_changed):
		_service.shop_changed.connect(_on_shop_changed)


func clear_service() -> void:
	if _service != null and _service.shop_changed.is_connected(_on_shop_changed):
		_service.shop_changed.disconnect(_on_shop_changed)
	_service = null


func get_team_slots() -> PrepareSlotBoard:
	return _team_slots


func set_animating(enabled: bool) -> void:
	_animating = enabled
	_refresh_buttons()


func is_animating() -> bool:
	return _animating


func show_hud() -> void:
	_ensure_hud()
	_hud.visible = true
	_refresh()


func hide_hud() -> void:
	if _hud != null:
		_hud.visible = false


func sync_arena(arena: RealtimeArenaView, deck: DeckState, board_size: Vector2i) -> void:
	if arena == null:
		return
	arena.clear_enchant_mode()
	arena.clear_recruit_mode()
	arena.map_shop_active = true
	_rebuild_team_slots(deck, board_size)
	arena.recruit_team_slots = _team_slots
	arena.map_shop_offers = _build_offer_previews(board_size)
	arena.prepare_slots = null
	arena.enemy_slots = null
	arena.enemy_previews = []
	arena.sim = null
	arena.placement_active = false
	arena.queue_redraw()


func clear_arena(arena: RealtimeArenaView) -> void:
	if arena == null:
		return
	arena.clear_map_shop_mode()


func rebuild_team_slots(deck: DeckState, board_size: Vector2i) -> void:
	_rebuild_team_slots(deck, board_size)


func _rebuild_team_slots(deck: DeckState, board_size: Vector2i) -> void:
	var seat_rows := DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := DeckConfig.DEFAULT_SEAT_COLS
	if deck != null:
		var config := deck.get_config()
		if config != null:
			seat_rows = config.get_seat_rows()
			seat_cols = config.get_seat_cols()
	## 与招募一致：上半场敌区几何、行序与我半场前排同向。
	_team_slots.configure_grid(seat_rows, seat_cols, board_size, true, true)
	if deck == null:
		return
	for entry in deck.get_entries():
		if entry == null:
			continue
		var seat_i := entry.seat_index
		if seat_i < 0 or seat_i >= _team_slots.slot_count or not _team_slots.is_empty(seat_i):
			seat_i = -1
			for i in _team_slots.slot_count:
				if _team_slots.is_empty(i) and deck.is_seat_free(i):
					seat_i = i
					break
			if seat_i < 0:
				continue
			deck.assign_seat(entry.entry_id, seat_i)
		_team_slots.try_assign_with_seq(seat_i, entry, entry.seat_assign_seq)


func _build_offer_previews(board_size: Vector2i) -> Array:
	var out: Array = []
	if _service == null or not _service.is_open():
		return out
	var consumables := _service.get_consumable_offers()
	var equipment := _service.get_equipment_offers()
	var cons_cells := _build_shelf_row_cells(consumables.size(), board_size, 1)
	var equip_cells := _build_shelf_row_cells(equipment.size(), board_size, 3)
	for i in consumables.size():
		var item: MapShopConsumableData = consumables[i] as MapShopConsumableData
		var cell := cons_cells[i] if i < cons_cells.size() else Vector2i(-1, -1)
		var cost := item.cost if item != null else 0
		out.append({
			"index": i,
			"kind": &"consumable",
			"item": item,
			"cell": cell,
			"cost": cost,
			"affordable": _service.can_afford(cost) if item != null else false,
			"label": item.get_display_name() if item != null else "",
			"summary": item.get_effect_summary() if item != null else "",
		})
	for i in equipment.size():
		var item: EquipmentData = equipment[i] as EquipmentData
		var cell := equip_cells[i] if i < equip_cells.size() else Vector2i(-1, -1)
		var cost := item.cost if item != null else 0
		out.append({
			"index": i,
			"kind": &"equipment",
			"item": item,
			"cell": cell,
			"cost": cost,
			"affordable": _service.can_afford(cost) if item != null else false,
			"label": item.get_display_name() if item != null else "",
			"summary": "护甲 %d" % item.get_armor_block() if item != null else "",
		})
	return out


func _build_shelf_row_cells(count: int, board_size: Vector2i, row_offset: int) -> Array[Vector2i]:
	var n := maxi(0, count)
	var cells: Array[Vector2i] = []
	if n <= 0:
		return cells
	var mid := BoardHalf.midline_row(board_size.y)
	var y := clampi(mid + row_offset, mid, maxi(mid, board_size.y - 1))
	var gap := 1
	var block_w := n + (n - 1) * gap
	if block_w > board_size.x:
		gap = 0
		block_w = n
	var start_x := (board_size.x - block_w) / 2
	start_x = clampi(start_x, 0, maxi(0, board_size.x - 1))
	for i in n:
		var x := clampi(start_x + i * (1 + gap), 0, maxi(0, board_size.x - 1))
		cells.append(Vector2i(x, y))
	return cells


func _ensure_hud() -> void:
	if _hud != null or _battle == null:
		return
	var dock := _battle.get_dock()
	if dock == null:
		return
	_hud = VBoxContainer.new()
	_hud.name = "MapShopHud"
	_hud.visible = false
	dock.add_child(_hud)
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_stats_label)
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = "拖下半场货架到上半场角色购买；拖队伍换座"
	_hud.add_child(_hint_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud.add_child(row)
	_btn_refresh = Button.new()
	_btn_refresh.text = "刷新消耗品"
	_btn_refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_refresh.pressed.connect(_on_refresh)
	row.add_child(_btn_refresh)
	_btn_leave = Button.new()
	_btn_leave.text = "离开"
	_btn_leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_leave.pressed.connect(_on_leave)
	row.add_child(_btn_leave)


func _refresh() -> void:
	if _service == null:
		return
	var gold := _service.get_gold()
	var cost := _service.get_refresh_cost()
	_stats_label.text = "%s · 刷新消耗品 %d 金" % [UiStatIcons.format_gold_label(gold), cost]
	_refresh_buttons()
	if _battle != null:
		_battle.refresh_map_shop_chrome()


func _refresh_buttons() -> void:
	if _btn_refresh != null and _service != null:
		var cost := _service.get_refresh_cost()
		_btn_refresh.text = "刷新消耗品（%d 金）" % cost
		_btn_refresh.disabled = _animating or not _service.can_refresh()
	if _btn_leave != null:
		_btn_leave.disabled = _animating


func set_hint(text: String) -> void:
	if _hint_label != null:
		_hint_label.text = text


func _on_refresh() -> void:
	if _service == null or _animating:
		return
	var result := _service.try_refresh_consumables()
	if int(result.get("result", MapShopService.BuyResult.FAILED)) != MapShopService.BuyResult.OK:
		var reason := String(result.get("reason", ""))
		match reason:
			"cant_afford":
				set_hint("金币不足，无法刷新")
			_:
				set_hint("无法刷新")
		_refresh()
		return
	set_hint("已刷新消耗品货架")
	_refresh()


func _on_leave() -> void:
	if _animating or _battle == null:
		return
	_battle.request_exit_map_shop()


func _on_shop_changed() -> void:
	_refresh()
	if _battle != null:
		_battle.on_map_shop_changed()
