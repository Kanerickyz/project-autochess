extends SceneTree

const BadgeFlowTestScript := preload("res://scripts/core/run/badge_flow_test.gd")


func _initialize() -> void:
	var ok: bool = BadgeFlowTestScript.run_all()
	if ok:
		print("BadgeFlowTest: all passed")
	quit(0 if ok else 1)
