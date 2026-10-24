class_name AllyDeathSpawnRules
extends RefCounted
## 召魂「义士应召」：随从只数走 spawn_count；攻血升星见 ability.merge_value_mult（与掘墓一致）。


static func merged_spawn_count(base_count: int, _ability: AbilityData = null, _star_level: int = 1) -> int:
	return maxi(1, base_count)


static func spawn_count_for_owner(action: EffectAction, _owner: UnitInstance = null) -> int:
	if action == null:
		return 1
	return merged_spawn_count(action.spawn_count)
