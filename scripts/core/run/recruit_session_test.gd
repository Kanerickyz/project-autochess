class_name RecruitSessionTest
extends RefCounted

const ARCHER := preload("res://resources/units/realtime/archer.tres")
const KNIGHT := preload("res://resources/units/realtime/knight.tres")
const BARBARIAN := preload("res://resources/units/realtime/barbarian.tres")
const MUSKETEER := preload("res://resources/units/realtime/musketeer.tres")
const VALKYRIE := preload("res://resources/units/realtime/valkyrie.tres")
const MINI_PEKKA := preload("res://resources/units/realtime/mini_pekka.tres")


static func run_all() -> bool:
	var passed := true
	passed = _test_should_offer_recruit() and passed
	passed = _test_seat_cap_uses_min_of_max_size_and_seat_grid() and passed
	passed = _test_snapshot_reset_restores_gold_team_candidates() and passed
	passed = _test_refresh_keeps_recruited() and passed
	passed = _test_refresh_keeps_locked_candidate() and passed
	passed = _test_replace_no_refund() and passed
	passed = _test_skip_discards_finish_keeps() and passed
	passed = _test_opening_require_nonempty_roster() and passed
	passed = _test_auto_merge_three_same_level() and passed
	passed = _test_auto_merge_skips_max_star() and passed
	passed = _test_sell_refunds_and_reset_rolls_back() and passed
	passed = _test_persistent_seats_recruit_replace_sell_swap_merge() and passed
	passed = _test_unlocked_tier_merges_into_pool() and passed
	passed = _test_full_roster_buy_completes_triple() and passed
	if passed:
		print("RecruitSessionTest: all passed")
	else:
		push_error("RecruitSessionTest: failures detected")
	return passed


static func _make_config() -> RecruitConfig:
	var config := RecruitConfig.new()
	config.refresh_cost = 1
	config.default_unit_cost = 3
	config.candidate_count = 3
	var pool: Array[UnitData] = []
	pool.append(ARCHER)
	pool.append(BARBARIAN)
	pool.append(KNIGHT)
	pool.append(MUSKETEER)
	pool.append(VALKYRIE)
	pool.append(MINI_PEKKA)
	config.unit_pool = pool
	return config


static func _make_deck(units: Array, max_size: int = 5) -> DeckState:
	var deck := DeckState.new()
	var deck_config := DeckConfig.new()
	deck_config.max_size = max_size
	deck_config.seat_rows = 2
	deck_config.seat_cols = 5
	deck_config.max_board_units = max_size
	deck.configure(deck_config)
	for unit in units:
		if unit is UnitData:
			deck.add_entry(unit as UnitData)
	return deck


static func _make_economy(gold: int) -> RunEconomy:
	var economy := RunEconomy.new()
	economy.configure(null)
	economy.gold = 0
	economy.grant(gold)
	return economy


static func _make_session(
	deck: DeckState,
	economy: RunEconomy,
	seed: int = 1,
	progress: float = 0.0,
) -> RecruitSession:
	var session := RecruitSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	session.configure(_make_config(), deck, economy, rng)
	session.begin(progress)
	return session


static func _test_seat_cap_uses_min_of_max_size_and_seat_grid() -> bool:
	## 本版主路径 max_size=5 → cap=5；仍尊重更小 max_size。
	var deck := _make_deck([ARCHER], 5)
	var economy := _make_economy(5)
	var session := _make_session(deck, economy, 3, 0.0)
	if session.get_seat_cap() != 5:
		push_error("RecruitSessionTest: seat cap should be min(5, 2x5)=5, got %d" % session.get_seat_cap())
		return false
	var large := _make_deck([ARCHER], 20)
	var session_large := _make_session(large, _make_economy(5), 5, 0.0)
	if session_large.get_seat_cap() != 10:
		push_error("RecruitSessionTest: seat cap should be min(20, 2x5)=10, got %d" % session_large.get_seat_cap())
		return false
	var small := _make_deck([ARCHER, KNIGHT], 2)
	var session_small := _make_session(small, _make_economy(5), 4, 0.0)
	if session_small.get_seat_cap() != 2:
		push_error("RecruitSessionTest: seat cap should respect smaller max_size=2")
		return false
	if not session_small.needs_replace():
		push_error("RecruitSessionTest: full at max_size=2 should need replace")
		return false
	return true


