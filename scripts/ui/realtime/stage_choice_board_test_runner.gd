extends SceneTree
## Headless：上半场选项卡片几何。

const TestScript := preload("res://scripts/ui/realtime/stage_choice_board_test.gd")


func _initialize() -> void:
	var ok := TestScript.run_all()
	quit(0 if ok else 1)
