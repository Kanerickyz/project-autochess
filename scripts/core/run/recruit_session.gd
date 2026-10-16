class_name RecruitSession
extends RefCounted
## 招募阶段逻辑：进门快照、抽三人、招募/替换、刷新、重置、跳过/完成。
## 不拥有 UI；只改 DeckState（队伍 As-Is）与 RunEconomy 金币。

signal session_changed
signal session_finished(kept_changes: bool)

const CANDIDATE_COUNT := 3

var config: RecruitConfig
var deck: DeckState
var economy: RunEconomy
var _rng: RandomNumberGenerator

var candidates: Array[UnitData] = []
var is_active: bool = false
var progress_ratio: float = 0.0
## 开局招募：完成须队伍 ≥1，且禁用跳过；胜后招募保持 false。
var require_nonempty_roster: bool = false

var _snapshot_gold: int = 0
var _snapshot_entries: Array[DeckEntry] = []
var _snapshot_next_entry_id: int = 0
var _snapshot_candidates: Array[UnitData] = []


func configure(
	p_config: RecruitConfig,
	p_deck: DeckState,
	p_economy: RunEconomy,
	rng: RandomNumberGenerator = null,
) -> void:
	config = p_config
	deck = p_deck
	economy = p_economy
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()


func begin(p_progress_ratio: float = 0.0) -> void:
	if deck == null or economy == null:
		push_error("RecruitSession.begin: deck/economy missing")
		return
	progress_ratio = clampf(p_progress_ratio, 0.0, 1.0)
	candidates.clear()
	_roll_candidates()
	_capture_snapshot()
	is_active = true
	session_changed.emit()


func get_candidates() -> Array[UnitData]:
	return candidates.duplicate()


func get_candidate(index: int) -> UnitData:
	if index < 0 or index >= candidates.size():
		return null
	return candidates[index]


func get_refresh_cost() -> int:
	if config == null:
		return RecruitConfig.DEFAULT_REFRESH_COST
	return config.get_refresh_cost()


func get_recruit_cost(unit: UnitData) -> int:
	if config == null:
		if unit != null and unit.cost > 0:
			return unit.cost
		return RecruitConfig.DEFAULT_UNIT_COST
	return config.get_recruit_cost(unit)


func get_seat_cap() -> int:
	## 队伍席位上限：取牌库 max_size 与座位网格总数的较小值（默认 ≤10），
	## 不用 deploy_cap（As-Is 上场上限可小于队伍人数）。
	if deck == null:
		return 0
	var deck_cap := deck.get_max_size()
	var seat_grid := deck.get_slot_count()
	if deck_cap <= 0 and seat_grid <= 0:
		return 0
	if deck_cap <= 0:
		return seat_grid
	if seat_grid <= 0:
		return deck_cap
	return mini(deck_cap, seat_grid)


func is_roster_full() -> bool:
	if deck == null:
		return true
	return deck.size() >= get_seat_cap()


func get_preferred_tier() -> int:
	if progress_ratio < 1.0 / 3.0:
		return 1
	if progress_ratio < 2.0 / 3.0:
		return 2
	return 3


func can_afford_recruit(candidate_index: int) -> bool:
	var unit := get_candidate(candidate_index)
	if unit == null or economy == null:
		return false
	return economy.can_afford(get_recruit_cost(unit))


func can_refresh() -> bool:
	if not is_active or economy == null:
		return false
	return economy.can_afford(get_refresh_cost())


func needs_replace() -> bool:
	return is_roster_full()


## 空席：replace_entry_id 忽略；满员：必须指定被替换成员。
func try_recruit(candidate_index: int, replace_entry_id: int = -1) -> Dictionary:
	var result := {"ok": false, "reason": "inactive", "entry": null, "replaced": false}
	if not is_active or deck == null or economy == null:
		return result
	var unit := get_candidate(candidate_index)
	if unit == null:
		result["reason"] = "no_candidate"
		return result
	var cost := get_recruit_cost(unit)
	if not economy.can_afford(cost):
		result["reason"] = "no_gold"
		return result

	if not is_roster_full():
		## 空席加入：仍受牌库 max_size 硬顶（DeckState.add_entry），但席位以 deploy_cap 为准。
		if not economy.spend(cost):
			result["reason"] = "no_gold"
			return result
		var entry := deck.add_entry(unit)
		if entry == null:
			economy.grant(cost)
			result["reason"] = "add_failed"
			return result
		candidates[candidate_index] = null
		result["ok"] = true
		result["reason"] = "added"
		result["entry"] = entry
		session_changed.emit()
		return result

	## 满员替换：旧人不退金
	if replace_entry_id < 0:
		result["reason"] = "need_replace"
		return result
	if deck.get_entry(replace_entry_id) == null:
		result["reason"] = "bad_replace"
		return result
	if not economy.spend(cost):
		result["reason"] = "no_gold"
		return result
	var replaced := deck.replace_entry(replace_entry_id, unit)
	if replaced == null:
		economy.grant(cost)
		result["reason"] = "replace_failed"
		return result
	candidates[candidate_index] = null
	result["ok"] = true
	result["reason"] = "replaced"
	result["entry"] = replaced
	result["replaced"] = true
	session_changed.emit()
	return result


