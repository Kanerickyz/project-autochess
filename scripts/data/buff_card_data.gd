class_name BuffCardData
extends Resource

enum EffectType { PERMANENT_ATTACK, PERMANENT_MAX_HP, CANNOT_MOVE }

@export var id: String = ""
@export var display_name: String = ""
@export_range(1, 6, 1) var tier: int = 1
@export var shop_cost: int = 1
@export var effect_type: EffectType = EffectType.PERMANENT_ATTACK
@export var value: int = 1
