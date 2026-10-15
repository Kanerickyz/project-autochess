class_name RecruitScreen
extends Control
## 【遗留卡片面板】主路径已改为 RealtimeBattleController.enter_recruit（Arena 草地+单位体）。
## 本场景可留作对照/废弃；Run 不再实例化。上区队伍、下区三人卡片与拼屏动画。

signal finished(kept_changes: bool)

const CANDIDATE_CARD_SCENE := preload("res://scenes/ui/recruit/recruit_candidate_card.tscn")
const TEAM_CARD_SCENE := preload("res://scenes/ui/recruit/recruit_team_card.tscn")
const UNIT_CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")

@onready var _team_panel: Control = %TeamPanel
@onready var _recruit_panel: Control = %RecruitPanel
@onready var _title_label: Label = %TitleLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _seat_label: Label = %SeatLabel
@onready var _hint_label: Label = %HintLabel
@onready var _team_row: HBoxContainer = %TeamRow
@onready var _candidate_row: HBoxContainer = %CandidateRow
@onready var _refresh_button: Button = %RefreshButton
@onready var _reset_button: Button = %ResetButton
@onready var _skip_button: Button = %SkipButton
@onready var _finish_button: Button = %FinishButton
@onready var _ghost_layer: Control = %GhostLayer
@onready var _team_drop_zone: Control = %TeamDropZone

var _session: RecruitSession
var _enter_seconds: float = RecruitConfig.DEFAULT_ENTER_SECONDS
var _selected_candidate: int = -1
var _selected_replace_id: int = -1
var _drag_candidate: int = -1
var _ghost: UnitCardDisplay
var _team_cards: Array[RecruitTeamCard] = []
var _candidate_cards: Array[RecruitCandidateCard] = []
var _animating: bool = false


func _ready() -> void:
	visible = false
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_finish_button.pressed.connect(_on_finish_pressed)
	_ensure_ghost()


func _input(event: InputEvent) -> void:
	if not visible or _drag_candidate < 0:
		return
	if event is InputEventMouseMotion:
		_update_ghost((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_finish_drag(mb.position)


func show_recruit(session: RecruitSession, enter_seconds: float = -1.0) -> void:
	_session = session
	if enter_seconds >= 0.0:
		_enter_seconds = enter_seconds
	elif session != null and session.config != null:
		_enter_seconds = session.config.panel_enter_seconds
	_selected_candidate = -1
	_selected_replace_id = -1
	_cancel_drag()
	if _session != null and not _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.connect(_on_session_changed)
	visible = true
	_refresh_view()
	await _play_enter_animation()


func hide_recruit() -> void:
	_cancel_drag()
	if _session != null and _session.session_changed.is_connected(_on_session_changed):
		_session.session_changed.disconnect(_on_session_changed)
	_session = null
	visible = false


func _on_session_changed() -> void:
	_refresh_view()


func _refresh_view() -> void:
	if _session == null:
		return
	_title_label.text = "招募"
	var gold := _session.economy.gold if _session.economy != null else 0
	_gold_label.text = "金币 %d" % gold
	var seats := _session.deck.size() if _session.deck != null else 0
	var cap := _session.get_seat_cap()
	_seat_label.text = "席位 %d/%d" % [seats, cap]
	_refresh_button.disabled = not _session.can_refresh() or _animating
	_refresh_button.text = "刷新（%d 金）" % _session.get_refresh_cost()
	if _session.needs_replace():
		_hint_label.text = "队伍已满：将候选人拖到要替换的成员上（旧人不退金）"
	else:
		_hint_label.text = "将下区候选人拖到上区队伍，或点选后确认加入"
	_rebuild_team()
	_rebuild_candidates()


func _rebuild_team() -> void:
	for card in _team_cards:
		if is_instance_valid(card):
			card.queue_free()
	_team_cards.clear()
	if _session == null or _session.deck == null:
		return
	for entry in _session.deck.get_entries():
		if entry == null:
			continue
		var card: RecruitTeamCard = TEAM_CARD_SCENE.instantiate()
		_team_row.add_child(card)
		card.setup(entry, entry.entry_id == _selected_replace_id)
		card.selected.connect(_on_team_selected)
		_team_cards.append(card)


func _rebuild_candidates() -> void:
	for card in _candidate_cards:
		if is_instance_valid(card):
			card.queue_free()
	_candidate_cards.clear()
	if _session == null:
		return
	var list := _session.get_candidates()
	for i in list.size():
		var unit: UnitData = list[i]
		var card: RecruitCandidateCard = CANDIDATE_CARD_SCENE.instantiate()
		_candidate_row.add_child(card)
		if unit == null:
			card.setup(i, null, 0, false)
		else:
			var cost := _session.get_recruit_cost(unit)
			card.setup(i, unit, cost, _session.can_afford_recruit(i))
		card.drag_started.connect(_on_candidate_drag_started)
		card.pressed.connect(_on_candidate_pressed)
		_candidate_cards.append(card)


func _on_candidate_pressed(index: int) -> void:
	if _animating or _session == null:
		return
	_selected_candidate = index
	if not _session.needs_replace():
		_try_recruit(index, -1)
		return
	if _selected_replace_id >= 0:
		_try_recruit(index, _selected_replace_id)
	else:
		_hint_label.text = "请先点选上区要替换的成员，或把候选人拖到成员上"


func _on_team_selected(entry_id: int) -> void:
	if _animating or _session == null:
		return
	_selected_replace_id = entry_id
	for card in _team_cards:
		card.set_selected(card.entry_id == entry_id)
	if _selected_candidate >= 0 and _session.needs_replace():
		_try_recruit(_selected_candidate, entry_id)


func _on_candidate_drag_started(index: int, viewport_pos: Vector2) -> void:
	if _animating or _session == null:
		return
	if _session.get_candidate(index) == null:
		return
	_drag_candidate = index
	_selected_candidate = index
	_ensure_ghost()
	if _ghost != null:
		_ghost.visible = true
		_ghost.bind_unit_data(_session.get_candidate(index))
		_update_ghost(viewport_pos)


func _finish_drag(viewport_pos: Vector2) -> void:
	var index := _drag_candidate
	_cancel_drag()
	if index < 0 or _session == null:
		return
	var replace_id := _find_team_entry_at(viewport_pos)
	if _session.needs_replace():
		if replace_id < 0:
			_hint_label.text = "满员时请拖到要替换的成员上"
			return
		_try_recruit(index, replace_id)
		return
	if _is_over_team_zone(viewport_pos) or replace_id >= 0:
		_try_recruit(index, -1)


func _try_recruit(candidate_index: int, replace_entry_id: int) -> void:
	var result := _session.try_recruit(candidate_index, replace_entry_id)
	if result.get("ok", false):
		_selected_candidate = -1
		_selected_replace_id = -1
		return
	var reason := String(result.get("reason", ""))
	match reason:
		"no_gold":
			_hint_label.text = "金币不足"
		"need_replace":
			_hint_label.text = "队伍已满：请指定替换目标"
		_:
			_hint_label.text = "无法招募（%s）" % reason


func _on_refresh_pressed() -> void:
	if _animating or _session == null:
		return
	if not _session.try_refresh():
		_hint_label.text = "金币不足，无法刷新"


func _on_reset_pressed() -> void:
	if _animating or _session == null:
		return
	_session.reset()
	_selected_candidate = -1
	_selected_replace_id = -1


func _on_skip_pressed() -> void:
	if _animating or _session == null:
		return
	_session.skip()
	finished.emit(false)
	hide_recruit()


func _on_finish_pressed() -> void:
	if _animating or _session == null:
		return
	_session.finish()
	finished.emit(true)
	hide_recruit()


func _play_enter_animation() -> void:
	_animating = true
	_set_action_buttons_enabled(false)
	await get_tree().process_frame
	var h := size.y
	if h <= 1.0:
		h = get_viewport_rect().size.y
	var team_top := _team_panel.offset_top
	var team_bottom := _team_panel.offset_bottom
	var recruit_top := _recruit_panel.offset_top
	var recruit_bottom := _recruit_panel.offset_bottom
	_team_panel.offset_top = team_top - h
	_team_panel.offset_bottom = team_bottom - h
	_recruit_panel.offset_top = recruit_top + h
	_recruit_panel.offset_bottom = recruit_bottom + h
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_team_panel, "offset_top", team_top, _enter_seconds)
	tween.tween_property(_team_panel, "offset_bottom", team_bottom, _enter_seconds)
	tween.tween_property(_recruit_panel, "offset_top", recruit_top, _enter_seconds)
	tween.tween_property(_recruit_panel, "offset_bottom", recruit_bottom, _enter_seconds)
	await tween.finished
	_animating = false
	_set_action_buttons_enabled(true)
	_refresh_view()


func _set_action_buttons_enabled(enabled: bool) -> void:
	_refresh_button.disabled = not enabled or (_session != null and not _session.can_refresh())
	_reset_button.disabled = not enabled
	_skip_button.disabled = not enabled
	_finish_button.disabled = not enabled


func _ensure_ghost() -> void:
	if _ghost != null or _ghost_layer == null:
		return
	_ghost = UNIT_CARD_SCENE.instantiate() as UnitCardDisplay
	if _ghost == null:
		return
	_ghost_layer.add_child(_ghost)
	_ghost.configure(UnitCardDisplay.SIZE_DEFAULT)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.visible = false
	_ghost.modulate = Color(1, 1, 1, 0.85)


func _update_ghost(viewport_pos: Vector2) -> void:
	if _ghost == null:
		return
	_ghost.global_position = viewport_pos - _ghost.size * 0.5


func _cancel_drag() -> void:
	_drag_candidate = -1
	if _ghost != null:
		_ghost.visible = false


func _is_over_team_zone(viewport_pos: Vector2) -> bool:
	if _team_drop_zone == null:
		return false
	return _team_drop_zone.get_global_rect().has_point(viewport_pos)


func _find_team_entry_at(viewport_pos: Vector2) -> int:
	for card in _team_cards:
		if card != null and is_instance_valid(card) and card.get_global_rect().has_point(viewport_pos):
			return card.entry_id
	return -1
