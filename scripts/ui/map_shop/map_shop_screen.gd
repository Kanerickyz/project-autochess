class_name MapShopScreen
extends Control
## 【遗留卡片面板】主路径已改为 RealtimeBattleController.enter_map_shop（Arena 草地+纸片单位）。
## 保留场景供对照；Run 不再挂载。旧布局为上货架下队伍（与现行上队伍下货架相反）。

signal finished

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const SEAT_ROWS := 4
const SEAT_COLS := 5
const SLOT_MIN := Vector2(128, 72)
## 与 UnitCardDisplay.SIZE_DEFAULT 对齐，并留装备行高度。
const SEAT_MIN := Vector2(118, 168)
const SEAT_CARD_SIZE := Vector2(110.0, 138.0)

var _service: MapShopService
var _deck: DeckState
var _busy: bool = false

@onready var _gold_row: HBoxContainer = %GoldRow
@onready var _gold_label: Label = %GoldLabel
@onready var _hint_label: Label = %HintLabel
@onready var _refresh_btn: Button = %RefreshButton
@onready var _leave_btn: Button = %LeaveButton
@onready var _consumable_row: HBoxContainer = %ConsumableRow
@onready var _equipment_row: HBoxContainer = %EquipmentRow
@onready var _seat_grid: GridContainer = %SeatGrid


func _ready() -> void:
	visible = false
	_ensure_ui_nodes()
	if _refresh_btn != null and not _refresh_btn.pressed.is_connected(_on_refresh_pressed):
		_refresh_btn.pressed.connect(_on_refresh_pressed)
	if _leave_btn != null and not _leave_btn.pressed.is_connected(_on_leave_pressed):
		_leave_btn.pressed.connect(_on_leave_pressed)
	if _seat_grid != null:
		_seat_grid.columns = SEAT_COLS


func open_shop(service: MapShopService, deck: DeckState) -> void:
	## SceneTree._initialize 等场景下 add_child 后 @onready 可能尚未跑完。
	if not is_node_ready():
		await ready
	_ensure_ui_nodes()
	_service = service
	_deck = deck
	_busy = false
	if _service != null and not _service.shop_changed.is_connected(_on_shop_changed):
		_service.shop_changed.connect(_on_shop_changed)
	if _deck != null and not _deck.deck_changed.is_connected(_on_deck_changed):
		_deck.deck_changed.connect(_on_deck_changed)
	visible = true
	_refresh_all()
	if _leave_btn != null:
		_leave_btn.grab_focus()


func _ensure_ui_nodes() -> void:
	if _gold_row == null:
		_gold_row = get_node_or_null("%GoldRow") as HBoxContainer
	if _gold_label == null:
		_gold_label = get_node_or_null("%GoldLabel") as Label
	if _hint_label == null:
		_hint_label = get_node_or_null("%HintLabel") as Label
	if _refresh_btn == null:
		_refresh_btn = get_node_or_null("%RefreshButton") as Button
	if _leave_btn == null:
		_leave_btn = get_node_or_null("%LeaveButton") as Button
	if _consumable_row == null:
		_consumable_row = get_node_or_null("%ConsumableRow") as HBoxContainer
	if _equipment_row == null:
		_equipment_row = get_node_or_null("%EquipmentRow") as HBoxContainer
	if _seat_grid == null:
		_seat_grid = get_node_or_null("%SeatGrid") as GridContainer
		if _seat_grid != null:
			_seat_grid.columns = SEAT_COLS


func hide_shop() -> void:
	visible = false
	if _service != null and _service.shop_changed.is_connected(_on_shop_changed):
		_service.shop_changed.disconnect(_on_shop_changed)
	if _deck != null and _deck.deck_changed.is_connected(_on_deck_changed):
		_deck.deck_changed.disconnect(_on_deck_changed)
	_service = null
	_deck = null


func _on_shop_changed() -> void:
	_refresh_all()


func _on_deck_changed() -> void:
	_refresh_gold()
	_rebuild_seats()


func _refresh_all() -> void:
	_refresh_gold()
	_rebuild_consumable_slots()
	_rebuild_equipment_slots()
	_rebuild_seats()
	if _refresh_btn != null and _service != null:
		var cost := _service.get_refresh_cost()
		_refresh_btn.text = "刷新消耗品（%d 金）" % cost
		_refresh_btn.disabled = _busy or not _service.can_refresh()


func _refresh_gold() -> void:
	var gold := _service.get_gold() if _service != null else 0
	if _gold_label != null:
		_gold_label.text = UiStatIcons.format_gold_label(gold)
	if _gold_row != null:
		UiStatIcons.ensure_gold_icon(_gold_row)


func _rebuild_consumable_slots() -> void:
	if _consumable_row == null:
		return
	_clear_children(_consumable_row)
	if _service == null:
		return
	var offers := _service.get_consumable_offers()
	for i in offers.size():
		var item: MapShopConsumableData = offers[i] as MapShopConsumableData
		_consumable_row.add_child(_make_offer_slot(i, true, item))


