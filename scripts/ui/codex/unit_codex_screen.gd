extends Control
## 角色库：用战斗棋盘同款剪影铺招募池单位，按 tier 筛选；长按弹出技能卡。

const MAIN_MENU_PATH := "res://scenes/main/main_menu.tscn"
const RECRUIT_CONFIG_PATH := "res://resources/recruit/default_recruit_config.tres"
const CATALOG_COLUMNS := 5

@onready var _back_button: Button = %BackButton
@onready var _tier_filter: HBoxContainer = %TierFilter
@onready var _count_label: Label = %CountLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _arena: RealtimeArenaView = %CodexArena

var _all_units: Array[UnitData] = []
## 0 = 全部；1–6 = 对应 tier
var _selected_tier: int = 0
var _tier_buttons: Dictionary = {} # tier -> Button
var _tier_button_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_tier_button_group.allow_unpress = false
	_load_pool()
	_build_tier_filters()
	_rebuild_board()
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
	_rebuild_board()


func _filtered_units() -> Array[UnitData]:
	var out: Array[UnitData] = []
	for unit in _all_units:
		if _selected_tier > 0 and maxi(1, unit.tier) != _selected_tier:
			continue
		out.append(unit)
	return out


func _rebuild_board() -> void:
	var shown := _filtered_units()
	_empty_label.visible = shown.is_empty()
	_count_label.text = (
		"共 %d 名" % shown.size()
		if _selected_tier == 0
		else "T%d · %d 名" % [_selected_tier, shown.size()]
	)
	if _arena == null:
		return
	if shown.is_empty():
		_arena.clear_catalog_mode()
		return
	_arena.set_catalog_units(shown, CATALOG_COLUMNS)


func _on_back_pressed() -> void:
	if _arena != null:
		_arena.clear_catalog_mode()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
