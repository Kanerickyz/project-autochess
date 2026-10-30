class_name DirectPickRecruiter
extends RefCounted
## Sim 直选池：每次招募阶段候选 = 当前层解锁档位全部玩家角色；无视金币/旗帜/刷新。
## F4 起每阶段先免费席位 +1（封顶 DeckState.SEAT_CAP_HARD_MAX）；每阶段最多拿 MAX_PICKS_PER_PHASE。
## 加人与三合一走 DeckState.add_entry（与 RecruitSession.try_recruit 同一入口）；满员替换走 DeckState.replace_entry。

const MAX_PICKS_PER_PHASE := 10
const SEAT_BONUS_FROM_FLOOR := 4

var recruit_config: RecruitConfig
var _taken_copies: Dictionary = {}
var _run_picks: Array[Dictionary] = []


func configure(p_recruit: RecruitConfig) -> void:
	recruit_config = p_recruit


func begin_run() -> void:
	_taken_copies.clear()
	_run_picks.clear()


func get_run_picks() -> Array:
	return _run_picks.duplicate(true)


func copies_remaining(unit_id: String) -> int:
	return maxi(0, RecruitSession.COPIES_PER_CHARACTER - int(_taken_copies.get(unit_id, 0)))


## chooser 须实现：
## direct_pick_choose(deck, candidates: Array[UnitData], floor: int) -> UnitData（null=停止本阶段）
## direct_pick_replace_target(deck, unit: UnitData) -> int（entry_id；<0 放弃）
func run_phase(
	deck: DeckState,
	chooser: Object,
	map_floor: int,
	floor_count: int,
	forward_unlock: bool,
) -> int:
	if deck == null or chooser == null:
		return 0
	var floor := maxi(1, map_floor)
	if floor >= SEAT_BONUS_FROM_FLOOR and not deck.is_seat_cap_maxed():
		deck.try_increase_seat_cap(1)
	var min_tier := TierUnlock.get_min_unlocked_tier(floor, floor_count, forward_unlock)
	var max_tier := TierUnlock.get_max_unlocked_tier(floor, floor_count, forward_unlock)
	var picks := 0
	for _i in MAX_PICKS_PER_PHASE:
		var candidates := _build_candidates(deck, min_tier, max_tier)
		if candidates.is_empty():
			break
		var unit: UnitData = chooser.direct_pick_choose(deck, candidates, floor)
		if unit == null:
			break
		var mode := _apply_pick(deck, chooser, unit)
		if mode.is_empty():
			break
		_taken_copies[unit.id] = int(_taken_copies.get(unit.id, 0)) + 1
		_run_picks.append({"unit_id": unit.id, "floor": floor, "mode": mode, "tier": unit.tier})
		picks += 1
	_rebalance_seating(deck, chooser)
	return picks


func _build_candidates(deck: DeckState, min_tier: int, max_tier: int) -> Array[UnitData]:
	var out: Array[UnitData] = []
	if recruit_config == null:
		return out
	for unit in recruit_config.get_unit_pool():
		if unit == null or unit.id.is_empty():
			continue
		if unit.team_default != UnitInstance.Team.PLAYER:
			continue
		if unit.tier < min_tier or unit.tier > max_tier:
			continue
		if copies_remaining(unit.id) <= 0:
			continue
		out.append(unit)
	return out


func _apply_pick(deck: DeckState, chooser: Object, unit: UnitData) -> String:
	var merge := deck.would_complete_triple_on_add(unit, 1)
	if deck.can_add() or merge:
		var entry := deck.add_entry(unit, 0, -1, false)
		if entry == null:
			return ""
		return "merge" if merge else "add"
	var replace_id: int = chooser.direct_pick_replace_target(deck, unit)
	if replace_id < 0 or deck.get_entry(replace_id) == null:
		return ""
	var replaced := deck.replace_entry(replace_id, unit)
	if replaced == null:
		return ""
	return "replace"


## 备战里比已入座更强的人换上场（DeckState.try_place_on_bench 与备战占位互换）。
func _rebalance_seating(deck: DeckState, chooser: Object) -> void:
	for _guard in DeckState.BENCH_CAPACITY + 1:
		var best_bench: DeckEntry = null
		var worst_seated: DeckEntry = null
		var best_s := -1.0e9
		var worst_s := 1.0e9
		for entry in deck.get_entries():
			if entry == null or entry.unit == null:
				continue
			var s: float = chooser.direct_pick_entry_score(entry)
			if entry.seat_index >= 0:
				if s < worst_s:
					worst_s = s
					worst_seated = entry
			elif s > best_s:
				best_s = s
				best_bench = entry
		if best_bench == null:
			return
		if deck.can_seat_more():
			var seat := deck.find_first_empty_seat()
			if seat < 0 or not deck.assign_seat(best_bench.entry_id, seat):
				return
			continue
		if worst_seated == null or best_s <= worst_s:
			return
		if not deck.try_place_on_bench(worst_seated.entry_id, best_bench.bench_slot_index):
			return
