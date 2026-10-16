class_name EconomyConfig
extends Resource

@export var starting_gold: int = 10
@export var refresh_cost: int = 2
@export var default_kill_gold: int = 1
@export var default_wave_gold: int = 3
## 已废弃：出售现按 UnitData.cost 全额退款，不再读取此字段。
@export_range(0.0, 1.0, 0.05) var sell_ratio: float = 0.5