static func _test_should_offer_recruit() -> bool:
	var session := RecruitSession.new()
	if not session.should_offer_recruit(MapNodeType.Type.COMBAT, true):
		push_error("RecruitSessionTest: combat win should offer recruit")
		return false
	if not session.should_offer_recruit(MapNodeType.Type.ELITE, true):
		push_error("RecruitSessionTest: elite win should offer recruit")
		return false
	if session.should_offer_recruit(MapNodeType.Type.BOSS, true):
		push_error("RecruitSessionTest: boss win must not offer recruit")
		return false
	if session.should_offer_recruit(MapNodeType.Type.COMBAT, false):
		push_error("RecruitSessionTest: loss must not offer recruit")
		return false
	return true


static func _test_snapshot_reset_restores_gold_team_candidates() -> bool:
	var deck := _make_deck([ARCHER, KNIGHT])
	var economy := _make_economy(10)
	var session := _make_session(deck, economy, 42, 0.1)
	var entry_ids_before: Array[int] = []
	for entry in deck.get_entries():
		entry_ids_before.append(entry.entry_id)
	var cand_ids_before: PackedStringArray = PackedStringArray()
	for unit in session.get_candidates():
		cand_ids_before.append(unit.id if unit != null else "")

	var buy := session.try_recruit(0)
	if not buy.get("ok", false):
		push_error("RecruitSessionTest: recruit for reset fixture failed: %s" % buy.get("reason"))
		return false
	if not session.try_refresh():
		push_error("RecruitSessionTest: refresh for reset fixture failed")
		return false
	if economy.gold >= 10:
		push_error("RecruitSessionTest: gold should have decreased before reset")
		return false

	session.reset()
	if economy.gold != 10:
		push_error("RecruitSessionTest: reset should restore gold to 10, got %d" % economy.gold)
		return false
	if deck.size() != 2:
		push_error("RecruitSessionTest: reset should restore team size 2, got %d" % deck.size())
		return false
	var entry_ids_after: Array[int] = []
	for entry in deck.get_entries():
		entry_ids_after.append(entry.entry_id)
	if entry_ids_after != entry_ids_before:
		push_error("RecruitSessionTest: reset should restore entry ids")
		return false
	var cand_ids_after: PackedStringArray = PackedStringArray()
	for unit in session.get_candidates():
		cand_ids_after.append(unit.id if unit != null else "")
	if cand_ids_after != cand_ids_before:
		push_error("RecruitSessionTest: reset should restore candidates")
		return false
	return true


static func _test_refresh_keeps_recruited() -> bool:
	var deck := _make_deck([ARCHER])
	var economy := _make_economy(20)
	var session := _make_session(deck, economy, 7, 0.2)
	var before_size := deck.size()
	var buy := session.try_recruit(0)
	if not buy.get("ok", false):
		push_error("RecruitSessionTest: recruit before refresh failed")
		return false
	var after_buy_size := deck.size()
	if after_buy_size != before_size + 1:
		push_error("RecruitSessionTest: recruit should grow team")
		return false
	var recruited_id: String = (buy["entry"] as DeckEntry).get_unit_id()
	if not session.try_refresh():
		push_error("RecruitSessionTest: refresh failed")
		return false
	if deck.size() != after_buy_size:
		push_error("RecruitSessionTest: refresh must keep recruited members")
		return false
	var still_has := false
	for entry in deck.get_entries():
		if entry.get_unit_id() == recruited_id:
			still_has = true
			break
	if not still_has:
		push_error("RecruitSessionTest: recruited unit missing after refresh")
		return false
	return true


