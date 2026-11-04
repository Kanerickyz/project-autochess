class_name ThemeDirectedBattleExtension
extends RefCounted
## 胜后主题定向：两主题立绘二选一 → 长按 Tween 展开三人三选一（免费拿 1）→ 完成回整理招募。


signal finished

const THEME_EXPAND_SEC := 0.35
const UNIT_STAGGER_SEC := 0.08

var _battle: RealtimeBattleController
var _session: RecruitSession
var _hud: Control
var _hint: Label
var _skip_btn: Button
var _claim_btn: Button

var _themes: Array[StringName] = []
var _units: Array[UnitData] = []
var _selected_theme: int = -1
var _selected_unit: int = -1
var _step: StringName = &"themes" ## themes | units
var _busy: bool = false
var _awaiting: bool = false


func setup(battle: RealtimeBattleController) -> void:
	_battle = battle
	_ensure_hud()


func is_busy() -> bool:
	return _busy


## 进入主题定向；结束后发出 finished。session 须已 configure，并写好 map_floor / progress。
func begin(session: RecruitSession) -> void:
	_session = session
	_busy = true
	_awaiting = true
	_step = &"themes"
	_selected_theme = -1
	_selected_unit = -1
	_units.clear()
	_themes.clear()
	if _session != null:
		_themes = _session.roll_theme_pair()
	_ensure_hud()
	if _hud != null:
		_hud.visible = true
	_sync_arena()
	_refresh_hud()


func end() -> void:
	_busy = false
	_awaiting = false
	_step = &"themes"
	_selected_theme = -1
	_selected_unit = -1
	_themes.clear()
	_units.clear()
	if _hud != null:
		_hud.visible = false
	if _battle != null and _battle.get_arena() != null:
		_battle.get_arena().clear_theme_directed_mode()


func _complete() -> void:
	if not _awaiting:
		return
	_awaiting = false
	end()
	finished.emit()


func on_theme_pressed(index: int) -> void:
	if not _busy or _step != &"themes":
		return
	if index < 0 or index >= _themes.size():
		return
	_selected_theme = index
	_sync_arena()
	_refresh_hud()


## 长按主题卡：收束两卡 → 错峰入场三人。
func on_theme_long_pressed(index: int) -> void:
	if not _busy or _step != &"themes" or _battle == null:
		return
	if index < 0 or index >= _themes.size():
		return
	_selected_theme = index
	var theme_id := _themes[index]
	_units.clear()
	if _session != null:
		_units = _session.roll_units_for_theme(theme_id)
	_selected_unit = -1
	await _play_expand_tween()
	_step = &"units"
	_sync_arena()
	_refresh_hud()


func on_unit_pressed(index: int) -> void:
	if not _busy or _step != &"units":
		return
	if index < 0 or index >= _units.size():
		return
	_selected_unit = index
	_sync_arena()
	_refresh_hud()
	## 点选即领（短按确认）。
	_try_claim_selected()


func on_unit_info_requested(index: int) -> void:
	## 长按信息由 Arena inspect 路径处理；此处仅同步选中。
	if not _busy or _step != &"units":
		return
	if index < 0 or index >= _units.size():
		return
	_selected_unit = index
	_sync_arena()


func _try_claim_selected() -> void:
	if _session == null or _selected_unit < 0 or _selected_unit >= _units.size():
		return
	var unit := _units[_selected_unit]
	var result := _session.claim_unit_free(unit)
	if bool(result.get("ok", false)):
		_set_hint("已免费加入 %s" % unit.display_name)
		_complete()
		return
	var reason := String(result.get("reason", ""))
	match reason:
		"roster_full":
			_set_hint("拥有已满：请跳过拿人，稍后在整理招募出售腾位")
		"no_copies":
			_set_hint("该角色份数已用尽")
		_:
			_set_hint("无法领取（%s）" % reason)
	_refresh_hud()


func _on_skip_pressed() -> void:
	if not _busy:
		return
	## 仅三人界面可跳过拿人；主题二选一不可跳过整场。
	if _step != &"units":
		_set_hint("请先短按选中主题，再长按展开三人")
		return
	_complete()


func _on_claim_pressed() -> void:
	if not _busy or _step != &"units":
		return
	if _selected_unit < 0:
		_set_hint("请先点选一名角色")
		return
	_try_claim_selected()


func _play_expand_tween() -> void:
	var arena := _battle.get_arena() if _battle != null else null
	if arena == null:
		return
	arena.theme_directed_theme_shrink = 0.0
	arena.theme_directed_unit_reveal = 0.0
	_sync_arena()
	var tree := _battle.get_tree()
	if tree == null:
		arena.theme_directed_theme_shrink = 1.0
		arena.theme_directed_unit_reveal = 1.0
		return
	var tween := _battle.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(arena, "theme_directed_theme_shrink", 1.0, THEME_EXPAND_SEC)
	tween.parallel().tween_property(
		arena, "theme_directed_unit_reveal", 1.0, THEME_EXPAND_SEC + UNIT_STAGGER_SEC * 2.0
	)
	await tween.finished


