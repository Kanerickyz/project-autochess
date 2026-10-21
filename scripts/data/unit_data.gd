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
## 首领衍生小兵身体（单模板回退）；空且 summon_pool 空 = 不可召唤。
@export var summon_unit: UnitData
## 首领召唤池（优先）：非空时每次从中随机一只（如 T4/T5）。
@export var summon_pool: Array[UnitData] = []
## 场上衍生小兵硬上限（存活计数）；0 = 不召唤。
@export_range(0, 20, 1) var summon_max_alive: int = 0
## 本场战斗累计召唤上限；0 = 仅受 summon_max_alive 约束（可反复补员）。
@export_range(0, 50, 1) var summon_max_total: int = 0
## 单次召唤只数。
@export_range(0, 10, 1) var summon_per_action: int = 1
## 召唤成功后，首领需再过多少次自己的行动才能再次召唤；0 = 无冷却。
@export_range(0, 20, 1) var summon_cooldown_actions: int = 0


func pick_summon_unit(rng: RandomNumberGenerator = null) -> UnitData:
	var pool: Array[UnitData] = []
	for entry in summon_pool:
		if entry != null:
			pool.append(entry)
	if not pool.is_empty():
		if rng != null:
			return pool[rng.randi_range(0, pool.size() - 1)]
		return pool[randi() % pool.size()]
	return summon_unit

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
