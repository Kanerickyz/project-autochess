class_name BadgeFlowTest
extends RefCounted
## 徽章流程：胜后阶段门闩、选择写入、同 id 不重复、跳过、失败清空。


static func run_all() -> bool:
	var passed := true
	passed = _test_should_offer_badge() and passed
	passed = _test_pick_writes_run_state() and passed
	passed = _test_no_duplicate_id() and passed
	passed = _test_skip_keeps_owned() and passed
	passed = _test_fail_clears_badges() and passed
	passed = _test_catalog_loads_roster() and passed
	passed = _test_tier_filter() and passed
	passed = _test_max_owned_fifo_replace() and passed
	return passed


static func _test_should_offer_badge() -> bool:
	var session := BadgeSession.new()
	if not session.should_offer_badge(MapNodeType.Type.COMBAT, true):
		push_error("badge offer: combat win should offer")
		return false
	if not session.should_offer_badge(MapNodeType.Type.ELITE, true):
		push_error("badge offer: elite win should offer")
		return false
	if session.should_offer_badge(MapNodeType.Type.BOSS, true):
		push_error("badge offer: boss win must not offer")
		return false
	if session.should_offer_badge(MapNodeType.Type.COMBAT, false):
		push_error("badge offer: loss must not offer")
		return false
	return true


static func _test_pick_writes_run_state() -> bool:
	var run := RunState.new()
	var session := BadgeSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	session.configure(run, rng)
	session.begin(1, 15, false)
	if session.get_candidates().is_empty():
		push_error("badge pick: expected candidates at floor 1")
		return false
	var first := session.get_candidate(0)
	if first == null:
		push_error("badge pick: candidate 0 null")
		return false
	var result := session.try_pick(0)
	if not bool(result.get("ok", false)):
		push_error("badge pick: try_pick failed %s" % str(result))
		return false
	if not run.has_badge(first.id):
		push_error("badge pick: run_state missing id %s" % first.id)
		return false
	if session.is_active:
		push_error("badge pick: session should end after pick")
		return false
	return true


static func _test_no_duplicate_id() -> bool:
	var run := RunState.new()
	run.add_badge("badge_tank_hp_2")
	var session := BadgeSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	session.configure(run, rng)
	session.begin(1, 15, false)
	for badge in session.get_candidates():
		if badge != null and badge.id == "badge_tank_hp_2":
			push_error("badge dup: owned id appeared in offers")
			return false
	var dup := run.add_badge("badge_tank_hp_2")
	if bool(dup.get("ok", false)):
		push_error("badge dup: add_badge should reject duplicate")
		return false
	return true


static func _test_skip_keeps_owned() -> bool:
	var run := RunState.new()
	run.add_badge("badge_tank_hp_2")
	var session := BadgeSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	session.configure(run, rng)
	session.begin(1, 15, false)
	session.skip()
	if not run.has_badge("badge_tank_hp_2"):
		push_error("badge skip: must keep owned")
		return false
	if session.is_active:
		push_error("badge skip: session should end")
		return false
	return true


static func _test_fail_clears_badges() -> bool:
	var run := RunState.new()
	run.add_badge("badge_tank_hp_2")
	run.add_badge("badge_ranged_hit_1")
	run.reset_progress()
	if run.get_owned_badge_count() != 0:
		push_error("badge fail: reset_progress must clear badges")
		return false
	return true


static func _test_catalog_loads_roster() -> bool:
	BadgeCatalog.clear_cache()
	var all_badges := BadgeCatalog.all_badges()
	if all_badges.size() < 13:
		push_error("badge catalog: expected >=13 got %d" % all_badges.size())
		return false
	var ids := {
		"badge_tank_hp_2": true,
		"badge_alliance_amp": true,
		"badge_arcane_open_2": true,
	}
	for badge_id in ids.keys():
		if BadgeCatalog.get_by_id(str(badge_id)) == null:
			push_error("badge catalog: missing %s" % badge_id)
			return false
	return true


static func _test_tier_filter() -> bool:
	BadgeCatalog.clear_cache()
	var owned := PackedStringArray()
	var t1 := BadgeCatalog.filter_candidates(owned, 1, 1, false)
	for badge in t1:
		if badge.tier > 1:
			push_error("badge tier: T1 pool leaked tier %d (%s)" % [badge.tier, badge.id])
			return false
	var t2 := BadgeCatalog.filter_candidates(owned, 2, 1, false)
	var saw_t2 := false
	for badge2 in t2:
		if badge2.tier == 2:
			saw_t2 = true
			break
	if not saw_t2:
		push_error("badge tier: T2 pool should include tier 2")
		return false
	return true


static func _test_max_owned_fifo_replace() -> bool:
	var run := RunState.new()
	for i in BadgeCatalog.MAX_OWNED:
		var id := "badge_fill_%d" % i
		## 直接塞假 id（不经 catalog），测 FIFO。
		run.owned_badge_ids.append(id)
	var add := run.add_badge("badge_tank_hp_2")
	if not bool(add.get("ok", false)):
		push_error("badge cap: add at cap should ok via replace")
		return false
	if not bool(add.get("replaced", false)):
		push_error("badge cap: expected replaced=true")
		return false
	if run.get_owned_badge_count() != BadgeCatalog.MAX_OWNED:
		push_error("badge cap: size should stay at MAX_OWNED")
		return false
	if run.owned_badge_ids[0] == "badge_fill_0":
		push_error("badge cap: oldest should be dropped")
		return false
	if not run.has_badge("badge_tank_hp_2"):
		push_error("badge cap: new id missing")
		return false
	return true
