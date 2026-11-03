class_name DayPickOverlay
extends Control
## 十五天日程统一弹层：暗场 + 居中纸片卡（三选一 / 选商店 / 货架 / 选人）+ 底栏按钮。
## 视觉沿用胜后强化：同款暗场渐变、浅绿标题、底栏深绿面板；进出与选中都用 Tween。
## 调用方：present() 后 await resolved，拿到 {kind:&"option"|&"action", index, action}。

signal resolved(result: Dictionary)

const DIM_TOP := Color(0.02, 0.03, 0.05, 0.72)
const DIM_MID := Color(0.04, 0.05, 0.07, 0.58)
const DIM_BOT := Color(0.03, 0.04, 0.06, 0.66)
const TITLE_COLOR := Color(0.85, 1.0, 0.78, 0.95)
const SUBTITLE_COLOR := Color(0.92, 0.96, 1.0, 0.9)
const HINT_COLOR := Color(0.85, 0.75, 0.55, 0.95)
const HUD_BG := Color(0.10, 0.16, 0.12, 0.92)
const DETAIL_BG := Color(0.12, 0.14, 0.2, 0.96)
const DETAIL_BORDER := Color(0.75, 0.7, 0.45, 0.9)
const STEP_DONE := Color(0.85, 1.0, 0.78, 0.9)
const STEP_CURRENT := Color(1.0, 0.92, 0.55, 1.0)
const STEP_TODO := Color(0.6, 0.65, 0.7, 0.55)
const ENTER_SECONDS := 0.32
const CARD_STAGGER := 0.06
const CARD_GAP := 10

## headless / 测试：≤0 时所有动画瞬时完成。
var anim_scale: float = 1.0

var _dim: Control
var _dim_alpha: float = 0.0
var _title: Label
var _subtitle: Label
var _progress_row: HBoxContainer
var _cards_center: CenterContainer
var _grid: GridContainer
var _hud: PanelContainer
var _hint: Label
var _gold: Label
var _actions_row: HBoxContainer
var _detail: PanelContainer
var _detail_title: Label
var _detail_body: Label
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _cards: Array[DayPickCard] = []
var _busy: bool = false
var _open: bool = false
var _gold_value: int = -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	_dim = Control.new()
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.draw.connect(_draw_dim)
	add_child(_dim)

	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 14
	top.add_theme_constant_override("separation", 4)
	add_child(top)
	_progress_row = HBoxContainer.new()
	_progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_row.add_theme_constant_override("separation", 4)
	top.add_child(_progress_row)
	_title = _label(20, TITLE_COLOR)
	top.add_child(_title)
	_subtitle = _label(13, SUBTITLE_COLOR)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_subtitle)

	_cards_center = CenterContainer.new()
	_cards_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards_center.offset_top = 96
	_cards_center.offset_bottom = -110
	add_child(_cards_center)
	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	_cards_center.add_child(_grid)

	_hud = PanelContainer.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hud.offset_left = 10
	_hud.offset_right = -10
	_hud.offset_bottom = -12
	_hud.offset_top = -96
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = HUD_BG
	hud_style.set_corner_radius_all(10)
	hud_style.set_content_margin_all(8)
	_hud.add_theme_stylebox_override("panel", hud_style)
	add_child(_hud)
	var hud_col := VBoxContainer.new()
	hud_col.add_theme_constant_override("separation", 6)
	_hud.add_child(hud_col)
	var hud_top := HBoxContainer.new()
	hud_col.add_child(hud_top)
	_hint = _label(12, HINT_COLOR)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_top.add_child(_hint)
	_gold = _label(15, Color(1.0, 0.9, 0.5, 1.0))
	_gold.visible = false
	hud_top.add_child(_gold)
	_actions_row = HBoxContainer.new()
	_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions_row.add_theme_constant_override("separation", 10)
	hud_col.add_child(_actions_row)

	_detail = PanelContainer.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_detail.custom_minimum_size = Vector2(320, 0)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = DETAIL_BG
	detail_style.set_border_width_all(2)
	detail_style.border_color = DETAIL_BORDER
	detail_style.set_corner_radius_all(8)
	detail_style.set_content_margin_all(12)
	_detail.add_theme_stylebox_override("panel", detail_style)
	_detail.visible = false
	_detail.gui_input.connect(_on_detail_input)
	add_child(_detail)
	var detail_col := VBoxContainer.new()
	detail_col.add_theme_constant_override("separation", 6)
	_detail.add_child(detail_col)
	_detail_title = _label(17, TITLE_COLOR)
	detail_col.add_child(_detail_title)
	_detail_body = _label(13, SUBTITLE_COLOR)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.custom_minimum_size = Vector2(296, 0)
	detail_col.add_child(_detail_body)
	var detail_hint := _label(11, HINT_COLOR)
	detail_hint.text = "点任意处关闭"
	detail_col.add_child(detail_hint)

	_banner = VBoxContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.visible = false
	add_child(_banner)
	_banner_title = _label(34, TITLE_COLOR)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_sub = _label(15, SUBTITLE_COLOR)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_sub)


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _draw_dim() -> void:
	var a := clampf(_dim_alpha, 0.0, 1.0)
	if a <= 0.001:
		return
	var r := _dim.get_rect()
	var h := r.size.y
	_dim.draw_rect(Rect2(Vector2.ZERO, Vector2(r.size.x, h * 0.38)), _mul_a(DIM_TOP, a))
	_dim.draw_rect(Rect2(Vector2(0, h * 0.32), Vector2(r.size.x, h * 0.36)), _mul_a(DIM_MID, a))
	_dim.draw_rect(Rect2(Vector2(0, h * 0.62), Vector2(r.size.x, h * 0.38)), _mul_a(DIM_BOT, a))


