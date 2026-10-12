extends SceneTree


func _initialize() -> void:
	var ok := ProjectLoadSmokeTest.run_all()
	quit(0 if ok else 1)
