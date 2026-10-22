extends SceneTree

const ArmorDamageBoundaryTestScript := preload("res://scripts/combat/armor_damage_boundary_test.gd")


func _initialize() -> void:
	var ok: bool = ArmorDamageBoundaryTestScript.run_all()
	quit(0 if ok else 1)
