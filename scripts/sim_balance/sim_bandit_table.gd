class_name SimBanditTable
extends RefCounted
## 遭遇胜负（win/loss）驱动的离散 bandit 统计；键 = state_key + action_key。

const UCB_C := 1.414
const LAPLACE_PRIOR_W := 1.0
const LAPLACE_PRIOR_L := 1.0


func _init() -> void:
	_stats.clear()
	_total_updates = 0


var _stats: Dictionary = {}
var _total_updates: int = 0


func clear() -> void:
	_stats.clear()
	_total_updates = 0


func import_dict(data: Dictionary) -> void:
	_stats = data.duplicate(true) if data != null else {}
	_total_updates = 0
	for key in _stats.keys():
		var row: Variant = _stats[key]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		_total_updates += int(row.get("w", 0)) + int(row.get("l", 0))


func export_dict() -> Dictionary:
	return _stats.duplicate(true)


func record_outcome(state_key: String, action_key: String, won: bool, learning: bool) -> void:
	record_weighted(state_key, action_key, 1 if won else 0, 0 if won else 1, learning)


func record_weighted(
	state_key: String,
	action_key: String,
	w_add: int,
	l_add: int,
	learning: bool,
) -> void:
	if not learning:
		return
	w_add = maxi(0, w_add)
	l_add = maxi(0, l_add)
	if w_add == 0 and l_add == 0:
		return
	var k := _compound_key(state_key, action_key)
	if not _stats.has(k):
		_stats[k] = {"w": 0, "l": 0}
	var row: Dictionary = _stats[k]
	row["w"] = int(row.get("w", 0)) + w_add
	row["l"] = int(row.get("l", 0)) + l_add
	_total_updates += w_add + l_add


func select_arm(
	state_key: String,
	arm_count: int,
	heuristic_arm: int,
	explore: bool,
	min_samples: int = 0,
) -> int:
	if arm_count <= 0:
		return 0
	var fallback := clampi(heuristic_arm, 0, arm_count - 1)
	if arm_count == 1:
		return 0
	if min_samples > 0:
		var seen := 0
		for i in arm_count:
			var row := _row(state_key, str(i))
			seen += int(row.get("w", 0)) + int(row.get("l", 0))
		if seen < min_samples:
			return fallback
	if not explore:
		return _greedy_arm(state_key, arm_count, fallback)
	return _ucb_arm(state_key, arm_count, fallback)


func select_arm_by_action_keys(
	state_key: String,
	action_keys: PackedStringArray,
	heuristic_key: String,
	explore: bool,
	min_samples: int = 0,
) -> String:
	if action_keys.is_empty():
		return ""
	if action_keys.size() == 1:
		return action_keys[0]
	var fallback := heuristic_key
	if not action_keys.has(fallback):
		fallback = action_keys[0]
	if min_samples > 0:
		var seen := 0
		for ak in action_keys:
			var row := _row(state_key, ak)
			seen += int(row.get("w", 0)) + int(row.get("l", 0))
		if seen < min_samples:
			return fallback
	if not explore:
		return _greedy_action_key(state_key, action_keys, fallback)
	return _ucb_action_key(state_key, action_keys, fallback)


func _greedy_action_key(
	state_key: String,
	action_keys: PackedStringArray,
	fallback: String,
) -> String:
	var best_key := fallback
	var best_rate := -1.0
	var seen_data := false
	for ak in action_keys:
		var row := _row(state_key, ak)
		var total := int(row.get("w", 0)) + int(row.get("l", 0))
		if total <= 0:
			continue
		seen_data = true
		var rate := float(row.get("w", 0)) / float(total)
		if rate > best_rate:
			best_rate = rate
			best_key = ak
	if not seen_data:
		return fallback
	return best_key


func _ucb_action_key(
	state_key: String,
	action_keys: PackedStringArray,
	fallback: String,
) -> String:
	var log_n := log(maxf(2.0, float(_total_updates + 1)))
	var best_key := fallback
	var best_score := -1.0e9
	for ak in action_keys:
		var row := _row(state_key, ak)
		var w := int(row.get("w", 0))
		var l := int(row.get("l", 0))
		var n := w + l
		var score: float
		if n <= 0:
			score = 1.0e6
		else:
			score = float(w) / float(n) + UCB_C * sqrt(log_n / float(n))
		if score > best_score:
			best_score = score
			best_key = ak
	return best_key


func _greedy_arm(state_key: String, arm_count: int, fallback: int) -> int:
	var best_i := fallback
	var best_rate := -1.0
	var seen_data := false
	for i in arm_count:
		var row := _row(state_key, str(i))
		var total := int(row.get("w", 0)) + int(row.get("l", 0))
		if total <= 0:
			continue
		seen_data = true
		var rate := float(row.get("w", 0)) / float(total)
		if rate > best_rate:
			best_rate = rate
			best_i = i
	if not seen_data:
		return fallback
	return best_i


func _ucb_arm(state_key: String, arm_count: int, fallback: int) -> int:
	var log_n := log(maxf(2.0, float(_total_updates + 1)))
	var best_i := fallback
	var best_score := -1.0e9
	for i in arm_count:
		var row := _row(state_key, str(i))
		var w := int(row.get("w", 0))
		var l := int(row.get("l", 0))
		var n := w + l
		var score: float
		if n <= 0:
			score = 1.0e6
		else:
			score = float(w) / float(n) + UCB_C * sqrt(log_n / float(n))
		if score > best_score:
			best_score = score
			best_i = i
	return best_i


func _row(state_key: String, action_key: String) -> Dictionary:
	var k := _compound_key(state_key, action_key)
	if not _stats.has(k):
		return {"w": 0, "l": 0}
	return _stats[k]


func get_total_updates() -> int:
	return _total_updates


func get_coverage_summary() -> Dictionary:
	var totals: Array[int] = []
	for key in _stats.keys():
		var row: Variant = _stats[key]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		totals.append(int(row.get("w", 0)) + int(row.get("l", 0)))
	var key_count := totals.size()
	if key_count == 0:
		return {"keys": 0, "median_wl": 0, "pct_keys_ge5": 0.0}
	totals.sort()
	var median := totals[key_count / 2]
	var ge5 := 0
	for t in totals:
		if t >= 5:
			ge5 += 1
	return {
		"keys": key_count,
		"median_wl": median,
		"pct_keys_ge5": roundf(float(ge5) / float(key_count) * 1000.0) / 10.0,
	}


func smoothed_win_rate(
	state_key: String,
	action_key: String,
	prior_w: float = LAPLACE_PRIOR_W,
	prior_l: float = LAPLACE_PRIOR_L,
) -> float:
	var row := _row(state_key, action_key)
	var w := prior_w + float(row.get("w", 0))
	var l := prior_l + float(row.get("l", 0))
	return w / maxf(1.0, w + l)


func _compound_key(state_key: String, action_key: String) -> String:
	return "%s|%s" % [state_key, action_key]
