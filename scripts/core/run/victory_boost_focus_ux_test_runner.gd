extends SceneTree

const VictoryBoostFocusUxTestScript := preload("res://scripts/core/run/victory_boost_focus_ux_test.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := await VictoryBoostFocusUxTestScript.run_all(self)
	quit(0 if ok else 1)
