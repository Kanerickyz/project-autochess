class_name PaperArchetypeTest
extends RefCounted


static func run_all() -> bool:
	var cases := [
		["archer", PaperArchetype.ARCHER],
		["enemy_horsebow", PaperArchetype.ARCHER],
		["musketeer", PaperArchetype.ARCHER],
		["hunter", PaperArchetype.ARCHER],
		["maul", PaperArchetype.HEAVY_AXE],
		["barbarian", PaperArchetype.HEAVY_AXE],
		["giant_knight", PaperArchetype.CAPTAIN_CAPE],
		["valkyrie", PaperArchetype.CAPTAIN_CAPE],
		["banner", PaperArchetype.CAPTAIN_CAPE],
		["knight", PaperArchetype.KNIGHT_SHIELD],
		["spike_shield", PaperArchetype.KNIGHT_SHIELD],
		["relic_aegis", PaperArchetype.KNIGHT_SHIELD],
		["mini_pekka", PaperArchetype.KNIGHT_SHIELD],
		["goblin", &""],
		["skeleton", &""],
		["", &""],
	]
	var ok := true
	for row in cases:
		var got := PaperArchetype.from_unit_id(String(row[0]))
		if got != row[1]:
			push_error("PaperArchetype %s -> %s, expected %s" % [row[0], got, row[1]])
			ok = false
	return ok
