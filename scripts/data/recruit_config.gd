class_name RecruitConfig
extends Resource
## 招募阶段配置：刷新费、默认单价、候选人池与进出动画时长。

const DEFAULT_REFRESH_COST := 2
const DEFAULT_UNIT_COST := 3
const DEFAULT_CANDIDATE_COUNT := 5
const DEFAULT_EXIT_SECONDS := 0.5
const DEFAULT_ENTER_SECONDS := 0.45
## 招募阶段限时（秒）；≤0 关闭自动结束。
const DEFAULT_PHASE_SECONDS := 0.0
const REALTIME_UNITS_DIR := "res://resources/units/realtime/"

@export_range(0, 20, 1) var refresh_cost: int = DEFAULT_REFRESH_COST
@export_range(1, 20, 1) var default_unit_cost: int = DEFAULT_UNIT_COST
@export_range(1, 8, 1) var candidate_count: int = DEFAULT_CANDIDATE_COUNT
@export_range(0.1, 2.0, 0.05) var half_exit_seconds: float = DEFAULT_EXIT_SECONDS
@export_range(0.1, 2.0, 0.05) var panel_enter_seconds: float = DEFAULT_ENTER_SECONDS
@export_range(0.0, 120.0, 0.5) var phase_seconds: float = DEFAULT_PHASE_SECONDS
## 友方可购单位池；空则回退 character_pool / pool。
@export var unit_pool: Array[UnitData] = []
@export var character_pool: Array[UnitData] = []
## Legacy alias for ShopPoolConfig-style resources.
@export var pool: Array[UnitData] = []

static var _runtime_unit_pool: Array[UnitData] = []
static var _logged_runtime_fallback: bool = false


func get_refresh_cost() -> int:
	return maxi(0, refresh_cost)


func get_default_unit_cost() -> int:
	return maxi(1, default_unit_cost)


func get_candidate_count() -> int:
	return maxi(1, candidate_count)


## ≤0 表示不自动结束招募阶段。
func get_phase_seconds() -> float:
	return phase_seconds


func get_unit_pool() -> Array[UnitData]:
	var merged := _merge_exported_pools()
	if not merged.is_empty():
		return merged
	if _runtime_unit_pool.is_empty():
		_runtime_unit_pool = _scan_realtime_player_units()
	if not _runtime_unit_pool.is_empty() and not _logged_runtime_fallback:
		_logged_runtime_fallback = true
		push_warning(
			"RecruitConfig: exported unit_pool empty; using runtime scan (%d units)"
			% _runtime_unit_pool.size()
		)
	return _runtime_unit_pool.duplicate()


func _merge_exported_pools() -> Array[UnitData]:
	var result: Array[UnitData] = []
	for source in [unit_pool, character_pool, pool]:
		for unit in source:
			if unit != null:
				result.append(unit)
	return result


static func _scan_realtime_player_units() -> Array[UnitData]:
	var result: Array[UnitData] = []
	var dir := DirAccess.open(REALTIME_UNITS_DIR)
	if dir == null:
		push_warning("RecruitConfig: cannot open %s" % REALTIME_UNITS_DIR)
		return result
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var path := REALTIME_UNITS_DIR.path_join(file_name)
		var unit := load(path) as UnitData
		if unit != null and unit.team_default == UnitInstance.Team.PLAYER:
			result.append(unit)
	result.sort_custom(func(a: UnitData, b: UnitData) -> bool:
		if a.tier != b.tier:
			return a.tier < b.tier
		return String(a.display_name) < String(b.display_name)
	)
	return result


## 合同名 shop_cost → As-Is 字段 UnitData.cost；≤0 用默认。
func get_recruit_cost(unit: UnitData) -> int:
	if unit == null:
		return get_default_unit_cost()
	if unit.cost > 0:
		return unit.cost
	return get_default_unit_cost()