static func _test_refresh_keeps_locked_candidate() -> bool:
	var deck := _make_deck([ARCHER])
	var economy := _make_economy(20)
	var session := _make_session(deck, economy, 99, 0.2)
	var locked_unit := session.get_candidate(0)
	if locked_unit == null:
		push_error("RecruitSessionTest: lock fixture missing candidate 0")
		return false
	var locked_id := locked_unit.id
	if not session.toggle_candidate_lock(0):
		push_error("RecruitSessionTest: toggle lock should lock slot 0")
		return false
	if not session.is_candidate_locked(0):
		push_error("RecruitSessionTest: slot 0 should be locked")
		return false
	var unlocked_before := session.get_candidate(1)
	var unlocked_id := unlocked_before.id if unlocked_before != null else ""
	if not session.try_refresh():
		push_error("RecruitSessionTest: refresh with lock failed")
		return false
	var after_locked := session.get_candidate(0)
	if after_locked == null or after_locked.id != locked_id:
		push_error("RecruitSessionTest: locked candidate must survive refresh")
		return false
	if not session.is_candidate_locked(0):
		push_error("RecruitSessionTest: lock flag must survive refresh")
		return false
	## 未锁定槽应被重抽（种子固定下通常会变；若碰巧同 id 仍算合法，只断言锁槽）。
	var _ignore := unlocked_id
	return true


static func _test_replace_no_refund() -> bool:
	var deck := _make_deck([ARCHER, KNIGHT], 2)
	var economy := _make_economy(20)
	var gold_before := economy.gold
	var session := _make_session(deck, economy, 11, 0.5)
	var replace_id := deck.get_entries()[0].entry_id
	var candidate := session.get_candidate(0)
	if candidate == null:
		push_error("RecruitSessionTest: missing candidate for replace")
		return false
	var cost := session.get_recruit_cost(candidate)
	var new_unit_id := candidate.id
	var buy := session.try_recruit(0, replace_id)
	if not buy.get("ok", false):
		push_error("RecruitSessionTest: replace recruit failed: %s" % buy.get("reason"))
		return false
	if economy.gold != gold_before - cost:
		push_error(
			"RecruitSessionTest: replace should only deduct recruit cost (no refund); gold=%d expected=%d"
			% [economy.gold, gold_before - cost]
		)
		return false
	if deck.size() != 2:
		push_error("RecruitSessionTest: replace should keep team size")
		return false
	if deck.get_entry(replace_id) != null:
		push_error("RecruitSessionTest: old entry_id should be gone after replace")
		return false
	var has_new := false
	for entry in deck.get_entries():
		if entry.get_unit_id() == new_unit_id:
			has_new = true
	if not has_new:
		push_error("RecruitSessionTest: replacement unit missing from team")
		return false
	return true


static func _test_skip_discards_finish_keeps() -> bool:
	var deck := _make_deck([ARCHER])
	var economy := _make_economy(15)
	var session := _make_session(deck, economy, 3, 0.0)
	session.try_recruit(0)
	session.skip()
	if deck.size() != 1:
		push_error("RecruitSessionTest: skip should discard recruit")
		return false
	if economy.gold != 15:
		push_error("RecruitSessionTest: skip should restore gold")
		return false

	session = _make_session(deck, economy, 5, 0.0)
	session.try_recruit(0)
	var size_after_buy := deck.size()
	var gold_after_buy := economy.gold
	session.finish()
	if deck.size() != size_after_buy:
		push_error("RecruitSessionTest: finish should keep team changes")
		return false
	if economy.gold != gold_after_buy:
		push_error("RecruitSessionTest: finish should keep gold")
		return false
	return true


