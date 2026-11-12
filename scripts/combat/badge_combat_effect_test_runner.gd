extends SceneTree

const BadgeCombatEffectTestScript := preload("res://scripts/combat/badge_combat_effect_test.gd")


func _initialize() -> void:
	var ok: bool = BadgeCombatEffectTestScript.run_all()
	if ok:
		print("BadgeCombatEffectTest: all passed")
	quit(0 if ok else 1)
