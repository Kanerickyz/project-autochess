class_name EconomyConfig
extends Resource

@export var starting_gold: int = 10
@export var refresh_cost: int = 2
## 【已否决主路径】击杀掉金；保留字段兼容旧 .tres。
@export var default_kill_gold: int = 1
## 【遗留】旧波次金默认；实时主路径改用层结算金（第 n 层 +n）。
@export var default_wave_gold: int = 3
## 已废弃：出售现按 UnitData.cost 全额退款，不再读取此字段。
@export_range(0.0, 1.0, 0.05) var sell_ratio: float = 0.5
