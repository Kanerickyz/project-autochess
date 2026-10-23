class_name RealtimeUnitInfoCard
extends PanelContainer
## 长按单位弹出的信息卡（参考 SAP）：头像 + 名称 + 攻血标 + 技能描述。
## 只读展示，不拦截输入；松手由战场视图收起。
## 在单位间滑动切换时用小丑牌式抬起 / 倾斜 / 弹性落位。

const CARD_WIDTH := 236.0
const PORTRAIT_SIZE := Vector2(56.0, 64.0)
const BADGE_HEIGHT := 22.0
const MARGIN_PX := 6.0
const PAPER := Color(0.97, 0.92, 0.79, 0.98)
const INK := Color(0.13, 0.10, 0.08, 1.0)
const INK_SOFT := Color(0.32, 0.27, 0.21, 1.0)
const PLAYER_ACCENT := Color(0.20, 0.36, 0.78, 1.0)
const ENEMY_ACCENT := Color(0.69, 0.23, 0.20, 1.0)

const POP_IN_SEC := 0.18
const SWITCH_SEC := 0.22
const TILT_DEG := 11.0
const SWITCH_KICK_PX := 42.0
const SWITCH_LIFT_PX := 10.0
const SCALE_POP := 0.88
const SCALE_PUNCH := 1.08
const FINGER_PARALLAX := 0.14
const FINGER_TILT := 0.035
const FINGER_MAX_OFFSET := 28.0
const SHADOW_REST := 6
const SHADOW_LIFT := 14


class StatBadge:
	extends Control
	var texture: Texture2D
	var value := 0
	var value_color := RealtimeArenaView.STAT_TEXT

	func _draw() -> void:
		if texture == null:
			return
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
		var font := RealtimeArenaView.STAT_FONT
		var text := str(maxi(0, value))
		var font_size := maxi(8, int(size.y * 0.62))
		var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := Vector2(
			size.x * RealtimeArenaView.STAT_NUMBER_CENTER_X - text_w * 0.5,
			size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5,
		)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, value_color)


var _portrait: TextureRect
var _name_label: Label
var _side_label: Label
var _attack_badge: StatBadge
var _hp_badge: StatBadge
var _armor_badge: StatBadge
var _gold_badge: StatBadge
var _skills_label: RichTextLabel
var _style: StyleBoxFlat
var _motion: Tween
var _rest_position := Vector2.ZERO
var _follow_offset := Vector2.ZERO
var _base_rotation := 0.0
var _base_scale := 1.0
var _open := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 10
	custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	_style = StyleBoxFlat.new()
	_style.bg_color = PAPER
	_style.border_color = INK
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(10)
	_style.set_content_margin_all(10.0)
	_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	_style.shadow_size = SHADOW_REST
	_style.shadow_offset = Vector2(0.0, 3.0)
	add_theme_stylebox_override("panel", _style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_portrait)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(titles)

	_name_label = Label.new()
	## 名称含中文：须走带 CJK fallback 的 Theme/ui_font，勿用纯数字用的 embolden 字体覆盖。
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", INK)
	titles.add_child(_name_label)

	_side_label = Label.new()
	_side_label.add_theme_font_size_override("font_size", 12)
	titles.add_child(_side_label)

	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 4)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.add_child(badges)
	_attack_badge = _make_badge(RealtimeArenaView.STAT_ATTACK_TEX)
	badges.add_child(_attack_badge)
	_hp_badge = _make_badge(RealtimeArenaView.STAT_HP_TEX)
	badges.add_child(_hp_badge)
	_armor_badge = _make_badge(UiStatIcons.armor_texture())
	_armor_badge.visible = false
	badges.add_child(_armor_badge)
	_gold_badge = _make_badge(UiStatIcons.gold_texture())
	_gold_badge.visible = false
	badges.add_child(_gold_badge)

	var rule := ColorRect.new()
	rule.color = Color(INK, 0.35)
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_skills_label = RichTextLabel.new()
	_skills_label.bbcode_enabled = true
	_skills_label.fit_content = true
	_skills_label.scroll_active = false
	_skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skills_label.custom_minimum_size = Vector2(CARD_WIDTH - 20.0, 0.0)
	_skills_label.add_theme_font_size_override("normal_font_size", 14)
	_skills_label.add_theme_color_override("default_color", INK)
	_skills_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_skills_label)


