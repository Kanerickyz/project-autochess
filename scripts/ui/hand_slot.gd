class_name HandSlot
extends Button

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const DRAG_THRESHOLD := 8.0

signal entry_hovered(entry: DeckEntry)
signal entry_unhovered
signal sell_pressed
signal entry_drag_started(entry_id: int, viewport_pos: Vector2)

@onready var _card_host: Control = %CardHost
@onready var _sell_button: Button = %SellButton
@onready var _status_badge: Label = %StatusBadge

var _card: UnitCardDisplay
var _interactive: bool = true
var _sell_mode: bool = false
var _selected: bool = false
var _deployed: bool = false
var _entry_id: int = -1
var _entry: DeckEntry
var _press_viewport_pos: Vector2 = Vector2.ZERO
var _drag_started: bool = false
var _suppress_press: bool = false


func _ready() -> void:
	_ensure_card()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_sell_button.pressed.connect(_on_sell_button_pressed)


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	_apply_interactive_state()


func set_sell_mode(enabled: bool, sell_price: int) -> void:
	_sell_mode = enabled
	if _sell_button != null:
		_sell_button.visible = enabled
		if enabled:
			_sell_button.text = "出售 (%d)" % sell_price
			_sell_button.disabled = not _interactive
	_apply_interactive_state()
	_update_status_badge()


func set_entry(
	entry: DeckEntry,
	selected: bool,
	deployed: bool,
	level_config: LevelConfig = null,
) -> void:
	_entry = entry
	_entry_id = entry.entry_id if entry != null else -1
	_selected = selected
	_deployed = deployed
	_ensure_card()

	if entry == null or entry.unit == null:
		text = "空"
		if _card != null:
			_card.visible = false
		disabled = true
		modulate = Color(0.6, 0.6, 0.6)
		if _sell_button != null:
			_sell_button.disabled = true
		_update_status_badge()
		return

	text = ""
	_card.visible = true
	_card.bind_deck_entry(entry, level_config)
	_card.set_state(_selected, _deployed)
	_apply_interactive_state()
	_update_status_badge()


func get_entry_id() -> int:
	return _entry_id


func get_entry() -> DeckEntry:
	return _entry


func _gui_input(event: InputEvent) -> void:
	if not _interactive or _sell_mode or _deployed or _entry == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_viewport_pos = mb.position
			_drag_started = false
		else:
			if _drag_started:
				accept_event()
				_drag_started = false
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if _drag_started:
			accept_event()
			return
		if motion.position.distance_to(_press_viewport_pos) >= DRAG_THRESHOLD:
			_drag_started = true
			_suppress_press = true
			entry_drag_started.emit(_entry_id, get_viewport().get_mouse_position())
			accept_event()


func _pressed() -> void:
	if _suppress_press:
		_suppress_press = false
		return
	pressed.emit()


func _apply_interactive_state() -> void:
	if _entry == null or _entry.unit == null:
		return

	if _sell_mode:
		disabled = true
		if _sell_button != null:
			_sell_button.disabled = not _interactive
		return

	if _sell_button != null:
		_sell_button.disabled = true

	if _deployed:
		disabled = true
	else:
		disabled = not _interactive


func _update_status_badge() -> void:
	if _status_badge == null:
		return
	if _sell_mode or _entry == null or _entry.unit == null:
		_status_badge.visible = false
		return
	if _deployed:
		_status_badge.visible = true
		_status_badge.text = "在场"
	elif _selected:
		_status_badge.visible = true
		_status_badge.text = "选中"
	else:
		_status_badge.visible = false


func _ensure_card() -> void:
	if _card != null or _card_host == null:
		return
	_card = CARD_SCENE.instantiate() as UnitCardDisplay
	_card_host.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.configure(UnitCardDisplay.SIZE_DEFAULT)


func _on_mouse_entered() -> void:
	if _entry != null and _entry.unit != null:
		entry_hovered.emit(_entry)


func _on_mouse_exited() -> void:
	entry_unhovered.emit()


func _on_sell_button_pressed() -> void:
	sell_pressed.emit()
