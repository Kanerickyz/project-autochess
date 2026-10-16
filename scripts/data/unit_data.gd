@tool
class_name UnitData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
## 商店买进构筑库的金币。
@export var cost: int = 1
@export_range(1, 6, 1) var tier: int = 1
## 【已停用】原号令费用字段；逻辑与 UI 不再读取。保留以免批量改 .tres。
@export_range(1, 10, 1) var command_cost: int = 1
## -1 表示使用 EconomyConfig.default_kill_gold
@export var kill_gold_reward: int = -1
@export var stats: UnitStats
@export var team_default: UnitInstance.Team = UnitInstance.Team.PLAYER
@export var ability: AbilityData
@export var passives: Array[AbilityData] = []

@export_group("Boss")
## Boss 遭遇首领标记：斩首胜负、对砍例外、足迹策略机。
@export var is_boss_leader: bool = false
## 逻辑足迹宽（格）；普通单位为 1。Boss 召唤统领为 2。
@export_range(1, 3, 1) var footprint_w: int = 1
## 逻辑足迹高（格）；普通单位为 1。Boss 召唤统领为 2。
@export_range(1, 3, 1) var footprint_h: int = 1
## 首领衍生小兵身体（如枯骨）；空 = 不可召唤。
@export var summon_unit: UnitData
## 场上衍生小兵硬上限（存活计数）；0 = 不召唤。
@export_range(0, 20, 1) var summon_max_alive: int = 0
## 单次召唤只数。
@export_range(0, 10, 1) var summon_per_action: int = 1

@export_group("UI")
## 角色头像/立绘，用于卡片与棋盘 UI；留空则使用色块占位。
@export var icon: Texture2D
## 纸面角色头部（棋盘 paper mode）；留空则使用 0_head 占位。
@export var portrait_head: Texture2D
## 纸面角色身体（棋盘 paper mode）；留空则使用 0_body 占位。
@export var portrait_body: Texture2D


## 【已停用】勿再用于出牌/商店费用。
func get_command_cost() -> int:
	return maxi(1, command_cost)
