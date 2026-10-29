class_name BanditRunAI
extends HeuristicRunAI
## v1：选路+招募均吃下一场遭遇胜负。v2：选路吃胜负；招募吃 Run 终局（见 on_run_finished）。

const REWARD_V1 := "v1"
const REWARD_V2 := "v2"
const K_COMPLETE := 2
const K_DEPTH := 3

var bandit_table: SimBanditTable
var learning_enabled: bool = false
var reward_mode: String = REWARD_V1

var _pending_map: Array[Dictionary] = []
var _recruit_log: Array[Dictionary] = []
var _combats_fought: int = 0


func _init(
	p_profile: SimAIProfile = null,
	p_table: SimBanditTable = null,
	p_learning: bool = false,
	p_reward_mode: String = REWARD_V1,
) -> void:
	super._init(p_profile)
	bandit_table = p_table if p_table != null else SimBanditTable.new()
	learning_enabled = p_learning
	reward_mode = p_reward_mode if not p_reward_mode.is_empty() else REWARD_V1
	_reset_run_state()


func begin_run() -> void:
	_reset_run_state()


func _reset_run_state() -> void:
	_pending_map = []
	_recruit_log = []
	_combats_fought = 0


func on_encounter_resolved(won: bool) -> void:
	_combats_fought += 1
	if reward_mode == REWARD_V2:
		for item in _pending_map:
			bandit_table.record_outcome(
				str(item.get("state_key", "")),
				str(item.get("action_key", "")),
				won,
				learning_enabled,
			)
		_pending_map.clear()
		return
	for item in _pending_map:
		bandit_table.record_outcome(
			str(item.get("state_key", "")),
			str(item.get("action_key", "")),
			won,
			learning_enabled,
		)
	_pending_map.clear()


func on_run_finished(outcome: String, death_floor: int, map_floor_max: int) -> void:
	if not learning_enabled or reward_mode != REWARD_V2:
		return
	if _combats_fought < 1:
		return
	if _recruit_log.is_empty():
		return
	var f_max := maxi(1, map_floor_max)
	var d := maxi(0, death_floor)
	for item in _recruit_log:
		var sk := str(item.get("state_key", ""))
		var ak := str(item.get("action_key", ""))
		if outcome == "RUN_COMPLETE":
			bandit_table.record_weighted(sk, ak, K_COMPLETE, 0, true)
		else:
			var w_add := int(round(float(d) / float(f_max) * float(K_DEPTH)))
			var l_add := int(round(float(f_max - d) / float(f_max) * float(K_DEPTH)))
			bandit_table.record_weighted(sk, ak, w_add, l_add, true)


func pick_map_node(run_controller: RunController) -> MapNodeRuntime:
	var ranked := enumerate_map_candidates(run_controller)
	if ranked.is_empty():
		return null
	var options: Array = []
	for item in ranked:
		options.append(item.get("node"))
	var floor := _current_map_floor(run_controller)
	var state_key := SimBanditKeys.map_state(floor, options)
	var heuristic_arm := 0
	var arm := bandit_table.select_arm(
		state_key,
		options.size(),
		heuristic_arm,
		learning_enabled,
	)
	arm = clampi(arm, 0, options.size() - 1)
	_queue_map_decision(state_key, str(arm))
	return options[arm]


func _try_best_recruit(session: RecruitSession) -> bool:
	var candidates: Array[int] = []
	for i in session.get_candidate_slot_count():
		var unit := session.get_candidate(i)
		if unit == null:
			continue
		if not _can_try_recruit(session, unit):
			continue
		candidates.append(i)
	if candidates.is_empty():
		return false
	var floor := maxi(0, session.map_floor)
	var gold := session.economy.gold if session.economy != null else 0
	var roster := session.deck.get_entries().size() if session.deck != null else 0
	var state_key := SimBanditKeys.recruit_state(floor, gold, roster, session)
	var heuristic_arm := 0
	var best_score := -1.0
	for j in candidates.size():
		var idx: int = candidates[j]
		var score := _score_recruit_candidate(session, session.get_candidate(idx))
		if score > best_score:
			best_score = score
			heuristic_arm = j
	var arm_idx := bandit_table.select_arm(
		state_key,
		candidates.size(),
		heuristic_arm,
		learning_enabled,
	)
	arm_idx = clampi(arm_idx, 0, candidates.size() - 1)
	var pick: int = candidates[arm_idx]
	if session.is_roster_full() and not session.can_recruit_via_merge(session.get_candidate(pick)):
		_free_weakest_roster_slot(session)
	var result := session.try_recruit(pick)
	if not bool(result.get("ok", false)):
		return false
	if reward_mode == REWARD_V2:
		_recruit_log.append({"state_key": state_key, "action_key": str(arm_idx)})
	elif reward_mode == REWARD_V1:
		_queue_map_decision(state_key, str(arm_idx))
	return true


func enumerate_map_candidates(run_controller: RunController) -> Array:
	var state := run_controller.get_map_state()
	if state == null:
		return []
	var options := state.get_available_nodes()
	if options.is_empty():
		return []
	var boss_id := state.boss_node_id
	var ranked: Array = []
	for node in options:
		var dist := _distance_to_boss(state, node.get_id(), boss_id)
		var score := _map_node_tie_score(node, dist)
		ranked.append({"node": node, "dist": dist, "score": score})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := int(a.get("dist", 999))
		var db := int(b.get("dist", 999))
		if da != db:
			return da < db
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	return ranked


func _queue_map_decision(state_key: String, action_key: String) -> void:
	_pending_map.append({"state_key": state_key, "action_key": action_key})


func _current_map_floor(run_controller: RunController) -> int:
	var state := run_controller.get_map_state()
	if state == null:
		return 0
	var options := state.get_available_nodes()
	if options.is_empty():
		return 0
	var max_f := 0
	for node in options:
		if node != null:
			max_f = maxi(max_f, node.get_floor())
	return max_f
