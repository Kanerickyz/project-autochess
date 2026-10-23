class_name PartyBarkService
extends RefCounted
## 招募进队后评估应播的队伍台词；不改队伍/经济。

const DEFAULT_CATALOG_PATH := "res://resources/barks/default_party_barks.tres"


static func load_default_catalog() -> PartyBarkCatalog:
	return load(DEFAULT_CATALOG_PATH) as PartyBarkCatalog


## 返回应播的台词；无则 null。成功选用后调用 mark_played。
static func pick_recruit_join_bark(
	deck: DeckState,
	played_ids: PackedStringArray,
	catalog: PartyBarkCatalog = null,
) -> PartyBarkLine:
	if deck == null:
		return null
	var cat := catalog if catalog != null else load_default_catalog()
	if cat == null:
		return null
	var present := _collect_unit_ids(deck)
	if present.is_empty():
		return null
	for line in cat.lines:
		if line == null or line.id.is_empty() or line.line.is_empty():
			continue
		if line.speaker_unit_id.is_empty():
			continue
		if line.once_per_run and played_ids.has(line.id):
			continue
		if not present.has(line.speaker_unit_id):
			continue
		if not _requirements_met(present, line.required_unit_ids):
			continue
		return line
	return null


static func mark_played(played_ids: PackedStringArray, bark_id: String) -> PackedStringArray:
	if bark_id.is_empty() or played_ids.has(bark_id):
		return played_ids
	var next := played_ids.duplicate()
	next.append(bark_id)
	return next


static func _collect_unit_ids(deck: DeckState) -> Dictionary:
	var present: Dictionary = {}
	for entry in deck.get_entries():
		if entry == null or entry.unit == null:
			continue
		var uid := String(entry.unit.id)
		if uid.is_empty():
			continue
		present[uid] = true
	return present


static func _requirements_met(present: Dictionary, required: PackedStringArray) -> bool:
	if required.is_empty():
		return false
	for req in required:
		var rid := String(req)
		if rid.is_empty() or not present.has(rid):
			return false
	return true
