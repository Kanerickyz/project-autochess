class_name RealtimeUnitInfoCard
extends PanelContainer
## 长按单位弹出的信息卡（参考 SAP）：头像 + 名称 + 攻血标 + 技能描述。
## 只读展示，不拦截输入；松手由战场视图收起。

const CARD_WIDTH := 236.0
const PORTRAIT_SIZE := Vector2(56.0, 64.0)
const BADGE_HEIGHT := 22.0
const MARGIN_PX := 6.0
const PAPER := Color(0.97, 0.92, 0.79, 0.98)
const INK := Color(0.13, 0.10, 0.08, 1.0)
const INK_SOFT := Color(0.32, 0.27, 0.21, 1.0)
const PLAYER_ACCENT := Color(0.20, 0.36, 0.78, 1.0)
const ENEMY_ACCENT := Color(0.69, 0.23, 0.20, 1.0)


class StatBadge:
	extends Control
	var texture: Texture2D
	var value := 0

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
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, RealtimeArenaView.STAT_TEXT)


var _portrait: TextureRect
var _name_label: Label
var _side_label: Label
var _attack_badge: StatBadge
var _hp_badge: StatBadge
var _skills_label: Label
var _style: StyleBoxFlat


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
	_style.shadow_size = 6
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
	_name_label.add_theme_font_override("font", RealtimeArenaView.STAT_FONT)
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

	var rule := ColorRect.new()
	rule.color = Color(INK, 0.35)
	rule.custom_minimum_size = Vector2(0.0, 2.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	_skills_label = Label.new()
	_skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skills_label.custom_minimum_size = Vector2(CARD_WIDTH - 20.0, 0.0)
	_skills_label.add_theme_font_size_override("font_size", 14)
	_skills_label.add_theme_color_override("font_color", INK)
	column.add_child(_skills_label)


## info: {name, side_player, attack, hp, skills, texture?, tier?}
## anchor: 单位贴图头顶（父节点本地坐标）；bounds: 可放置范围。
func show_info(info: Dictionary, anchor: Vector2, foot: Vector2, bounds: Rect2) -> void:
	var is_player := bool(info.get("side_player", true))
	_portrait.texture = info.get("texture") as Texture2D
	_portrait.visible = _portrait.texture != null
	_name_label.text = String(info.get("name", "未知"))
	var tier := int(info.get("tier", 0))
	var side := "我方" if is_player else "敌方"
	_side_label.text = "%s · T%d" % [side, tier] if tier > 0 else side
	_side_label.add_theme_color_override("font_color", PLAYER_ACCENT if is_player else ENEMY_ACCENT)
	_style.border_color = INK
	_attack_badge.value = int(info.get("attack", 0))
	_hp_badge.value = int(info.get("hp", 0))
	_attack_badge.queue_redraw()
	_hp_badge.queue_redraw()
	_skills_label.text = _format_skills(String(info.get("skills", "")))
	visible = true
	reset_size()
	var card_size := get_combined_minimum_size()
	size = card_size
	var pos := Vector2(anchor.x - card_size.x * 0.5, anchor.y - card_size.y - MARGIN_PX)
	if pos.y < bounds.position.y + MARGIN_PX:
		pos.y = foot.y + MARGIN_PX
	pos.x = clampf(pos.x, bounds.position.x + MARGIN_PX, maxf(bounds.position.x + MARGIN_PX, bounds.end.x - card_size.x - MARGIN_PX))
	pos.y = clampf(pos.y, bounds.position.y + MARGIN_PX, maxf(bounds.position.y + MARGIN_PX, bounds.end.y - card_size.y - MARGIN_PX))
	position = pos


func hide_info() -> void:
	visible = false


## 去掉「【技能】」等标签前缀，SAP 式直接读效果句。
func _format_skills(raw: String) -> String:
	if raw.is_empty() or raw == "无技能":
		return "无技能：只会普通攻击。"
	var lines: PackedStringArray = []
	for line in raw.split("\n"):
		var text := line.strip_edges()
		if text.begins_with("【技能】"):
			text = text.trim_prefix("【技能】")
		lines.append(text)
	return "\n".join(lines)


func _make_badge(texture: Texture2D) -> StatBadge:
	var badge := StatBadge.new()
	badge.texture = texture
	var tex_size := texture.get_size()
	badge.custom_minimum_size = Vector2(BADGE_HEIGHT * tex_size.x / maxf(1.0, tex_size.y), BADGE_HEIGHT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge
