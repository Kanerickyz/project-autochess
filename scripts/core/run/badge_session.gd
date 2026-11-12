class_name BadgeSession
extends RefCounted
## 胜后徽章三选一：不花金、可跳过；同 id 不重复（重滚排除已持有）。

signal session_changed
signal session_finished(picked: bool)

const OFFER_COUNT := 3

var run_state: RunState
var is_active: bool = false
var map_floor: int = 0
var map_floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT
var forward_tier_unlock: bool = false
var candidates: Array[BadgeData] = []

var _rng: RandomNumberGenerator


func configure(p_run_state: RunState, rng: RandomNumberGenerator = null) -> void:
	run_state = p_run_state
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()


func begin(
	p_map_floor: int = 0,
	p_map_floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT,
	p_forward_tier_unlock: bool = false,
) -> void:
	if run_state == null:
		push_error("BadgeSession.begin: run_state missing")
		return
	map_floor = maxi(0, p_map_floor)
	map_floor_count = maxi(1, p_map_floor_count)
	forward_tier_unlock = p_forward_tier_unlock
	candidates.clear()
	_roll_candidates()
	is_active = true
	session_changed.emit()


func get_candidates() -> Array[BadgeData]:
	return candidates.duplicate()


func get_candidate(index: int) -> BadgeData:
	if index < 0 or index >= candidates.size():
		return null
	return candidates[index]


func get_max_tier() -> int:
	if map_floor > 0:
		return TierUnlock.get_max_unlocked_tier(map_floor, map_floor_count, forward_tier_unlock)
	return 1


func get_min_tier() -> int:
	if map_floor > 0:
		return TierUnlock.get_min_unlocked_tier(map_floor, map_floor_count, forward_tier_unlock)
	return 1


func can_pick(index: int) -> bool:
	if not is_active:
		return false
	var badge := get_candidate(index)
	if badge == null or badge.id.is_empty():
		return false
	if run_state != null and run_state.has_badge(badge.id):
		return false
	return true


func try_pick(index: int) -> Dictionary:
	var result := {"ok": false, "reason": "inactive", "badge_id": "", "replaced": false}
	if not is_active or run_state == null:
		return result
	if not can_pick(index):
		result["reason"] = "cannot_pick"
		return result
	var badge := get_candidate(index)
	var add := run_state.add_badge(badge.id)
	if not bool(add.get("ok", false)):
		result["reason"] = str(add.get("reason", "add_failed"))
		return result
	result["ok"] = true
	result["reason"] = "picked"
	result["badge_id"] = badge.id
	result["replaced"] = bool(add.get("replaced", false))
	is_active = false
	session_finished.emit(true)
	return result


func skip() -> void:
	if not is_active:
		return
	is_active = false
	session_finished.emit(false)


## 普通/精英胜后进徽章；Boss / 失败不进。
func should_offer_badge(node_type: MapNodeType.Type, won: bool) -> bool:
	if not won:
		return false
	if node_type == MapNodeType.Type.BOSS:
		return false
	return node_type == MapNodeType.Type.COMBAT or node_type == MapNodeType.Type.ELITE


func _roll_candidates() -> void:
	candidates.clear()
	var owned := PackedStringArray()
	if run_state != null:
		owned = run_state.get_owned_badge_ids()
	var pool := BadgeCatalog.filter_candidates(
		owned,
		get_max_tier(),
		get_min_tier(),
		false,
	)
	## 品阶窗过窄时放宽到 ≤max_tier，避免三选一空白。
	if pool.is_empty():
		pool = BadgeCatalog.filter_candidates(owned, get_max_tier(), 1, false)
	if pool.is_empty():
		push_warning(
			"BadgeSession: empty offer pool (owned=%d catalog=%d max_tier=%d)"
			% [owned.size(), BadgeCatalog.all_badges().size(), get_max_tier()]
		)
		return
	## 洗牌后取前 OFFER_COUNT。
	var shuffled: Array[BadgeData] = pool.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: BadgeData = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	for i in mini(OFFER_COUNT, shuffled.size()):
		candidates.append(shuffled[i])