## info: {name, side_player, attack, hp, skills, texture?, tier?, recruit_cost?, recruit_cost_affordable?}
## 物品：{is_item, kind_label, cost, armor?, skills, texture?} — 隐藏攻血标，侧栏写种类与价格。
## anchor: 单位贴图头顶（父节点本地坐标）；bounds: 可放置范围。
## slide_dir: 滑动切换水平方向（-1 左 / 0 首次弹出 / +1 右），小丑牌式倾斜用。
func show_info(
	info: Dictionary,
	anchor: Vector2,
	foot: Vector2,
	bounds: Rect2,
	slide_dir: float = 0.0,
) -> void:
	var was_open := _open and visible
	_apply_content(info)
	reset_size()
	var card_size := get_combined_minimum_size()
	size = card_size
	pivot_offset = card_size * 0.5
	var target := _compute_position(anchor, foot, bounds, card_size)
	_rest_position = target
	_follow_offset = Vector2.ZERO
	visible = true
	_open = true
	if was_open and absf(slide_dir) > 0.01:
		_play_switch(target, slide_dir)
	elif was_open:
		_snap_rest(target)
	else:
		_play_pop_in(target)


## 按住滑动时：卡面轻跟手指并微倾，类似小丑牌悬停跟手。
func follow_finger(finger_local: Vector2) -> void:
	if not _open or not visible:
		return
	## 弹出 / 切换弹性动画中不抢位，避免跟手冲掉倾斜落位。
	if _motion != null and _motion.is_valid() and _motion.is_running():
		return
	var center := _rest_position + size * 0.5
	var delta := (finger_local - center) * FINGER_PARALLAX
	delta.x = clampf(delta.x, -FINGER_MAX_OFFSET, FINGER_MAX_OFFSET)
	delta.y = clampf(delta.y, -FINGER_MAX_OFFSET * 0.6, FINGER_MAX_OFFSET * 0.6)
	_follow_offset = delta
	position = _rest_position + _follow_offset
	rotation_degrees = _base_rotation + delta.x * FINGER_TILT
	scale = Vector2.ONE * _base_scale


func hide_info() -> void:
	_kill_motion()
	_open = false
	_follow_offset = Vector2.ZERO
	_base_rotation = 0.0
	_base_scale = 1.0
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	_set_shadow_lift(false)
	visible = false


func _apply_content(info: Dictionary) -> void:
	var is_player := bool(info.get("side_player", true))
	var is_item := bool(info.get("is_item", false))
	_portrait.texture = info.get("texture") as Texture2D
	_portrait.visible = _portrait.texture != null
	_name_label.text = String(info.get("name", "未知"))
	if is_item:
		var kind := String(info.get("kind_label", "物品"))
		var cost := int(info.get("cost", 0))
		_side_label.text = "%s · %d金" % [kind, cost] if cost > 0 else kind
		_side_label.add_theme_color_override("font_color", PLAYER_ACCENT)
	else:
		var tier := int(info.get("tier", 0))
		var side := "我方" if is_player else "敌方"
		_side_label.text = "%s · T%d" % [side, tier] if tier > 0 else side
		_side_label.add_theme_color_override("font_color", PLAYER_ACCENT if is_player else ENEMY_ACCENT)
	_style.border_color = INK
	_attack_badge.visible = not is_item
	_hp_badge.visible = not is_item
	if not is_item:
		_attack_badge.value = int(info.get("attack", 0))
		_hp_badge.value = int(info.get("hp", 0))
		_attack_badge.queue_redraw()
		_hp_badge.queue_redraw()
	var armor := int(info.get("armor", 0))
	var armor_tex := UiStatIcons.armor_texture()
	if _armor_badge != null:
		_armor_badge.texture = armor_tex
		_armor_badge.value = armor
		_armor_badge.visible = armor > 0 and armor_tex != null
		_armor_badge.queue_redraw()
	var recruit_cost := int(info.get("recruit_cost", -1))
	if _gold_badge != null:
		var gold_tex := UiStatIcons.gold_texture()
		_gold_badge.texture = gold_tex
		_gold_badge.value = recruit_cost
		_gold_badge.visible = not is_item and recruit_cost >= 0 and gold_tex != null
		_gold_badge.value_color = (
			RealtimeArenaView.STAT_TEXT
			if bool(info.get("recruit_cost_affordable", true))
			else Color(0.85, 0.22, 0.18, 1.0)
		)
		_gold_badge.queue_redraw()
	_skills_label.clear()
	_skills_label.append_text(_format_skills_bbcode(String(info.get("skills", "")), is_item))


func _compute_position(anchor: Vector2, foot: Vector2, bounds: Rect2, card_size: Vector2) -> Vector2:
	var pos := Vector2(anchor.x - card_size.x * 0.5, anchor.y - card_size.y - MARGIN_PX)
	if pos.y < bounds.position.y + MARGIN_PX:
		pos.y = foot.y + MARGIN_PX
	pos.x = clampf(
		pos.x,
		bounds.position.x + MARGIN_PX,
		maxf(bounds.position.x + MARGIN_PX, bounds.end.x - card_size.x - MARGIN_PX),
	)
	pos.y = clampf(
		pos.y,
		bounds.position.y + MARGIN_PX,
		maxf(bounds.position.y + MARGIN_PX, bounds.end.y - card_size.y - MARGIN_PX),
	)
	return pos


