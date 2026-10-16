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
	passed = _test_replace_no_refund() and passed
	passed = _test_skip_discards_finish_keeps() and passed
	passed = _test_opening_require_nonempty_roster() and passed
	passed = _test_auto_merge_three_same_level() and passed
	passed = _test_auto_merge_skips_max_star() and passed
	passed = _test_sell_refunds_and_reset_rolls_back() and passed
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


static func _make_deck(units: Array, max_size: int = 20) -> DeckState:
	var deck := DeckState.new()
	var deck_config := DeckConfig.new()
	deck_config.max_size = max_size
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
	var deck := _make_deck([ARCHER], 20)
	var economy := _make_economy(5)
	var session := _make_session(deck, economy, 3, 0.0)
	if session.get_seat_cap() != 10:
		push_error("RecruitSessionTest: seat cap should be min(20, 2x5)=10, got %d" % session.get_seat_cap())
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
