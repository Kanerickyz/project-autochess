extends RefCounted
## 远征行囊圆形徽章条：槽数 / 占用 / 空满边界（headless）。


static func run() -> bool:
	var ok := true
	ok = _check("strip_slot_count", _test_strip_slot_count()) and ok
	ok = _check("strip_empty_and_fill", _test_strip_empty_and_fill()) and ok
	ok = _check("badge_glyph", _test_badge_glyph()) and ok
	ok = _check("bag_changed_refresh", _test_bag_changed_refresh()) and ok
	ok = _check("unified_detail_api", _test_unified_detail_api()) and ok
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("expedition_relic_badge_strip_test: OK %s" % name)
	else:
		push_error("expedition_relic_badge_strip_test: FAIL %s" % name)
	return passed


static func _make_relic(id: String, display_name: String, tier: int = 1) -> ExpeditionRelicData:
	var r := ExpeditionRelicData.new()
	r.id = id
	r.display_name = display_name
	r.description = "测试效果：%s" % display_name
	r.tier = tier
	r.sell_gold = tier * 2
	return r


static func _test_strip_slot_count() -> bool:
	var strip := ExpeditionRelicBadgeStrip.new()
	strip.configure(null)
	if strip.get_slot_count() != ExpeditionRelicBag.CAPACITY:
		return false
	if strip.get_slot_count() != 6:
		return false
	if strip.get_occupied_count() != 0:
		return false
	for i in 6:
		var badge := strip.get_badge(i)
		if badge == null or badge.is_occupied():
			return false
	strip.free()
	return true


static func _test_strip_empty_and_fill() -> bool:
	var bag := ExpeditionRelicBag.new()
	var strip := ExpeditionRelicBadgeStrip.new()
	strip.configure(bag)
	if strip.get_occupied_count() != 0:
		return false
	if not bag.try_add(_make_relic("a", "摊贩折角", 1)):
		return false
	if not bag.try_add(_make_relic("b", "铁扉插销", 2)):
		return false
	## 仅依赖 bag_changed → refresh，不手动 refresh。
	if strip.get_occupied_count() != 2:
		return false
	if strip.get_badge(0) == null or not strip.get_badge(0).is_occupied():
		return false
	if strip.get_badge(0).relic == null or strip.get_badge(0).relic.id != "a":
		return false
	if strip.get_badge(1) == null or strip.get_badge(1).relic.id != "b":
		return false
	if strip.get_badge(2).is_occupied():
		return false
	for i in 4:
		if not bag.try_add(_make_relic("f%d" % i, "满%d" % i, 3)):
			return false
	if not bag.is_full():
		return false
	if strip.get_occupied_count() != 6:
		return false
	for i in 6:
		if not strip.get_badge(i).is_occupied():
			return false
	if bag.try_add(_make_relic("overflow", "溢出", 1)):
		return false
	if strip.get_occupied_count() != 6:
		return false
	strip.free()
	return true


static func _test_badge_glyph() -> bool:
	var badge := ExpeditionRelicBadge.new()
	badge.configure(0, null)
	if not badge.glyph_text().is_empty():
		return false
	badge.configure(0, _make_relic("x", "摊贩折角", 1))
	if badge.glyph_text() != "摊":
		return false
	badge.configure(1, _make_relic("y", "AB", 2))
	if badge.glyph_text() != "AB":
		return false
	badge.free()
	return true


static func _test_bag_changed_refresh() -> bool:
	var bag := ExpeditionRelicBag.new()
	var strip := ExpeditionRelicBadgeStrip.new()
	strip.configure(bag)
	bag.try_add(_make_relic("c", "鼓点耳环", 2))
	## 依赖 signal → refresh，不手动 refresh。
	if strip.get_occupied_count() != 1:
		return false
	if strip.get_badge(0).glyph_text() != "鼓":
		return false
	bag.try_remove_at(0)
	if strip.get_occupied_count() != 0:
		return false
	strip.free()
	return true


static func _test_unified_detail_api() -> bool:
	var strip := ExpeditionRelicBadgeStrip.new()
	var relic := _make_relic("d", "铁扉插销", 2)
	strip.show_relic_detail(relic)
	if not strip.has_detail_popup():
		return false
	if strip.get_detail_title_text() != "铁扉插销":
		return false
	if not strip.get_detail_body_text().contains("测试效果：铁扉插销"):
		return false
	strip.hide_detail()
	if strip.has_detail_popup():
		return false
	strip.free()
	return true
