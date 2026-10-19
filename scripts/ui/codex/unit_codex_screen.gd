extends Control
## 角色库：列出招募池全部单位，按战斗卡片样式网格展示，可按 tier 筛选。

const MAIN_MENU_PATH := "res://scenes/main/main_menu.tscn"
const RECRUIT_CONFIG_PATH := "res://resources/recruit/default_recruit_config.tres"
const CARD_SCENE := preload("res://scenes/ui/unit_card_display.tscn")
const ENTRY_SIZE := Vector2(120, 168)
const GRID_COLUMNS := 4

@onready var _back_button: Button = %BackButton
@onready var _tier_filter: HBoxContainer = %TierFilter
@onready var _unit_grid: GridContainer = %UnitGrid
@onready var _count_label: Label = %CountLabel
@onready var _empty_label: Label = %EmptyLabel

var _all_units: Array[UnitData] = []
## 0 = 全部；1–6 = 对应 tier
var _selected_tier: int = 0
var _tier_buttons: Dictionary = {} # tier -> Button
var _tier_button_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_tier_button_group.allow_unpress = false
	_unit_grid.columns = GRID_COLUMNS
	_load_pool()
	_build_tier_filters()
	_rebuild_grid()
	_back_button.grab_focus()


func _load_pool() -> void:
	_all_units.clear()
	var cfg := load(RECRUIT_CONFIG_PATH) as RecruitConfig
	if cfg == null:
		push_error("UnitCodex: missing recruit config at %s" % RECRUIT_CONFIG_PATH)
		return
	var seen: Dictionary = {}
	for unit in cfg.get_unit_pool():
		if unit == null:
			continue
		var key := unit.id if not unit.id.is_empty() else unit.resource_path
		if seen.has(key):
			continue
		seen[key] = true
		_all_units.append(unit)
	_all_units.sort_custom(_cmp_units)


func _cmp_units(a: UnitData, b: UnitData) -> bool:
	if a.tier != b.tier:
		return a.tier < b.tier
	var an := a.display_name if not a.display_name.is_empty() else a.id
	var bn := b.display_name if not b.display_name.is_empty() else b.id
	return an < bn


func _build_tier_filters() -> void:
	for child in _tier_filter.get_children():
		child.queue_free()
	_tier_buttons.clear()
	var tiers: Array[int] = [0]
	var present: Dictionary = {}
	for unit in _all_units:
		present[maxi(1, unit.tier)] = true
	var sorted_tiers: Array = present.keys()
	sorted_tiers.sort()
	for t in sorted_tiers:
		tiers.append(int(t))
	for tier in tiers:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _tier_button_group
		button.custom_minimum_size = Vector2(64, 36)
		button.text = "全部" if tier == 0 else "T%d" % tier
		button.pressed.connect(_on_tier_pressed.bind(tier))
		_tier_filter.add_child(button)
		_tier_buttons[tier] = button
	if _tier_buttons.has(_selected_tier):
		(_tier_buttons[_selected_tier] as Button).button_pressed = true


func _on_tier_pressed(tier: int) -> void:
	if _selected_tier == tier:
		return
	_selected_tier = tier
	_rebuild_grid()


func _rebuild_grid() -> void:
	for child in _unit_grid.get_children():
		child.queue_free()
	var shown := 0
	for unit in _all_units:
		if _selected_tier > 0 and maxi(1, unit.tier) != _selected_tier:
			continue
		_unit_grid.add_child(_make_entry(unit))
		shown += 1
	_empty_label.visible = shown == 0
	_count_label.text = "共 %d 名" % shown if _selected_tier == 0 else "T%d · %d 名" % [_selected_tier, shown]


func _make_entry(unit: UnitData) -> Control:
	var root := Control.new()
	root.custom_minimum_size = ENTRY_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0.16, 0.14, 0.12, 0.92)
	root.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vbox)

	var name_label := Label.new()
	name_label.text = unit.display_name if not unit.display_name.is_empty() else unit.id
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var card_host := Control.new()
	card_host.custom_minimum_size = Vector2(110, 130)
	card_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(card_host)

	var card := CARD_SCENE.instantiate() as UnitCardDisplay
	if card != null:
		card_host.add_child(card)
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.configure(UnitCardDisplay.SIZE_DEFAULT)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.bind_unit_data(unit)
		card.set_level(1)

	var tier_label := Label.new()
	tier_label.text = "T%d" % maxi(1, unit.tier)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_font_size_override("font_size", 13)
	var tier_color := UnitCardDisplay.TIER_LABEL_COLORS[
		clampi(maxi(1, unit.tier) - 1, 0, UnitCardDisplay.TIER_LABEL_COLORS.size() - 1)
	]
	tier_label.add_theme_color_override("font_color", tier_color)
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tier_label)

	return root


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
