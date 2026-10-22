class_name EffectSpec
extends Resource

enum TargetSelector {
	SELF,
	EVENT_TARGET,
	RANDOM_ALLY,
	ALL_UNITS,
	RANDOM_ENEMY,
	HEALTHIEST_ALLY,
	RANDOM_DECK_ALLY,
	ALL_SHOP_CHARACTERS,
	ALL_ALLIES,
	FIRST_ENEMY,
	LAST_ENEMY,
	NEAREST_ALLY_BEHIND,
	CELLS_AROUND_EVENT,
	RANDOM_CELLS,
	UNIT_AHEAD_OF_MOVE,
	HIGHEST_CURRENT_HP_ALLY,
	## 事件目标邻格上的敌人（Chebyshev=1；不含事件目标自身）。
	ENEMIES_ADJACENT_TO_EVENT_TARGET,
	## 事件来源单位（如受伤时的施害者）；须追加在枚举末尾以免破坏既有 .tres 序号。
	EVENT_SOURCE,
	## 持有者附近友方（切比雪夫 ≤ NEARBY_ALLY_RADIUS）；可 exclude_owner。
	NEARBY_ALLIES,
	## 当前生命最低的友方（可 exclude_owner）；平局先比生命上限再比 instance_id。
	LOWEST_CURRENT_HP_ALLY,
	## 附近友方中当前生命最低者（半径同 NEARBY_ALLY_RADIUS）。
	LOWEST_CURRENT_HP_NEARBY_ALLY,
	## 当前生命最低的敌方；平局先比生命上限再比 instance_id。
	LOWEST_CURRENT_HP_ENEMY,
}


## 「附近」切比雪夫半径（格）：附近友方 / 附近敌人均为周围一格。
const NEARBY_ALLY_RADIUS := 1
const NEARBY_ENEMY_RADIUS := 1

## Optional gate evaluated when the trigger fires (before targets/actions).
enum Condition {
	NONE,
	## 事件目标当前生命 > 技能持有者当前生命。
	EVENT_TARGET_HP_GT_OWNER,
	## 事件目标是战斗随从（战中召唤体）；须追加在枚举末尾。
	EVENT_TARGET_IS_COMBAT_SUMMON,
	## 事件目标不是战斗随从/代理（正式角色单位）。
	EVENT_TARGET_IS_NOT_COMBAT_SUMMON,
	## 事件目标当前生命未满（可再接受治疗）；须追加在枚举末尾。
	EVENT_TARGET_NOT_AT_MAX_HP,
}

## Combat + shop trigger names (CombatEvents / ShopEvents).
const TRIGGER_NAMES: PackedStringArray = [
	"OnCombatStart",
	"OnFriendSummoned",
	"OnSummoned",
	"OnFriendDeath",
	"OnEnemyDeath",
	"OnFriendDamageTaken",
	"OnDamageTaken",

	"OnDealDamage",
	"OnCrit",
	"OnKill",
	"OnDeath",
	"OnAttackHit",
	"OnLineAttack",
	"OnEffectResolved",
	"OnEffectFizzled",
	"OnMove",
	"OnRoundStart",
	"OnLevelUp",
	"OnBuy",
	"OnSell",
]

## Kept as StringName for .tres compatibility (`trigger = &"OnDeath"`).
@export var trigger: StringName = &"OnCombatStart"
@export var target_selector: TargetSelector = TargetSelector.SELF
@export var exclude_owner: bool = false
@export_range(1, 5, 1) var target_count: int = 1
@export var actions: Array[EffectAction] = []
## 0 = unlimited. Counts successful enqueues per owner+spec this combat.
@export_range(0, 99, 1) var max_triggers_per_combat: int = 0
@export var condition: Condition = Condition.NONE


func is_trigger_registered() -> bool:
	return String(trigger) in TRIGGER_NAMES


func validate_config() -> PackedStringArray:
	var issues: PackedStringArray = []
	if not is_trigger_registered():
		issues.append("trigger '%s' is not a known CombatEvents/ShopEvents name" % String(trigger))
	for action in actions:
		if action == null:
			issues.append("actions contains null EffectAction")
			continue
		for issue in action.validate_config():
			issues.append(issue)
	return issues
