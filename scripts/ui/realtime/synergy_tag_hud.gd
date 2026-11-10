class_name SynergyTagHud
extends Control
## 左上角职业 Tag 条：仅展示「职业名 × 数量」；无阈值激活态。

const ROW_FONT_SIZE := 13
const PANEL_ALPHA := 0.55
const PAD := 8.0
const ROW_GAP := 2.0


var _list: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 8.0
	offset_top = 8.0
	offset_right = 128.0
	offset_bottom = 8.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, PANEL_ALPHA)
	style.content_margin_left = PAD
	style.content_margin_top = PAD * 0.75
	style.content_margin_right = PAD
	style.content_margin_bottom = PAD * 0.75
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", int(ROW_GAP))
	panel.add_child(_list)
	visible = false


## rows: Array of {name, count} 或 Dictionary 职业→人数（内部会再过滤）。
func set_occupation_rows(rows) -> void:
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
		## 稳定排序：按六类固定词表
		display.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return SynergyOccupations.ORDER.find(str(a.get("name", ""))) < SynergyOccupations.ORDER.find(str(b.get("name", "")))
		)
	_rebuild(display)


func _rebuild(rows: Array[Dictionary]) -> void:
	for child in _list.get_children():
		child.queue_free()
	if rows.is_empty():
		visible = false
		custom_minimum_size = Vector2.ZERO
		return
	visible = true
	for row in rows:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s × %d" % [str(row.get("name", "")), int(row.get("count", 0))]
		label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 0.92))
		_list.add_child(label)
	## 窄竖条：按行数估高，宽固定可读
	var h := PAD * 1.5 + float(rows.size()) * (float(ROW_FONT_SIZE) + ROW_GAP + 4.0)
	offset_right = offset_left + 112.0
	offset_bottom = offset_top + h
	custom_minimum_size = Vector2(104.0, h)
