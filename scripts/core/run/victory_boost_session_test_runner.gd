extends SceneTree

const VictoryBoostSessionTestScript := preload("res://scripts/core/run/victory_boost_session_test.gd")


func _init() -> void:
	var ok := VictoryBoostSessionTestScript.run_all()
	quit(0 if ok else 1)
