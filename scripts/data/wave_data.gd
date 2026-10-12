@tool
class_name WaveData
extends Resource

@export_range(0, 64, 1) var spawn_count: int = 3
## 波次胜利结算金；-1 表示使用 EconomyConfig.default_wave_gold
@export var wave_gold_reward: int = -1
## 除随机抽取外必定刷出的敌人（如 Boss）
@export var fixed_entries: Array[SpawnScheduleEntry] = []


func roll_spawn_entries(
	enemy_pool: Array[UnitData],
	wave_index: int,
	rng: RandomNumberGenerator,
) -> Array[SpawnScheduleEntry]:
	var result: Array[SpawnScheduleEntry] = []
	for fixed in fixed_entries:
		if fixed != null and fixed.unit != null:
			result.append(fixed.duplicate_entry())
	if spawn_count <= 0:
		return result
	if rng == null:
		return result

	var max_tier := TierUnlock.get_max_unlocked_tier(wave_index + 1)
	var filtered: Array = TierUnlock.filter_by_tier(
		enemy_pool,
		_get_unit_tier,
		max_tier,
	)
	var pool: Array[UnitData] = []
	for item in filtered:
		if item is UnitData:
			pool.append(item)

	if pool.is_empty():
		push_warning(
			"WaveData: enemy pool empty after tier filter (wave_index=%d, max_tier=%d)"
			% [wave_index, max_tier]
		)
		return result

	var unit_counts: Dictionary = {}
	var unit_by_key: Dictionary = {}
	for _i in spawn_count:
		var unit := pool[rng.randi_range(0, pool.size() - 1)]
		var key := _unit_pool_key(unit)
		unit_counts[key] = int(unit_counts.get(key, 0)) + 1
		unit_by_key[key] = unit

	for key in unit_by_key.keys():
		var entry := SpawnScheduleEntry.new()
		entry.combat_tick = 0
		entry.unit = unit_by_key[key]
		entry.count = int(unit_counts.get(key, 1))
		result.append(entry)
	return result


static func _get_unit_tier(item: Variant) -> int:
	if item is UnitData:
		return (item as UnitData).tier
	return 99


static func _unit_pool_key(unit: UnitData) -> String:
	if unit == null:
		return ""
	if not unit.resource_path.is_empty():
		return unit.resource_path
	return unit.id
