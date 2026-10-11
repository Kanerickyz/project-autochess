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
}

## Combat + shop trigger names (CombatEvents / ShopEvents).
const TRIGGER_NAMES: PackedStringArray = [
	"OnCombatStart",
	"OnFriendSummoned",
	"OnSummoned",
	"OnFriendDeath",
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
