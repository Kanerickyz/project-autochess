class_name SynergyTagHud
extends Control
## 左上职业 Tag 浮层：展示「职业 × 人数」；CanvasLayer 挂载，避开顶栏遮挡与棋盘中央。

const ROW_FONT_SIZE := 14
const CHIP_SEP := 10
const PANEL_PAD := 8.0


var _panel: PanelContainer
var _row: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	## 落在战斗 HUD / 沙盒「返回」下方，靠左不挡棋盘中心。
	offset_left = 12.0
	offset_top = 108.0
	offset_right = 12.0
	offset_bottom = 108.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	_ensure_children()
	visible = false


func _ensure_children() -> void:
	if _panel != null and _row != null:
		return
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.82)
	style.content_margin_left = PANEL_PAD
	style.content_margin_right = PANEL_PAD
	style.content_margin_top = PANEL_PAD * 0.65
	style.content_margin_bottom = PANEL_PAD * 0.65
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_row = HBoxContainer.new()
	_row.name = "TagRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", CHIP_SEP)
	_panel.add_child(_row)


## rows: Array of {name, count} 或 Dictionary 职业→人数。
func set_occupation_rows(rows) -> void:
	if _row == null or _panel == null:
		## 偶发：refresh 早于 _ready 时先建好子节点。
		_ensure_children()
	var display: Array[Dictionary] = []
	if rows is Dictionary:
		display = SynergyOccupations.to_display_rows(rows)
	elif rows is Array:
		for item in rows:
			if item is Dictionary:
				var n := int(item.get("count", 0))
				var nm := str(item.get("name", "")).strip_edges()
				if n >= 1 and SynergyOccupations.is_known(nm):
					display.append({"name": nm, "count": n})
		display.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return SynergyOccupations.ORDER.find(str(a.get("name", ""))) < SynergyOccupations.ORDER.find(str(b.get("name", "")))
		)
	_rebuild(display)


func _rebuild(rows: Array[Dictionary]) -> void:
	for child in _row.get_children():
		child.queue_free()
	if rows.is_empty():
		visible = false
		custom_minimum_size = Vector2.ZERO
		return
	visible = true
	var approx_w := PANEL_PAD * 2.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var text := "%s × %d" % [str(row.get("name", "")), int(row.get("count", 0))]
		label.text = text
		label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
		_row.add_child(label)
		## 粗估字宽（中文约 1em）；避免 await。
		approx_w += float(text.length()) * float(ROW_FONT_SIZE) * 0.95
		if i + 1 < rows.size():
			approx_w += float(CHIP_SEP)
	var h := PANEL_PAD * 1.3 + float(ROW_FONT_SIZE) + 6.0
	offset_right = offset_left + maxf(approx_w, 96.0)
	offset_bottom = offset_top + h
	custom_minimum_size = Vector2(offset_right - offset_left, h)
	_panel.custom_minimum_size = custom_minimum_size
