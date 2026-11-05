class_name ThemeCommitmentPanel
extends Control
## 招募主题三选一 + 重 roll（2 金）。未选主题前挡住短名单。

signal theme_committed(theme_id: StringName)
signal theme_reroll_pressed

var _session: RecruitSession
var _title: Label
var _tip: Label
var _offers: VBoxContainer
var _reroll_btn: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 280)
	panel.offset_left = -230
	panel.offset_top = -140
	panel.offset_right = 230
	panel.offset_bottom = 140
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.12, 0.96)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = Label.new()
	_title.text = "选择主题"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)

	_tip = Label.new()
	_tip.text = "本阶段候选人仅出主或辅匹配该主题的角色。"
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_tip)

	_offers = VBoxContainer.new()
	_offers.add_theme_constant_override("separation", 8)
	box.add_child(_offers)

	_reroll_btn = Button.new()
	_reroll_btn.text = "重 roll 主题（2 金）"
	_reroll_btn.pressed.connect(_on_reroll)
	box.add_child(_reroll_btn)


func bind_session(session: RecruitSession) -> void:
	_session = session
	refresh()


func show_for_session(session: RecruitSession) -> void:
	bind_session(session)
	visible = true


func hide_panel() -> void:
	visible = false
	_session = null


func refresh() -> void:
	if _offers == null:
		return
	for child in _offers.get_children():
		child.queue_free()
	if _session == null:
		return
	var offers := _session.get_theme_offers()
	for theme_id in offers:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = UnitTheme.display_name(theme_id)
		btn.pressed.connect(_on_pick.bind(theme_id))
		_offers.add_child(btn)
	if _reroll_btn != null:
		var cost := _session.get_theme_reroll_cost()
		_reroll_btn.text = "重 roll 主题（%d 金）" % cost
		_reroll_btn.disabled = not _session.can_reroll_themes()
	var gold := 0
	if _session.economy != null:
		gold = _session.economy.gold
	_tip.text = "本阶段候选人仅出主或辅匹配该主题的角色。当前金币 %d。" % gold


func _on_pick(theme_id: StringName) -> void:
	if _session == null:
		return
	if not _session.commit_theme(theme_id):
		refresh()
		return
	hide_panel()
	theme_committed.emit(theme_id)


func _on_reroll() -> void:
	theme_reroll_pressed.emit()
	if _session == null:
		return
	if _session.try_reroll_themes():
		refresh()
	else:
		refresh()
