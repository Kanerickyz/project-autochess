class_name SimUnitFeatures
extends RefCounted
## 直选池启发式 / bandit-v5 状态用的单位角色特征（只读 UnitData / AbilityData）。

const ROLE_FRONT := "front"
const ROLE_RANGED := "ranged"
const ROLE_HEALER := "healer"
const ROLE_DPS := "dps"

const DPS_TOP_FRACTION := 0.3

static var _healer_cache: Dictionary = {}
## 全花名册攻/血比前 30% 分位阈值；未配置时回退 1/3。
static var _dps_ratio_threshold: float = -1.0


static func configure_pool(pool: Array) -> void:
	var ratios: Array[float] = []
	for unit in pool:
		var u := unit as UnitData
		if u == null or u.team_default != UnitInstance.Team.PLAYER:
			continue
		ratios.append(_atk_hp_ratio(u))
	if ratios.is_empty():
		return
	ratios.sort()
	var idx := clampi(int(floor(float(ratios.size()) * (1.0 - DPS_TOP_FRACTION))), 0, ratios.size() - 1)
	_dps_ratio_threshold = ratios[idx]


static func _atk_hp_ratio(unit: UnitData) -> float:
	return float(atk(unit)) / float(maxi(1, hp(unit)))


static func atk(unit: UnitData) -> int:
	return unit.stats.attack if unit != null and unit.stats != null else 1


static func hp(unit: UnitData) -> int:
	return unit.stats.max_hp if unit != null and unit.stats != null else 1


static func is_ranged(unit: UnitData) -> bool:
	return unit != null and unit.stats != null and unit.stats.attack_range >= 2


static func is_healer(unit: UnitData) -> bool:
	if unit == null or unit.id.is_empty():
		return false
	if _healer_cache.has(unit.id):
		return bool(_healer_cache[unit.id])
	var found := _ability_heals(unit.ability)
	if not found:
		for p in unit.passives:
			if _ability_heals(p):
				found = true
				break
	_healer_cache[unit.id] = found
	return found


static func _ability_heals(ability: AbilityData) -> bool:
	if ability == null:
		return false
	for spec in ability.effect_specs:
		if spec == null:
			continue
		for action in spec.actions:
			if action != null and action.action_type == EffectAction.Type.HEAL:
				return true
	return false


static func is_dps(unit: UnitData) -> bool:
	if _dps_ratio_threshold < 0.0:
		return atk(unit) * 3 >= hp(unit)
	return _atk_hp_ratio(unit) >= _dps_ratio_threshold


static func roles(unit: UnitData) -> PackedStringArray:
	var out := PackedStringArray()
	if unit == null:
		return out
	out.append(ROLE_RANGED if is_ranged(unit) else ROLE_FRONT)
	if is_healer(unit):
		out.append(ROLE_HEALER)
	if is_dps(unit):
		out.append(ROLE_DPS)
	return out


static func unit_strength(unit: UnitData) -> float:
	if unit == null:
		return 0.0
	return (float(atk(unit)) * 2.0 + float(hp(unit))) * (1.0 + 0.25 * float(maxi(1, unit.tier) - 1))


static func entry_strength(entry: DeckEntry) -> float:
	if entry == null or entry.unit == null:
		return 0.0
	var base := float(atk(entry.unit) + entry.bonus_attack) * 2.0 + float(hp(entry.unit) + entry.bonus_max_hp)
	var tier_mult := 1.0 + 0.25 * float(maxi(1, entry.unit.tier) - 1)
	return base * tier_mult * pow(1.8, float(maxi(1, entry.level) - 1))


## 入座上限内最强的 N 人（按 entry_strength），即战斗实际阵容近似。
static func lineup(deck: DeckState) -> Array[DeckEntry]:
	var all: Array[DeckEntry] = []
	for entry in deck.get_entries():
		if entry != null and entry.unit != null:
			all.append(entry)
	all.sort_custom(func(a: DeckEntry, b: DeckEntry) -> bool:
		return entry_strength(a) > entry_strength(b)
	)
	var n := mini(all.size(), deck.get_max_size())
	var out: Array[DeckEntry] = []
	for i in n:
		out.append(all[i])
	return out


