extends SceneTree


func _initialize() -> void:
	var ok := PrepareShopFloorGoldTest.run_all()
	quit(0 if ok else 1)