static func _mul_a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


func _set_dim_alpha(a: float) -> void:
	_dim_alpha = a
	_dim.queue_redraw()


func _secs(s: float) -> float:
	return maxf(0.0, s * anim_scale)


func is_open() -> bool:
	return _open


## 顶部日程条：第 N 天 + 六段阶段点（已过 / 当前 / 未到）。
func set_day_progress(day: int, day_count: int, step_labels: PackedStringArray, current: int) -> void:
	for c in _progress_row.get_children():
		c.queue_free()
	var day_label := _label(12, TITLE_COLOR)
	day_label.text = "第 %d/%d 天" % [day, day_count]
	_progress_row.add_child(day_label)
	for i in step_labels.size():
		var dot := _label(11, STEP_DONE if i < current else (STEP_CURRENT if i == current else STEP_TODO))
		dot.text = ("· " if i > 0 else "  ") + step_labels[i]
		_progress_row.add_child(dot)
		if i == current:
			_pulse(dot)


func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := create_tween().set_loops(3)
	tw.tween_property(node, "modulate:a", 0.55, _secs(0.35))
	tw.tween_property(node, "modulate:a", 1.0, _secs(0.35))


## options: [{title, texture, attack, hp, cost, tag, desc, detail, disabled, disabled_reason, sold}]
## actions: [{id: StringName, text: String, primary?: bool}]
func present(cfg: Dictionary) -> void:
	_detail.visible = false
	var was_open := _open
	_open = true
	visible = true
	move_to_front()
	_title.text = String(cfg.get("title", ""))
	_subtitle.text = String(cfg.get("subtitle", ""))
	_hint.text = String(cfg.get("hint", "短按选择 · 长按查看详情"))
	set_gold(int(cfg.get("gold", -1)), false)
	_build_actions(cfg.get("actions", []) as Array)
	if was_open and not _cards.is_empty():
		await _play_cards_out()
	_build_cards(cfg.get("options", []) as Array)
	if not was_open:
		_set_dim_alpha(0.0)
		_hud.modulate.a = 0.0
		_title.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(_set_dim_alpha, 0.0, 1.0, _secs(ENTER_SECONDS))
		tw.tween_property(_hud, "modulate:a", 1.0, _secs(ENTER_SECONDS))
		tw.tween_property(_title, "modulate:a", 1.0, _secs(ENTER_SECONDS))
		if _secs(ENTER_SECONDS) <= 0.0:
			tw.kill()
			_set_dim_alpha(1.0)
			_hud.modulate.a = 1.0
			_title.modulate.a = 1.0
	await _play_cards_in()


func _build_actions(actions: Array) -> void:
	for c in _actions_row.get_children():
		c.queue_free()
	for a in actions:
		if not (a is Dictionary):
			continue
		var d := a as Dictionary
		var b := Button.new()
		b.text = String(d.get("text", ""))
		b.custom_minimum_size = Vector2(120, 40)
		var action_id: StringName = StringName(d.get("id", &""))
		b.pressed.connect(func() -> void: _on_action_pressed(action_id, b))
		_actions_row.add_child(b)
	_actions_row.visible = _actions_row.get_child_count() > 0


