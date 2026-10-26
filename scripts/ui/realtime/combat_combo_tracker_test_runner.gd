extends SceneTree

func _init() -> void:
	var ok := CombatComboTrackerTest.run_all()
	if not ok:
		quit(1)
		return
	print("combat_combo_tracker_test: OK")
	quit(0)
