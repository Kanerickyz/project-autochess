@tool
class_name UnitData
extends Resource

## 主题羁绊（玩家可读包装类）；见 Documents/Features/UNIT_THEME_BONDS.md。
enum ThemeBond {
	NONE = 0,
	UNDEAD = 1,
	WARRIOR = 2,
	KNIGHT = 3,
	ARTISAN = 4,
	BAND = 5,
	ARCANA = 6,
	GUARD = 7,
}

## 行为职业：管走打与装备格（坦克 0／近战 1／刺客 2／远程 3）。
enum CombatProfession {
	MELEE = 0,
	TANK = 1,
	RANGED = 2,
	ASSASSIN = 3,
}

@export var id: String = ""
@export var display_name: String = ""
## 商店买进构筑库的金币。
@export var cost: int = 1
@export_range(1, 6, 1) var tier: int = 1
## 【已停用】原号令费用字段；逻辑与 UI 不再读取。保留以免批量改 .tres。
@export_range(1, 10, 1) var command_cost: int = 1
## -1 表示使用 EconomyConfig.default_kill_gold
@export var kill_gold_reward: int = -1
## 主题羁绊主归类（可招友方须非 NONE）。
@export var theme_bond: ThemeBond = ThemeBond.NONE
## 行为职业（走打 + 装备格）；见 Features/UNITS.md §7。
@export var combat_profession: CombatProfession = CombatProfession.MELEE:
	set(value):
		combat_profession = value
		equipment_slot_count = equipment_slots_for_profession(value)
@export var stats: UnitStats
@export var team_default: UnitInstance.Team = UnitInstance.Team.PLAYER
@export var ability: AbilityData
@export var passives: Array[AbilityData] = []
## 装备槽上限（0～3）；以行为职业为准，导出字段同步便于旧资源/测例对照。
@export_range(0, 3, 1) var equipment_slot_count: int = 1


static func theme_bond_label(bond: ThemeBond) -> String:
	match bond:
		ThemeBond.UNDEAD:
			return "亡灵"
		ThemeBond.WARRIOR:
			return "战士"
		ThemeBond.KNIGHT:
			return "骑士"
		ThemeBond.ARTISAN:
			return "工匠"
		ThemeBond.BAND:
			return "军乐队"
		ThemeBond.ARCANA:
			return "秘术"
		ThemeBond.GUARD:
			return "护卫"
		_:
			return "未定"


static func combat_profession_label(prof: CombatProfession) -> String:
	match prof:
		CombatProfession.TANK:
			return "坦克"
		CombatProfession.RANGED:
			return "远程"
		CombatProfession.ASSASSIN:
			return "刺客"
		_:
			return "近战"


## 长按介绍卡职业词条（玩家可读规则摘要）。
static func combat_profession_rules_text(prof: CombatProfession) -> String:
	match prof:
		CombatProfession.TANK:
			return "【职业·坦克】嘲讽：敌人必须优先攻击坦克；无法携带装备。"
		CombatProfession.RANGED:
			return "【职业·远程】攻击距离 2；普通攻击约 5% 暴击（1.5 倍，先算再进护甲）；可携带 3 件装备。"
		CombatProfession.ASSASSIN:
			return "【职业·刺客】无视嘲讽；优先攻击远程→刺客→近战→坦克；瞬移贴近后再出手；可携带 2 件装备。"
		_:
			return "【职业·近战】标准近战走打；可携带 1 件装备。"


static func equipment_slots_for_profession(prof: CombatProfession) -> int:
	match prof:
		CombatProfession.TANK:
			return 0
		CombatProfession.ASSASSIN:
			return 2
		CombatProfession.RANGED:
			return 3
		_:
			return 1


func get_equipment_slot_count_resolved() -> int:
	return equipment_slots_for_profession(combat_profession)


func is_tank_profession() -> bool:
	return combat_profession == CombatProfession.TANK


func is_ranged_profession() -> bool:
	return combat_profession == CombatProfession.RANGED


func is_assassin_profession() -> bool:
	return combat_profession == CombatProfession.ASSASSIN

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
## 场上衍生小兵存活硬上限；0 = 无场上数量上限（仍受空格与冷却约束；无可召模板则不召）。
@export_range(0, 20, 1) var summon_max_alive: int = 0
## 本场战斗累计召唤上限；0 = 无累计上限（小兵阵亡后可再补员，仍受 summon_max_alive 约束）。
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
