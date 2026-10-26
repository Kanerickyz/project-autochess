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
## 层威胁增长：E_raw *= (1 + growth × (F−1))；F 为地图层号（≥1）。使同队越深层越难。
@export_range(0.0, 0.5, 0.01) var floor_threat_growth: float = 0.06

@export_group("Bandwidth")
## 普通默认半宽（±20%）
@export_range(0.05, 1.0, 0.01) var band_combat: float = 0.20
## 精英默认半宽（±15%）
@export_range(0.05, 1.0, 0.01) var band_elite: float = 0.15
## Boss 默认半宽
@export_range(0.05, 1.0, 0.01) var band_boss: float = 0.15
## 拒采样失败后放宽一档的增量
@export_range(0.0, 1.0, 0.01) var band_widen_step: float = 0.10
## 带宽内偏向上沿：接受解优先 ΣU≥E；同误差时偏好更高 ΣU。
@export var prefer_upper_band: bool = true

@export_group("Formation")
## soft 阵型标签池；空则用默认 frontline/skirmish/backline。仅池内标签参与加权抽取。
@export var formation_tags: Array[String] = ["frontline", "skirmish", "backline"]
## 阵型标签权重（按权重抽，非等权数组重复）。balance 可抬前排/游走。
@export_range(0.0, 100.0, 0.1) var formation_weight_frontline: float = 1.0
@export_range(0.0, 100.0, 0.1) var formation_weight_skirmish: float = 1.0
@export_range(0.0, 100.0, 0.1) var formation_weight_backline: float = 1.0

@export_group("Skill Alpha")
@export_range(0.1, 3.0, 0.05) var skill_alpha_no_ability: float = 0.85
@export_range(0.1, 3.0, 0.05) var skill_alpha_default: float = 1.0
## unit.id → α_skill 覆盖；无映射则走 SkillExpectation 深评分（敌 id 可回退去 enemy_ 前缀）。
@export var skill_alpha_by_unit_id: Dictionary = {}

@export_group("Sampling")
@export_range(1, 200, 1) var rejection_attempts: int = 64
@export_range(0, 100, 1) var hill_climb_swaps: int = 32
@export_range(1, 10, 1) var n_min: int = 1
## 同场已选种类须重复时的降权（0～1）：优先从未选种类抽；仅种类不够时 soft^次数。
@export_range(0.0, 1.0, 0.01) var same_id_soft_dedup_weight: float = 0.05

@export_group("Roster Count")
## 【弃用】普通战斗已改层绑定人数；保留字段兼容旧 .tres。
@export_range(0.0, 1.0, 0.01) var combat_plus_one_chance: float = 0.0
## 精英：以该概率选 N＋2，否则＝N。
@export_range(0.0, 1.0, 0.01) var elite_plus_two_chance: float = 0.5

@export_group("Panel Match")
## 名单锁死后按队均展示攻/血缩放本场敌方面板（主加压）；Boss 节点跳过。
@export var panel_match_enabled: bool = true
## 普通：面板锚＝队均 × 本倍率（再与层下限取 max）。
@export_range(0.1, 3.0, 0.05) var panel_mult_combat: float = 1.0
## 精英：更高一档面板倍率。
@export_range(0.1, 3.0, 0.05) var panel_mult_elite: float = 1.25
## 层向面板攻击下限表；空则用 default_panel_atk_floor × (1+growth)^(F−1)。
@export var floor_panel_atk_min: Array[float] = []
## 层向面板生命下限表；空则用 default_panel_hp_floor × (1+growth)^(F−1)。
@export var floor_panel_hp_min: Array[float] = []
@export_range(1.0, 100.0, 0.5) var default_panel_atk_floor: float = 3.0
@export_range(1.0, 200.0, 0.5) var default_panel_hp_floor: float = 5.0
## 无表时层向面板下限随层缓增。
@export_range(0.0, 0.5, 0.01) var panel_floor_growth: float = 0.08
## 跟队缩放后再加：每层（F−1）每单位固定攻击；0＝关闭（主塔默认）。无尽建议 1。
@export_range(0, 20, 1) var floor_flat_atk_per_level: int = 0
## 跟队缩放后再加：每层（F−1）每单位固定生命；0＝关闭。无尽建议 1。
@export_range(0, 40, 1) var floor_flat_hp_per_level: int = 0

@export_group("Enemy Stars")
## 层向 2★ 保底配额乘数：want≥(F−1)×本值，再与玩家 2★ 人数取 max；0＝仅跟玩家（主塔）。无尽建议 1。
@export_range(0, 5, 1) var floor_star2_per_level: int = 0


## 第 F 层每单位应加的固定攻（F≤1 为 0）。
func get_floor_flat_atk_bonus(floor_index: int) -> int:
	if floor_flat_atk_per_level <= 0:
		return 0
	return maxi(0, maxi(1, floor_index) - 1) * floor_flat_atk_per_level


