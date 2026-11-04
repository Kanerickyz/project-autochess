extends RefCounted
## Headless 烟测：行囊 take/replace/sell 与 Offer 去重（不强制进 verify runners）。


static func run() -> bool:
	var ok := true
	ok = _check("bag_capacity", _test_bag()) and ok
	ok = _check("offer_dedupe", _test_offer_dedupe()) and ok
	ok = _check("economy_aggregate", _test_economy()) and ok
	ok = _check("event_gold_loss_shatter", _test_event_gold_loss()) and ok
	ok = _check("attach_combat_triggers", _test_attach_combat()) and ok
	ok = _check("combat_hooks_drum_cap", _test_hooks_drum()) and ok
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


static func _test_event_gold_loss() -> bool:
	var bag := ExpeditionRelicBag.new()
	var vellum := ExpeditionRelicData.new()
	vellum.id = "relic_credit_vellum"
	vellum.display_name = "赊账羊皮"
	vellum.event_gold_cost_reduction = 3
	vellum.shatter_after_first_real_save = true
	bag.try_take(vellum)
	var resolved := ExpeditionRelicEffectService.apply_event_gold_loss(bag, 5)
	if int(resolved.get("loss", -1)) != 2:
		return false
	var shattered: ExpeditionRelicData = resolved.get("shattered") as ExpeditionRelicData
	if shattered == null or shattered.id != "relic_credit_vellum":
		return false
	if bag.get_count() != 0:
		return false
	## 无羊皮时原样扣。
	var plain := ExpeditionRelicEffectService.apply_event_gold_loss(null, 4)
	return int(plain.get("loss", -1)) == 4 and plain.get("shattered") == null


static func _test_attach_combat() -> bool:
	var bag := ExpeditionRelicBag.new()
	var thin := load("res://resources/relics/relic_thin_mail_prayer.tres") as ExpeditionRelicData
	var horn := load("res://resources/relics/relic_hunt_horn_shard.tres") as ExpeditionRelicData
	var martyr := load("res://resources/relics/relic_martyr_thorns.tres") as ExpeditionRelicData
	var hedge := load("res://resources/relics/relic_hedge_of_pikes.tres") as ExpeditionRelicData
	if thin == null or horn == null or martyr == null or hedge == null:
		return false
	bag.try_take(thin)
	bag.try_take(horn)
	bag.try_take(martyr)
	bag.try_take(hedge)
	var unit := UnitInstance.new()
	unit.team = UnitInstance.Team.PLAYER
	unit.grid_pos = Vector2i(2, 6)
	unit.current_hp = 10
	var stats := UnitStats.new()
	stats.max_hp = 10
	stats.attack = 2
	unit.stats = stats
	var ally := UnitInstance.new()
	ally.team = UnitInstance.Team.PLAYER
	ally.grid_pos = Vector2i(3, 6)
	ally.current_hp = 10
	ally.stats = stats.duplicate()
	ExpeditionRelicEffectService.attach_combat_abilities([unit, ally], bag, null, 8)
	var ids: Array[String] = []
	for ab in unit.attached_abilities:
		if ab != null:
			ids.append(String(ab.id))
	var joined := " ".join(ids)
	if not joined.contains("expedition_relic_relic_thin_mail_prayer"):
		return false
	if not joined.contains("expedition_relic_relic_hunt_horn_shard"):
		return false
	if not joined.contains("expedition_relic_relic_martyr_thorns"):
		return false
	## 正交邻友 → 刺篱挂载。
	if not joined.contains("expedition_relic_relic_hedge_of_pikes"):
		return false
	return true


static func _test_hooks_drum() -> bool:
	var bag := ExpeditionRelicBag.new()
	var drum := load("res://resources/relics/relic_drum_earring.tres") as ExpeditionRelicData
	if drum == null:
		return false
	bag.try_take(drum)
	var owner := UnitInstance.new()
	owner.team = UnitInstance.Team.PLAYER
	owner.current_hp = 8
	var stats := UnitStats.new()
	stats.max_hp = 10
	stats.attack = 1
	owner.stats = stats
	owner.stat_modifiers = StatModifierStack.new()
	var hooks := ExpeditionRelicCombatHooks.new()
	var bus := CombatEventBus.new()
	hooks.bind(bus, bag, [owner], 1)
	## 伪造受伤技能结算（非圣物挂载）。
	var spec := EffectSpec.new()
	spec.trigger = CombatEvents.ON_DAMAGE_TAKEN
	spec.target_selector = EffectSpec.TargetSelector.SELF
	var payload := CombatEventPayload.new()
	payload.effect_owner = owner
	payload.effect_spec = spec
	payload.effect_action = EffectAction.new()
	bus.emit_event(CombatEvents.ON_EFFECT_RESOLVED, payload)
	bus.emit_event(CombatEvents.ON_EFFECT_RESOLVED, payload)
	bus.emit_event(CombatEvents.ON_EFFECT_RESOLVED, payload)
	var atk_bonus := owner.stat_modifiers.get_flat_bonus(&"attack")
	hooks.unbind()
	## cap_per_unit_per_round = 2
	return atk_bonus == 2
