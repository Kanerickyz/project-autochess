extends SceneTree

const Tests := preload("res://scripts/core/run/run_stat_ledger_test.gd")


func _init() -> void:
	var ok := Tests.run_all()
	quit(0 if ok else 1)
