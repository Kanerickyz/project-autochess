extends SceneTree


func _initialize() -> void:
	var ok := RosterBudgetTest.run_all()
	quit(0 if ok else 1)