## 第 F 层每单位应加的固定血。
func get_floor_flat_hp_bonus(floor_index: int) -> int:
	if floor_flat_hp_per_level <= 0:
		return 0
	return maxi(0, maxi(1, floor_index) - 1) * floor_flat_hp_per_level


## 第 F 层层向 2★ 保底只数（尚未与座位数 / 玩家人数取 min/max）。
func get_floor_star2_quota(floor_index: int) -> int:
	if floor_star2_per_level <= 0:
		return 0
	return maxi(0, maxi(1, floor_index) - 1) * floor_star2_per_level


## 普通关：第 F 层人数闭区间 [F, F＋1]（F≥1；floor_index≤0 按第 1 层）。
static func combat_enemy_count_bounds(floor_index: int) -> Vector2i:
	var floor_f := maxi(1, floor_index)
	return Vector2i(floor_f, floor_f + 1)


## 按节点类型掷敌方目标人数（不含座位硬顶裁切）。
## Boss 返回 -1（调用方应跳过人数规则）。
## 普通：层绑定 [F, F＋1]；精英：＝N 或 N＋2（第一关精英强制 ≤N）；空队时 N 按 1 保底。
func roll_enemy_count(
	node_type: MapNodeType.Type,
	player_roster_n: int,
	rng: RandomNumberGenerator,
	floor_index: int = -1,
) -> int:
	if node_type == MapNodeType.Type.BOSS:
		return -1
	var n := maxi(1, player_roster_n)
	if node_type == MapNodeType.Type.ELITE:
		## 第一关：精英不得超过玩家人数。
		if is_first_floor(floor_index):
			return n
		if rng != null and rng.randf() < clampf(elite_plus_two_chance, 0.0, 1.0):
			return n + 2
		return n
	## 普通战斗：与层号绑定，在 [F, F＋1] 内掷点。
	var bounds := combat_enemy_count_bounds(floor_index)
	if rng != null:
		return rng.randi_range(bounds.x, bounds.y)
	return bounds.x


## 地图第 1 层（及测试传入的 0）视为第一关。
static func is_first_floor(floor_index: int) -> bool:
	return floor_index >= 0 and floor_index <= 1


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
	config.panel_match_enabled = true
	config.panel_mult_combat = 1.0
	config.panel_mult_elite = 1.25
	config.default_panel_atk_floor = 3.0
	config.default_panel_hp_floor = 5.0
	config.panel_floor_growth = 0.08
	return config


func get_kappa(node_type: MapNodeType.Type) -> float:
	match node_type:
		MapNodeType.Type.ELITE:
			return maxf(0.01, kappa_elite)
		MapNodeType.Type.BOSS:
			return maxf(0.01, kappa_boss)
		_:
			return maxf(0.01, kappa_combat)


func get_panel_mult(node_type: MapNodeType.Type) -> float:
	if node_type == MapNodeType.Type.ELITE:
		return maxf(0.01, panel_mult_elite)
	return maxf(0.01, panel_mult_combat)


