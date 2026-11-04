extends SceneTree
## 可选：godot --headless --path . --script res://scripts/core/run/expedition_relic_bag_test_runner.gd

const TestScript := preload("res://scripts/core/run/expedition_relic_bag_test.gd")


func _init() -> void:
	var ok: bool = TestScript.run()
	quit(0 if ok else 1)
