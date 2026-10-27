@tool
extends Control

enum SortKey { ID, DISPLAY_NAME, SPEC_COUNT }

const ABILITIES_DIR := "res://resources/abilities"

const TRIGGER_ENTRIES: Array[Dictionary] = [
	{"id": CombatEvents.ON_COMBAT_START, "label": "开战时"},
	{"id": CombatEvents.ON_COMBAT_END, "label": "战斗结束且自身存活时"},
	{"id": CombatEvents.ON_FRIEND_SUMMONED, "label": "友方召唤时"},
	{"id": CombatEvents.ON_FRIEND_DEATH, "label": "友方死亡时"},
	{"id": CombatEvents.ON_ROUND_START, "label": "回合开始时"},
	{"id": CombatEvents.ON_DAMAGE_TAKEN, "label": "受伤时"},
	{"id": CombatEvents.ON_DEAL_DAMAGE, "label": "造成伤害时"},
	{"id": CombatEvents.ON_KILL, "label": "击杀时"},
	{"id": CombatEvents.ON_FRIEND_KILL, "label": "友方击杀时"},
	{"id": CombatEvents.ON_DEATH, "label": "死亡时"},
	{"id": CombatEvents.ON_ATTACK_HIT, "label": "攻击命中时"},
	{"id": CombatEvents.ON_MOVE, "label": "移动时"},
	{"id": ShopEvents.ON_BUY, "label": "购买时"},
	{"id": ShopEvents.ON_SELL, "label": "出售时"},
	{"id": ShopEvents.ON_LEVEL_UP, "label": "升级时"},
]

const TARGET_ENTRIES: Array[Dictionary] = [
	{"id": EffectSpec.TargetSelector.SELF, "label": "对自身"},
	{"id": EffectSpec.TargetSelector.EVENT_TARGET, "label": "对事件目标"},
	{"id": EffectSpec.TargetSelector.RANDOM_ALLY, "label": "对随机队友"},
	{"id": EffectSpec.TargetSelector.ALL_UNITS, "label": "对全场"},
	{"id": EffectSpec.TargetSelector.RANDOM_ENEMY, "label": "对随机敌人"},
	{"id": EffectSpec.TargetSelector.HEALTHIEST_ALLY, "label": "对最健康队友"},
	{"id": EffectSpec.TargetSelector.RANDOM_DECK_ALLY, "label": "对随机牌库队友"},
	{"id": EffectSpec.TargetSelector.ALL_SHOP_CHARACTERS, "label": "对商店角色"},
	{"id": EffectSpec.TargetSelector.ALL_ALLIES, "label": "对全体队友"},
	{"id": EffectSpec.TargetSelector.FIRST_ENEMY, "label": "对前排敌人"},
	{"id": EffectSpec.TargetSelector.LAST_ENEMY, "label": "对后排敌人"},
	{"id": EffectSpec.TargetSelector.UNIT_AHEAD_OF_MOVE, "label": "移动方向前 1 格敌人"},
]

const ACTION_TYPE_ENTRIES: Array[Dictionary] = [
	{"id": EffectAction.Type.MODIFY_STAT, "label": "修改属性"},
	{"id": EffectAction.Type.HEAL, "label": "治疗"},
	{"id": EffectAction.Type.SPAWN_UNIT, "label": "召唤单位"},
	{"id": EffectAction.Type.DEAL_DAMAGE, "label": "造成伤害"},
	{"id": EffectAction.Type.APPLY_COMBAT_STATUS, "label": "施加战斗状态"},
	{"id": EffectAction.Type.REMOVE_COMBAT_STATUS, "label": "驱散战斗状态"},
	{"id": EffectAction.Type.SET_HP_FROM_ALLY_PERCENT, "label": "复制生命%"},
	{"id": EffectAction.Type.GRANT_GOLD, "label": "获得金币"},
	{"id": EffectAction.Type.PERMANENT_DECK_STAT, "label": "永久牌库属性"},
	{"id": EffectAction.Type.STOCK_FREE_BUFF, "label": "补充免费增益"},
	{"id": EffectAction.Type.SHOP_CHARACTER_BONUS_HP, "label": "商店角色加血"},
	{"id": EffectAction.Type.FUSE_EXPLODE, "label": "引信爆炸"},
]

