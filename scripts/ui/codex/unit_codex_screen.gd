extends Control
## 角色库：用战斗棋盘同款剪影铺招募池单位；可按 tier / 触发时机 / 技能效果筛选；长按弹技能卡。

const MAIN_MENU_PATH := "res://scenes/main/main_menu.tscn"
const RECRUIT_CONFIG_PATH := "res://resources/recruit/default_recruit_config.tres"
const CATALOG_COLUMNS := 5
## 触发按钮优先按此序排列（与 UnitInfoText 文案一致）；池中未出现的不显示。
const TRIGGER_ORDER: Array[StringName] = [
	CombatEvents.ON_COMBAT_START,
	CombatEvents.ON_ROUND_START,
	CombatEvents.ON_SUMMONED,
	CombatEvents.ON_FRIEND_SUMMONED,
	CombatEvents.ON_FRIEND_DEATH,
	CombatEvents.ON_ENEMY_DEATH,
	CombatEvents.ON_FRIEND_DAMAGE_TAKEN,
	CombatEvents.ON_DAMAGE_TAKEN,
	CombatEvents.ON_ATTACK_HIT,
	CombatEvents.ON_DEAL_DAMAGE,
	CombatEvents.ON_CRIT,
	CombatEvents.ON_KILL,
	CombatEvents.ON_DEATH,
	CombatEvents.ON_MOVE,
	ShopEvents.ON_BUY,
	ShopEvents.ON_SELL,
	ShopEvents.ON_LEVEL_UP,
]
const TRIGGER_NONE := &"__none__"

enum EffectCategory {
	ALL,
	ATTACK,
	HP,
	SPAWN,
	GOLD,
	DAMAGE,
	OTHER,
}

const EFFECT_CATEGORY_ORDER: Array[EffectCategory] = [
	EffectCategory.ALL,
	EffectCategory.ATTACK,
	EffectCategory.HP,
	EffectCategory.SPAWN,
	EffectCategory.GOLD,
	EffectCategory.DAMAGE,
	EffectCategory.OTHER,
]

@onready var _back_button: Button = %BackButton
@onready var _filter_toggle: Button = %FilterToggle
@onready var _filter_body: VBoxContainer = %FilterBody
@onready var _tier_filter: HBoxContainer = %TierFilter
@onready var _trigger_filter: HBoxContainer = %TriggerFilter
@onready var _effect_filter: HBoxContainer = %EffectFilter
@onready var _star_filter: HBoxContainer = %StarFilter
@onready var _count_label: Label = %CountLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _arena: RealtimeArenaView = %CodexArena

var _all_units: Array[UnitData] = []
## 0 = 全部；1–6 = 对应 tier
var _selected_tier: int = 0
## &"" = 全部时机；TRIGGER_NONE = 无技能；其余为 CombatEvents / ShopEvents
var _selected_trigger: StringName = &""
var _selected_effect: EffectCategory = EffectCategory.ALL
## 1 = 一星；2 = 一次三合一预览
var _preview_level: int = 1
## 顶部筛选栏展开；收起后棋盘更高。
var _filters_expanded: bool = true
var _tier_buttons: Dictionary = {} # tier -> Button
var _trigger_buttons: Dictionary = {} # StringName -> Button
var _effect_buttons: Dictionary = {} # EffectCategory -> Button
var _star_buttons: Dictionary = {} # level -> Button
var _tier_button_group: ButtonGroup = ButtonGroup.new()
var _trigger_button_group: ButtonGroup = ButtonGroup.new()
var _effect_button_group: ButtonGroup = ButtonGroup.new()
var _star_button_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	if _filter_toggle != null:
		_filter_toggle.pressed.connect(_on_filter_toggle_pressed)
	_tier_button_group.allow_unpress = false
	_trigger_button_group.allow_unpress = false
	_effect_button_group.allow_unpress = false
	_star_button_group.allow_unpress = false
	_load_pool()
	_build_tier_filters()
	_build_trigger_filters()
	_build_effect_filters()
	_build_star_filters()
	_apply_filter_collapsed()
	_rebuild_board()
	_back_button.grab_focus()


func _on_filter_toggle_pressed() -> void:
	_filters_expanded = not _filters_expanded
	_apply_filter_collapsed()


func _apply_filter_collapsed() -> void:
	if _filter_body != null:
		_filter_body.visible = _filters_expanded
	if _filter_toggle != null:
		_filter_toggle.text = "筛选 ▴" if _filters_expanded else "筛选 ▾"
		_filter_toggle.tooltip_text = (
			"收起筛选栏，扩大棋盘" if _filters_expanded else "展开品阶 / 触发 / 效果 / 星级筛选"
		)


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