func _rebuild_equipment_slots() -> void:
	if _equipment_row == null:
		return
	_clear_children(_equipment_row)
	if _service == null:
		return
	var offers := _service.get_equipment_offers()
	for i in offers.size():
		var item: EquipmentData = offers[i] as EquipmentData
		_equipment_row.add_child(_make_offer_slot(i, false, item))


func _make_offer_slot(index: int, is_consumable: bool, item: Resource) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_MIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("slot_index", index)
	panel.set_meta("is_consumable", is_consumable)
	panel.set_meta("item", item)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.18, 0.22, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.48, 0.32, 0.9)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.85, 0.82, 0.72))
	var cost_l := Label.new()
	cost_l.add_theme_font_size_override("font_size", 12)
	if item == null:
		title.text = "（空）"
		detail.text = ""
		cost_l.text = ""
		panel.modulate = Color(1, 1, 1, 0.45)
	elif is_consumable:
		var c := item as MapShopConsumableData
		title.text = c.get_display_name()
		detail.text = c.get_effect_summary()
		cost_l.text = "售价 %d" % c.cost
		panel.set_drag_forwarding(_get_offer_drag_data.bind(panel), Callable(), Callable())
	else:
		var e := item as EquipmentData
		title.text = e.get_display_name()
		detail.text = "护甲抵挡 %d" % e.get_armor_block()
		cost_l.text = "售价 %d" % e.cost
		panel.set_drag_forwarding(_get_offer_drag_data.bind(panel), Callable(), Callable())
	col.add_child(title)
	col.add_child(detail)
	col.add_child(cost_l)
	## 兼容无 drag_forwarding 的点击：点选后点座位。
	panel.gui_input.connect(_on_offer_gui_input.bind(panel))
	return panel


func _get_offer_drag_data(at_position: Vector2, panel: PanelContainer) -> Variant:
	var item: Variant = panel.get_meta("item", null)
	if item == null:
		return null
	var preview := Label.new()
	if item is MapShopConsumableData:
		preview.text = (item as MapShopConsumableData).get_display_name()
	elif item is EquipmentData:
		preview.text = (item as EquipmentData).get_display_name()
	else:
		return null
	panel.set_drag_preview(preview)
	return {
		"kind": "map_shop_offer",
		"slot_index": int(panel.get_meta("slot_index", -1)),
		"is_consumable": bool(panel.get_meta("is_consumable", true)),
	}


func _on_offer_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_hint_label.text = "拖到下方角色购买（或先点货再点角色）"
			_selected_offer = panel


var _selected_offer: PanelContainer = null


func _rebuild_seats() -> void:
	if _seat_grid == null:
		return
	_clear_children(_seat_grid)
	if _deck == null:
		return
	var total := SEAT_ROWS * SEAT_COLS
	for seat_i in total:
		_seat_grid.add_child(_make_seat_cell(seat_i))


func _make_seat_cell(seat_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SEAT_MIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("seat_index", seat_index)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(0.40, 0.44, 0.50, 0.8)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var entry := _deck.get_entry_at_seat(seat_index) if _deck != null else null
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	if entry == null or entry.unit == null:
		var empty := Label.new()
		empty.text = "空座"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58))
		col.add_child(empty)
	else:
		var card_host := Control.new()
		card_host.custom_minimum_size = SEAT_CARD_SIZE
		card_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(card_host)
		var card := CARD_SCENE.instantiate() as UnitCardDisplay
		card_host.add_child(card)
		card.configure(SEAT_CARD_SIZE)
		card.bind_unit_data(
			entry.unit,
			DeckUpgradeService.get_display_attack(entry),
			DeckUpgradeService.get_display_max_hp(entry),
			DeckUpgradeService.get_display_max_hp(entry),
		)
		card.set_level(entry.get_star_display_level())
		card.set_state(false, false)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_meta("entry_id", entry.entry_id)
		panel.set_meta("unit_card", card)
		if entry.equipment != null:
			var eq_row := HBoxContainer.new()
			eq_row.alignment = BoxContainer.ALIGNMENT_CENTER
			eq_row.add_theme_constant_override("separation", 4)
			eq_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(eq_row)
			var armor_tex := UiStatIcons.armor_texture()
			if armor_tex != null:
				var icon := TextureRect.new()
				icon.texture = armor_tex
				icon.custom_minimum_size = Vector2(14, 14)
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				eq_row.add_child(icon)
			var eq := Label.new()
			eq.add_theme_font_size_override("font_size", 11)
			eq.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			eq.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
			eq.text = "%s %d" % [entry.get_equipment_display_name(), entry.get_armor_block()]
			eq.mouse_filter = Control.MOUSE_FILTER_IGNORE
			eq_row.add_child(eq)

	var drag_cb := _get_seat_drag_data.bind(panel) if entry != null and entry.unit != null else Callable()
	panel.set_drag_forwarding(drag_cb, _can_drop_on_seat.bind(panel), _drop_on_seat.bind(panel))
	panel.gui_input.connect(_on_seat_gui_input.bind(panel))
	return panel


