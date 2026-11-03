class_name ThemeBondDef
extends Resource
## 单主题羁绊定义：成形门槛 + 团队层 EffectSpec（须走 EffectResolver）。

@export var theme_id: StringName = &""
## 成形人数门槛（规格未定；默认 3，可在资源上改）。
@export_range(1, 20, 1) var threshold: int = 3
## 成形后发放的团队层效果；占位阶段为开战临时攻等弱效果。
@export var effect_specs: Array[EffectSpec] = []


func is_formed(count: int) -> bool:
	return count >= maxi(1, threshold)


## 挂到友方 attached_abilities 的占位 AbilityData（merge_value_mult=1 → 不随星放大）。
## 注意：当前 EffectResolver 按持有者主技能升星倍率缩放；测试用 1★ 载体验收管线。
func build_runtime_ability() -> AbilityData:
	var ab := AbilityData.new()
	ab.id = "theme_bond_placeholder_%s" % String(theme_id)
	var theme_label := UnitTheme.display_name(theme_id)
	if theme_label.is_empty():
		theme_label = String(theme_id)
	ab.display_name = "主题羁绊·%s（占位·待数值）" % theme_label
	ab.can_normal_attack = true
	## step=1 → 任意星级倍率恒为 1（若日后 resolver 按本 Ability 缩放）。
	ab.merge_value_mult = 1
	ab.effect_specs = effect_specs.duplicate()
	return ab