func _build_trigger_filters() -> void:
	for child in _trigger_filter.get_children():
		child.queue_free()
	_trigger_buttons.clear()
	var present: Dictionary = {}
	var has_none := false
	for unit in _all_units:
		var triggers := _unit_triggers(unit)
		if triggers.is_empty():
			has_none = true
			continue
		for trigger in triggers:
			present[trigger] = true

	_add_trigger_button(&"", "全部时机")
	for trigger in TRIGGER_ORDER:
		if present.has(trigger):
			_add_trigger_button(trigger, _trigger_label(trigger))
	## 池中出现但未列入固定序的触发（兜底）。
	var extras: Array = present.keys()
	extras.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String(a) < String(b)
	)
	for trigger in extras:
		var key := trigger as StringName
		if _trigger_buttons.has(key):
			continue
		_add_trigger_button(key, _trigger_label(key))
	if has_none:
		_add_trigger_button(TRIGGER_NONE, "无技能")

	if _trigger_buttons.has(_selected_trigger):
		(_trigger_buttons[_selected_trigger] as Button).button_pressed = true
	elif _trigger_buttons.has(&""):
		_selected_trigger = &""
		(_trigger_buttons[&""] as Button).button_pressed = true


func _build_effect_filters() -> void:
	for child in _effect_filter.get_children():
		child.queue_free()
	_effect_buttons.clear()
	## 与触发筛一样：池中未出现的效果分类不显示（「全部效果」始终保留）。
	var present: Dictionary = {}
	for unit in _all_units:
		for cat in _unit_effect_categories(unit):
			present[cat] = true
	for category in EFFECT_CATEGORY_ORDER:
		if category != EffectCategory.ALL and not present.has(category):
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _effect_button_group
		button.custom_minimum_size = Vector2(0, 36)
		button.text = _effect_category_label(category)
		button.pressed.connect(_on_effect_pressed.bind(category))
		_effect_filter.add_child(button)
		_effect_buttons[category] = button
	if _effect_buttons.has(_selected_effect):
		(_effect_buttons[_selected_effect] as Button).button_pressed = true
	elif _effect_buttons.has(EffectCategory.ALL):
		_selected_effect = EffectCategory.ALL
		(_effect_buttons[EffectCategory.ALL] as Button).button_pressed = true


func _add_trigger_button(trigger: StringName, label: String) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _trigger_button_group
	button.custom_minimum_size = Vector2(0, 36)
	button.text = label
	button.pressed.connect(_on_trigger_pressed.bind(trigger))
	_trigger_filter.add_child(button)
	_trigger_buttons[trigger] = button


func _trigger_label(trigger: StringName) -> String:
	if UnitInfoText.TRIGGER_LABELS.has(trigger):
		return String(UnitInfoText.TRIGGER_LABELS[trigger])
	return String(trigger)


func _effect_category_label(category: EffectCategory) -> String:
	match category:
		EffectCategory.ALL:
			return "全部效果"
		EffectCategory.ATTACK:
			return "攻击力"
		EffectCategory.HP:
			return "生命值"
		EffectCategory.SPAWN:
			return "生成角色"
		EffectCategory.GOLD:
			return "金币"
		EffectCategory.DAMAGE:
			return "伤害"
		EffectCategory.OTHER:
			return "其他"
	return "其他"


func _on_tier_pressed(tier: int) -> void:
	if _selected_tier == tier:
		return
	_selected_tier = tier
	_rebuild_board()


func _on_trigger_pressed(trigger: StringName) -> void:
	if _selected_trigger == trigger:
		return
	_selected_trigger = trigger
	_rebuild_board()


func _on_effect_pressed(category: EffectCategory) -> void:
	if _selected_effect == category:
		return
	_selected_effect = category
	_rebuild_board()


func _build_star_filters() -> void:
	if _star_filter == null:
		return
	for child in _star_filter.get_children():
		child.queue_free()
	_star_buttons.clear()
	_add_star_button(1, "一星")
	_add_star_button(2, "三合一")
	if _star_buttons.has(_preview_level):
		(_star_buttons[_preview_level] as Button).button_pressed = true


func _add_star_button(level: int, label: String) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _star_button_group
	button.custom_minimum_size = Vector2(96, 36)
	button.text = label
	button.pressed.connect(_on_star_pressed.bind(level))
	_star_filter.add_child(button)
	_star_buttons[level] = button


func _on_star_pressed(level: int) -> void:
	if _preview_level == level:
		return
	_preview_level = clampi(level, 1, 3)
	_rebuild_board()


func _unit_triggers(unit: UnitData) -> Array[StringName]:
	var out: Array[StringName] = []
	var seen: Dictionary = {}
	if unit == null:
		return out
	_collect_ability_triggers(unit.ability, out, seen)
	for passive in unit.passives:
		_collect_ability_triggers(passive, out, seen)
	return out


