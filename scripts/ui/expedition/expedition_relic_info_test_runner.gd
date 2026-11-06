extends SceneTree
## godot --headless --path . --script res://scripts/ui/expedition/expedition_relic_info_test_runner.gd

const InfoTest := preload("res://scripts/ui/expedition/expedition_relic_info_test.gd")


func _initialize() -> void:
	var ok := InfoTest.run()
	quit(0 if ok else 1)
