class_name AbilityData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var shop_cost: int = 2
@export var can_normal_attack: bool = true
@export var skip_attack_after_move: bool = false
@export var uses_line_attack: bool = false
@export var line_attack_uses_attack: bool = true
@export_range(1, 99, 1) var line_attack_damage: int = 2
@export var effect_specs: Array[EffectSpec] = []
## 每次三合一的技能数值倍率；0 = 用全局 ×6（1★×1 / 2★×6 / 3★×36）。
@export_range(0, 99, 1) var merge_value_mult: int = 0
