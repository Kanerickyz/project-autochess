class_name BadgeData
extends Resource
## 整局玩家徽章（类尖塔圣遗物）。羁绊向按职业×N 兑现；纯全局预留 Kind.GLOBAL。

enum Kind {
	## 职业 × N（或同盟放大器）。
	SYNERGY = 0,
	## 纯全局（本版花名册不做内容，架构预留）。
	GLOBAL = 1,
}

enum EffectKind {
	## 开战：全体已入座友方最大生命 +value（当前生命同步）。
	ALLY_MAX_HP = 0,
	## 开战：全体已入座近战友方攻击 +value。
	ALLY_MELEE_ATTACK = 1,
	## 本场：友方远程投射普攻命中，护甲前伤害 +value。
	RANGED_HIT_BONUS = 2,
	## 开战：全体已入座友方临时护甲 +value。
	ALLY_TEMP_ARMOR = 3,
	## 开战：全体已入座友方狂暴 +value 层。
	ALLY_BERSERK = 4,
	## 开战：全体敌军虚弱 +value、中毒 +value_secondary。
	ENEMY_WEAK_AND_POISON = 5,
	## 放大器：另有职绑徽章条件已满足时，各整数点数 +1。
	ALLIANCE_AMPLIFY = 6,
}

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.SYNERGY
## 绑定职业（SynergyOccupations 词表）；同盟 / 纯全局可空。
@export var occupation: String = ""
## 种类数门槛 N；同盟放大器忽略（用 effect_kind 判定）。
@export_range(0, 10, 1) var threshold_n: int = 2
@export_range(1, 3, 1) var tier: int = 1
@export var effect_kind: EffectKind = EffectKind.ALLY_MAX_HP
## 主点数（生命 / 攻击 / 命中加伤 / 护甲 / 层数）。
@export var value: int = 0
## 副点数（如虚弱+中毒的中毒层；默认与 value 相同可由内容填）。
@export var value_secondary: int = 0
@export var condition_short: String = ""
@export var effect_text: String = ""
## 三选一 / 持有条圆形占位色。
@export var accent_color: Color = Color(0.55, 0.62, 0.78, 1.0)


func is_alliance_amplifier() -> bool:
	return effect_kind == EffectKind.ALLIANCE_AMPLIFY


func is_occupation_bound() -> bool:
	return kind == Kind.SYNERGY and not is_alliance_amplifier() and SynergyOccupations.is_known(occupation)


func get_condition_label() -> String:
	var short := condition_short.strip_edges()
	if not short.is_empty():
		return short
	if is_alliance_amplifier():
		return "同盟 · 已满足职绑"
	if is_occupation_bound():
		return "%s × %d" % [occupation, threshold_n]
	return "全局"


func matches_condition(occupation_counts: Dictionary) -> bool:
	if is_alliance_amplifier():
		## 同盟：由 BadgeCombatApplier 另行判定「另有职绑已满足」。
		return true
	if kind == Kind.GLOBAL:
		## 纯全局：无职业门槛。
		return true
	if not is_occupation_bound():
		return false
	return int(occupation_counts.get(occupation, 0)) >= threshold_n
