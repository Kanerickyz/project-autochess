extends SceneTree

const CombatStatusTestScript := preload("res://scripts/combat/combat_status_test.gd")


func _initialize() -> void:
	var ok: bool = CombatStatusTestScript.run_all()
	quit(0 if ok else 1)
