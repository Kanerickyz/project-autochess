class_name SimAIProfile
extends Resource
## 批跑启发式策略参数（仅 sim_balance 使用）。

@export var profile_id: String = "default"
## 优先招募的单位 id（UnitData.id）。
@export var priority_unit_ids: PackedStringArray = PackedStringArray()
## 地图选路：true 时在等距路径上优先商店节点。
@export var prefer_shop_nodes: bool = false
## 单次招募阶段最多尝试购买次数。
@export_range(1, 64, 1) var max_recruit_passes: int = 16
## 席位将满时尝试买旗帜扩席。
@export var buy_banner_when_affordable: bool = true

## --- 效用权重（供手调 / 外部优化；见 Documents/Features/SIM_BALANCE_AI.md）---
@export_group("Utility Weights")
@export var weight_stat_per_cost: float = 1.0
@export var weight_merge_bonus: float = 80.0
@export var weight_priority_unit_bonus: float = 50.0
@export var weight_shop_node_tie: float = 40.0
@export var weight_boss_path_tie: float = 100.0
@export var weight_combat_node_tie: float = 5.0