func _build_cards(options: Array) -> void:
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	var n := options.size()
	var cols := n if n <= 3 else (2 if n == 4 else 3)
	_grid.columns = maxi(1, cols)
	var view_w := get_viewport_rect().size.x if is_inside_tree() else 393.0
	var avail := view_w - 28.0 - float(CARD_GAP * maxi(0, cols - 1))
	var card_w := clampf(avail / float(maxi(1, cols)), 96.0, 160.0)
	var card_h := card_w * 1.62 if n <= 4 else card_w * 1.45
	for i in n:
		var opt: Dictionary = options[i] if options[i] is Dictionary else {}
		var card := DayPickCard.new()
		card.custom_minimum_size = Vector2(card_w, card_h)
		card.setup(i, opt.duplicate())
		card.tapped.connect(_on_card_tapped)
		card.long_pressed.connect(_on_card_long_pressed)
		card.get_body().modulate.a = 0.0
		_grid.add_child(card)
		_cards.append(card)


func _play_cards_in() -> void:
	if _cards.is_empty():
		return
	if _secs(1.0) <= 0.0:
		for c in _cards:
			c.get_body().modulate.a = 1.0
			c.get_body().position = Vector2.ZERO
			c.get_body().scale = Vector2.ONE
		return
	_busy = true
	await get_tree().process_frame
	var tw := create_tween().set_parallel(true)
	for i in _cards.size():
		var body := _cards[i].get_body()
		body.pivot_offset = _cards[i].size * 0.5
		body.position = Vector2(0, 90)
		body.scale = Vector2.ONE * 0.72
		var delay := _secs(CARD_STAGGER * i)
		tw.tween_property(body, "modulate:a", 1.0, _secs(0.22)).set_delay(delay)
		tw.tween_property(body, "position", Vector2.ZERO, _secs(0.38)).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(body, "scale", Vector2.ONE, _secs(0.38)).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	_busy = false


func _play_cards_out() -> void:
	if _cards.is_empty() or _secs(1.0) <= 0.0:
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for c in _cards:
		tw.tween_property(c.get_body(), "modulate:a", 0.0, _secs(0.18))
		tw.tween_property(c.get_body(), "position", Vector2(0, -40), _secs(0.18))
	await tw.finished


## 选中反馈：被选卡放大闪亮，其余下沉变淡；随后调用方决定换下一组或关闭。
func play_choice_feedback(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_busy = true
	var chosen := _cards[index]
	chosen.set_selected(true)
	chosen.move_to_front()
	if _secs(1.0) <= 0.0:
		_busy = false
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(chosen.get_body(), "scale", Vector2.ONE * 1.14, _secs(0.22))
	tw.tween_property(chosen.get_body(), "modulate", Color(1.25, 1.22, 1.05, 1.0), _secs(0.12))
	for c in _cards:
		if c == chosen:
			continue
		tw.tween_property(c.get_body(), "modulate:a", 0.25, _secs(0.2))
		tw.tween_property(c.get_body(), "position", Vector2(0, 26), _secs(0.24))
		tw.tween_property(c.get_body(), "scale", Vector2.ONE * 0.9, _secs(0.24))
	await tw.finished
	var settle := create_tween()
	settle.tween_property(chosen.get_body(), "modulate", Color.WHITE, _secs(0.16))
	settle.parallel().tween_property(chosen.get_body(), "scale", Vector2.ONE * 1.06, _secs(0.16))
	await settle.finished
	_busy = false


## 购买成功：卡片弹一下并标「已购入」。
func mark_sold(index: int, text: String = "已购入") -> void:
	if index < 0 or index >= _cards.size():
		return
	var card := _cards[index]
	card.set_sold(true, text)
	if _secs(1.0) <= 0.0:
		return
	var body := card.get_body()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "scale", Vector2.ONE * 1.12, _secs(0.12))
	tw.tween_property(body, "scale", Vector2.ONE, _secs(0.18))


func set_option_disabled(index: int, disabled: bool, reason: String = "") -> void:
	if index < 0 or index >= _cards.size():
		return
	_cards[index].option["disabled"] = disabled
	_cards[index].option["disabled_reason"] = reason
	_cards[index].refresh_state()


## 失败反馈：左右抖动 + 底栏提示变红闪一下。
func reject(index: int, message: String) -> void:
	flash_hint(message, true)
	if index < 0 or index >= _cards.size() or _secs(1.0) <= 0.0:
		return
	var body := _cards[index].get_body()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for dx in [10.0, -9.0, 6.0, -4.0, 0.0]:
		tw.tween_property(body, "position:x", dx, _secs(0.045))


func flash_hint(message: String, is_error: bool = false) -> void:
	_hint.text = message
	_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5, 1.0) if is_error else TITLE_COLOR)
	if _secs(1.0) <= 0.0:
		_hint.add_theme_color_override("font_color", HINT_COLOR)
		return
	_hint.pivot_offset = _hint.size * 0.5
	var tw := create_tween()
	tw.tween_property(_hint, "scale", Vector2.ONE * 1.06, _secs(0.08))
	tw.tween_property(_hint, "scale", Vector2.ONE, _secs(0.12))
	tw.tween_interval(_secs(0.9))
	tw.tween_callback(func() -> void: _hint.add_theme_color_override("font_color", HINT_COLOR))


