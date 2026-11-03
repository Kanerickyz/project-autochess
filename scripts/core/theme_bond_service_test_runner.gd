extends SceneTree

const ThemeBondServiceTestScript := preload("res://scripts/core/theme_bond_service_test.gd")


func _initialize() -> void:
	var ok: bool = ThemeBondServiceTestScript.run_all()
	quit(0 if ok else 1)
