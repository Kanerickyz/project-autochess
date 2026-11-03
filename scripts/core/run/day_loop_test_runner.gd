extends SceneTree

const DayLoopTestScript := preload("res://scripts/core/run/day_loop_test.gd")


func _initialize() -> void:
	var ok: bool = DayLoopTestScript.run_all()
	quit(0 if ok else 1)
