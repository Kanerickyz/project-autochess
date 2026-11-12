class_name BadgeCatalog
extends RefCounted
## 徽章池查询：显式路径加载（Web/导出不可依赖 DirAccess 列目录）。

## 整局持有上限（文档未给格数；实现常量，满员 FIFO 替换）。
const MAX_OWNED := 8

## 花名册路径（与 resources/badges / BADGE_ROSTER 对齐；新增徽章须追加）。
const BADGE_PATHS: PackedStringArray = [
	"res://resources/badges/badge_tank_hp_2.tres",
	"res://resources/badges/badge_tank_hp_5.tres",
	"res://resources/badges/badge_warrior_melee_atk_3.tres",
	"res://resources/badges/badge_warrior_melee_atk_5.tres",
	"res://resources/badges/badge_ranged_hit_1.tres",
	"res://resources/badges/badge_ranged_hit_2.tres",
	"res://resources/badges/badge_artisan_armor_2.tres",
	"res://resources/badges/badge_artisan_armor_5.tres",
	"res://resources/badges/badge_band_rage_2.tres",
	"res://resources/badges/badge_band_rage_4.tres",
	"res://resources/badges/badge_arcane_open_1.tres",
	"res://resources/badges/badge_arcane_open_2.tres",
	"res://resources/badges/badge_alliance_amp.tres",
]

static var _cache: Array[BadgeData] = []
static var _cache_loaded: bool = false


static func clear_cache() -> void:
	_cache.clear()
	_cache_loaded = false


static func all_badges() -> Array[BadgeData]:
	_ensure_loaded()
	return _cache.duplicate()


static func get_by_id(badge_id: String) -> BadgeData:
	if badge_id.is_empty():
		return null
	_ensure_loaded()
	for badge in _cache:
		if badge != null and badge.id == badge_id:
			return badge
	return null


static func resolve_owned(ids: PackedStringArray) -> Array[BadgeData]:
	var out: Array[BadgeData] = []
	for badge_id in ids:
		var badge := get_by_id(str(badge_id))
		if badge != null:
			out.append(badge)
	return out


## 可出现候选：品阶 ∈ [min_tier, max_tier]，排除已持有 id；可选仅羁绊向。
static func filter_candidates(
	owned_ids: PackedStringArray,
	max_tier: int,
	min_tier: int = 1,
	synergy_only: bool = false,
) -> Array[BadgeData]:
	_ensure_loaded()
	var owned := {}
	for badge_id in owned_ids:
		owned[str(badge_id)] = true
	var lo := maxi(1, min_tier)
	var hi := maxi(lo, max_tier)
	var out: Array[BadgeData] = []
	for badge in _cache:
		if badge == null or badge.id.is_empty():
			continue
		if owned.has(badge.id):
			continue
		if badge.tier < lo or badge.tier > hi:
			continue
		if synergy_only and badge.kind != BadgeData.Kind.SYNERGY:
			continue
		out.append(badge)
	return out


static func _ensure_loaded() -> void:
	if _cache_loaded:
		return
	_cache.clear()
	for path in BADGE_PATHS:
		var res := load(path)
		if res is BadgeData:
			_cache.append(res as BadgeData)
		else:
			push_warning("BadgeCatalog: failed to load BadgeData at %s" % path)
	_cache.sort_custom(func(a: BadgeData, b: BadgeData) -> bool:
		if a == null or b == null:
			return a != null
		if a.tier != b.tier:
			return a.tier < b.tier
		return a.id < b.id
	)
	_cache_loaded = true
