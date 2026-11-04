class_name ExpeditionRelicOfferService
extends RefCounted

## 事件三选一：按层深抽 Tier → 抽件；三格去重；排除行囊已有 id。

const DEFAULT_POOL_PATH := "res://resources/relics/default_relic_pool.tres"

var _pool: ExpeditionRelicPoolConfig
var _rng: RandomNumberGenerator


func configure(pool: ExpeditionRelicPoolConfig = null, rng: RandomNumberGenerator = null) -> void:
	_pool = pool if pool != null else load_pool_or_stub()
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()


static func load_pool_or_stub() -> ExpeditionRelicPoolConfig:
	if ResourceLoader.exists(DEFAULT_POOL_PATH):
		var loaded := load(DEFAULT_POOL_PATH)
		if loaded is ExpeditionRelicPoolConfig:
			return loaded as ExpeditionRelicPoolConfig
	return build_inline_stub_pool()


## balance-designer 资源未到位时的可玩 stub（经济 + 开战生命），保证事件三选一不空。
static func build_inline_stub_pool() -> ExpeditionRelicPoolConfig:
	var cfg := ExpeditionRelicPoolConfig.new()
	cfg.relics = [
		_stub(
			"relic_merchant_writ",
			"商路符牒",
			"战斗胜利发层金时，额外 +1 金",
			1,
			2,
			{"bonus_floor_gold": 1},
		),
		_stub(
			"relic_bazaar_clip",
			"摊贩折角",
			"地图商店刷新费 −1（不低于 1）",
			1,
			2,
			{"map_shop_refresh_cost_delta": -1, "min_refresh_cost": 1},
		),
		_stub(
			"relic_thin_mail_prayer",
			"薄甲祷文",
			"开战全体友方本场临时生命上限 +1",
			1,
			2,
			{"combat_start_temp_max_hp": 1},
		),
		_stub(
			"relic_tax_scale",
			"税吏铜衡",
			"层金额外 +2；地图商店标价 +1",
			2,
			4,
			{"bonus_floor_gold": 2, "map_shop_price_delta": 1},
		),
		_stub(
			"relic_spearwall_chart",
			"矛壁阵图",
			"开战前两排友方本场临时攻 +2",
			2,
			4,
			{"front_two_rows_temp_attack": 2},
		),
		_stub(
			"relic_banner_afterglow",
			"旗缘余晖",
			"至少一主题已成形时，开战全体临时生命上限 +1",
			2,
			4,
			{"requires_any_theme_formed": true, "combat_start_temp_max_hp": 1},
		),
		_stub(
			"relic_dragon_tax_edict",
			"龙税敕令",
			"层金额外 +3；开战全体临时生命上限 −2（最低 1）",
			3,
			6,
			{
				"bonus_floor_gold": 3,
				"combat_start_temp_max_hp": -2,
				"min_max_hp_after": 1,
			},
		),
		_stub(
			"relic_eight_sigil_shard",
			"八徽残印",
			"每成形主题全体临时攻 +1（硬顶 +2）",
			3,
			6,
			{"per_formed_theme_temp_attack": 1, "relic_attack_bonus_cap": 2},
		),
		_stub(
			"relic_empty_coffin_pact",
			"空棺契约",
			"备战每 1 人 → 上场全体临时攻 +1（硬顶 +3）",
			3,
			6,
			{"temp_attack_per_bench_unit": 1, "relic_attack_bonus_cap": 3},
		),
	]
	return cfg


static func _stub(
	id: String,
	display: String,
	desc: String,
	tier: int,
	sell: int,
	fields: Dictionary,
) -> ExpeditionRelicData:
	var r := ExpeditionRelicData.new()
	r.id = id
	r.display_name = display
	r.description = desc
	r.tier = tier
	r.sell_gold = sell
	r.effect_id = id
	if fields.has("bonus_floor_gold"):
		r.bonus_floor_gold = int(fields["bonus_floor_gold"])
	if fields.has("map_shop_refresh_cost_delta"):
		r.map_shop_refresh_cost_delta = int(fields["map_shop_refresh_cost_delta"])
	if fields.has("min_refresh_cost"):
		r.min_refresh_cost = int(fields["min_refresh_cost"])
	if fields.has("map_shop_price_delta"):
		r.map_shop_price_delta = int(fields["map_shop_price_delta"])
	if fields.has("combat_start_temp_max_hp"):
		r.combat_start_temp_max_hp = int(fields["combat_start_temp_max_hp"])
	if fields.has("combat_start_temp_attack"):
		r.combat_start_temp_attack = int(fields["combat_start_temp_attack"])
	if fields.has("front_two_rows_temp_attack"):
		r.front_two_rows_temp_attack = int(fields["front_two_rows_temp_attack"])
	if fields.has("requires_any_theme_formed"):
		r.requires_any_theme_formed = bool(fields["requires_any_theme_formed"])
	if fields.has("per_formed_theme_temp_attack"):
		r.per_formed_theme_temp_attack = int(fields["per_formed_theme_temp_attack"])
	if fields.has("relic_attack_bonus_cap"):
		r.relic_attack_bonus_cap = int(fields["relic_attack_bonus_cap"])
	if fields.has("temp_attack_per_bench_unit"):
		r.temp_attack_per_bench_unit = int(fields["temp_attack_per_bench_unit"])
	if fields.has("min_max_hp_after"):
		r.min_max_hp_after = int(fields["min_max_hp_after"])
	return r


func get_pool() -> ExpeditionRelicPoolConfig:
	return _pool


## 抽取至多 count 件；不足时返回已有数量。
func roll_offers(
	floor_index: int,
	bag: ExpeditionRelicBag,
	count: int = 3,
) -> Array[ExpeditionRelicData]:
	var out: Array[ExpeditionRelicData] = []
	if _pool == null or count <= 0:
		return out
	var exclude: Dictionary = {}
	if bag != null:
		for owned in bag.get_relics():
			if owned != null and not owned.id.is_empty():
				exclude[owned.id] = true
	var attempts := 0
	var max_attempts := maxi(24, count * 12)
	while out.size() < count and attempts < max_attempts:
		attempts += 1
		var pick := _roll_one(floor_index, exclude)
		if pick == null:
			break
		out.append(pick)
		exclude[pick.id] = true
	return out


func _roll_one(floor_index: int, exclude: Dictionary) -> ExpeditionRelicData:
	var weights := _pool.get_weights_for_floor(floor_index)
	var tier := _pick_tier(weights)
	var candidates := _eligible_of_tier(tier, exclude)
	if candidates.is_empty():
		## Tier 抽空时回退其它档，避免整池因排除而空白。
		for t in [1, 2, 3]:
			if t == tier:
				continue
			candidates = _eligible_of_tier(t, exclude)
			if not candidates.is_empty():
				break
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _eligible_of_tier(tier: int, exclude: Dictionary) -> Array[ExpeditionRelicData]:
	var raw := _pool.relics_of_tier(tier)
	var out: Array[ExpeditionRelicData] = []
	for r in raw:
		if r == null or r.id.is_empty():
			continue
		if exclude.has(r.id):
			continue
		out.append(r)
	return out


func _pick_tier(weights: Vector3i) -> int:
	var w1 := maxi(0, weights.x)
	var w2 := maxi(0, weights.y)
	var w3 := maxi(0, weights.z)
	var total := w1 + w2 + w3
	if total <= 0:
		return 1
	var roll := _rng.randi_range(1, total)
	if roll <= w1:
		return 1
	if roll <= w1 + w2:
		return 2
	return 3
