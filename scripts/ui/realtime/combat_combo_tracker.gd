class_name CombatComboTracker
extends RefCounted
## 技能连击计数：每张友方技能介绍卡 +1；当前行动者一动结束清零。

const MAX_DISPLAY := 15

var combo: int = 0


func reset() -> void:
	combo = 0


## 返回更新后的连击数（非友方不增加）。
func register_skill_intro_card(owner: UnitInstance) -> int:
	if owner == null or owner.team != UnitInstance.Team.PLAYER:
		return combo
	combo += 1
	return combo


func get_display_value() -> int:
	if combo <= 0:
		return 0
	return mini(combo, MAX_DISPLAY)


func should_show() -> bool:
	return combo > 0
