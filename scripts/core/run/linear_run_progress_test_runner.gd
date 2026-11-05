extends SceneTree

const LinearRunProgressTestScript := preload("res://scripts/core/run/linear_run_progress_test.gd")


func _init() -> void:
	var ok: bool = LinearRunProgressTestScript.run_all()
	quit(0 if ok else 1)