static func _test_opening_require_nonempty_roster() -> bool:
	var deck := _make_deck([])
	var economy := _make_economy(6)
	var session := _make_session(deck, economy, 9, 0.0)
	session.require_nonempty_roster = true
	if session.can_skip():
		push_error("RecruitSessionTest: opening should disable skip")
		return false
	if session.can_finish():
		push_error("RecruitSessionTest: empty opening roster cannot finish")
		return false
	session.finish()
	if not session.is_active:
		push_error("RecruitSessionTest: finish must no-op while empty opening roster")
		return false
	session.skip()
	if not session.is_active:
		push_error("RecruitSessionTest: skip must no-op while opening require_nonempty")
		return false
	var buy := session.try_recruit(0)
	if not buy.get("ok", false):
		push_error("RecruitSessionTest: opening recruit buy failed: %s" % buy.get("reason"))
		return false
	if not session.can_finish():
		push_error("RecruitSessionTest: opening can finish after roster >=1")
		return false
	if session.can_skip():
		push_error("RecruitSessionTest: opening skip stays disabled after buy")
		return false
	session.finish()
	if session.is_active:
		push_error("RecruitSessionTest: opening finish should end session")
		return false
	if deck.size() < 1:
		push_error("RecruitSessionTest: opening finish should keep recruited unit")
		return false
	return true


static func _test_auto_merge_three_same_level() -> bool:
	var deck := _make_deck([])
	var a := deck.add_entry(ARCHER)
	var b := deck.add_entry(ARCHER)
	if a == null or b == null or deck.size() != 2:
		push_error("RecruitSessionTest: merge fixture failed to add two archers")
		return false
	a.bonus_attack = 1
	a.bonus_max_hp = 2
	b.bonus_attack = 3
	b.bonus_max_hp = 4
	var base_atk := ARCHER.stats.attack
	var base_hp := ARCHER.stats.max_hp
	var expected_atk := (base_atk + 1) + (base_atk + 3) + base_atk
	var expected_hp := (base_hp + 2) + (base_hp + 4) + base_hp
	var c := deck.add_entry(ARCHER)
	if c == null:
		push_error("RecruitSessionTest: third archer should add then merge")
		return false
	if deck.size() != 1:
		push_error("RecruitSessionTest: 3 same id/level should merge to 1, size=%d" % deck.size())
		return false
	var product := deck.get_entries()[0]
	if product.level != 2:
		push_error("RecruitSessionTest: merge product level should be 2, got %d" % product.level)
		return false
	if product.get_unit_id() != ARCHER.id:
		push_error("RecruitSessionTest: merge product unit id mismatch")
		return false
	var got_atk := DeckUpgradeService.get_display_attack(product)
	var got_hp := DeckUpgradeService.get_display_max_hp(product)
	if got_atk != expected_atk:
		push_error("RecruitSessionTest: merge atk sum expected %d got %d" % [expected_atk, got_atk])
		return false
	if got_hp != expected_hp:
		push_error("RecruitSessionTest: merge hp sum expected %d got %d" % [expected_hp, got_hp])
		return false
	## 招募招入第 3 个也应合并
	var economy := _make_economy(30)
	var session := _make_session(_make_deck([KNIGHT, KNIGHT]), economy, 21, 0.0)
	## 强制候选人为骑士以便招入触发三合一
	session.candidates = [KNIGHT, ARCHER, ARCHER]
	var before := session.deck.size()
	var buy := session.try_recruit(0)
	if not buy.get("ok", false):
		push_error("RecruitSessionTest: recruit for merge failed: %s" % buy.get("reason"))
		return false
	if session.deck.size() != before - 1:
		push_error(
			"RecruitSessionTest: recruit merge should shrink by 1 (3→1), size=%d before=%d"
			% [session.deck.size(), before]
		)
		return false
	var merged := false
	for entry in session.deck.get_entries():
		if entry.get_unit_id() == KNIGHT.id and entry.level == 2:
			merged = true
	if not merged:
		push_error("RecruitSessionTest: recruit should produce level-2 knight")
		return false
	return true


