extends RefCounted
## ExpeditionRelicInfo 统一文案契约。


static func run() -> bool:
	var ok := true
	ok = _check("null_relic", _test_null()) and ok
	ok = _check("detail_and_summary", _test_detail_and_summary()) and ok
	ok = _check("info_dict_item_contract", _test_info_dict()) and ok
	ok = _check("stage_choice_dict", _test_stage_choice_dict()) and ok
	return ok


static func _check(name: String, passed: bool) -> bool:
	if passed:
		print("expedition_relic_info_test: OK %s" % name)
	else:
		push_error("expedition_relic_info_test: FAIL %s" % name)
	return passed


static func _make() -> ExpeditionRelicData:
	var r := ExpeditionRelicData.new()
	r.id = "test_relic"
	r.display_name = "摊贩折角"
	r.description = "商店刷新更便宜一些。"
	r.tier = 2
	r.sell_gold = 4
	return r


static func _test_null() -> bool:
	return (
		ExpeditionRelicInfo.detail_text(null).contains("空槽")
		and ExpeditionRelicInfo.info_dict(null, Vector2.ZERO).is_empty()
	)


static func _test_detail_and_summary() -> bool:
	var r := _make()
	var detail := ExpeditionRelicInfo.detail_text(r)
	if not detail.contains("摊贩折角"):
		return false
	if not detail.contains("商店刷新更便宜一些"):
		return false
	if not detail.contains("Tier 2"):
		return false
	if not detail.contains("出售 4 金"):
		return false
	var preview := ExpeditionRelicInfo.summary_preview(r, 8)
	return preview.length() <= 8 and preview.contains("…")


static func _test_info_dict() -> bool:
	var r := _make()
	var info := ExpeditionRelicInfo.info_dict(r, Vector2(10, 20), "relic_badge:0")
	if not bool(info.get("is_item", false)):
		return false
	if String(info.get("kind_label", "")) != "圣物":
		return false
	if String(info.get("name", "")) != "摊贩折角":
		return false
	if String(info.get("inspect_key", "")) != "relic_badge:0":
		return false
	if int(info.get("cost", -1)) != 4:
		return false
	return String(info.get("skills", "")).contains("商店刷新更便宜一些")


static func _test_stage_choice_dict() -> bool:
	var r := _make()
	var d := ExpeditionRelicInfo.stage_choice_dict(r, 2, true)
	return (
		d.get("id") == &"relic_2"
		and bool(d.get("selected", false))
		and String(d.get("kind_label", "")) == "圣物"
		and String(d.get("detail", "")).contains("摊贩折角")
	)
