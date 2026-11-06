class_name ExpeditionRelicInfo
extends RefCounted
## 远征圣物统一检视文案：徽章长按 / StageChoice 卡片共用 RealtimeUnitInfoCard 契约。


## 信息卡 skills 正文（完整说明）。
static func detail_text(relic: ExpeditionRelicData) -> String:
	if relic == null:
		return "空槽。"
	var desc := relic.description.strip_edges() if relic.description != null else ""
	if desc.is_empty():
		desc = "（暂无详细说明）"
	var sell := relic.resolve_sell_gold()
	return "远征圣物 · %s\nTier %d · 出售 %d 金\n\n%s" % [
		relic.display_name if not relic.display_name.is_empty() else "圣物",
		clampi(relic.tier, 1, 3),
		sell,
		desc,
	]


## 卡片面短摘要（可截断）。
static func summary_preview(relic: ExpeditionRelicData, max_chars: int = 14) -> String:
	if relic == null:
		return "空槽"
	var desc := relic.description.strip_edges() if relic.description != null else ""
	if desc.is_empty():
		desc = relic.display_name if not relic.display_name.is_empty() else "圣物"
	return StageChoiceBoard.truncate_preview(desc, max_chars)


## RealtimeUnitInfoCard 用的 is_item 字典；center 由调用方填锚点。
static func info_dict(
	relic: ExpeditionRelicData,
	center: Vector2,
	inspect_key: String = "",
) -> Dictionary:
	if relic == null:
		return {}
	var key := inspect_key
	if key.is_empty():
		key = "relic:%s" % (relic.id if not relic.id.is_empty() else relic.display_name)
	return {
		"inspect_key": key,
		"center": center,
		"name": relic.display_name if not relic.display_name.is_empty() else "圣物",
		"side_player": true,
		"tier": clampi(relic.tier, 1, 3),
		"is_item": true,
		"kind_label": "圣物",
		"cost": relic.resolve_sell_gold(),
		"attack": 0,
		"hp": 0,
		"skills": detail_text(relic),
		"texture": null,
	}


## StageChoice 选项字典字段（再经 StageChoiceBoard.layout_choices 补 cell）。
static func stage_choice_dict(
	relic: ExpeditionRelicData,
	index: int,
	selected: bool = false,
) -> Dictionary:
	return {
		"id": StringName("relic_%d" % index),
		"label": _format_label(relic),
		"summary": summary_preview(relic, 14),
		"detail": detail_text(relic),
		"kind_label": "圣物",
		"tier": clampi(relic.tier, 1, 3) if relic != null else 0,
		"selected": selected,
		"meta": index,
	}


static func _format_label(relic: ExpeditionRelicData) -> String:
	if relic == null:
		return "（空）"
	return "T%d · %s" % [clampi(relic.tier, 1, 3), relic.display_name]