## 金币：变化时数字滚动 + 轻弹。
func set_gold(value: int, animate: bool = true) -> void:
	_gold.visible = value >= 0
	if value < 0:
		_gold_value = -1
		return
	var from := _gold_value if _gold_value >= 0 else value
	_gold_value = value
	if not animate or from == value or _secs(1.0) <= 0.0:
		_gold.text = UiStatIcons.format_gold_label(value)
		return
	_gold.pivot_offset = _gold.size * 0.5
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _gold.text = UiStatIcons.format_gold_label(int(round(v))), float(from), float(value), _secs(0.3))
	tw.parallel().tween_property(_gold, "scale", Vector2.ONE * 1.18, _secs(0.12))
	tw.tween_property(_gold, "scale", Vector2.ONE, _secs(0.14))


## 关闭：卡片收起 + 暗场淡出。
func close() -> void:
	if not _open:
		return
	_detail.visible = false
	if _secs(1.0) > 0.0:
		await _play_cards_out()
		var tw := create_tween().set_parallel(true)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_method(_set_dim_alpha, _dim_alpha, 0.0, _secs(0.22))
		tw.tween_property(_hud, "modulate:a", 0.0, _secs(0.2))
		tw.tween_property(_title, "modulate:a", 0.0, _secs(0.2))
		await tw.finished
	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	_open = false
	visible = false


## 全屏横幅（第 N 天 / 一天结束）：缩放弹入、停留、淡出；不吞卡片状态。
func show_banner(title: String, subtitle: String = "", hold_seconds: float = 0.7) -> void:
	var standalone := not _open
	visible = true
	move_to_front()
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_sub.visible = not subtitle.is_empty()
	_banner.visible = true
	if standalone:
		_hud.modulate.a = 0.0
		_title.modulate.a = 0.0
	if _secs(1.0) <= 0.0:
		_banner.visible = false
		if standalone:
			visible = false
		return
	await get_tree().process_frame
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 0.6
	_banner.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	if standalone:
		tw.tween_method(_set_dim_alpha, _dim_alpha, 0.85, _secs(0.25))
	tw.tween_property(_banner, "modulate:a", 1.0, _secs(0.2))
	tw.tween_property(_banner, "scale", Vector2.ONE, _secs(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(_secs(hold_seconds)).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(_banner, "modulate:a", 0.0, _secs(0.22))
	out.tween_property(_banner, "scale", Vector2.ONE * 1.08, _secs(0.22))
	if standalone:
		out.tween_method(_set_dim_alpha, 0.85, 0.0, _secs(0.25))
	await out.finished
	_banner.visible = false
	if standalone:
		visible = false


func _on_card_tapped(card: DayPickCard) -> void:
	if _busy or _detail.visible:
		return
	if card.is_disabled():
		reject(card.index, String(card.option.get("disabled_reason", "不可选")) if bool(card.option.get("disabled", false)) else "已购入")
		return
	resolved.emit({"kind": &"option", "index": card.index, "action": &""})


func _on_card_long_pressed(card: DayPickCard) -> void:
	var detail := String(card.option.get("detail", card.option.get("desc", "")))
	_detail_title.text = String(card.option.get("title", ""))
	_detail_body.text = detail if not detail.is_empty() else "暂无说明"
	_detail.visible = true
	_detail.move_to_front()
	if _secs(1.0) <= 0.0:
		return
	await get_tree().process_frame
	_detail.position = (size - _detail.size) * 0.5
	_detail.pivot_offset = _detail.size * 0.5
	_detail.scale = Vector2.ONE * 0.85
	_detail.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_detail, "scale", Vector2.ONE, _secs(0.18)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_detail, "modulate:a", 1.0, _secs(0.14))


func _on_detail_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed):
		_detail.visible = false
		accept_event()


func _gui_input(event: InputEvent) -> void:
	if not _detail.visible:
		return
	if (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed):
		_detail.visible = false
		accept_event()


func _on_action_pressed(action_id: StringName, button: Button) -> void:
	if _busy or _detail.visible:
		return
	if _secs(1.0) > 0.0 and is_instance_valid(button):
		button.pivot_offset = button.size * 0.5
		var tw := create_tween()
		tw.tween_property(button, "scale", Vector2.ONE * 0.92, _secs(0.06))
		tw.tween_property(button, "scale", Vector2.ONE, _secs(0.1))
	resolved.emit({"kind": &"action", "index": -1, "action": action_id})