func _play_pop_in(target: Vector2) -> void:
	_kill_motion()
	_set_shadow_lift(true)
	position = target + Vector2(0.0, 16.0)
	rotation_degrees = 0.0
	scale = Vector2.ONE * SCALE_POP
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_base_rotation = 0.0
	_base_scale = 1.0
	_motion = create_tween()
	_motion.set_parallel(true)
	_motion.tween_property(self, "position", target, POP_IN_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "scale", Vector2.ONE, POP_IN_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "modulate:a", 1.0, POP_IN_SEC * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motion.chain().tween_callback(_on_motion_settled)


func _play_switch(target: Vector2, slide_dir: float) -> void:
	_kill_motion()
	var dir := signf(slide_dir)
	if is_zero_approx(dir):
		dir = 1.0
	_set_shadow_lift(true)
	## 从滑动来向踢出：抬起、倾斜、轻微放大，再弹性落位到新单位上方。
	var kick := Vector2(dir * SWITCH_KICK_PX, -SWITCH_LIFT_PX)
	position = target - kick * 0.35
	rotation_degrees = dir * TILT_DEG
	scale = Vector2.ONE * SCALE_PUNCH
	modulate = Color.WHITE
	_base_rotation = dir * TILT_DEG
	_base_scale = SCALE_PUNCH
	_motion = create_tween()
	_motion.set_parallel(true)
	_motion.tween_property(self, "position", target, SWITCH_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "rotation_degrees", 0.0, SWITCH_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.tween_property(self, "scale", Vector2.ONE, SWITCH_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion.chain().tween_callback(_on_motion_settled)


func _snap_rest(target: Vector2) -> void:
	_kill_motion()
	position = target
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	_base_rotation = 0.0
	_base_scale = 1.0
	_set_shadow_lift(true)


func _on_motion_settled() -> void:
	_base_rotation = 0.0
	_base_scale = 1.0
	_set_shadow_lift(true)
	## 若跟手偏移仍在，保持当前跟手位，不硬拽回 rest。
	if _follow_offset.length_squared() < 0.25:
		position = _rest_position


func _set_shadow_lift(lifted: bool) -> void:
	if _style == null:
		return
	if lifted:
		_style.shadow_size = SHADOW_LIFT
		_style.shadow_offset = Vector2(0.0, 6.0)
		_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	else:
		_style.shadow_size = SHADOW_REST
		_style.shadow_offset = Vector2(0.0, 3.0)
		_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)


func _kill_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


## 去掉「【技能】」等标签前缀；攻/血占位换成脚下同款图标。
## is_item：商店物品详情，空文案不套「无技能」单位兜底。
func _format_skills_bbcode(raw: String, is_item: bool = false) -> String:
	if raw.is_empty() or raw == "无技能":
		return "商店物品。" if is_item else "无技能：只会普通攻击。"
	var lines: PackedStringArray = []
	for line in raw.split("\n"):
		var text := line.strip_edges()
		if text.begins_with("【技能】"):
			text = text.trim_prefix("【技能】")
		lines.append(text)
	var plain := "\n".join(lines)
	## BBCode 字面量方括号。
	var escaped := plain.replace("[", "[lb]")
	var icon_h := 16.0
	var atk_tex: Texture2D = RealtimeArenaView.STAT_ATTACK_TEX
	var hp_tex: Texture2D = RealtimeArenaView.STAT_HP_TEX
	var atk_w := icon_h * atk_tex.get_width() / maxf(1.0, float(atk_tex.get_height()))
	var hp_w := icon_h * hp_tex.get_width() / maxf(1.0, float(hp_tex.get_height()))
	escaped = escaped.replace(
		UnitInfoText.STAT_ICON_ATK,
		"[img=%dx%d]%s[/img]" % [int(round(atk_w)), int(icon_h), atk_tex.resource_path],
	)
	escaped = escaped.replace(
		UnitInfoText.STAT_ICON_HP,
		"[img=%dx%d]%s[/img]" % [int(round(hp_w)), int(icon_h), hp_tex.resource_path],
	)
	return escaped


func _make_badge(texture: Texture2D) -> StatBadge:
	var badge := StatBadge.new()
	badge.texture = texture
	var tex_size := Vector2(BADGE_HEIGHT, BADGE_HEIGHT)
	if texture != null:
		tex_size = texture.get_size()
	badge.custom_minimum_size = Vector2(BADGE_HEIGHT * tex_size.x / maxf(1.0, tex_size.y), BADGE_HEIGHT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge
