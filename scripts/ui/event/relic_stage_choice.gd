class_name RelicStageChoice
extends RefCounted
## 远征圣物三选一：选项画在 Arena 上半场；跳过/拿取/换下挂在战斗 Dock。
## 取代全屏 RelicOfferScreen 主路径。

signal finished(took: bool)

var _battle: RealtimeBattleController
var _bag: ExpeditionRelicBag
var _candidates: Array[ExpeditionRelicData] = []
var _selected: int = -1
var _awaiting_swap: bool = false
var _active: bool = false
var _hud: VBoxContainer
var _hint: Label
var _skip_btn: Button
var _take_btn: Button
var _swap_btn: Button
var _bag_box: VBoxContainer


func bind_battle(battle: RealtimeBattleController) -> void:
	if _battle == battle:
		return
	if _battle != null and _battle.stage_choice_picked.is_connected(_on_stage_picked):
		_battle.stage_choice_picked.disconnect(_on_stage_picked)
	_battle = battle
	if _battle != null and not _battle.stage_choice_picked.is_connected(_on_stage_picked):
		_battle.stage_choice_picked.connect(_on_stage_picked)


func show_offers(candidates: Array[ExpeditionRelicData], bag: ExpeditionRelicBag) -> void:
	_candidates = candidates.duplicate()
	_bag = bag
	_selected = -1
	_awaiting_swap = false
	_active = true
	if _battle == null:
		push_error("RelicStageChoice: battle not bound")
		_complete(false)
		return
	_ensure_hud()
	_refresh_cards()
	_refresh_hud()
	_battle.enter_stage_choice("远征圣物", _build_choice_dicts(), 0.0)


func hide_offers() -> void:
	_active = false
	_hide_hud()
	if _battle != null and _battle.get_phase() == RealtimeBattleController.Phase.STAGE_CHOICE:
		_battle.exit_stage_choice()


func _build_choice_dicts() -> Array:
	var out: Array = []
	for i in _candidates.size():
		var relic := _candidates[i]
		var selected := i == _selected
		var card := ExpeditionRelicInfo.stage_choice_dict(relic, i, selected)
		## 三选一额外提示：与徽章/信息卡正文共用 ExpeditionRelicInfo.detail_text。
		var detail := String(card.get("detail", ""))
		if not detail.is_empty():
			detail += "\n\n点选后可放入行囊；行囊满时可换下旧件。长按本卡查看说明，松手不代表确认拿取。"
		card["detail"] = detail
		out.append(card)
	return out


func _refresh_cards() -> void:
	if _battle == null:
		return
	_battle.refresh_stage_choice_cards(_build_choice_dicts(), "远征圣物")


func _on_stage_picked(choice_id: StringName, index: int) -> void:
	if not _active:
		return
	if not String(choice_id).begins_with("relic_"):
		return
	_selected = index
	if _bag != null and _bag.is_full():
		_awaiting_swap = true
	else:
		_awaiting_swap = false
	_refresh_cards()
	_refresh_hud()


func _ensure_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
		return
	if _battle == null:
		return
	var dock := _battle.get_dock()
	if dock == null:
		return
	var host: Node = _battle.get_phase_dock_host()
	_hud = VBoxContainer.new()
	_hud.name = "RelicStageHud"
	_hud.add_theme_constant_override("separation", 6)
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if host != null:
		host.add_child(_hud)
	else:
		dock.add_child(_hud)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.clip_text = true
	_hud.add_child(_hint)
	var bag_scroll := ScrollContainer.new()
	bag_scroll.name = "RelicBagScroll"
	bag_scroll.custom_minimum_size = Vector2(0, 56)
	bag_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hud.add_child(bag_scroll)
	_bag_box = VBoxContainer.new()
	_bag_box.add_theme_constant_override("separation", 4)
	_bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_scroll.add_child(_bag_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_hud.add_child(row)
	_skip_btn = UiKit.make_secondary_button("跳过")
	_skip_btn.pressed.connect(_on_skip)
	row.add_child(_skip_btn)
	_take_btn = UiKit.make_primary_button("放入行囊")
	_take_btn.pressed.connect(_on_take)
	row.add_child(_take_btn)
	_swap_btn = UiKit.make_secondary_button("换下旧件")
	_swap_btn.pressed.connect(_on_swap_mode)
	row.add_child(_swap_btn)


func _hide_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false


func _refresh_hud() -> void:
	_ensure_hud()
	if _hint == null:
		return
	var has_pick := _selected >= 0 and _selected < _candidates.size()
	var full := _bag != null and _bag.is_full()
	var has_bag := _bag != null and _bag.get_count() > 0
	if not has_pick:
		_hint.text = "点选上半场圣物卡片，或跳过。"
	elif full:
		_hint.text = "行囊已满：点下方旧件换下（无金）。"
		_awaiting_swap = true
	elif _awaiting_swap:
		_hint.text = "点下方旧件换下（无金）。"
	else:
		_hint.text = "可「放入行囊」，或「换下旧件」。"
	if _take_btn != null:
		_take_btn.visible = has_pick and not full
		_take_btn.disabled = not has_pick or full
	if _swap_btn != null:
		_swap_btn.visible = has_pick and not full and has_bag
		_swap_btn.disabled = not has_pick or full or not has_bag
		_swap_btn.text = "换下旧件…" if not _awaiting_swap else "选择下方旧件"
	_rebuild_bag_row()


func _rebuild_bag_row() -> void:
	if _bag_box == null:
		return
	for child in _bag_box.get_children():
		child.queue_free()
	var count := _bag.get_count() if _bag != null else 0
	var cap := ExpeditionRelicBag.CAPACITY
	var title := Label.new()
	title.text = "行囊 %d/%d" % [count, cap]
	_bag_box.add_child(title)
	if _bag == null or count <= 0:
		return
	var can_replace := _can_pick_replace()
	for i in count:
		var relic := _bag.get_at(i)
		var btn := UiKit.make_secondary_button(
			"换下 [%d] %s" % [i + 1, relic.display_name if relic != null else "？"]
		)
		btn.disabled = not can_replace
		btn.pressed.connect(_on_bag_slot.bind(i))
		_bag_box.add_child(btn)


func _can_pick_replace() -> bool:
	if _selected < 0 or _bag == null or _bag.get_count() <= 0:
		return false
	if _bag.is_full():
		return true
	return _awaiting_swap


func _on_take() -> void:
	if not _active or _selected < 0 or _bag == null:
		return
	if _bag.is_full():
		_awaiting_swap = true
		_refresh_hud()
		return
	var relic := _candidates[_selected]
	if _bag.try_take(relic, -1):
		_complete(true)


func _on_swap_mode() -> void:
	if _selected < 0:
		return
	_awaiting_swap = true
	_refresh_hud()


func _on_bag_slot(index: int) -> void:
	if not _can_pick_replace():
		return
	if _selected < 0 or _bag == null:
		return
	var relic := _candidates[_selected]
	if _bag.try_take(relic, index):
		_complete(true)


func _on_skip() -> void:
	_complete(false)


func _complete(took: bool) -> void:
	hide_offers()
	finished.emit(took)