@onready var _search_edit: LineEdit = %SearchEdit
@onready var _tab_bar: TabBar = %TabBar
@onready var _sort_option: OptionButton = %SortOption
@onready var _sort_desc_check: CheckBox = %SortDescCheck
@onready var _ability_list: ItemList = %AbilityList
@onready var _id_edit: LineEdit = %IdEdit
@onready var _name_edit: LineEdit = %NameEdit
@onready var _shop_cost_spin: SpinBox = %ShopCostSpin
@onready var _skip_attack_after_move_check: CheckBox = %SkipAttackAfterMoveCheck
@onready var _can_normal_attack_check: CheckBox = %CanNormalAttackCheck
@onready var _uses_line_attack_check: CheckBox = %UsesLineAttackCheck
@onready var _line_attack_uses_attack_check: CheckBox = %LineAttackUsesAttackCheck
@onready var _line_attack_damage_spin: SpinBox = %LineAttackDamageSpin
@onready var _preview_label: Label = %PreviewLabel
@onready var _spec_list: ItemList = %SpecList
@onready var _trigger_option: OptionButton = %TriggerOption
@onready var _target_option: OptionButton = %TargetOption
@onready var _exclude_owner_check: CheckBox = %ExcludeOwnerCheck
@onready var _target_count_spin: SpinBox = %TargetCountSpin
@onready var _action_list: ItemList = %ActionList
@onready var _action_type_option: OptionButton = %ActionTypeOption
@onready var _stat_name_option: OptionButton = %StatNameOption
@onready var _value_spin: SpinBox = %ValueSpin
@onready var _damage_mode_option: OptionButton = %DamageModeOption
@onready var _percent_spin: SpinBox = %PercentSpin
@onready var _spawn_unit_picker: EditorResourcePicker = %SpawnUnitPicker
@onready var _spawn_hp_spin: SpinBox = %SpawnHpSpin
@onready var _buff_card_picker: EditorResourcePicker = %BuffCardPicker
@onready var _stat_name_label: Label = %StatNameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _damage_mode_label: Label = %DamageModeLabel
@onready var _percent_label: Label = %PercentLabel
@onready var _spawn_unit_label: Label = %SpawnUnitLabel
@onready var _spawn_hp_label: Label = %SpawnHpLabel
@onready var _buff_card_label: Label = %BuffCardLabel
@onready var _status_label: Label = %StatusLabel

var _editor_interface: EditorInterface
var _all_entries: Array = []
var _filtered_entries: Array = []
var _current_path: String = ""
var _current_data: AbilityData
var _selected_spec_index: int = -1
var _selected_action_index: int = -1
var _loading_form: bool = false
var _pending_delete_path: String = ""
var _delete_dialog: ConfirmationDialog


