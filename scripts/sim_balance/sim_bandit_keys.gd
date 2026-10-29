class_name SimBanditKeys
extends RefCounted


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
