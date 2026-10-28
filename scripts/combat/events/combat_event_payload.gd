class_name CombatEventPayload
extends RefCounted

var event_type: StringName
var source: UnitInstance
var target: UnitInstance
var amount: int = 0
## 击杀来自出手（普攻、溅射、对砍），不是技能伤害。
var from_attack: bool = false
## 扣血前目标当前生命；≥0 时供条件（如削峰）使用。-1 = 未设置。
var target_hp_before: int = -1
## 效果链深度：总线 emit 时由 EffectResolver.on_event 读入队深度（0=战斗层直达事件）。
var chain_depth: int = 0
var from_cell: Vector2i = Vector2i.ZERO
var to_cell: Vector2i = Vector2i.ZERO
var line_axis: int = -1
var effect_action: EffectAction
var effect_owner: UnitInstance
var effect_spec: EffectSpec
var effect_entries: Array = []
var removed_owner_instance_id: int = -1
var fizzle_message: String = ""
var fuse_explosion_cells: Array[Vector2i] = []
