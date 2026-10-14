class_name ShopSlot
extends PanelContainer

signal buy_pressed
signal offer_hovered(offer: ShopOffer)
signal offer_unhovered

const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")

@onready var _type_label: Label = %TypeLabel
@onready var _name_label: Label = %NameLabel
@onready var _cost_label: Label = %CostLabel
@onready var _buy_button: Button = %BuyButton
@onready var _text_stack: VBoxContainer = %TextStack
@onready var _card_host: Control = %CardHost

var _card: UnitCardDisplay
var _offer: ShopOffer
var _show_type_label: bool = true


func _ready() -> void:
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit())
	_apply_type_label_visibility()
	_ensure_card()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_show_type_label(show_label: bool) -> void:
	_show_type_label = show_label
	if is_node_ready():
		_apply_type_label_visibility()


func _apply_type_label_visibility() -> void:
	if _type_label:
		_type_label.visible = _show_type_label


func set_interactive(enabled: bool) -> void:
	_buy_button.disabled = not enabled or _offer == null


func set_offer(offer: ShopOffer, gold: int) -> void:
	_offer = offer
	_ensure_card()

	if offer == null:
		_type_label.text = ""
		_name_label.text = "—"
		_cost_label.text = ""
		_buy_button.disabled = true
		if _card != null:
			_card.visible = false
		if _text_stack != null:
			_text_stack.visible = true
		return

	_cost_label.text = "%d 金" % offer.get_cost()
	_buy_button.disabled = gold < offer.get_cost()

	if offer.type == ShopOffer.OfferType.CHARACTER and offer.unit != null:
		if _text_stack != null:
			_text_stack.visible = false
		if _card != null:
			_card.visible = true
			var stats := offer.unit.stats
			var atk := stats.attack if stats != null else 0
			var max_hp := stats.max_hp if stats != null else 0
			max_hp += offer.shop_bonus_max_hp
			_card.bind_unit_data(offer.unit, atk, max_hp, max_hp)
			_card.set_level(1)
			_card.set_state(false, false)
	else:
		if _card != null:
			_card.visible = false
		if _text_stack != null:
			_text_stack.visible = true
		_type_label.text = "[%s]" % offer.get_type_label()
		_name_label.text = offer.get_display_name()


func _ensure_card() -> void:
	if _card != null or _card_host == null:
		return
	_card = CARD_SCENE.instantiate() as UnitCardDisplay
	_card_host.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.configure(UnitCardDisplay.SIZE_SHOP)
	_card.visible = false


func _on_mouse_entered() -> void:
	if _offer == null:
		return
	offer_hovered.emit(_offer)


func _on_mouse_exited() -> void:
	offer_unhovered.emit()
