class_name SimBanditKeys
extends RefCounted

## 训练「无限金」时 state 内金桶标记，避免真金币额干扰键分布。
const GOLD_BUCKET_UNLIMITED := -1


static func map_state(floor: int, options: Array) -> String:
	var types: PackedStringArray = PackedStringArray()
	for node in options:
		if node == null:
			continue
		types.append(str(int(node.get_effective_type())))
	types.sort()
	return "map|f%d|n%d|%s" % [maxi(0, floor), options.size(), "|".join(types)]


static func recruit_state(
	floor: int,
	gold: int,
	roster_size: int,
	session: RecruitSession,
) -> String:
	var gold_bucket := (maxi(0, gold) / 5) * 5
	var parts: PackedStringArray = PackedStringArray()
	parts.append("recruit|f%d|g%d|r%d" % [maxi(0, floor), gold_bucket, maxi(0, roster_size)])
	if session == null:
		return parts[0]
	for i in session.get_candidate_slot_count():
		var unit: UnitData = session.get_candidate(i)
		if unit == null or unit.stats == null:
			parts.append("-")
			continue
		var cost := maxi(1, session.get_recruit_cost(unit))
		parts.append("%d/%d" % [unit.stats.attack + unit.stats.max_hp, cost])
	return "|".join(parts)


static func roster_team_signature(deck: DeckState) -> String:
	if deck == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for entry in deck.get_entries():
		if entry == null:
			continue
		var uid := entry.get_unit_id()
		if uid.is_empty():
			continue
		parts.append("%s#%d" % [uid, maxi(1, entry.level)])
	parts.sort()
	return "|".join(parts)


## v4：当前队伍 + 本店可选 unit_id；动作为 unit_id。
static func recruit_state_v4(
	floor: int,
	gold: int,
	deck: DeckState,
	shop_unit_ids: PackedStringArray,
) -> String:
	var gold_bucket := _gold_bucket_value(gold)
	var team := roster_team_signature(deck)
	var shop := shop_unit_ids.duplicate()
	shop.sort()
	return "recruit4|f%d|g%s|team=%s|shop=%s" % [
		maxi(0, floor),
		gold_bucket,
		team if not team.is_empty() else "-",
		"|".join(shop) if shop.size() > 0 else "-",
	]


## 直选池：opts 为当前可购 unit_id 全集（非 5 槽子集）。
static func recruit_state_v4_direct_pool(
	floor: int,
	gold: int,
	deck: DeckState,
	option_ids: PackedStringArray,
) -> String:
	var gold_bucket := _gold_bucket_value(gold)
	var team := roster_team_signature(deck)
	var opts := option_ids.duplicate()
	opts.sort()
	return "recruit4pool|f%d|g%s|team=%s|opts=%s" % [
		maxi(0, floor),
		gold_bucket,
		team if not team.is_empty() else "-",
		"|".join(opts) if opts.size() > 0 else "-",
	]


static func _gold_bucket_value(gold: int) -> String:
	if gold == GOLD_BUCKET_UNLIMITED:
		return "*"
	return str((maxi(0, gold) / 5) * 5)