static func role_counts(entries: Array[DeckEntry]) -> Dictionary:
	var counts := {ROLE_FRONT: 0, ROLE_RANGED: 0, ROLE_HEALER: 0, ROLE_DPS: 0}
	for entry in entries:
		for r in roles(entry.unit):
			counts[r] = int(counts[r]) + 1
	return counts


static func role_targets(seat_cap: int) -> Dictionary:
	var n := maxi(1, seat_cap)
	return {
		ROLE_FRONT: int(ceil(float(n) * 0.4)),
		ROLE_RANGED: maxi(1, int(floor(float(n) * 0.3))),
		ROLE_HEALER: 1 if n >= 5 else 0,
		ROLE_DPS: 1 if n >= 4 else 0,
	}


static func count_same_level1(deck: DeckState, unit_id: String) -> int:
	var c := 0
	for entry in deck.get_entries():
		if entry != null and entry.unit != null and entry.get_unit_id() == unit_id and entry.level == 1:
			c += 1
	return c


static func count_same_level(deck: DeckState, unit_id: String, level: int) -> int:
	var c := 0
	for entry in deck.get_entries():
		if entry != null and entry.unit != null and entry.get_unit_id() == unit_id and entry.level == level:
			c += 1
	return c


## 同名 1★ 恰 2 只（再拿 1 只即 2★）的组数。
static func pair_group_count(deck: DeckState) -> int:
	var c1: Dictionary = {}
	for entry in deck.get_entries():
		if entry == null or entry.unit == null or entry.level != 1:
			continue
		var uid := entry.get_unit_id()
		c1[uid] = int(c1.get(uid, 0)) + 1
	var n := 0
	for k in c1.keys():
		if int(c1[k]) >= 2:
			n += 1
	return n


## 只有 1 只 1★、尚未成对的不同角色数（「新开」散件）。
static func single_group_count(deck: DeckState) -> int:
	var c1: Dictionary = {}
	for entry in deck.get_entries():
		if entry == null or entry.unit == null or entry.level != 1:
			continue
		var uid := entry.get_unit_id()
		c1[uid] = int(c1.get(uid, 0)) + 1
	var n := 0
	for k in c1.keys():
		if int(c1[k]) == 1:
			n += 1
	return n


static func has_pair(deck: DeckState) -> bool:
	var buckets: Dictionary = {}
	for entry in deck.get_entries():
		if entry == null or entry.unit == null or entry.level >= 3:
			continue
		var k := "%s#%d" % [entry.get_unit_id(), entry.level]
		buckets[k] = int(buckets.get(k, 0)) + 1
		if int(buckets[k]) >= 2:
			return true
	return false


static func floor_segment(floor: int) -> String:
	if floor <= 3:
		return "f1"
	if floor <= 9:
		return "f4"
	if floor <= 12:
		return "f10"
	return "f13"


static func _bucket3(v: int) -> int:
	if v <= 0:
		return 0
	if v <= 2:
		return 1
	return 2


## bandit-v5 特征化状态：层段 / 席位 / 拥有数 / 阵容角色缺口 / 三合一进度。
static func direct_state_key(deck: DeckState, floor: int) -> String:
	var seats := deck.get_max_size()
	var owned := deck.size()
	var lu := lineup(deck)
	var counts := role_counts(lu)
	var targets := role_targets(seats)
	var gaps := PackedStringArray()
	for r in [ROLE_FRONT, ROLE_RANGED, ROLE_HEALER, ROLE_DPS]:
		gaps.append("1" if int(counts[r]) < int(targets[r]) else "0")
	var avg_tier := 0.0
	for e in lu:
		avg_tier += float(e.unit.tier)
	avg_tier = avg_tier / float(maxi(1, lu.size()))
	var seat_b := 0 if seats <= 6 else (1 if seats <= 8 else 2)
	var owned_b := 0 if owned <= 2 else (1 if owned <= 5 else (2 if owned <= 8 else 3))
	var pairs := pair_group_count(deck)
	var stars2 := 0
	for e in lu:
		if e.level >= 2:
			stars2 += 1
	return "v5|%s|s%d|o%d|gap%s|fr%d|rg%d|t%d|pg%d|st%d" % [
		floor_segment(floor),
		seat_b,
		owned_b,
		"".join(gaps),
		_bucket3(int(counts[ROLE_FRONT])),
		_bucket3(int(counts[ROLE_RANGED])),
		int(round(avg_tier)),
		mini(pairs, 2),
		_bucket3(stars2),
	]