func sync_arena() -> void:
	_sync_arena()


func _sync_arena() -> void:
	if _battle == null:
		return
	var arena := _battle.get_arena()
	if arena == null:
		return
	arena.theme_directed_active = true
	arena.recruit_active = false
	arena.map_shop_active = false
	arena.enchant_active = false
	arena.theme_directed_step = _step
	arena.theme_directed_selected_theme = _selected_theme
	arena.theme_directed_selected_unit = _selected_unit
	arena.theme_directed_themes = _build_theme_previews()
	arena.theme_directed_units = _build_unit_previews()
	## 上半场仍可显示当前队伍，方便满员判断。
	_battle.sync_theme_directed_team_slots()
	arena.queue_redraw()


func _build_theme_previews() -> Array:
	var out: Array = []
	var cells := _theme_cells(_themes.size())
	for i in _themes.size():
		var theme_id := _themes[i]
		out.append({
			"index": i,
			"theme_id": theme_id,
			"label": UnitTheme.display_name(theme_id),
			"cell": cells[i] if i < cells.size() else Vector2i(-1, -1),
			"selected": i == _selected_theme,
		})
	return out


func _build_unit_previews() -> Array:
	var out: Array = []
	var cells := _unit_cells(_units.size())
	for i in _units.size():
		var unit := _units[i]
		out.append({
			"index": i,
			"unit": unit,
			"cell": cells[i] if i < cells.size() else Vector2i(-1, -1),
			"selected": i == _selected_unit,
			"label": unit.display_name if unit != null else "",
			"stagger": float(i) * UNIT_STAGGER_SEC,
		})
	return out


func _theme_cells(count: int) -> Array[Vector2i]:
	var board := Vector2i(5, 8)
	if _battle != null:
		board = _battle.get_board_size()
	var mid := BoardHalf.midline_row(board.y)
	var y := clampi(mid + 2, mid, maxi(mid, board.y - 1))
	var n := maxi(1, count)
	var start_x := (board.x - n) / 2
	var cells: Array[Vector2i] = []
	for i in n:
		cells.append(Vector2i(clampi(start_x + i, 0, maxi(0, board.x - 1)), y))
	return cells


func _unit_cells(count: int) -> Array[Vector2i]:
	var board := Vector2i(5, 8)
	if _battle != null:
		board = _battle.get_board_size()
	var mid := BoardHalf.midline_row(board.y)
	var y := clampi(mid + 2, mid, maxi(mid, board.y - 1))
	var n := maxi(1, count)
	var start_x := (board.x - n) / 2
	var cells: Array[Vector2i] = []
	for i in n:
		cells.append(Vector2i(clampi(start_x + i, 0, maxi(0, board.x - 1)), y))
	return cells


func _ensure_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	if _battle == null:
		return
	_hud = PanelContainer.new()
	_hud.name = "ThemeDirectedHud"
	_hud.visible = false
	_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.16, 0.92)
	style.set_content_margin_all(8.0)
	_hud.add_theme_stylebox_override("panel", style)
	var dock := _battle.get_node_or_null("Layout/Dock") as Control
	var dock_box: Node = null
	if dock != null:
		dock_box = dock.get_node_or_null("DockBox")
	if dock_box != null:
		dock_box.add_child(_hud)
	else:
		_battle.add_child(_hud)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_hud.add_child(box)
	var title := Label.new()
	title.text = "主题定向"
	box.add_child(title)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.text = "短按选中主题，长按展开该主题三人"
	box.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_claim_btn = Button.new()
	_claim_btn.text = "领取"
	_claim_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_claim_btn.pressed.connect(_on_claim_pressed)
	row.add_child(_claim_btn)
	_skip_btn = Button.new()
	_skip_btn.text = "跳过拿人"
	_skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip_btn.pressed.connect(_on_skip_pressed)
	row.add_child(_skip_btn)


func _refresh_hud() -> void:
	if _hint == null:
		return
	if _step == &"themes":
		_hint.text = "短按选中主题，长按展开该主题三人（免费）"
		if _claim_btn != null:
			_claim_btn.visible = false
		if _skip_btn != null:
			_skip_btn.visible = false
	else:
		if _units.is_empty():
			_hint.text = "该主题暂无可招角色，可跳过拿人"
		else:
			_hint.text = "短按领取 1 人（免费）；长按查看信息；可跳过"
		if _claim_btn != null:
			_claim_btn.visible = true
			_claim_btn.disabled = _selected_unit < 0 or _units.is_empty()
		if _skip_btn != null:
			_skip_btn.visible = true
			_skip_btn.disabled = false


func _set_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text
