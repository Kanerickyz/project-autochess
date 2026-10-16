class_name RecruitConfig
extends Resource
## 招募阶段配置：刷新费、默认单价、候选人池与进出动画时长。

const DEFAULT_REFRESH_COST := 1
const DEFAULT_UNIT_COST := 3
const DEFAULT_CANDIDATE_COUNT := 5
const DEFAULT_EXIT_SECONDS := 0.5
const DEFAULT_ENTER_SECONDS := 0.45

@export_range(0, 20, 1) var refresh_cost: int = DEFAULT_REFRESH_COST
@export_range(1, 20, 1) var default_unit_cost: int = DEFAULT_UNIT_COST
@export_range(1, 8, 1) var candidate_count: int = DEFAULT_CANDIDATE_COUNT
@export_range(0.1, 2.0, 0.05) var half_exit_seconds: float = DEFAULT_EXIT_SECONDS
@export_range(0.1, 2.0, 0.05) var panel_enter_seconds: float = DEFAULT_ENTER_SECONDS
## 友方可购单位池；空则回退 character_pool / pool。
@export var unit_pool: Array[UnitData] = []
@export var character_pool: Array[UnitData] = []
## Legacy alias for ShopPoolConfig-style resources.
@export var pool: Array[UnitData] = []


func get_refresh_cost() -> int:
	return maxi(0, refresh_cost)


func get_default_unit_cost() -> int:
	return maxi(1, default_unit_cost)


func get_candidate_count() -> int:
	return maxi(1, candidate_count)


func get_unit_pool() -> Array[UnitData]:
	if not unit_pool.is_empty():
		return unit_pool
	if not character_pool.is_empty():
		return character_pool
	return pool


## 合同名 shop_cost → As-Is 字段 UnitData.cost；≤0 用默认。
func get_recruit_cost(unit: UnitData) -> int:
	if unit == null:
		return get_default_unit_cost()
	if unit.cost > 0:
		return unit.cost
	return get_default_unit_cost()