func _get_seat_drag_data(_at_position: Vector2, panel: PanelContainer) -> Variant:
	if not panel.has_meta("entry_id"):
		return null
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(72, 72)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.18, 0.2, 0.26, 0.92)
	preview_style.set_border_width_all(2)
	preview_style.border_color = Color(0.85, 0.75, 0.4, 0.95)
	preview.add_theme_stylebox_override("panel", preview_style)
	var src_card: UnitCardDisplay = panel.get_meta("unit_card", null) as UnitCardDisplay
	if src_card != null and _deck != null:
		var entry := _deck.get_entry(int(panel.get_meta("entry_id")))
		if entry != null and entry.unit != null:
			var mini := CARD_SCENE.instantiate() as UnitCardDisplay
			preview.add_child(mini)
			mini.configure(Vector2(68, 90))
			mini.bind_unit_data(
				entry.unit,
				DeckUpgradeService.get_display_attack(entry),
				DeckUpgradeService.get_display_max_hp(entry),
				DeckUpgradeService.get_display_max_hp(entry),
			)
			mini.set_level(entry.get_star_display_level())
			mini.set_state(false, false)
			mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		var fallback := Label.new()
		fallback.text = "换座"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview.add_child(fallback)
	panel.set_drag_preview(preview)
	return {
		"kind": "map_shop_seat",
		"entry_id": int(panel.get_meta("entry_id")),
		"from_seat": int(panel.get_meta("seat_index", -1)),
	}


func _can_drop_on_seat(_at_position: Vector2, data: Variant, _panel: PanelContainer) -> bool:
	if data is Dictionary:
		var kind := String(data.get("kind", ""))
		return kind == "map_shop_offer" or kind == "map_shop_seat"
	return false


func _drop_on_seat(_at_position: Vector2, data: Variant, panel: PanelContainer) -> void:
	if _busy or _service == null or not (data is Dictionary):
		return
	var kind := String(data.get("kind", ""))
	var seat_index := int(panel.get_meta("seat_index", -1))
	if kind == "map_shop_seat":
		var entry_id := int(data.get("entry_id", -1))
		if _service.try_swap_seat(entry_id, seat_index):
			_hint_label.text = "已换座"
			_rebuild_seats()
		else:
			_hint_label.text = "换座失败"
		return
	if kind == "map_shop_offer":
		_try_buy_on_seat(
			int(data.get("slot_index", -1)),
			bool(data.get("is_consumable", true)),
			seat_index,
		)


func _on_seat_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _selected_offer == null:
		return
	var seat_index := int(panel.get_meta("seat_index", -1))
	_try_buy_on_seat(
		int(_selected_offer.get_meta("slot_index", -1)),
		bool(_selected_offer.get_meta("is_consumable", true)),
		seat_index,
	)
	_selected_offer = null


func _try_buy_on_seat(slot_index: int, is_consumable: bool, seat_index: int) -> void:
	if _busy or _service == null or _deck == null:
		return
	var entry := _deck.get_entry_at_seat(seat_index)
	if entry == null:
		_hint_label.text = "请拖到有角色的座位"
		return
	_busy = true
	var result: Dictionary
	if is_consumable:
		result = _service.try_buy_consumable_on_entry(slot_index, entry.entry_id)
	else:
		result = _service.try_buy_equipment_on_entry(slot_index, entry.entry_id)
	_busy = false
	if int(result.get("result", MapShopService.BuyResult.FAILED)) != MapShopService.BuyResult.OK:
		var reason := String(result.get("reason", "failed"))
		if reason == "cant_afford":
			_hint_label.text = "金币不足"
		else:
			_hint_label.text = "购买失败"
		_refresh_all()
		return
	if is_consumable and bool(result.get("destroyed", false)):
		_hint_label.text = "生命归零，角色已销毁"
	elif is_consumable:
		_hint_label.text = "已使用消耗品"
	elif bool(result.get("kept_new", true)):
		_hint_label.text = "已装备"
	else:
		_hint_label.text = "装备冲突：保留了旧装备（不退金）"
	_refresh_all()


func _on_refresh_pressed() -> void:
	if _busy or _service == null:
		return
	_busy = true
	var result := _service.try_refresh_consumables()
	_busy = false
	if int(result.get("result", MapShopService.BuyResult.FAILED)) != MapShopService.BuyResult.OK:
		_hint_label.text = "金币不足，无法刷新"
	else:
		_hint_label.text = "已刷新消耗品"
	_refresh_all()


func _on_leave_pressed() -> void:
	if _busy:
		return
	finished.emit()


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
