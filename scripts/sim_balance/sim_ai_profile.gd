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
