extends SceneTree

func _init() -> void:
	var ok := EnchantSessionTest.run_all()
	quit(0 if ok else 1)
