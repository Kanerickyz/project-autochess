class_name HandPanel
extends Control

enum Mode {
	DEPLOY,
	SELL,
}

signal entry_pressed(entry_id: int)
signal entry_sell_pressed(entry_id: int)
signal entry_hovered(entry: DeckEntry)
signal entry_unhovered
signal entry_drag_started(entry_id: int, viewport_pos: Vector2)

const SLOT_SCENE := preload("res://scenes/ui/hand_slot.tscn")

@onready var _title: Label = %Title
@onready var _population_label: Label = %PopulationLabel
@onready var _slots_row: HBoxContainer = %SlotsRow
@onready var _scroll: ScrollContainer = %Scroll
@onready var _start_button_host: Control = %StartButtonHost

var _slot_widgets: Array[HandSlot] = []
var _entry_ids: Array[int] = []
var _mode: Mode = Mode.DEPLOY
var _deploy_title: String = "手牌 · 拖到己方半场"
var _home_offset_top: float
var _home_offset_bottom: float
var _home_offsets_ready: bool = false
var _shop_tween: Tween


func _ready() -> void:
	_store_home_offsets()


func _store_home_offsets() -> void:
	if _home_offsets_ready:
		return
	_home_offset_top = offset_top
	_home_offset_bottom = offset_bottom
	_home_offsets_ready = true


func get_withdraw_drop_rect() -> Rect2:
	if _scroll != null and is_instance_valid(_scroll):
		return _scroll.get_global_rect().grow(8.0)
	return get_global_rect().grow(8.0)


func get_start_button_host() -> Control:
	return _start_button_host


func set_title(text: String) -> void:
	_deploy_title = text
	if _mode == Mode.DEPLOY and _title != null:
		_title.text = text


func set_population(current: int, maximum: int) -> void:
	if _population_label == null:
		return
	_population_label.visible = _mode == Mode.DEPLOY
	_population_label.text = "人口 %d/%d" % [current, maximum]


func set_mode(mode: Mode) -> void:
	_mode = mode
	if _title == null:
		return
	if mode == Mode.SELL:
		_title.text = "牌库 — 点击「出售」换金"
		if _population_label != null:
			_population_label.visible = false
		if _start_button_host != null:
			_start_button_host.visible = false
	else:
		_title.text = _deploy_title
		if _population_label != null:
			_population_label.visible = true
		if _start_button_host != null:
			_start_button_host.visible = true


func set_start_button_host_visible(visible_flag: bool) -> void:
	if _start_button_host != null:
		_start_button_host.visible = visible_flag and _mode == Mode.DEPLOY


func set_scroll_interactive(enabled: bool) -> void:
	if _scroll == null:
		return
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func show_shop_instant() -> void:
	_store_home_offsets()
	_kill_shop_tween()
	modulate.a = 1.0
	if _home_offsets_ready:
		offset_top = _home_offset_top
		offset_bottom = _home_offset_bottom


func play_shop_reveal() -> void:
	_store_home_offsets()
	_kill_shop_tween()
	if not _home_offsets_ready:
		modulate.a = 1.0
		return
	var rise := CombatAnimationConfig.SHOP_HAND_RISE_OFFSET
	var duration := CombatAnimationConfig.SHOP_HAND_RISE_DUR
	var alpha_ratio := CombatAnimationConfig.SHOP_HAND_ALPHA_FADE_RATIO
	modulate.a = 0.0
	offset_top = _home_offset_top + rise
	offset_bottom = _home_offset_bottom + rise
	_shop_tween = create_tween()
	_shop_tween.set_parallel(true)
	_shop_tween.tween_property(self, "modulate:a", 1.0, duration * alpha_ratio)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shop_tween.tween_property(self, "offset_top", _home_offset_top, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shop_tween.tween_property(self, "offset_bottom", _home_offset_bottom, duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill_shop_tween() -> void:
	if _shop_tween != null and _shop_tween.is_valid():
		_shop_tween.kill()
	_shop_tween = null


func _rebuild_slots(entries: Array[DeckEntry]) -> void:
	for child in _slots_row.get_children():
		child.queue_free()
	_slot_widgets.clear()
	_entry_ids.clear()

	for entry in entries:
		if entry == null:
			continue
		var slot: HandSlot = SLOT_SCENE.instantiate()
		_slots_row.add_child(slot)
		var entry_id := entry.entry_id
		slot.pressed.connect(func() -> void: entry_pressed.emit(entry_id))
		slot.sell_pressed.connect(func() -> void: entry_sell_pressed.emit(entry_id))
		slot.entry_hovered.connect(_on_slot_entry_hovered)
		slot.entry_unhovered.connect(_on_slot_entry_unhovered)
		slot.entry_drag_started.connect(_on_slot_entry_drag_started)
		_slot_widgets.append(slot)
		_entry_ids.append(entry_id)


func set_interactive(enabled: bool) -> void:
	for slot in _slot_widgets:
		slot.set_interactive(enabled)


func refresh_deck(
	deck: DeckState,
	deployed_ids: Dictionary,
	selected_entry_id: int,
	get_sell_price: Callable = Callable(),
) -> void:
	if deck == null:
		_rebuild_slots([])
		return
	_apply_entries(
		deck.get_entries(),
		deck,
		deployed_ids,
		selected_entry_id,
		get_sell_price,
	)


func refresh_entries(
	entries: Array[DeckEntry],
	deck: DeckState,
	deployed_ids: Dictionary,
	selected_entry_id: int,
	get_sell_price: Callable = Callable(),
) -> void:
	_apply_entries(entries, deck, deployed_ids, selected_entry_id, get_sell_price)


func _apply_entries(
	entries: Array[DeckEntry],
	deck: DeckState,
	deployed_ids: Dictionary,
	selected_entry_id: int,
	get_sell_price: Callable,
) -> void:
	if entries.size() != _entry_ids.size():
		_rebuild_slots(entries)
	elif not _entries_match(entries):
		_rebuild_slots(entries)

	for i in _slot_widgets.size():
		var entry_id := _entry_ids[i]
		var entry: DeckEntry = null
		if deck != null:
			entry = deck.get_entry(entry_id)
		if entry == null and i < entries.size():
			entry = entries[i]
		var deployed := deployed_ids.has(entry_id)
		var selected := entry_id == selected_entry_id and not deployed
		_slot_widgets[i].set_entry(
			entry,
			selected,
			deployed,
			deck.get_level_config() if deck != null else null,
		)

		if _mode == Mode.SELL and entry != null and entry.unit != null:
			var price := 0
			if get_sell_price.is_valid():
				price = int(get_sell_price.call(entry))
			_slot_widgets[i].set_sell_mode(true, price)
		else:
			_slot_widgets[i].set_sell_mode(false, 0)


func _entries_match(entries: Array[DeckEntry]) -> bool:
	if entries.size() != _entry_ids.size():
		return false
	for i in entries.size():
		if entries[i] == null or entries[i].entry_id != _entry_ids[i]:
			return false
	return true


func _on_slot_entry_hovered(entry: DeckEntry) -> void:
	entry_hovered.emit(entry)


func _on_slot_entry_unhovered() -> void:
	entry_unhovered.emit()


func _on_slot_entry_drag_started(entry_id: int, viewport_pos: Vector2) -> void:
	entry_drag_started.emit(entry_id, viewport_pos)
