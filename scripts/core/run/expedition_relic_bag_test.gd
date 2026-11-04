extends RefCounted
## Headless 烟测：行囊 take/replace/sell 与 Offer 去重（不强制进 verify runners）。


static func run() -> bool:
	var ok := true
	ok = _check("bag_capacity", _test_bag()) and ok
	ok = _check("offer_dedupe", _test_offer_dedupe()) and ok
	ok = _check("economy_aggregate", _test_economy()) and ok
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("expedition_relic_bag_test: OK %s" % name)
	else:
		push_error("expedition_relic_bag_test: FAIL %s" % name)
	return passed


static func _make_relic(id: String, tier: int = 1) -> ExpeditionRelicData:
	var r := ExpeditionRelicData.new()
	r.id = id
	r.display_name = id
	r.tier = tier
	r.sell_gold = tier * 2
	r.bonus_floor_gold = 1
	r.map_shop_refresh_cost_delta = -1
	r.min_refresh_cost = 1
	return r


static func _test_bag() -> bool:
	var bag := ExpeditionRelicBag.new()
	if not bag.try_take(_make_relic("a")):
		return false
	if bag.get_count() != 1:
		return false
	if not bag.try_take(_make_relic("b"), 0):
		return false
	if bag.get_at(0) == null or bag.get_at(0).id != "b":
		return false
	if bag.has_id("a"):
		return false
	for i in 5:
		if not bag.try_take(_make_relic("r%d" % i)):
			return false
	if not bag.is_full():
		return false
	if bag.try_take(_make_relic("overflow")):
		return false
	if not bag.try_take(_make_relic("swap_in"), 2):
		return false
	var removed := bag.try_remove_at(0)
	if removed == null or bag.get_count() != 5:
		return false
	return true


static func _test_offer_dedupe() -> bool:
	var bag := ExpeditionRelicBag.new()
	bag.try_take(_make_relic("relic_merchant_writ"))
	var svc := ExpeditionRelicOfferService.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	svc.configure(ExpeditionRelicOfferService.build_inline_stub_pool(), rng)
	var offers := svc.roll_offers(1, bag, 3)
	if offers.size() > 3:
		return false
	var seen := {}
	for o in offers:
		if o == null or o.id.is_empty():
			return false
		if seen.has(o.id):
			return false
		if o.id == "relic_merchant_writ":
			return false
		seen[o.id] = true
	return true


static func _test_economy() -> bool:
	var bag := ExpeditionRelicBag.new()
	var a := _make_relic("a")
	a.bonus_floor_gold = 2
	a.map_shop_refresh_cost_delta = -1
	a.min_refresh_cost = 1
	a.map_shop_price_delta = 1
	bag.try_take(a)
	if ExpeditionRelicEffectService.sum_bonus_floor_gold(bag) != 2:
		return false
	if ExpeditionRelicEffectService.resolve_refresh_cost(2, bag) != 1:
		return false
	if ExpeditionRelicEffectService.resolve_shop_price(2, bag) != 3:
		return false
	var econ := RunEconomy.new()
	econ.configure(null)
	econ.reset()
	var got := econ.grant_floor_gold(1, 2)
	## 第1层基础 4 + bonus 2
	return got == 6 and econ.gold == 6
