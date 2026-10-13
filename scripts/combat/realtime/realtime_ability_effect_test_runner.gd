extends SceneTree

const AbilityEffectTest := preload("res://scripts/combat/realtime/realtime_ability_effect_test.gd")


func _initialize() -> void:
	var ok: bool = AbilityEffectTest.run_all()
	quit(0 if ok else 1)