static func _test_auto_merge_skips_max_star() -> bool:
	## restore_roster 不触发三合一；三只 3 星保持并存且 try_auto_merge 无操作。
	var deck := _make_deck([])
	var e1 := DeckEntry.new()
	e1.entry_id = 0
	e1.unit = ARCHER
	e1.level = 3
	var e2 := DeckEntry.new()
	e2.entry_id = 1
	e2.unit = ARCHER
	e2.level = 3
	var e3 := DeckEntry.new()
	e3.entry_id = 2
	e3.unit = ARCHER
	e3.level = 3
	deck.restore_roster({"entries": [e1, e2, e3], "next_entry_id": 3})
	if deck.size() != 3:
		push_error("RecruitSessionTest: max-star fixture size should be 3")
		return false
	if deck.try_auto_merge():
		push_error("RecruitSessionTest: three 3-star units must not merge")
		return false
	if deck.size() != 3:
		push_error("RecruitSessionTest: max-star roster size changed unexpectedly")
		return false
	return true


static func _test_sell_refunds_and_reset_rolls_back() -> bool:
	var deck := _make_deck([ARCHER, KNIGHT])
	var economy := _make_economy(10)
	var session := _make_session(deck, economy, 33, 0.0)
	var sell_target := deck.get_entries()[0]
	var sell_id := sell_target.entry_id
	var price := DeckUpgradeService.get_sell_price(sell_target)
	var gold_before := economy.gold
	var size_before := deck.size()
	var sold := session.try_sell(sell_id)
	if not sold.get("ok", false):
		push_error("RecruitSessionTest: try_sell failed: %s" % sold.get("reason"))
		return false
	if int(sold.get("gold", 0)) != price:
		push_error("RecruitSessionTest: sell gold mismatch")
		return false
	if economy.gold != gold_before + price:
		push_error(
			"RecruitSessionTest: sell should grant %d gold; gold=%d"
			% [price, economy.gold]
		)
		return false
	if deck.size() != size_before - 1:
		push_error("RecruitSessionTest: sell should free a seat")
		return false
	if deck.get_entry(sell_id) != null:
		push_error("RecruitSessionTest: sold entry should be gone")
		return false
	## 招入与出售互不串：出售落点逻辑由 UI 测；此处确认 sell 后仍可招入空席
	var buy := session.try_recruit(0)
	if not buy.get("ok", false):
		push_error("RecruitSessionTest: recruit after sell should succeed: %s" % buy.get("reason"))
		return false
	session.reset()
	if economy.gold != 10:
		push_error("RecruitSessionTest: reset after sell should restore gold 10, got %d" % economy.gold)
		return false
	if deck.size() != 2:
		push_error("RecruitSessionTest: reset after sell should restore team size 2")
		return false
	if deck.get_entry(sell_id) == null:
		push_error("RecruitSessionTest: reset should restore sold entry id")
		return false
	## 非活跃不可卖
	session.finish()
	var inactive := session.try_sell(sell_id)
	if inactive.get("ok", false):
		push_error("RecruitSessionTest: inactive session must not sell")
		return false
	return true


