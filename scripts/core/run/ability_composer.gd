class_name AbilityComposer
extends RefCounted


static func get_single_effect_spec(ability: AbilityData) -> EffectSpec:
	if ability == null or ability.effect_specs.is_empty():
		return null
	if ability.effect_specs.size() != 1:
		push_warning(
			"AbilityComposer: expected 1 effect_spec, got %d on %s"
			% [ability.effect_specs.size(), ability.id]
		)
		return null
	return ability.effect_specs[0]


static func can_use_as_enchant_material(entry: DeckEntry) -> bool:
	if entry == null or entry.unit == null:
		return false
	var ability := entry.get_main_ability()
	return get_single_effect_spec(ability) != null


## 时机来自 A 的唯一 spec；效果与战斗壳来自 B 的主技能（壳在 compose 时复制 B 的 AbilityData）。
static func compose(material_a: DeckEntry, material_b: DeckEntry) -> AbilityData:
	if material_a == null or material_b == null:
		return null
	var ability_a := material_a.get_main_ability()
	var ability_b := material_b.get_main_ability()
	var spec_a := get_single_effect_spec(ability_a)
	var spec_b := get_single_effect_spec(ability_b)
	if spec_a == null or spec_b == null or ability_b == null:
		return null
	var shell := ability_b.duplicate(true) as AbilityData
	if shell == null:
		return null
	var composed_spec := spec_b.duplicate(true) as EffectSpec
	if composed_spec == null:
		return null
	composed_spec.trigger = spec_a.trigger
	composed_spec.condition = spec_a.condition
	shell.effect_specs = [composed_spec]
	shell.id = "fused_%s_%s" % [String(spec_a.trigger), ability_b.id]
	if shell.display_name.is_empty():
		shell.display_name = "熔合技能"
	return shell
