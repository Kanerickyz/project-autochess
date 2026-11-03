class_name ThemeBondService
extends RefCounted
## 主题羁绊计数与成形：只计上场友方；双计；随从/无主题不计。

const ATTACHED_PREFIX := "theme_bond_placeholder_"


## 计入主题人数的上场友方（已入座名单由调用方传入；此处再滤随从与无主题）。
static func is_countable(unit: UnitInstance) -> bool:
	if unit == null or unit.unit_data == null:
		return false
	if unit.is_combat_summon:
		return false
	## 熔印者等：未挂主题则不计。
	return not unit.unit_data.get_theme_ids().is_empty()


## 主题 id → 上场人数（双计：主+辅各 +1）。
static func count_themes(deployed_units: Array) -> Dictionary:
	var counts: Dictionary = {}
	for theme_id in UnitTheme.ALL_IDS:
		counts[theme_id] = 0
	for item in deployed_units:
		var unit := item as UnitInstance
		if not is_countable(unit):
			continue
		for theme_id in unit.unit_data.get_theme_ids():
			if not UnitTheme.is_valid_id(theme_id):
				continue
			counts[theme_id] = int(counts.get(theme_id, 0)) + 1
	return counts


## 已达门槛的主题 id 列表（按 UnitTheme.ALL_IDS 稳定序）。
static func list_formed_themes(
	deployed_units: Array, catalog: ThemeBondCatalog = null
) -> Array[StringName]:
	var cat := catalog if catalog != null else ThemeBondCatalog.load_default()
	var counts := count_themes(deployed_units)
	var formed: Array[StringName] = []
	for theme_id in UnitTheme.ALL_IDS:
		var bond := cat.get_bond(theme_id)
		var threshold := 3 if bond == null else maxi(1, bond.threshold)
		if int(counts.get(theme_id, 0)) >= threshold:
			formed.append(theme_id)
	return formed


## 开战锁阵后：把已成形主题的 EffectSpec 挂到一名友方载体的 attached_abilities，
## 随后 OnCombatStart 经 EffectResolver 与开战技能同一管线结算。敌方调用方勿传入。
## 返回本场已成形主题 id。
static func apply_formed_bonds_to_player_units(
	deployed_player_units: Array, catalog: ThemeBondCatalog = null
) -> Array[StringName]:
	var cat := catalog if catalog != null else ThemeBondCatalog.load_default()
	_strip_previous_theme_attachments(deployed_player_units)
	var formed := list_formed_themes(deployed_player_units, cat)
	if formed.is_empty():
		return formed
	var carrier := _pick_carrier(deployed_player_units)
	if carrier == null:
		return formed
	for theme_id in formed:
		var bond := cat.get_bond(theme_id)
		if bond == null or bond.effect_specs.is_empty():
			continue
		carrier.attached_abilities.append(bond.build_runtime_ability())
	return formed


static func _pick_carrier(units: Array) -> UnitInstance:
	for item in units:
		var unit := item as UnitInstance
		if unit != null and unit.is_alive() and not unit.is_combat_summon:
			return unit
	return null


static func _strip_previous_theme_attachments(units: Array) -> void:
	for item in units:
		var unit := item as UnitInstance
		if unit == null or unit.attached_abilities.is_empty():
			continue
		var kept: Array[AbilityData] = []
		for ab in unit.attached_abilities:
			if ab == null:
				continue
			if String(ab.id).begins_with(ATTACHED_PREFIX):
				continue
			kept.append(ab)
		unit.attached_abilities = kept