static func _test_persistent_seats_recruit_replace_sell_swap_merge() -> bool:
	## cap=5；招入占座；替换继承；出售腾座；招募换座持久；三合一占最早座。
	var deck := _make_deck([], 5)
	var economy := _make_economy(40)
	var session := _make_session(deck, economy, 61, 0.0)
	if session.get_seat_cap() != 5:
		push_error("RecruitSessionTest: persist seats fixture cap should be 5")
		return false

	session.candidates = [ARCHER, KNIGHT, BARBARIAN]
	var buy0 := session.try_recruit(0, -1, 3)
	if not buy0.get("ok", false):
		push_error("RecruitSessionTest: recruit to seat 3 failed: %s" % buy0.get("reason"))
		return false
	var e0 := buy0["entry"] as DeckEntry
	if e0 == null or e0.seat_index != 3:
		push_error("RecruitSessionTest: recruit should land on seat 3")
		return false

	session.candidates = [KNIGHT, BARBARIAN, MUSKETEER]
	var buy1 := session.try_recruit(0)
	if not buy1.get("ok", false):
		push_error("RecruitSessionTest: recruit default first empty failed")
		return false
	var e1 := buy1["entry"] as DeckEntry
	if e1 == null or e1.seat_index != 0:
		push_error("RecruitSessionTest: first empty seat should be 0, got %d" % (e1.seat_index if e1 else -1))
		return false

	## 换座：骑士 0 ↔ 空座 2
	if not session.try_swap_seat(e1.entry_id, 2):
		push_error("RecruitSessionTest: recruit swap to empty seat failed")
		return false
	e1 = deck.get_entry(e1.entry_id)
	if e1 == null or e1.seat_index != 2:
		push_error("RecruitSessionTest: swap should move knight to seat 2")
		return false
	if deck.get_entry_at_seat(0) != null:
		push_error("RecruitSessionTest: seat 0 should be empty after move")
		return false

	## 互换：弓箭手(3) ↔ 骑士(2)
	var archer_id := e0.entry_id
	var knight_id := e1.entry_id
	if not session.try_swap_seat(archer_id, 2):
		push_error("RecruitSessionTest: recruit swap between members failed")
		return false
	if deck.get_entry(archer_id).seat_index != 2:
		push_error("RecruitSessionTest: archer should be on seat 2 after swap")
		return false
	if deck.get_entry(knight_id).seat_index != 3:
		push_error("RecruitSessionTest: knight should be on seat 3 after swap")
		return false

	## 出售腾座（当前 deck：弓 seat2、骑 seat3）
	var sell_seat := deck.get_entry(archer_id).seat_index
	var sold := session.try_sell(archer_id)
	if not sold.get("ok", false):
		push_error("RecruitSessionTest: sell for clear seat failed")
		return false
	if deck.get_entry_at_seat(sell_seat) != null:
		push_error("RecruitSessionTest: sell should clear seat %d" % sell_seat)
		return false

	## 满员替换继承座位
	var full := _make_deck([ARCHER, KNIGHT, BARBARIAN, MUSKETEER, VALKYRIE], 5)
	var full_econ := _make_economy(20)
	var full_session := _make_session(full, full_econ, 62, 0.0)
	var replace_target := full.get_entries()[2]
	var inherit_seat := replace_target.seat_index
	full_session.candidates = [MINI_PEKKA, ARCHER, ARCHER]
	var replaced := full_session.try_recruit(0, replace_target.entry_id)
	if not replaced.get("ok", false):
		push_error("RecruitSessionTest: replace recruit failed: %s" % replaced.get("reason"))
		return false
	var new_e := replaced["entry"] as DeckEntry
	if new_e == null or new_e.seat_index != inherit_seat:
		push_error(
			"RecruitSessionTest: replace should inherit seat %d, got %d"
			% [inherit_seat, new_e.seat_index if new_e else -1]
		)
		return false

	## 三合一占最早落座时间座位
	var merge_deck := _make_deck([], 5)
	var a := merge_deck.add_entry(ARCHER, 0, 4)
	var b := merge_deck.add_entry(ARCHER, 0, 1)
	var c := merge_deck.add_entry(ARCHER, 0, 7)
	if a == null or b == null or c == null:
		push_error("RecruitSessionTest: merge seat fixture add failed")
		return false
	## add 第三个应已合并；产物占 a（最早 seq）的座位 4
	if merge_deck.size() != 1:
		push_error("RecruitSessionTest: merge seat size should be 1, got %d" % merge_deck.size())
		return false
	var product := merge_deck.get_entries()[0]
	if product.seat_index != 4:
		push_error(
			"RecruitSessionTest: merge product should keep earliest seat 4, got %d"
			% product.seat_index
		)
		return false
	if merge_deck.get_entry_at_seat(1) != null or merge_deck.get_entry_at_seat(7) != null:
		push_error("RecruitSessionTest: merge should free the other two seats")
		return false

	## 快照含占位：换座后 reset 恢复
	var snap_deck := _make_deck([ARCHER, KNIGHT], 5)
	var snap_econ := _make_economy(10)
	var snap_session := _make_session(snap_deck, snap_econ, 70, 0.0)
	var before_seats: Dictionary = {}
	for entry in snap_deck.get_entries():
		before_seats[entry.entry_id] = entry.seat_index
	var move_id: int = snap_deck.get_entries()[0].entry_id
	snap_session.try_swap_seat(move_id, 9)
	if snap_deck.get_entry(move_id).seat_index != 9:
		push_error("RecruitSessionTest: snapshot fixture swap failed")
		return false
	snap_session.reset()
	for entry in snap_deck.get_entries():
		if int(before_seats.get(entry.entry_id, -99)) != entry.seat_index:
			push_error("RecruitSessionTest: reset should restore seat layout")
			return false
	return true


