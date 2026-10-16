class_name SpawnBudgetConfig
extends Resource
## 队伍强度抽阵配置。enabled=false 时主路径保持 roll_spawn_entries + 顺序占座。
## 普通/精英：E＝κ×队伍强度 S，再经层护栏夹紧；Boss 不吃真队目标。

const DEFAULT_PATH := "res://resources/spawn/default_spawn_budget.tres"
## 无 floor_e_min/max 表时，由 floor_mid_power（层护栏参照）派生的占位比例。
const GUARD_MIN_RATIO := 0.5
const GUARD_MAX_RATIO := 1.5

enum FormationTag {
	FRONTLINE,
	SKIRMISH,
	BACKLINE,
}

@export var enabled: bool = true
## 独立敌池；空则回退 LevelData.enemy_pool（并 warning）。
@export var enemy_pool: Array[UnitData] = []

@export_group("Pressure")
## 层护栏参照中线（非主目标）。balance 未写 floor_e_min/max 时由此派生护栏。
## 与数值资源字段名 floor_mid_power 对齐（balance .tres）。
@export var floor_mid_power: Array[float] = []
## 层护栏 E 下限；空则用 0.5×floor_mid_power（占位，待 balance 填表）。
@export var floor_e_min: Array[float] = []
## 层护栏 E 上限；空则用 1.5×floor_mid_power（占位，待 balance 填表）。
@export var floor_e_max: Array[float] = []
@export_range(1.0, 10000.0, 1.0) var default_p_mid: float = 48.0
## 无表时的简易增长：default_p_mid * (1 + p_mid_floor_growth)^floor
@export_range(0.0, 1.0, 0.01) var p_mid_floor_growth: float = 0.12
## κ(普通)
@export_range(0.1, 5.0, 0.05) var kappa_combat: float = 1.0
## κ(精英)
@export_range(0.1, 5.0, 0.05) var kappa_elite: float = 1.35
## κ(Boss) — Boss 不吃真队目标；保留字段兼容旧资源，主路径不用于定 E。
@export_range(0.1, 5.0, 0.05) var kappa_boss: float = 1.8

@export_group("Bandwidth")
## 普通默认半宽（±20%）
@export_range(0.05, 1.0, 0.01) var band_combat: float = 0.20
## 精英默认半宽（±15%）
@export_range(0.05, 1.0, 0.01) var band_elite: float = 0.15
## Boss 默认半宽
@export_range(0.05, 1.0, 0.01) var band_boss: float = 0.15
## 拒采样失败后放宽一档的增量
@export_range(0.0, 1.0, 0.01) var band_widen_step: float = 0.10

@export_group("Formation")
## soft 阵型标签池；空则用默认 frontline/skirmish/backline。
@export var formation_tags: Array[String] = ["frontline", "skirmish", "backline"]

@export_group("Skill Alpha")
@export_range(0.1, 3.0, 0.05) var skill_alpha_no_ability: float = 0.85
@export_range(0.1, 3.0, 0.05) var skill_alpha_default: float = 1.0
## unit.id → α_skill；无映射则用有/无技能默认。
@export var skill_alpha_by_unit_id: Dictionary = {}

@export_group("Sampling")
@export_range(1, 200, 1) var rejection_attempts: int = 64
@export_range(0, 100, 1) var hill_climb_swaps: int = 32
@export_range(1, 10, 1) var n_min: int = 1


static func load_or_default() -> SpawnBudgetConfig:
	if ResourceLoader.exists(DEFAULT_PATH):
		var loaded := load(DEFAULT_PATH)
		if loaded is SpawnBudgetConfig:
			return loaded as SpawnBudgetConfig
		push_warning("SpawnBudgetConfig: %s is not SpawnBudgetConfig; using code defaults" % DEFAULT_PATH)
	return make_code_defaults()


static func make_code_defaults() -> SpawnBudgetConfig:
	var config := SpawnBudgetConfig.new()
	config.enabled = true
	## 占位护栏参照：约 3 名 mid-tier 单位量级，随层缓增；index 对齐 floor。
	var mids: Array[float] = []
	for floor_i in 16:
		mids.append(48.0 * pow(1.12, float(floor_i)))
	config.floor_mid_power = mids
	config.formation_tags = ["frontline", "skirmish", "backline"]
	return config


func get_kappa(node_type: MapNodeType.Type) -> float:
	match node_type:
		MapNodeType.Type.ELITE:
			return maxf(0.01, kappa_elite)
		MapNodeType.Type.BOSS:
			return maxf(0.01, kappa_boss)
		_:
			return maxf(0.01, kappa_combat)


func get_band(node_type: MapNodeType.Type) -> float:
	match node_type:
		MapNodeType.Type.ELITE:
			return maxf(0.01, band_elite)
		MapNodeType.Type.BOSS:
			return maxf(0.01, band_boss)
		_:
			return maxf(0.01, band_combat)


## 层护栏参照中线（非主目标）。表内 0 视为未配置该层。
func get_p_mid(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	if floor_mid_power.size() > 0:
		var idx := mini(floor_i, floor_mid_power.size() - 1)
		var value := float(floor_mid_power[idx])
		if value > 0.0:
			return value
		return maxf(1.0, default_p_mid)
	return maxf(1.0, default_p_mid * pow(1.0 + maxf(0.0, p_mid_floor_growth), float(floor_i)))


func get_floor_e_min(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	var from_table := _read_floor_table(floor_e_min, floor_i)
	if from_table > 0.0:
		return from_table
	## 占位：0.5×旧层中线（balance 未写 floor_e_min 时）。
	return maxf(1.0, get_p_mid(floor_i) * GUARD_MIN_RATIO)


func get_floor_e_max(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	var from_table := _read_floor_table(floor_e_max, floor_i)
	if from_table > 0.0:
		return maxf(get_floor_e_min(floor_i), from_table)
	## 占位：1.5×旧层中线（balance 未写 floor_e_max 时）。
	return maxf(get_floor_e_min(floor_i), get_p_mid(floor_i) * GUARD_MAX_RATIO)


## 普通/精英：E＝clamp(κ×S, 层下限, 层上限)。Boss：不吃真队，返回 0。
## team_power_s 为进点瞬间整局队伍强度；负值按 0 处理。
func get_target_pressure(
	floor_index: int,
	node_type: MapNodeType.Type,
	team_power_s: float = 0.0,
) -> float:
	if node_type == MapNodeType.Type.BOSS:
		return 0.0
	var s := maxf(0.0, team_power_s)
	var e_raw := get_kappa(node_type) * s
	var e_min := get_floor_e_min(floor_index)
	var e_max := get_floor_e_max(floor_index)
	return clampf(e_raw, e_min, e_max)


func get_enemy_pool_or_empty() -> Array[UnitData]:
	return enemy_pool


func pick_formation_tag(rng: RandomNumberGenerator) -> FormationTag:
	var tags := formation_tags
	if tags.is_empty():
		tags = ["frontline", "skirmish", "backline"]
	var pick: String = "skirmish"
	if rng != null and not tags.is_empty():
		pick = String(tags[rng.randi_range(0, tags.size() - 1)]).to_lower()
	match pick:
		"frontline":
			return FormationTag.FRONTLINE
		"backline":
			return FormationTag.BACKLINE
		_:
			return FormationTag.SKIRMISH


func _read_floor_table(table: Array[float], floor_i: int) -> float:
	if table.is_empty():
		return 0.0
	var idx := mini(floor_i, table.size() - 1)
	return float(table[idx])
