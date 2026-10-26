class_name CombatComboTrackerTest
extends RefCounted


static func run_all() -> bool:
	var ok := true
	ok = _case_reset() and ok
	ok = _case_player_cards() and ok
	ok = _case_enemy_ignored() and ok
	ok = _case_cap_display() and ok
	return ok


static func _case_reset() -> bool:
	var t := CombatComboTracker.new()
	t.combo = 5
	t.reset()
	if t.combo != 0:
		push_error("combo reset expected 0")
		return false
	return true


static func _case_player_cards() -> bool:
	var t := CombatComboTracker.new()
	var ally := UnitInstance.new("a", Vector2i.ZERO, UnitInstance.Team.PLAYER)
	if t.register_skill_intro_card(ally) != 1:
		push_error("combo expected 1 after first card")
		return false
	if t.register_skill_intro_card(ally) != 2:
		push_error("combo expected 2 after second card")
		return false
	return true


static func _case_enemy_ignored() -> bool:
	var t := CombatComboTracker.new()
	var foe := UnitInstance.new("e", Vector2i.ZERO, UnitInstance.Team.ENEMY)
	if t.register_skill_intro_card(foe) != 0:
		push_error("enemy skill card should not increment combo")
		return false
	return true


static func _case_cap_display() -> bool:
	var t := CombatComboTracker.new()
	t.combo = 20
	if t.get_display_value() != 15:
		push_error("display cap expected 15")
		return false
	return true
