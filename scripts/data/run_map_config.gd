class_name RunMapConfig
extends Resource

@export_range(0, 8, 1) var act_index: int = 0
@export var act_display_name: String = "第一幕"
@export_range(3, 20, 1) var floor_count: int = 14
## 兼容字段：尖塔式路径生成下每层节点数由路径合并决定，不再按此随机取样。
@export_range(1, 11, 1) var min_nodes_per_floor: int = 2
## 兼容字段：硬上限改为 column_count（见 MapGenerator 路径生成）。
@export_range(1, 11, 1) var max_nodes_per_floor: int = 3
@export_range(5, 11, 1) var column_count: int = 7
## 上行路径条数；≤0 时用 mini(6, column_count)。
@export_range(0, 11, 1) var path_count: int = 0
@export_range(5, 15, 1) var shop_min_floor: int = 5
## 精英最早出现层；≤0 时用 maxi(4, floor_count/3)。
@export_range(0, 15, 1) var elite_min_floor: int = 0
## 附魔最早出现层；≤0 时用中后期默认（见 MapGenerator._resolve_enchant_min_floor）。
@export_range(0, 15, 1) var enchant_min_floor: int = 0
@export_range(1, 4, 1) var max_shops_per_act: int = 2
@export_range(1, 4, 1) var max_rests_per_act: int = 2
@export_range(2, 6, 1) var elite_interval: int = 4
@export var board_defaults: LevelData
@export var combat_pool: Array[EncounterData] = []
@export var elite_pool: Array[EncounterData] = []
@export var boss_encounter: EncounterData
@export var event_pool: Array[EventData] = []
@export var treasure_buff_pool: Array[BuffCardData] = []

@export_group("Endless")
## 无尽模式：线性普通战斗串 + 定期商店；无精英/Boss/事件；败局记到达层深。
## 敌压由 EndlessLadderBalance 阶梯公式负责（不开跟队抽阵）。
@export var endless_mode: bool = false
## 前若干场普通战斗不插商店；产品无尽为 0（无前段纯战斗豁免）。
@export_range(0, 20, 1) var pure_combat_floors: int = 0
## 每完成该场数普通战，在下一场战斗之前插入一座商店（不占层号）。产品无尽为 4。
@export_range(1, 20, 1) var shop_every_n_combats: int = 4
## 初次/续写时一次追加的普通战斗层数。
@export_range(4, 40, 1) var endless_chunk_combats: int = 12
## 剩余可走战斗节点少于此值时续写下一段。
@export_range(1, 20, 1) var endless_append_threshold: int = 4
## 历史字段：无尽现用阶梯刷敌，产品路径应留空；主塔可不填。
@export var spawn_budget_override: SpawnBudgetConfig