func try_refresh() -> bool:
	if not can_refresh():
		return false
	var cost := get_refresh_cost()
	if not economy.spend(cost):
		return false
	_roll_candidates()
	session_changed.emit()
	return true


## 出售上区队伍成员：正常退金并腾位；变动计入快照，可 reset。
func try_sell(entry_id: int) -> Dictionary:
	var result := {"ok": false, "reason": "inactive", "gold": 0, "entry_id": entry_id}
	if not is_active or deck == null or economy == null:
		return result
	var entry := deck.get_entry(entry_id)
	if entry == null:
		result["reason"] = "bad_entry"
		return result
	var price := DeckUpgradeService.get_sell_price(entry)
	if not deck.remove_entry(entry_id):
		result["reason"] = "remove_failed"
		return result
	economy.grant(price)
	result["ok"] = true
	result["reason"] = "sold"
	result["gold"] = price
	session_changed.emit()
	return result


func reset() -> void:
	if not is_active or deck == null or economy == null:
		return
	_restore_snapshot()
	session_changed.emit()


func can_finish() -> bool:
	if not is_active:
		return false
	if require_nonempty_roster:
		return deck != null and deck.size() >= 1
	return true


func can_skip() -> bool:
	if not is_active:
		return false
	## 开局禁用跳过（空队不可离开）。
	if require_nonempty_roster:
		return false
	return true


func skip() -> void:
	if not can_skip():
		return
	reset()
	is_active = false
	session_finished.emit(false)


func finish() -> void:
	if not can_finish():
		return
	is_active = false
	session_finished.emit(true)


func should_offer_recruit(node_type: MapNodeType.Type, won: bool) -> bool:
	if not won:
		return false
	if node_type == MapNodeType.Type.BOSS:
		return false
	return node_type == MapNodeType.Type.COMBAT or node_type == MapNodeType.Type.ELITE


func _capture_snapshot() -> void:
	_snapshot_gold = economy.gold if economy != null else 0
	_snapshot_entries.clear()
	_snapshot_next_entry_id = 0
	if deck != null:
		var roster := deck.capture_roster()
		var source: Array = roster.get("entries", [])
		for item in source:
			if item is DeckEntry:
				_snapshot_entries.append(item as DeckEntry)
		_snapshot_next_entry_id = int(roster.get("next_entry_id", 0))
	_snapshot_candidates = candidates.duplicate()


func _restore_snapshot() -> void:
	if economy != null:
		var delta := _snapshot_gold - economy.gold
		if delta > 0:
			economy.grant(delta)
		elif delta < 0:
			economy.spend(-delta)
	if deck != null:
		deck.restore_roster({
			"entries": _snapshot_entries,
			"next_entry_id": _snapshot_next_entry_id,
		})
	candidates = _snapshot_candidates.duplicate()


func _roll_candidates() -> void:
	var count := CANDIDATE_COUNT
	if config != null:
		count = config.get_candidate_count()
	candidates.clear()
	var preferred := get_preferred_tier()
	for _i in count:
		candidates.append(_pick_one(preferred))


func _pick_one(preferred_tier: int) -> UnitData:
	var pool := _player_pool()
	if pool.is_empty():
		return null
	for tier in range(preferred_tier, 0, -1):
		var tier_pool: Array[UnitData] = []
		for unit in pool:
			if unit != null and unit.tier == tier:
				tier_pool.append(unit)
		if not tier_pool.is_empty():
			return tier_pool[_rng.randi_range(0, tier_pool.size() - 1)]
	## 该档与更低档皆空：任意池内单位
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _player_pool() -> Array[UnitData]:
	var raw: Array[UnitData] = []
	if config != null:
		raw = config.get_unit_pool()
	var result: Array[UnitData] = []
	for unit in raw:
		if unit == null:
			continue
		if unit.team_default != UnitInstance.Team.PLAYER:
			continue
		result.append(unit)
	return result
