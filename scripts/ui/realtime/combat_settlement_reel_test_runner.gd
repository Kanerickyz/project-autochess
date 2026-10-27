extends SceneTree

const TestScript := preload("res://scripts/ui/realtime/combat_settlement_reel_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = TestScript.run_all(root)
	quit(0 if ok else 1)