static func _test_unlocked_tier_merges_into_pool() -> bool:
	## 解锁 T2 时池内应同时含 T1 与 T2，而不是只抽当前最高档。
	var deck := _make_deck([], 5)
	var economy := _make_economy(5)
	var session := _make_session(deck, economy, 11, 0.5)
	if session.get_preferred_tier() != 2:
		push_error(
			"RecruitSessionTest: progress 0.5 should prefer tier 2, got %d"
			% session.get_preferred_tier()
		)
		return false
	var saw_t1 := false
	var saw_t2 := false
	for _i in 120:
		var unit: UnitData = session._pick_one(2)
		if unit == null:
			push_error("RecruitSessionTest: unlocked pool pick returned null")
			return false
		if unit.tier > 2:
			push_error("RecruitSessionTest: should not pick above unlocked tier 2")
			return false
		if unit.tier == 1:
			saw_t1 = true
		elif unit.tier == 2:
			saw_t2 = true
		if saw_t1 and saw_t2:
			break
	if not saw_t1 or not saw_t2:
		push_error("RecruitSessionTest: unlocked tier must merge lower tiers into pool")
		return false
	return true


static func _test_full_roster_buy_completes_triple() -> bool:
	## 满员且已有同名 1 星×2：买入第三只应自动三合一，无需换人。
	var deck := _make_deck([ARCHER, ARCHER, KNIGHT, BARBARIAN, MUSKETEER], 5)
	if deck.size() != 5:
		push_error("RecruitSessionTest: full roster fixture size should be 5")
		return false
	if not deck.would_complete_triple_on_add(ARCHER, 1):
		push_error("RecruitSessionTest: two 1★ archers should complete triple on add")
		return false
	var economy := _make_economy(20)
	var session := _make_session(deck, economy, 13, 0.0)
	if not session.needs_replace():
		push_error("RecruitSessionTest: full roster should report needs_replace")
		return false
	session.candidates = [ARCHER, KNIGHT, VALKYRIE]
	if session.needs_replace_for_candidate(0):
		push_error("RecruitSessionTest: mergeable candidate should not need replace")
		return false
	if not session.needs_replace_for_candidate(1):
		push_error("RecruitSessionTest: non-mergeable candidate should need replace")
		return false
	var gold_before := economy.gold
	var buy := session.try_recruit(0)
	if not buy.get("ok", false):
		push_error("RecruitSessionTest: full roster merge buy failed: %s" % buy.get("reason"))
		return false
	if String(buy.get("reason", "")) != "merged":
		push_error("RecruitSessionTest: merge buy reason should be merged, got %s" % buy.get("reason"))
		return false
	if deck.size() != 4:
		push_error("RecruitSessionTest: after overflow merge size should be 4, got %d" % deck.size())
		return false
	var product := buy["entry"] as DeckEntry
	if product == null or product.get_unit_id() != ARCHER.id or product.level != 2:
		push_error("RecruitSessionTest: merge product should be 2★ archer")
		return false
	if economy.gold >= gold_before:
		push_error("RecruitSessionTest: merge buy should spend gold")
		return false
	return true