func _collect_ability_triggers(
	ability: AbilityData,
	out: Array[StringName],
	seen: Dictionary,
) -> void:
	if ability == null:
		return
	for spec in ability.effect_specs:
		if spec == null or spec.trigger == &"":
			continue
		if seen.has(spec.trigger):
			continue
		seen[spec.trigger] = true
		out.append(spec.trigger)


func _unit_matches_trigger(unit: UnitData) -> bool:
	if _selected_trigger == &"":
		return true
	var triggers := _unit_triggers(unit)
	if _selected_trigger == TRIGGER_NONE:
		return triggers.is_empty()
	return triggers.has(_selected_trigger)


## 返回单位技能效果所属分类集合（可多标签）。
func _unit_effect_categories(unit: UnitData) -> Dictionary:
	var cats: Dictionary = {}
	if unit == null:
		return cats
	_collect_ability_effect_categories(unit.ability, cats)
	for passive in unit.passives:
		_collect_ability_effect_categories(passive, cats)
	return cats


func _collect_ability_effect_categories(ability: AbilityData, cats: Dictionary) -> void:
	if ability == null:
		return
	for spec in ability.effect_specs:
		if spec == null:
			continue
		for action in spec.actions:
			if action == null:
				continue
			for category in _classify_action_categories(action):
				cats[category] = true


## 单条效果可挂多标签（如读金加身 → 金币 + 攻击 + 生命）。
func _classify_action_categories(action: EffectAction) -> Array[EffectCategory]:
	var out: Array[EffectCategory] = []
	match action.action_type:
		EffectAction.Type.MODIFY_STAT, EffectAction.Type.PERMANENT_DECK_STAT:
			if action.stat_name == &"attack":
				out.append(EffectCategory.ATTACK)
			elif action.stat_name == &"max_hp":
				out.append(EffectCategory.HP)
			else:
				out.append(EffectCategory.OTHER)
		EffectAction.Type.HEAL, EffectAction.Type.SET_HP_FROM_ALLY_PERCENT, EffectAction.Type.SHOP_CHARACTER_BONUS_HP:
			out.append(EffectCategory.HP)
		EffectAction.Type.SPAWN_UNIT, EffectAction.Type.SPLIT_SELF:
			out.append(EffectCategory.SPAWN)
		EffectAction.Type.GRANT_GOLD:
			out.append(EffectCategory.GOLD)
		EffectAction.Type.BUFF_STATS_FROM_GOLD_HALF:
			out.append(EffectCategory.GOLD)
			out.append(EffectCategory.ATTACK)
			out.append(EffectCategory.HP)
		EffectAction.Type.DEAL_DAMAGE, EffectAction.Type.FRIENDS_HURT_AOE, EffectAction.Type.FUSE_EXPLODE:
			out.append(EffectCategory.DAMAGE)
		EffectAction.Type.ABSORB_STATS_AND_KILL:
			## 吞纳攻/血，可同时按攻击与生命筛选。
			out.append(EffectCategory.ATTACK)
			out.append(EffectCategory.HP)
		_:
			out.append(EffectCategory.OTHER)
	return out


func _unit_matches_effect(unit: UnitData) -> bool:
	if _selected_effect == EffectCategory.ALL:
		return true
	return _unit_effect_categories(unit).has(_selected_effect)


func _filtered_units() -> Array[UnitData]:
	var out: Array[UnitData] = []
	for unit in _all_units:
		if _selected_tier > 0 and maxi(1, unit.tier) != _selected_tier:
			continue
		if not _unit_matches_trigger(unit):
			continue
		if not _unit_matches_effect(unit):
			continue
		out.append(unit)
	return out


func _rebuild_board() -> void:
	var shown := _filtered_units()
	_empty_label.visible = shown.is_empty()
	_count_label.text = _format_count(shown.size())
	if _arena == null:
		return
	if shown.is_empty():
		_arena.clear_catalog_mode()
		return
	_arena.set_catalog_units(shown, CATALOG_COLUMNS, _preview_level)


func _format_count(count: int) -> String:
	var parts: PackedStringArray = []
	parts.append("一星" if _preview_level <= 1 else "三合一")
	if _selected_tier > 0:
		parts.append("T%d" % _selected_tier)
	if _selected_trigger == TRIGGER_NONE:
		parts.append("无技能")
	elif _selected_trigger != &"":
		parts.append(_trigger_label(_selected_trigger))
	if _selected_effect != EffectCategory.ALL:
		parts.append(_effect_category_label(_selected_effect))
	return "%s · %d 名" % [" · ".join(parts), count]


func _on_back_pressed() -> void:
	if _arena != null:
		_arena.clear_catalog_mode()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
