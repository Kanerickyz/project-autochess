class_name HeuristicRunAI
extends RefCounted
## 可复现的招募 / 站位 / 选路启发式（非玩家 AI）。

var profile: SimAIProfile


func _init(p_profile: SimAIProfile = null) -> void:
	profile = p_profile


func pick_map_node(run_controller: RunController) -> MapNodeRuntime:
	var state := run_controller.get_map_state()
	if state == null:
		return null
	var options := state.get_available_nodes()
	if options.is_empty():
		return null
	var boss_id := state.boss_node_id
	var best: MapNodeRuntime = null
	var best_dist := 1_000_000
	var best_score := -1_000_000
	for node in options:
		var dist := _distance_to_boss(state, node.get_id(), boss_id)
		var score := _map_node_tie_score(node, dist)
		if dist < best_dist or (dist == best_dist and score > best_score):
			best_dist = dist
			best_score = score
			best = node
	return best


func run_opening_recruit(session: RecruitSession, shop: RecruitShopService) -> void:
	if session == null:
		return
	shop.open_shop(session.deck)
	_run_recruit_passes(session, shop, true)
	shop.close_shop()
	if session.is_active:
		session.finish()


func run_post_combat_recruit(session: RecruitSession, shop: RecruitShopService) -> void:
	if session == null or not session.is_active:
		return
	shop.open_shop(session.deck)
	_run_recruit_passes(session, shop, false)
	shop.close_shop()
	if session.is_active:
		session.finish()


func ensure_combat_seating(deck: DeckState, board_size: Vector2i) -> void:
	if deck == null:
		return
	for entry in deck.get_entries():
		if entry == null:
			continue
		if entry.seat_index >= 0:
			continue
		if not deck.can_seat_more():
			break
		var seat := deck.find_first_empty_seat()
		if seat < 0:
			break
		deck.assign_seat(entry.entry_id, seat)
	_auto_frontline_layout(deck, board_size)


func _run_recruit_passes(session: RecruitSession, shop: RecruitShopService, opening: bool) -> void:
	if profile == null:
		profile = SimAIProfile.new()
	var passes := profile.max_recruit_passes
	for _i in passes:
		if not session.is_active:
			break
		if opening and session.deck.get_entries().size() >= 1 and not _any_recruit_option(session):
			break
		_try_buy_banner(shop, session.deck)
		var bought := _try_best_recruit(session)
		if not bought and not _try_buy_banner(shop, session.deck):
			break


func _any_affordable_recruit(session: RecruitSession) -> bool:
	for i in session.get_candidate_slot_count():
		var unit := session.get_candidate(i)
		if unit == null:
			continue
		if session.can_recruit_via_merge(unit):
			return session.economy.can_afford(session.get_recruit_cost(unit))
		if session.is_roster_full() and not session.can_recruit_via_merge(unit):
			continue
		if session.economy.can_afford(session.get_recruit_cost(unit)):
			return true
	return false


func _any_recruit_option(session: RecruitSession) -> bool:
	if profile != null and profile.direct_pool_recruit:
		for unit in session.get_recruitable_units():
			if _can_try_recruit_unit(session, unit):
				return true
		return false
	return _any_affordable_recruit(session)


func _can_try_recruit_unit(session: RecruitSession, unit: UnitData) -> bool:
	if unit == null or not session.is_active:
		return false
	if not session.economy.can_afford(session.get_recruit_cost(unit)):
		return false
	if session.can_recruit_via_merge(unit):
		return true
	if session.is_roster_full():
		return false
	return true


func _try_buy_banner(shop: RecruitShopService, deck: DeckState) -> bool:
	if profile == null or not profile.buy_banner_when_affordable:
		return false
	if shop == null or deck == null or not shop.is_open():
		return false
	for i in shop.get_item_offers().size():
		var item := shop.get_item_offer(i)
		if item == null or item.item_type != PrepareItemData.ItemType.BANNER:
			continue
		if not shop.can_afford_item(i):
			continue
		var r := shop.try_buy_banner(i, deck)
		return int(r.get("result", RecruitShopService.BuyResult.FAILED)) == RecruitShopService.BuyResult.OK
	return false


func _try_best_recruit(session: RecruitSession) -> bool:
	if profile != null and profile.direct_pool_recruit:
		return _try_best_recruit_direct_pool(session)
	var best_i := -1
	var best_score := -1.0
	for i in session.get_candidate_slot_count():
		var unit := session.get_candidate(i)
		if unit == null:
			continue
		if not _can_try_recruit(session, unit):
			continue
		var score := _score_recruit_candidate(session, unit)
		if score > best_score:
			best_score = score
			best_i = i
	if best_i < 0:
		return false
	if session.is_roster_full() and not session.can_recruit_via_merge(session.get_candidate(best_i)):
		_free_weakest_roster_slot(session)
	var result := session.try_recruit(best_i)
	return bool(result.get("ok", false))