func get_panel_atk_floor(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	var from_table := _read_floor_table_extrapolated(
		floor_panel_atk_min, floor_i, default_panel_atk_floor, panel_floor_growth
	)
	if from_table > 0.0:
		return from_table
	var floor_f := maxi(1, floor_index)
	return maxf(
		1.0,
		default_panel_atk_floor * pow(1.0 + maxf(0.0, panel_floor_growth), float(maxi(0, floor_f - 1))),
	)


func get_panel_hp_floor(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	var from_table := _read_floor_table_extrapolated(
		floor_panel_hp_min, floor_i, default_panel_hp_floor, panel_floor_growth
	)
	if from_table > 0.0:
		return from_table
	var floor_f := maxi(1, floor_index)
	return maxf(
		1.0,
		default_panel_hp_floor * pow(1.0 + maxf(0.0, panel_floor_growth), float(maxi(0, floor_f - 1))),
	)


func get_band(node_type: MapNodeType.Type) -> float:
	match node_type:
		MapNodeType.Type.ELITE:
			return maxf(0.01, band_elite)
		MapNodeType.Type.BOSS:
			return maxf(0.01, band_boss)
		_:
			return maxf(0.01, band_combat)


## 层护栏参照中线（非主目标）。表内 0 视为未配置该层；表外层用 p_mid_floor_growth 外推，避免高 F 难度平台。
func get_p_mid(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	if floor_mid_power.is_empty():
		return maxf(1.0, default_p_mid * pow(1.0 + maxf(0.0, p_mid_floor_growth), float(floor_i)))
	if floor_i < floor_mid_power.size():
		var value := float(floor_mid_power[floor_i])
		if value > 0.0:
			return value
		return maxf(1.0, default_p_mid)
	var last := _last_positive_table_value(floor_mid_power)
	if last <= 0.0:
		last = maxf(1.0, default_p_mid)
	var beyond := floor_i - (floor_mid_power.size() - 1)
	return maxf(1.0, last * pow(1.0 + maxf(0.0, p_mid_floor_growth), float(maxi(0, beyond))))


func get_floor_e_min(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	var from_table := _read_floor_table_extrapolated(
		floor_e_min, floor_i, 0.0, p_mid_floor_growth
	)
	if from_table > 0.0:
		return from_table
	## 占位：0.5×旧层中线（balance 未写 floor_e_min 时）。
	return maxf(1.0, get_p_mid(floor_i) * GUARD_MIN_RATIO)


func get_floor_e_max(floor_index: int) -> float:
	var floor_i := maxi(0, floor_index)
	var from_table := _read_floor_table_extrapolated(
		floor_e_max, floor_i, 0.0, p_mid_floor_growth
	)
	if from_table > 0.0:
		return maxf(get_floor_e_min(floor_i), from_table)
	## 占位：1.5×旧层中线（balance 未写 floor_e_max 时）。
	return maxf(get_floor_e_min(floor_i), get_p_mid(floor_i) * GUARD_MAX_RATIO)


## 普通/精英：E＝κ×S×层威胁乘数，再经层护栏（下限随层上升，保证越深层越难）。
## Boss：返回 0。team_power_s 为进点瞬间整局队伍强度；负值按 0 处理。
func get_target_pressure(
	floor_index: int,
	node_type: MapNodeType.Type,
	team_power_s: float = 0.0,
) -> float:
	if node_type == MapNodeType.Type.BOSS:
		return 0.0
	var s := maxf(0.0, team_power_s)
	var floor_f := maxi(1, floor_index)
	var floor_mult := 1.0 + maxf(0.0, floor_threat_growth) * float(maxi(0, floor_f - 1))
	var e_raw := get_kappa(node_type) * s * floor_mult
	var e_min := get_floor_e_min(floor_index)
	var e_max := get_floor_e_max(floor_index)
	return clampf(e_raw, e_min, maxf(e_min, e_max))


func get_enemy_pool_or_empty() -> Array[UnitData]:
	return enemy_pool


func pick_formation_tag(rng: RandomNumberGenerator) -> FormationTag:
	var tags := formation_tags
	if tags.is_empty():
		tags = ["frontline", "skirmish", "backline"]
	var pick: String = "skirmish"
	if rng != null and not tags.is_empty():
		pick = _pick_weighted_formation_name(tags, rng)
	match pick:
		"frontline":
			return FormationTag.FRONTLINE
		"backline":
			return FormationTag.BACKLINE
		_:
			return FormationTag.SKIRMISH


## 按配置权重从标签池抽一个名字；权重全灭则等权回退。
func _pick_weighted_formation_name(tags: Array[String], rng: RandomNumberGenerator) -> String:
	var names: Array[String] = []
	var weights: Array[float] = []
	var total := 0.0
	for raw in tags:
		var name := String(raw).to_lower()
		var w := formation_weight_for_name(name)
		names.append(name)
		weights.append(w)
		total += w
	if names.is_empty():
		return "skirmish"
	if total <= 0.0000001:
		return names[rng.randi_range(0, names.size() - 1)]
	var roll := rng.randf() * total
	var acc := 0.0
	for i in names.size():
		acc += weights[i]
		if roll <= acc:
			return names[i]
	return names[names.size() - 1]


func formation_weight_for_name(tag_name: String) -> float:
	match String(tag_name).to_lower():
		"frontline":
			return maxf(0.0, formation_weight_frontline)
		"backline":
			return maxf(0.0, formation_weight_backline)
		"skirmish":
			return maxf(0.0, formation_weight_skirmish)
		_:
			return 1.0


func _read_floor_table(table: Array[float], floor_i: int) -> float:
	if table.is_empty():
		return 0.0
	if floor_i < table.size():
		return float(table[floor_i])
	## 表外：返回末格（兼容旧调用）；加压路径请用 _read_floor_table_extrapolated。
	return float(table[table.size() - 1])


## 表内直接取值；表外以末个正值 × (1+growth)^beyond 外推。fallback_base≤0 时仅在表空返回 0。
func _read_floor_table_extrapolated(
	table: Array[float],
	floor_i: int,
	fallback_base: float,
	growth: float,
) -> float:
	if table.is_empty():
		if fallback_base <= 0.0:
			return 0.0
		return maxf(
			1.0,
			fallback_base * pow(1.0 + maxf(0.0, growth), float(maxi(0, floor_i))),
		)
	if floor_i < table.size():
		return float(table[floor_i])
	var last := _last_positive_table_value(table)
	if last <= 0.0:
		if fallback_base <= 0.0:
			return 0.0
		last = fallback_base
	var beyond := floor_i - (table.size() - 1)
	return maxf(0.0, last * pow(1.0 + maxf(0.0, growth), float(maxi(0, beyond))))


func _last_positive_table_value(table: Array[float]) -> float:
	for i in range(table.size() - 1, -1, -1):
		var v := float(table[i])
		if v > 0.0:
			return v
	return 0.0