func _ready() -> void:
	_sort_option.clear()
	_sort_option.add_item("id", SortKey.ID)
	_sort_option.add_item("显示名", SortKey.DISPLAY_NAME)
	_sort_option.add_item("Spec 数", SortKey.SPEC_COUNT)
	_sort_option.item_selected.connect(_on_sort_changed)
	_sort_desc_check.toggled.connect(_on_sort_changed)

	_populate_trigger_options()
	_populate_target_options()
	_populate_action_type_options()
	_populate_stat_name_options()
	_populate_damage_mode_options()

	_search_edit.text_changed.connect(_on_search_changed)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_ability_list.item_selected.connect(_on_ability_selected)

	_id_edit.text_changed.connect(_on_basic_field_changed)
	_name_edit.text_changed.connect(_on_basic_field_changed)
	_shop_cost_spin.value_changed.connect(_on_basic_field_changed.unbind(1))
	_skip_attack_after_move_check.toggled.connect(_on_basic_field_changed.unbind(1))
	_can_normal_attack_check.toggled.connect(_on_basic_field_changed.unbind(1))
	_uses_line_attack_check.toggled.connect(_on_line_attack_field_changed)
	_line_attack_uses_attack_check.toggled.connect(_on_line_attack_field_changed)
	_line_attack_damage_spin.value_changed.connect(_on_basic_field_changed.unbind(1))

	_spec_list.item_selected.connect(_on_spec_selected)
	_trigger_option.item_selected.connect(_on_spec_field_changed.unbind(1))
	_target_option.item_selected.connect(_on_spec_field_changed.unbind(1))
	_exclude_owner_check.toggled.connect(_on_spec_field_changed.unbind(1))
	_target_count_spin.value_changed.connect(_on_spec_field_changed.unbind(1))

	_action_list.item_selected.connect(_on_action_selected)
	_action_type_option.item_selected.connect(_on_action_field_changed.unbind(1))
	_stat_name_option.item_selected.connect(_on_action_field_changed.unbind(1))
	_value_spin.value_changed.connect(_on_action_field_changed.unbind(1))
	_damage_mode_option.item_selected.connect(_on_action_field_changed.unbind(1))
	_percent_spin.value_changed.connect(_on_action_field_changed.unbind(1))
	_spawn_unit_picker.resource_changed.connect(_on_action_resource_changed)
	_spawn_hp_spin.value_changed.connect(_on_action_field_changed.unbind(1))
	_buff_card_picker.resource_changed.connect(_on_action_resource_changed)

	%AddSpecButton.pressed.connect(_on_add_spec)
	%RemoveSpecButton.pressed.connect(_on_remove_spec)
	%SpecUpButton.pressed.connect(_on_move_spec.bind(-1))
	%SpecDownButton.pressed.connect(_on_move_spec.bind(1))
	%AddActionButton.pressed.connect(_on_add_action)
	%RemoveActionButton.pressed.connect(_on_remove_action)
	%ActionUpButton.pressed.connect(_on_move_action.bind(-1))
	%ActionDownButton.pressed.connect(_on_move_action.bind(1))
	%GenNameButton.pressed.connect(_on_generate_display_name)
	%NewButton.pressed.connect(_on_new_pressed)
	%DuplicateButton.pressed.connect(_on_duplicate_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%InspectorButton.pressed.connect(_on_inspector_pressed)
	%RefreshButton.pressed.connect(_reload_catalog)

	_ensure_delete_dialog()

	if Engine.is_editor_hint():
		_reload_catalog()


func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _populate_trigger_options() -> void:
	_trigger_option.clear()
	for i in TRIGGER_ENTRIES.size():
		_trigger_option.add_item(TRIGGER_ENTRIES[i]["label"], i)


func _populate_target_options() -> void:
	_target_option.clear()
	for entry in TARGET_ENTRIES:
		_target_option.add_item(entry["label"], entry["id"])


func _populate_action_type_options() -> void:
	_action_type_option.clear()
	for entry in ACTION_TYPE_ENTRIES:
		_action_type_option.add_item(entry["label"], entry["id"])


func _populate_stat_name_options() -> void:
	_stat_name_option.clear()
	_stat_name_option.add_item("attack", 0)
	_stat_name_option.set_item_metadata(0, &"attack")
	_stat_name_option.add_item("max_hp", 1)
	_stat_name_option.set_item_metadata(1, &"max_hp")


func _populate_damage_mode_options() -> void:
	_damage_mode_option.clear()
	_damage_mode_option.add_item("固定数值", EffectAction.DamageMode.FIXED)
	_damage_mode_option.add_item("攻击力%", EffectAction.DamageMode.OWNER_ATTACK_PERCENT)


func _safe_option_select(option: OptionButton, index: int) -> void:
	if option == null or option.item_count <= 0:
		return
	option.select(clampi(index, 0, option.item_count - 1))


func _safe_item_list_select(list: ItemList, index: int) -> void:
	if list == null or list.item_count <= 0:
		return
	list.select(clampi(index, 0, list.item_count - 1))


func _get_selected_trigger() -> StringName:
	var idx := _trigger_option.selected
	if idx < 0 or idx >= TRIGGER_ENTRIES.size():
		return &""
	return TRIGGER_ENTRIES[idx]["id"]


func _set_trigger_option(trigger: StringName) -> void:
	for i in TRIGGER_ENTRIES.size():
		if TRIGGER_ENTRIES[i]["id"] == trigger:
			_safe_option_select(_trigger_option, i)
			return
	_safe_option_select(_trigger_option, 0)


func _select_option_by_id(option: OptionButton, id: Variant, fallback: int = 0) -> void:
	if option == null or option.item_count <= 0:
		return
	for i in option.item_count:
		if option.get_item_id(i) == id:
			_safe_option_select(option, i)
			return
	_safe_option_select(option, fallback)


func _reload_catalog() -> void:
	_all_entries = AbilityCatalog.scan_abilities()
	_refresh_ability_list()
	_set_status("已扫描 %d 个技能" % _all_entries.size())


func _get_domain_filter() -> AbilityCatalog.Domain:
	match _tab_bar.current_tab:
		0:
			return AbilityCatalog.Domain.COMBAT
		1:
			return AbilityCatalog.Domain.SHOP
		_:
			return AbilityCatalog.Domain.ALL


func _apply_search_filter(entries: Array) -> Array:
	var query := _search_edit.text.strip_edges().to_lower()
	if query.is_empty():
		return entries
	var filtered: Array = []
	for entry in entries:
		var data: AbilityData = entry.get("data")
		if data == null:
			continue
		var preview := UnitInfoText.get_ability_description(data)
		var hay := "%s %s %s" % [data.id, data.display_name, preview]
		if hay.to_lower().contains(query):
			filtered.append(entry)
	return filtered


func _on_sort_changed(_unused = null) -> void:
	_refresh_ability_list()


func _apply_sort(entries: Array) -> Array:
	var sorted: Array = entries.duplicate()
	var key: SortKey = _sort_option.get_selected_id() as SortKey
	if key < 0:
		key = SortKey.DISPLAY_NAME
	var descending := _sort_desc_check.button_pressed
	sorted.sort_custom(func(a, b) -> bool:
		return _compare_entries(a, b, key, descending)
	)
	return sorted


func _compare_entries(a: Dictionary, b: Dictionary, key: SortKey, descending: bool) -> bool:
	var da: AbilityData = a.get("data")
	var db: AbilityData = b.get("data")
	if da == null:
		return not descending
	if db == null:
		return descending
	var cmp := 0
	match key:
		SortKey.ID:
			cmp = _cmp_str(da.id, db.id)
		SortKey.SPEC_COUNT:
			cmp = _cmp_int(da.effect_specs.size(), db.effect_specs.size())
		_:
			var na := da.display_name if not da.display_name.is_empty() else da.id
			var nb := db.display_name if not db.display_name.is_empty() else db.id
			cmp = _cmp_str(na, nb)
	if cmp == 0:
		cmp = _cmp_str(a.get("path", ""), b.get("path", ""))
	if descending:
		return cmp > 0
	return cmp < 0


func _cmp_str(a: String, b: String) -> int:
	if a < b:
		return -1
	if a > b:
		return 1
	return 0


func _cmp_int(a: int, b: int) -> int:
	if a < b:
		return -1
	if a > b:
		return 1
	return 0


func _refresh_ability_list() -> void:
	var selected_path := _current_path
	_filtered_entries = _apply_sort(
		_apply_search_filter(
			AbilityCatalog.filter_by_domain(_all_entries, _get_domain_filter())
		)
	)
	_ability_list.clear()
	for entry in _filtered_entries:
		var data: AbilityData = entry.get("data")
		if data == null:
			continue
		var preview := UnitInfoText.get_ability_description(data)
		if preview.length() > 48:
			preview = preview.substr(0, 45) + "…"
		var text := "%s  (%s)" % [
			data.display_name if not data.display_name.is_empty() else data.id,
			data.id,
		]
		if not preview.is_empty():
			text += " — " + preview
		_ability_list.add_item(text)
	if not selected_path.is_empty():
		_select_path_in_list(selected_path, false)


func _on_search_changed(_text: String) -> void:
	_refresh_ability_list()


func _on_tab_changed(_tab: int) -> void:
	_refresh_ability_list()


func _on_ability_selected(index: int) -> void:
	if index < 0 or index >= _filtered_entries.size():
		return
	var entry: Dictionary = _filtered_entries[index]
	_current_path = entry.get("path", "")
	_current_data = entry.get("data")
	_selected_spec_index = -1
	_selected_action_index = -1
	_load_form_from_data(_current_data)
	_check_warnings()


func _load_form_from_data(data: AbilityData) -> void:
	_loading_form = true
	if data == null:
		_loading_form = false
		return
	_id_edit.text = data.id
	_name_edit.text = data.display_name
	_shop_cost_spin.value = data.shop_cost
	_skip_attack_after_move_check.button_pressed = data.skip_attack_after_move
	_can_normal_attack_check.button_pressed = data.can_normal_attack
	_uses_line_attack_check.button_pressed = data.uses_line_attack
	_line_attack_uses_attack_check.button_pressed = data.line_attack_uses_attack
	_line_attack_damage_spin.value = data.line_attack_damage
	_update_line_attack_editor_state()
	_refresh_spec_list()
	if data.effect_specs.is_empty():
		_clear_spec_editor()
	else:
		_selected_spec_index = 0
		_spec_list.select(0)
		_load_spec_editor(data.effect_specs[0])
	_update_preview()
	_loading_form = false


func _refresh_spec_list() -> void:
	_spec_list.clear()
	if _current_data == null:
		return
	for spec in _current_data.effect_specs:
		if spec == null:
			_spec_list.add_item("（空 spec）")
		else:
			var line := UnitInfoText.format_effect_spec(spec)
			if line.is_empty():
				line = "（未配置）"
			_spec_list.add_item(line)


func _get_selected_spec() -> EffectSpec:
	if _current_data == null or _selected_spec_index < 0:
		return null
	if _selected_spec_index >= _current_data.effect_specs.size():
		return null
	return _current_data.effect_specs[_selected_spec_index]


func _get_selected_action() -> EffectAction:
	var spec := _get_selected_spec()
	if spec == null or _selected_action_index < 0:
		return null
	if _selected_action_index >= spec.actions.size():
		return null
	return spec.actions[_selected_action_index]


func _load_spec_editor(spec: EffectSpec) -> void:
	_loading_form = true
	if spec == null:
		_clear_spec_editor()
		_loading_form = false
		return
	_set_trigger_option(spec.trigger)
	_select_option_by_id(_target_option, spec.target_selector, 0)
	_exclude_owner_check.button_pressed = spec.exclude_owner
	_target_count_spin.value = spec.target_count
	_sync_spec_field_availability(spec.target_selector)
	_refresh_action_list(spec)
	if spec.actions.is_empty():
		_clear_action_editor()
	else:
		_selected_action_index = 0
		_action_list.select(0)
		_load_action_editor(spec.actions[0])
	_loading_form = false


func _clear_spec_editor() -> void:
	_loading_form = true
	_safe_option_select(_trigger_option, 0)
	_safe_option_select(_target_option, 0)
	_exclude_owner_check.button_pressed = false
	_target_count_spin.value = 1
	_action_list.clear()
	_clear_action_editor()
	_loading_form = false


func _refresh_action_list(spec: EffectSpec) -> void:
	_action_list.clear()
	if spec == null:
		return
	for action in spec.actions:
		if action == null:
			_action_list.add_item("（空 action）")
		else:
			var line := UnitInfoText.format_action(action)
			if line.is_empty():
				line = "（未配置）"
			_action_list.add_item(line)


func _load_action_editor(action: EffectAction) -> void:
	_loading_form = true
	if action == null:
		_clear_action_editor()
		_loading_form = false
		return
	_select_option_by_id(_action_type_option, action.action_type, 0)
	var stat_idx := 1 if action.stat_name == &"max_hp" else 0
	_safe_option_select(_stat_name_option, stat_idx)
	_value_spin.value = action.value
	if action.action_type == EffectAction.Type.FUSE_EXPLODE:
		_value_spin.value = action.threshold
	_select_option_by_id(_damage_mode_option, action.damage_mode, 0)
	_percent_spin.value = action.percent
	_spawn_unit_picker.edited_resource = action.spawn_unit
	_spawn_hp_spin.value = action.spawn_hp_override
	_buff_card_picker.edited_resource = action.buff_card
	_sync_action_form_visibility(action.action_type, action.damage_mode)
	_loading_form = false


func _clear_action_editor() -> void:
	_loading_form = true
	_safe_option_select(_action_type_option, 0)
	_safe_option_select(_stat_name_option, 0)
	_value_spin.value = 1
	_safe_option_select(_damage_mode_option, 0)
	_percent_spin.value = 100
	_spawn_unit_picker.edited_resource = null
	_spawn_hp_spin.value = 0
	_buff_card_picker.edited_resource = null
	_sync_action_form_visibility(EffectAction.Type.MODIFY_STAT, EffectAction.DamageMode.FIXED)
	_loading_form = false


func _sync_spec_field_availability(target: EffectSpec.TargetSelector) -> void:
	var deck_target := target == EffectSpec.TargetSelector.RANDOM_DECK_ALLY
	_exclude_owner_check.disabled = not (
		target == EffectSpec.TargetSelector.RANDOM_ALLY or deck_target
	)
	_target_count_spin.editable = deck_target


func _sync_action_form_visibility(
	action_type: EffectAction.Type,
	damage_mode: EffectAction.DamageMode = EffectAction.DamageMode.FIXED,
) -> void:
	var show_stat := action_type in [
		EffectAction.Type.MODIFY_STAT,
		EffectAction.Type.PERMANENT_DECK_STAT,
	]
	var show_value := action_type in [
		EffectAction.Type.MODIFY_STAT,
		EffectAction.Type.HEAL,
		EffectAction.Type.DEAL_DAMAGE,
		EffectAction.Type.SET_HP_FROM_ALLY_PERCENT,
		EffectAction.Type.GRANT_GOLD,
		EffectAction.Type.PERMANENT_DECK_STAT,
		EffectAction.Type.STOCK_FREE_BUFF,
		EffectAction.Type.SHOP_CHARACTER_BONUS_HP,
	]
	var show_fuse_round := action_type == EffectAction.Type.FUSE_EXPLODE
	var show_damage := action_type == EffectAction.Type.DEAL_DAMAGE
	var show_percent := show_damage and damage_mode == EffectAction.DamageMode.OWNER_ATTACK_PERCENT
	var show_spawn := action_type == EffectAction.Type.SPAWN_UNIT
	var show_buff := action_type == EffectAction.Type.STOCK_FREE_BUFF

	_stat_name_label.visible = show_stat
	_stat_name_option.visible = show_stat
	_value_label.visible = (show_value and not show_percent) or show_fuse_round
	_value_spin.visible = (show_value and not show_percent) or show_fuse_round
	_damage_mode_label.visible = show_damage
	_damage_mode_option.visible = show_damage
	_percent_label.visible = show_percent
	_percent_spin.visible = show_percent
	_spawn_unit_label.visible = show_spawn
	_spawn_unit_picker.visible = show_spawn
	_spawn_hp_label.visible = show_spawn
	_spawn_hp_spin.visible = show_spawn
	_buff_card_label.visible = show_buff
	_buff_card_picker.visible = show_buff


func _apply_spec_editor_to(spec: EffectSpec) -> void:
	if spec == null:
		return
	spec.trigger = _get_selected_trigger()
	spec.target_selector = _target_option.get_selected_id() as EffectSpec.TargetSelector
	spec.exclude_owner = _exclude_owner_check.button_pressed
	spec.target_count = int(_target_count_spin.value)


func _apply_action_editor_to(action: EffectAction) -> void:
	if action == null:
		return
	action.action_type = _action_type_option.get_selected_id() as EffectAction.Type
	var stat_meta: StringName = &"attack"
	if _stat_name_option.selected == 1:
		stat_meta = &"max_hp"
	action.stat_name = stat_meta
	action.value = int(_value_spin.value)
	if action.action_type == EffectAction.Type.FUSE_EXPLODE:
		action.threshold = int(_value_spin.value)
	action.damage_mode = _damage_mode_option.get_selected_id() as EffectAction.DamageMode
	action.percent = int(_percent_spin.value)
	action.spawn_unit = _spawn_unit_picker.edited_resource as UnitData
	action.spawn_hp_override = int(_spawn_hp_spin.value)
	action.buff_card = _buff_card_picker.edited_resource as BuffCardData


func _on_line_attack_field_changed(_unused = null) -> void:
	if _loading_form or _current_data == null:
		return
	_current_data.uses_line_attack = _uses_line_attack_check.button_pressed
	_current_data.line_attack_uses_attack = _line_attack_uses_attack_check.button_pressed
	_update_line_attack_editor_state()
	_update_preview()


func _update_line_attack_editor_state() -> void:
	var uses_attack := _line_attack_uses_attack_check.button_pressed
	_line_attack_damage_spin.editable = not uses_attack


func _on_basic_field_changed(_unused = null) -> void:
	if _loading_form or _current_data == null:
		return
	_current_data.id = _id_edit.text.strip_edges()
	_current_data.display_name = _name_edit.text.strip_edges()
	_current_data.shop_cost = int(_shop_cost_spin.value)
	_update_preview()


func _on_spec_selected(index: int) -> void:
	if _loading_form or _current_data == null:
		return
	if _selected_spec_index >= 0 and _selected_spec_index < _current_data.effect_specs.size():
		_apply_spec_editor_to(_current_data.effect_specs[_selected_spec_index])
	_selected_spec_index = index
	var spec := _get_selected_spec()
	_selected_action_index = -1
	_load_spec_editor(spec)


func _on_spec_field_changed(_unused = null) -> void:
	if _loading_form:
		return
	var spec := _get_selected_spec()
	if spec == null:
		return
	spec.trigger = _get_selected_trigger()
	spec.target_selector = _target_option.get_selected_id() as EffectSpec.TargetSelector
	spec.exclude_owner = _exclude_owner_check.button_pressed
	spec.target_count = int(_target_count_spin.value)
	_sync_spec_field_availability(spec.target_selector)
	_refresh_spec_list()
	_safe_item_list_select(_spec_list, _selected_spec_index)
	_refresh_action_list(spec)
	_update_preview()


func _on_action_selected(index: int) -> void:
	if _loading_form:
		return
	var spec := _get_selected_spec()
	if spec == null:
		return
	if _selected_action_index >= 0 and _selected_action_index < spec.actions.size():
		_apply_action_editor_to(spec.actions[_selected_action_index])
	_selected_action_index = index
	_load_action_editor(_get_selected_action())


func _on_action_field_changed(_unused = null) -> void:
	if _loading_form:
		return
	var action := _get_selected_action()
	if action == null:
		return
	_apply_action_editor_to(action)
	_sync_action_form_visibility(action.action_type, action.damage_mode)
	var spec := _get_selected_spec()
	if spec != null:
		_refresh_action_list(spec)
		_safe_item_list_select(_action_list, _selected_action_index)
	_update_preview()


func _on_action_resource_changed(_resource: Resource) -> void:
	_on_action_field_changed()


func _on_add_spec() -> void:
	if _current_data == null:
		return
	_commit_open_editors()
	var spec := EffectSpec.new()
	var action := EffectAction.new()
	spec.actions = [action]
	_current_data.effect_specs.append(spec)
	_selected_spec_index = _current_data.effect_specs.size() - 1
	_refresh_spec_list()
	_spec_list.select(_selected_spec_index)
	_load_spec_editor(spec)
	_update_preview()


func _on_remove_spec() -> void:
	if _current_data == null or _selected_spec_index < 0:
		return
	_current_data.effect_specs.remove_at(_selected_spec_index)
	_selected_spec_index = mini(_selected_spec_index, _current_data.effect_specs.size() - 1)
	_refresh_spec_list()
	if _selected_spec_index >= 0:
		_spec_list.select(_selected_spec_index)
		_load_spec_editor(_get_selected_spec())
	else:
		_clear_spec_editor()
	_update_preview()


func _on_move_spec(direction: int) -> void:
	if _current_data == null or _selected_spec_index < 0:
		return
	var new_idx := _selected_spec_index + direction
	if new_idx < 0 or new_idx >= _current_data.effect_specs.size():
		return
	_commit_open_editors()
	var tmp := _current_data.effect_specs[_selected_spec_index]
	_current_data.effect_specs[_selected_spec_index] = _current_data.effect_specs[new_idx]
	_current_data.effect_specs[new_idx] = tmp
	_selected_spec_index = new_idx
	_refresh_spec_list()
	_spec_list.select(_selected_spec_index)
	_load_spec_editor(_get_selected_spec())


func _on_add_action() -> void:
	var spec := _get_selected_spec()
	if spec == null:
		return
	_commit_open_editors()
	var action := EffectAction.new()
	spec.actions.append(action)
	_selected_action_index = spec.actions.size() - 1
	_refresh_action_list(spec)
	_action_list.select(_selected_action_index)
	_load_action_editor(action)
	_refresh_spec_list()
	_safe_item_list_select(_spec_list, _selected_spec_index)
	_update_preview()


func _on_remove_action() -> void:
	var spec := _get_selected_spec()
	if spec == null or _selected_action_index < 0:
		return
	spec.actions.remove_at(_selected_action_index)
	_selected_action_index = mini(_selected_action_index, spec.actions.size() - 1)
	_refresh_action_list(spec)
	if _selected_action_index >= 0:
		_action_list.select(_selected_action_index)
		_load_action_editor(spec.actions[_selected_action_index])
	else:
		_clear_action_editor()
	_refresh_spec_list()
	_safe_item_list_select(_spec_list, _selected_spec_index)
	_update_preview()


func _on_move_action(direction: int) -> void:
	var spec := _get_selected_spec()
	if spec == null or _selected_action_index < 0:
		return
	var new_idx := _selected_action_index + direction
	if new_idx < 0 or new_idx >= spec.actions.size():
		return
	_commit_open_editors()
	var tmp := spec.actions[_selected_action_index]
	spec.actions[_selected_action_index] = spec.actions[new_idx]
	spec.actions[new_idx] = tmp
	_selected_action_index = new_idx
	_refresh_action_list(spec)
	_action_list.select(_selected_action_index)
	_load_action_editor(spec.actions[_selected_action_index])
	_refresh_spec_list()
	_safe_item_list_select(_spec_list, _selected_spec_index)


func _commit_open_editors() -> void:
	if _current_data == null:
		return
	_apply_form_to_data(_current_data)


func _apply_form_to_data(data: AbilityData) -> void:
	if data == null:
		return
	data.id = _id_edit.text.strip_edges()
	data.display_name = _name_edit.text.strip_edges()
	data.shop_cost = int(_shop_cost_spin.value)
	data.skip_attack_after_move = _skip_attack_after_move_check.button_pressed
	data.can_normal_attack = _can_normal_attack_check.button_pressed
	data.uses_line_attack = _uses_line_attack_check.button_pressed
	data.line_attack_uses_attack = _line_attack_uses_attack_check.button_pressed
	data.line_attack_damage = int(_line_attack_damage_spin.value)
	var spec := _get_selected_spec()
	if spec != null:
		spec.trigger = _get_selected_trigger()
		spec.target_selector = _target_option.get_selected_id() as EffectSpec.TargetSelector
		spec.exclude_owner = _exclude_owner_check.button_pressed
		spec.target_count = int(_target_count_spin.value)
		var action := _get_selected_action()
		if action != null:
			_apply_action_editor_to(action)


func _update_preview() -> void:
	if _current_data == null:
		_preview_label.text = "预览：—"
		return
	var desc := UnitInfoText.get_ability_description(_current_data)
	_preview_label.text = "预览：" + (desc if not desc.is_empty() else "—")


func _on_generate_display_name() -> void:
	if _current_data == null:
		return
	_commit_open_editors()
	var parts: PackedStringArray = []
	for spec in _current_data.effect_specs:
		if spec == null:
			continue
		var line := UnitInfoText.format_effect_spec(spec)
		if not line.is_empty():
			parts.append(line)
	_name_edit.text = "，".join(parts) if not parts.is_empty() else _current_data.id
	_current_data.display_name = _name_edit.text
	_update_preview()
	_set_status("已从效果生成 display_name")


func _check_warnings() -> void:
	if _current_data == null:
		return
	var warnings: PackedStringArray = []
	if not _current_path.is_empty():
		var file_stem := _current_path.get_file().get_basename()
		if _current_data.id != file_stem:
			warnings.append("id 与文件名不一致")
	var refs := AbilityCatalog.find_unit_references(_current_data.id)
	if not refs.is_empty():
		warnings.append("%d 个单位引用此技能" % refs.size())
	if warnings.is_empty():
		return
	_set_status("⚠ " + " · ".join(warnings))


func _on_new_pressed() -> void:
	var data := AbilityData.new()
	data.id = "ability_new"
	data.display_name = "新技能"
	data.shop_cost = 2
	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_COMBAT_START
	var action := EffectAction.new()
	spec.actions = [action]
	data.effect_specs = [spec]
	_current_path = ""
	_current_data = data
	_selected_spec_index = 0
	_selected_action_index = 0
	_load_form_from_data(data)
	_ability_list.deselect_all()
	_set_status("新建草稿 — 填写 id 后保存")


func _on_duplicate_pressed() -> void:
	if _current_data == null:
		_set_status("请先选择或新建技能")
		return
	_commit_open_editors()
	var copy: AbilityData = _current_data.duplicate(true) as AbilityData
	copy.id = _current_data.id + "_copy"
	copy.display_name = _current_data.display_name + " 副本"
	_current_path = ""
	_current_data = copy
	_selected_spec_index = 0 if not copy.effect_specs.is_empty() else -1
	_selected_action_index = 0
	_load_form_from_data(copy)
	_ability_list.deselect_all()
	_set_status("已复制为草稿")


func _prepare_subresources_for_save(data: AbilityData) -> void:
	for spec in data.effect_specs:
		if spec == null:
			continue
		spec.resource_local_to_scene = false
		for action in spec.actions:
			if action != null:
				action.resource_local_to_scene = false


func _on_save_pressed() -> void:
	if _current_data == null:
		_set_status("无选中技能")
		return
	_commit_open_editors()
	if _current_data.id.is_empty():
		_set_status("id 不能为空")
		return
	var path := _current_path
	if path.is_empty():
		path = "%s/%s.tres" % [ABILITIES_DIR, _current_data.id]
		if ResourceLoader.exists(path):
			_set_status("文件已存在：%s" % path)
			return
	_prepare_subresources_for_save(_current_data)
	var err := ResourceSaver.save(_current_data, path)
	if err != OK:
		_set_status("保存失败：错误码 %d" % err)
		return
	_current_path = path
	_reload_catalog()
	_select_path_in_list(path)
	_set_status("已保存 %s" % path)
	_check_warnings()


func _select_path_in_list(path: String, reload_form: bool = true) -> void:
	for i in _filtered_entries.size():
		if _filtered_entries[i].get("path", "") == path:
			_ability_list.select(i)
			if reload_form:
				_on_ability_selected(i)
			return


func _ensure_delete_dialog() -> void:
	if _delete_dialog != null:
		return
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "删除技能"
	_delete_dialog.ok_button_text = "删除"
	_delete_dialog.confirmed.connect(_confirm_delete)
	add_child(_delete_dialog)


func _on_delete_pressed() -> void:
	if _current_path.is_empty():
		_set_status("草稿无法删除，请先保存或放弃")
		return
	_pending_delete_path = _current_path
	_ensure_delete_dialog()
	var refs := AbilityCatalog.find_unit_references(_current_data.id if _current_data else "")
	var ref_text := ""
	if not refs.is_empty():
		ref_text = "\n\n警告：%d 个单位仍引用此技能。" % refs.size()
	_delete_dialog.dialog_text = (
		"确定从磁盘删除以下技能文件？\n%s%s\n\n此操作不可撤销。"
		% [_pending_delete_path, ref_text]
	)
	_delete_dialog.popup_centered()


func _confirm_delete() -> void:
	var path := _pending_delete_path
	if path.is_empty():
		return
	var err := _delete_ability_file(path)
	_pending_delete_path = ""
	if err != OK:
		_set_status("删除失败：%s（错误码 %d）" % [path, err])
		return
	if _current_path == path:
		_current_path = ""
		_current_data = null
		_clear_form()
	_reload_catalog()
	_set_status("已从磁盘删除 %s" % path)


func _delete_ability_file(res_path: String) -> Error:
	if res_path.is_empty() or not res_path.begins_with("res://"):
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(res_path):
		return ERR_FILE_NOT_FOUND
	if _editor_interface != null:
		var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
		if fs != null and fs.has_method("delete_files"):
			fs.delete_files(PackedStringArray([res_path]))
			return OK
	var abs_path := ProjectSettings.globalize_path(res_path)
	if abs_path.is_empty():
		return ERR_FILE_NOT_FOUND
	var err := DirAccess.remove_absolute(abs_path)
	if err != OK:
		return err
	if _editor_interface != null:
		var fs_scan: EditorFileSystem = _editor_interface.get_resource_filesystem()
		if fs_scan != null:
			fs_scan.call_deferred("scan")
	return OK


func _clear_form() -> void:
	_loading_form = true
	_id_edit.text = ""
	_name_edit.text = ""
	_shop_cost_spin.value = 2
	_skip_attack_after_move_check.button_pressed = false
	_can_normal_attack_check.button_pressed = true
	_uses_line_attack_check.button_pressed = false
	_line_attack_uses_attack_check.button_pressed = true
	_line_attack_damage_spin.value = 2
	_update_line_attack_editor_state()
	_spec_list.clear()
	_action_list.clear()
	_clear_spec_editor()
	_preview_label.text = "预览：—"
	_selected_spec_index = -1
	_selected_action_index = -1
	_loading_form = false


func _on_inspector_pressed() -> void:
	if _current_data == null:
		_set_status("无选中技能")
		return
	_commit_open_editors()
	if _editor_interface != null:
		_editor_interface.edit_resource(_current_data)
		_set_status("已在检查器中打开")
	else:
		_set_status("EditorInterface 不可用")


func _set_status(text: String) -> void:
	_status_label.text = text
