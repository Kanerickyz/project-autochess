class_name ShopPhaseScreen
extends Control

@onready var shop_panel: ShopPanel = %ShopPanel
@onready var finish_button: Button = %FinishShopButton
@onready var _shop_content: VBoxContainer = $CenterContainer/ShopContent
@onready var _title: Control = %Title

var transition_active: bool = false

var _transition_tween: Tween
var _anim_items: Array[Control] = []


func _ready() -> void:
	_anim_items = [_title, shop_panel, finish_button]


func show_instant() -> void:
	_kill_transition_tween()
	transition_active = false
	visible = true
	_reset_items_shown()


func play_show() -> void:
	_kill_transition_tween()
	transition_active = true
	visible = true
	await get_tree().process_frame
	_prepare_items_hidden()
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	var base_delay := CombatAnimationConfig.SHOP_UI_REVEAL_DELAY
	var jitter_max := CombatAnimationConfig.SHOP_UI_REVEAL_JITTER
	var ordered := _anim_items.duplicate()
	ordered.shuffle()
	for item in ordered:
		var delay := base_delay + randf() * jitter_max
		_append_item_reveal_tween(_transition_tween, item, delay)
	await _transition_tween.finished
	_transition_tween = null
	transition_active = false


func play_hide() -> void:
	if not visible:
		return
	_kill_transition_tween()
	transition_active = true
	await get_tree().process_frame
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	var base_delay := CombatAnimationConfig.SHOP_UI_REVEAL_DELAY
	var jitter_max := CombatAnimationConfig.SHOP_UI_REVEAL_JITTER
	var ordered := _anim_items.duplicate()
	ordered.shuffle()
	for item in ordered:
		var delay := base_delay + randf() * jitter_max
		_append_item_hide_tween(_transition_tween, item, delay)
	await _transition_tween.finished
	visible = false
	_reset_items_shown()
	_transition_tween = null
	transition_active = false


func _kill_transition_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null


func _prepare_items_hidden() -> void:
	var start_scale := CombatAnimationConfig.SHOP_UI_REVEAL_SCALE
	for item in _anim_items:
		item.modulate.a = 0.0
		item.scale = Vector2.ONE * start_scale
		item.pivot_offset = item.size * 0.5


func _reset_items_shown() -> void:
	for item in _anim_items:
		item.modulate = Color.WHITE
		item.scale = Vector2.ONE
		item.pivot_offset = Vector2.ZERO


func _append_item_reveal_tween(master: Tween, item: Control, delay: float) -> void:
	var duration := CombatAnimationConfig.SHOP_UI_RISE_DUR
	var alpha_ratio := CombatAnimationConfig.SHOP_UI_ALPHA_FADE_RATIO
	master.tween_property(item, "scale", Vector2.ONE, duration)\
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	master.tween_property(item, "modulate:a", 1.0, duration * alpha_ratio)\
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _append_item_hide_tween(master: Tween, item: Control, delay: float) -> void:
	var end_scale := CombatAnimationConfig.SHOP_UI_REVEAL_SCALE
	var duration := CombatAnimationConfig.SHOP_UI_RISE_DUR
	var alpha_ratio := CombatAnimationConfig.SHOP_UI_ALPHA_FADE_RATIO
	master.tween_property(item, "scale", Vector2.ONE * end_scale, duration)\
		.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	master.tween_property(item, "modulate:a", 0.0, duration * alpha_ratio)\
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