func _try_best_recruit_direct_pool(session: RecruitSession) -> bool:
	var best_id := ""
	var best_score := -1.0
	for unit in session.get_recruitable_units():
		if not _can_try_recruit_unit(session, unit):
			continue
		var score := _score_recruit_candidate(session, unit)
		if score > best_score:
			best_score = score
			best_id = unit.id
	if best_id.is_empty():
		return false
	if session.is_roster_full() and not session.can_recruit_via_merge(_find_recruit_unit(session, best_id)):
		_free_weakest_roster_slot(session)
	var result := session.try_recruit_by_unit_id(best_id)
	return bool(result.get("ok", false))


func _find_recruit_unit(session: RecruitSession, unit_id: String) -> UnitData:
	for unit in session.get_recruitable_units():
		if unit != null and unit.id == unit_id:
			return unit
	return null


func _free_weakest_roster_slot(session: RecruitSession) -> void:
	var deck := session.deck
	if deck == null:
		return
	var worst_id := -1
	var worst_score := 1_000_000.0
	for entry in deck.get_entries():
		if entry == null or entry.unit == null:
			continue
		if _is_priority(entry.unit.id):
			continue
		var s := _score_roster_entry(entry)
		if s < worst_score:
			worst_score = s
			worst_id = entry.entry_id
	if worst_id >= 0:
		deck.remove_entry(worst_id)


func _can_try_recruit(session: RecruitSession, unit: UnitData) -> bool:
	if unit == null or not session.is_active:
		return false
	if not session.economy.can_afford(session.get_recruit_cost(unit)):
		return false
	if session.can_recruit_via_merge(unit):
		return true
	if session.is_roster_full():
		return false
	return true


func _score_recruit_candidate(session: RecruitSession, unit: UnitData) -> float:
	if unit == null or profile == null:
		return -1.0
	var cost := maxf(1.0, float(session.get_recruit_cost(unit)))
	var atk := unit.stats.attack if unit.stats != null else 1
	var hp := unit.stats.max_hp if unit.stats != null else 1
	var stats := float(atk + hp)
	var score := stats / cost * profile.weight_stat_per_cost
	if _is_priority(unit.id):
		score += profile.weight_priority_unit_bonus
	if session.can_recruit_via_merge(unit):
		score += profile.weight_merge_bonus
	return score


func _score_roster_entry(entry: DeckEntry) -> float:
	if entry == null or entry.unit == null:
		return 0.0
	var atk := entry.unit.stats.attack if entry.unit.stats != null else 1
	var hp := entry.unit.stats.max_hp if entry.unit.stats != null else 1
	return float(atk + hp + entry.bonus_attack + entry.bonus_max_hp) * float(entry.level)


func _is_priority(unit_id: String) -> bool:
	if profile == null or profile.priority_unit_ids.is_empty():
		return false
	return unit_id in profile.priority_unit_ids


func _map_node_tie_score(node: MapNodeRuntime, dist: int) -> int:
	var t := node.get_effective_type()
	var score := 1000 - dist * 10 + node.get_floor()
	if profile != null and profile.prefer_shop_nodes and t == MapNodeType.Type.SHOP:
		score += int(profile.weight_shop_node_tie)
	if t == MapNodeType.Type.BOSS:
		score += int(profile.weight_boss_path_tie)
	if MapNodeType.is_combat(t):
		score += int(profile.weight_combat_node_tie)
	return score


func _distance_to_boss(state: MapState, from_id: int, boss_id: int) -> int:
	if boss_id < 0:
		return 0
	if from_id == boss_id:
		return 0
	var queue: Array = [[from_id, 0]]
	var head := 0
	while head < queue.size():
		var item: Array = queue[head]
		head += 1
		var nid: int = item[0]
		var depth: int = item[1]
		if nid == boss_id:
			return depth
		var node := state.get_node(nid)
		if node == null:
			continue
		for next_id in node.get_outgoing_ids():
			queue.append([next_id, depth + 1])
	return 999


func _auto_frontline_layout(deck: DeckState, board_size: Vector2i) -> void:
	if deck == null:
		return
	var config := deck.get_config()
	if config == null:
		return
	var rows := config.get_seat_rows()
	var cols := config.get_seat_cols()
	var board := PrepareSlotBoard.new()
	board.configure_grid(rows, cols, board_size, false)
	var seated: Array[DeckEntry] = []
	for entry in deck.get_entries():
		if entry != null and entry.seat_index >= 0:
			seated.append(entry)
	if seated.size() <= 1:
		return
	seated.sort_custom(func(a: DeckEntry, b: DeckEntry) -> bool:
		var ha := _score_roster_entry(a)
		var hb := _score_roster_entry(b)
		return ha > hb
	)
	var seat_order := SeatLayout.iter_seats_center_out(rows, cols)
	var cap := mini(seated.size(), seat_order.size())
	for i in cap:
		var entry := seated[i]
		var target_seat: int = seat_order[i]
		if entry.seat_index == target_seat:
			continue
		if deck.is_seat_free(target_seat):
			deck.assign_seat(entry.entry_id, target_seat)
		else:
			deck.swap_seats(entry.entry_id, target_seat)
