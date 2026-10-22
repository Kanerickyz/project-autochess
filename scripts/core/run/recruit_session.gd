class_name RecruitSession
extends RefCounted
## 招募阶段逻辑：进门快照、抽候选人、招募/替换、刷新、重置、跳过/完成。
## 不拥有 UI；只改 DeckState（队伍 As-Is）与 RunEconomy 金币。
## 候选人默认 5 槽（RecruitConfig.candidate_count）；道具行见 RecruitShopService。

signal session_changed
signal session_finished(kept_changes: bool)

const CANDIDATE_COUNT := 5

var config: RecruitConfig
var deck: DeckState
var economy: RunEconomy
var _rng: RandomNumberGenerator

var candidates: Array[UnitData] = []
## 与 candidates 同长：锁定槽刷新时保留角色。
var candidate_locked: Array[bool] = []
var is_active: bool = false
var progress_ratio: float = 0.0
## 地图层号（1-based）；>0 时品阶解锁走 TierUnlock（T2 自第 4 层）。
var map_floor: int = 0
## 开局招募：完成须队伍 ≥1，且禁用跳过；胜后招募保持 false。
var require_nonempty_roster: bool = false

var _snapshot_gold: int = 0
var _snapshot_entries: Array[DeckEntry] = []
var _snapshot_next_entry_id: int = 0
var _snapshot_candidates: Array[UnitData] = []
var _snapshot_locked: Array[bool] = []
## 跨场招募保留：上一场结束时仍锁定的候选人（按槽）。
var _persisted_candidates: Array[UnitData] = []
var _persisted_locked: Array[bool] = []


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


func begin(p_progress_ratio: float = 0.0, p_map_floor: int = 0) -> void:
	if deck == null or economy == null:
		push_error("RecruitSession.begin: deck/economy missing")
		return
	progress_ratio = clampf(p_progress_ratio, 0.0, 1.0)
	map_floor = maxi(0, p_map_floor)
	## 开局招募不继承上一场锁定。
	if require_nonempty_roster:
		clear_persisted_locks()
	candidates.clear()
	_roll_candidates()
	_apply_persisted_locks()
	_capture_snapshot()
	is_active = true
	session_changed.emit()


## 清空跨场锁定（新 Run / 开局招募）。
func clear_persisted_locks() -> void:
	_persisted_candidates.clear()
	_persisted_locked.clear()


func get_candidates() -> Array[UnitData]:
	return candidates.duplicate()


func get_candidate_slot_count() -> int:
	if config != null:
		return config.get_candidate_count()
	return CANDIDATE_COUNT


func get_candidate(index: int) -> UnitData:
	if index < 0 or index >= candidates.size():
		return null
	return candidates[index]


func is_candidate_locked(index: int) -> bool:
	if index < 0 or index >= candidate_locked.size():
		return false
	return candidate_locked[index]


## 有候选人的槽可切换锁定；空槽强制解锁。返回切换后是否锁定。
func toggle_candidate_lock(index: int) -> bool:
	_ensure_lock_slots()
	if index < 0 or index >= candidates.size():
		return false
	if candidates[index] == null:
		candidate_locked[index] = false
		session_changed.emit()
		return false
	candidate_locked[index] = not candidate_locked[index]
	session_changed.emit()
	return candidate_locked[index]


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
	## 队伍席位上限：取牌库 max_size 与座位网格总数的较小值。
	## 本版主路径 max_size=5、网格 4×5=20 → cap≈5；不用 deploy_cap。
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
	## 主路径：按地图层解锁（T2 自第 4 层）。无层号时回退旧进度三段。
	if map_floor > 0:
		return TierUnlock.get_max_unlocked_tier(map_floor)
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


## 满员时若买入会使「同 id 同 1 星」凑满 3 只并自动三合一，则无需换人。
func can_recruit_via_merge(unit: UnitData) -> bool:
	if unit == null or deck == null:
		return false
	return deck.would_complete_triple_on_add(unit, 1)


func needs_replace_for_candidate(candidate_index: int) -> bool:
	if not is_roster_full():
		return false
	var unit := get_candidate(candidate_index)
	if can_recruit_via_merge(unit):
		return false
	return true


