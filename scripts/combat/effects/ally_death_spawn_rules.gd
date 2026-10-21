class_name AllyDeathSpawnRules
extends RefCounted
## 召魂「义士应召」：三合一（2★+）每次生成 3 只 2/2 随从；1★ 仍为 1 只。

const ABILITY_ID := "ally_death_spawn_weak"
const MERGED_MIN_LEVEL := 2
const MERGED_SPAWN_COUNT := 3


static func merged_spawn_count(base_count: int, ability: AbilityData, star_level: int) -> int:
	var count := maxi(1, base_count)
	if ability == null or ability.id != ABILITY_ID:
		return count
	if star_level >= MERGED_MIN_LEVEL:
		return MERGED_SPAWN_COUNT
	return count


static func spawn_count_for_owner(action: EffectAction, owner: UnitInstance) -> int:
	if action == null:
		return 1
	var ability: AbilityData = owner.get_main_ability() if owner != null else null
	var level := owner.level if owner != null else 1
	return merged_spawn_count(action.spawn_count, ability, level)
