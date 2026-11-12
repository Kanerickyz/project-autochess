class_name BadgeCatalog
extends RefCounted
## 徽章池查询：扫描 resources/badges；按品阶 / 已持有过滤候选。

const BADGES_DIR := "res://resources/badges"
## 整局持有上限（文档未给格数；实现常量，满员 FIFO 替换）。
const MAX_OWNED := 8

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
	var dir := DirAccess.open(BADGES_DIR)
	if dir == null:
		push_warning("BadgeCatalog: cannot open %s" % BADGES_DIR)
		_cache_loaded = true
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [BADGES_DIR, file_name]
			var res := load(path)
			if res is BadgeData:
				_cache.append(res as BadgeData)
		file_name = dir.get_next()
	dir.list_dir_end()
	_cache.sort_custom(func(a: BadgeData, b: BadgeData) -> bool:
		if a == null or b == null:
			return a != null
		if a.tier != b.tier:
			return a.tier < b.tier
		return a.id < b.id
	)
	_cache_loaded = true