## 空席：replace_entry_id 忽略；seat_index≥0 落到指定空座，否则首空座。
## 满员：必须指定被替换成员；新人继承其座位。
## 例外：已有同 id 同星 2 只时，满员也可买入并自动三合一。
func try_recruit(
	candidate_index: int,
	replace_entry_id: int = -1,
	seat_index: int = -1,
) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "inactive",
		"entry": null,
		"replaced": false,
		"seat_index": -1,
	}
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

	var merge_overflow := is_roster_full() and can_recruit_via_merge(unit)
	if not is_roster_full() or merge_overflow:
		if not economy.spend(cost):
			result["reason"] = "no_gold"
			return result
		var preferred := seat_index
		if preferred >= 0 and not deck.is_seat_free(preferred):
			preferred = -1
		var entry := deck.add_entry(unit, 0, preferred)
		if entry == null:
			economy.grant(cost)
			result["reason"] = "add_failed"
			return result
		candidates[candidate_index] = null
		_set_candidate_locked(candidate_index, false)
		result["ok"] = true
		result["reason"] = "merged" if merge_overflow else "added"
		result["entry"] = entry
		result["seat_index"] = entry.seat_index
		session_changed.emit()
		return result

	## 满员替换：旧人不退金；继承被替者座位。
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
	_set_candidate_locked(candidate_index, false)
	result["ok"] = true
	result["reason"] = "replaced"
	result["entry"] = replaced
	result["replaced"] = true
	result["seat_index"] = replaced.seat_index
	session_changed.emit()
	return result


## 招募上区换座：写回 DeckState 持久占位（与准备换座同一规则）。
func try_swap_seat(entry_id: int, target_seat: int) -> bool:
	if not is_active or deck == null:
		return false
	if deck.get_entry(entry_id) == null:
		return false
	if not deck.swap_seats(entry_id, target_seat):
		return false
	session_changed.emit()
	return true


func try_refresh() -> bool:
	if not can_refresh():
		return false
	var cost := get_refresh_cost()
	if not economy.spend(cost):
		return false
	_roll_unlocked_candidates()
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
	## 先记下当前锁定，再 reset 队伍/金币；锁定跨场保留，本场养成改动仍丢弃。
	_persist_locks_for_next_session()
	reset()
	is_active = false
	session_finished.emit(false)


func finish() -> void:
	if not can_finish():
		return
	_persist_locks_for_next_session()
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
	_snapshot_locked = candidate_locked.duplicate()


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
	candidate_locked = _snapshot_locked.duplicate()
	_ensure_lock_slots()


func _roll_candidates() -> void:
	var count := get_candidate_slot_count()
	candidates.clear()
	candidate_locked.clear()
	var preferred := get_preferred_tier()
	for _i in count:
		candidates.append(_pick_one(preferred))
		candidate_locked.append(false)


## 离开招募时写入跨场锁定；下一场 begin 时套回锁定槽。
func _persist_locks_for_next_session() -> void:
	_persisted_candidates.clear()
	_persisted_locked.clear()
	_ensure_lock_slots()
	var count := get_candidate_slot_count()
	for i in count:
		var locked := i < candidate_locked.size() and candidate_locked[i]
		var unit: UnitData = candidates[i] if i < candidates.size() else null
		if locked and unit != null:
			_persisted_candidates.append(unit)
			_persisted_locked.append(true)
		else:
			_persisted_candidates.append(null)
			_persisted_locked.append(false)


func _apply_persisted_locks() -> void:
	if _persisted_locked.is_empty():
		return
	_ensure_lock_slots()
	var count := get_candidate_slot_count()
	var preferred := get_preferred_tier()
	for i in count:
		if i >= _persisted_locked.size() or not _persisted_locked[i]:
			continue
		var unit: UnitData = _persisted_candidates[i] if i < _persisted_candidates.size() else null
		if unit == null:
			continue
		## 锁定单位须仍在当前解锁池内，否则改抽并解锁。
		if unit.tier > preferred:
			candidates[i] = _pick_one(preferred)
			candidate_locked[i] = false
			continue
		candidates[i] = unit
		candidate_locked[i] = true


## 刷新：锁定槽保留角色；未锁定槽重抽。
func _roll_unlocked_candidates() -> void:
	_ensure_lock_slots()
	var count := get_candidate_slot_count()
	var preferred := get_preferred_tier()
	while candidates.size() < count:
		candidates.append(null)
		candidate_locked.append(false)
	for i in count:
		if candidate_locked[i] and candidates[i] != null:
			continue
		candidates[i] = _pick_one(preferred)
		candidate_locked[i] = false


func _ensure_lock_slots() -> void:
	var count := maxi(candidates.size(), get_candidate_slot_count())
	while candidate_locked.size() < count:
		candidate_locked.append(false)
	while candidate_locked.size() > candidates.size() and candidate_locked.size() > 0:
		candidate_locked.pop_back()


func _set_candidate_locked(index: int, locked: bool) -> void:
	_ensure_lock_slots()
	if index < 0 or index >= candidate_locked.size():
		return
	candidate_locked[index] = locked


func _pick_one(preferred_tier: int) -> UnitData:
	var pool := _player_pool()
	if pool.is_empty():
		return null
	## 解锁到 T 时：把 ≤T 的角色全部并入可抽池（不是只抽当前最高 tier）。
	var unlocked: Array[UnitData] = []
	for unit in pool:
		if unit == null:
			continue
		if unit.tier <= preferred_tier:
			unlocked.append(unit)
	if unlocked.is_empty():
		return pool[_rng.randi_range(0, pool.size() - 1)]
	return unlocked[_rng.randi_range(0, unlocked.size() - 1)]


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
