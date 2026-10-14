@tool
class_name UnitData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
## 商店买进构筑库的金币（与号令费用独立）。
@export var cost: int = 1
@export_range(1, 6, 1) var tier: int = 1
## 战斗中打出消耗的号令点数（与商店 cost 独立；见 Features/PLAYER.md）。
@export_range(1, 10, 1) var command_cost: int = 1
## -1 表示使用 EconomyConfig.default_kill_gold
@export var kill_gold_reward: int = -1
@export var stats: UnitStats
@export var team_default: UnitInstance.Team = UnitInstance.Team.PLAYER
@export var ability: AbilityData
@export var passives: Array[AbilityData] = []

@export_group("UI")
## 角色头像/立绘，用于卡片与棋盘 UI；留空则使用色块占位。
@export var icon: Texture2D
## 纸面角色头部（棋盘 paper mode）；留空则使用 0_head 占位。
@export var portrait_head: Texture2D
## 纸面角色身体（棋盘 paper mode）；留空则使用 0_body 占位。
@export var portrait_body: Texture2D


func get_command_cost() -> int:
	return maxi(1, command_cost)
