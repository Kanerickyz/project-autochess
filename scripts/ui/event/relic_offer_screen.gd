class_name RelicOfferScreen
extends Control

## 远征圣物事件三选一：选一件 / 跳过；满囊或自愿换下时指定旧槽。

signal finished(took: bool)

@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel
@onready var _offers: VBoxContainer = %OffersContainer
@onready var _bag_box: VBoxContainer = %BagContainer
@onready var _bag_label: Label = %BagLabel
@onready var _skip_button: Button = %SkipButton
@onready var _take_button: Button = %TakeButton
@onready var _swap_button: Button = %SwapButton
@onready var _swap_hint: Label = %SwapHintLabel

var _bag: ExpeditionRelicBag
var _candidates: Array[ExpeditionRelicData] = []
var _selected_offer: int = -1
var _awaiting_swap: bool = false


func _ready() -> void:
	visible = false
	if _skip_button != null and not _skip_button.pressed.is_connected(_on_skip):
		_skip_button.pressed.connect(_on_skip)
	if _take_button != null and not _take_button.pressed.is_connected(_on_take_direct):
		_take_button.pressed.connect(_on_take_direct)
	if _swap_button != null and not _swap_button.pressed.is_connected(_on_swap_mode):
		_swap_button.pressed.connect(_on_swap_mode)


func show_offers(candidates: Array[ExpeditionRelicData], bag: ExpeditionRelicBag) -> void:
	_candidates = candidates.duplicate()
	_bag = bag
	_selected_offer = -1
	_awaiting_swap = false
	visible = true
	_title.text = "远征圣物"
	_body.text = "选择一件放入行囊，或跳过。换下旧件不获得金币。"
	_rebuild_all()
	if _skip_button != null:
		_skip_button.grab_focus()


func hide_offers() -> void:
	visible = false
	_candidates.clear()
	_bag = null
	_selected_offer = -1
	_awaiting_swap = false


func _rebuild_all() -> void:
	_rebuild_offers()
	_rebuild_bag()
	_refresh_actions()


func _rebuild_offers() -> void:
	for child in _offers.get_children():
		child.queue_free()
	if _candidates.is_empty():
		var empty := Label.new()
		empty.text = "本节点暂无圣物可选。"
		_offers.add_child(empty)
		return
	for i in _candidates.size():
		var relic := _candidates[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(440, 64)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var mark := "▶ " if i == _selected_offer else ""
		btn.text = mark + _format_offer(relic)
		btn.pressed.connect(_on_offer_pressed.bind(i))
		_offers.add_child(btn)


func _rebuild_bag() -> void:
	for child in _bag_box.get_children():
		child.queue_free()
	var count := _bag.get_count() if _bag != null else 0
	_bag_label.text = "行囊 %d/%d" % [count, ExpeditionRelicBag.CAPACITY]
	if _bag == null or count <= 0:
		var empty := Label.new()
		empty.text = "（空）"
		_bag_box.add_child(empty)
		return
	var can_replace := _can_pick_replace_slot()
	for i in count:
		var relic := _bag.get_at(i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(440, 40)
		var name := relic.display_name if relic != null else "？"
		btn.text = "换下 [%d] %s" % [i + 1, name]
		btn.disabled = not can_replace
		btn.pressed.connect(_on_bag_slot_pressed.bind(i))
		_bag_box.add_child(btn)


func _can_pick_replace_slot() -> bool:
	if _selected_offer < 0 or _bag == null or _bag.get_count() <= 0:
		return false
	if _bag.is_full():
		return true
	return _awaiting_swap


func _format_offer(relic: ExpeditionRelicData) -> String:
	if relic == null:
		return "（空）"
	var tier := clampi(relic.tier, 1, 3)
	var desc := relic.description.strip_edges() if relic.description != null else ""
	if desc.is_empty():
		return "T%d · %s" % [tier, relic.display_name]
	return "T%d · %s — %s" % [tier, relic.display_name, desc]


func _refresh_actions() -> void:
	var has_pick := _selected_offer >= 0 and _selected_offer < _candidates.size()
	var full := _bag != null and _bag.is_full()
	var has_bag := _bag != null and _bag.get_count() > 0
	if _take_button != null:
		_take_button.visible = has_pick and not full
		_take_button.disabled = not has_pick or full
	if _swap_button != null:
		_swap_button.visible = has_pick and not full and has_bag
		_swap_button.disabled = not has_pick or full or not has_bag
		_swap_button.text = "换下旧件…" if not _awaiting_swap else "选择下方旧件"
	if _swap_hint != null:
		if not has_pick:
			_swap_hint.text = "点选上方候选，或跳过。"
		elif full:
			_swap_hint.text = "行囊已满：必须点下方旧件换下（无金）。"
			_awaiting_swap = true
		elif _awaiting_swap:
			_swap_hint.text = "点下方旧件换下（无金）。"
		else:
			_swap_hint.text = "可「直接放入」，或「换下旧件」。"


func _on_offer_pressed(index: int) -> void:
	_selected_offer = index
	if _bag != null and _bag.is_full():
		_awaiting_swap = true
	else:
		_awaiting_swap = false
	_rebuild_all()


func _on_bag_slot_pressed(index: int) -> void:
	if not _can_pick_replace_slot():
		return
	if _selected_offer < 0 or _bag == null:
		return
	var relic := _candidates[_selected_offer]
	if _bag.try_take(relic, index):
		_complete(true)


func _on_take_direct() -> void:
	if _selected_offer < 0 or _bag == null:
		return
	if _bag.is_full():
		_awaiting_swap = true
		_rebuild_all()
		return
	var relic := _candidates[_selected_offer]
	if _bag.try_take(relic, -1):
		_complete(true)


func _on_swap_mode() -> void:
	if _selected_offer < 0:
		return
	_awaiting_swap = true
	_rebuild_all()


func _on_skip() -> void:
	_complete(false)


func _complete(took: bool) -> void:
	hide_offers()
	finished.emit(took)
