extends SceneTree


func _initialize() -> void:
	var ok := CombatBusLifecycleTest.run_all()
	quit(0 if ok else 1)
