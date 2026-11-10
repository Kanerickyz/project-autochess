class_name SynergyTagHud
extends MarginContainer
## 顶栏职业 Tag 条：展示「职业 × 人数」；不挡棋盘。无阈值激活态。

const ROW_FONT_SIZE := 12
const CHIP_SEP := 8


var _row: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_bottom", 2)
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_right", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row = HBoxContainer.new()
	_row.name = "TagRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", CHIP_SEP)
	add_child(_row)
	visible = false


## rows: Array of {name, count} 或 Dictionary 职业→人数。
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
		display.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return SynergyOccupations.ORDER.find(str(a.get("name", ""))) < SynergyOccupations.ORDER.find(str(b.get("name", "")))
		)
	_rebuild(display)


func _rebuild(rows: Array[Dictionary]) -> void:
	for child in _row.get_children():
		child.queue_free()
	if rows.is_empty():
		visible = false
		return
	visible = true
	for row in rows:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s × %d" % [str(row.get("name", "")), int(row.get("count", 0))]
		label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0, 1.0))
		_row.add_child(label)
