extends SceneTree

const EquipmentWeaponTestScript := preload("res://scripts/combat/equipment_weapon_test.gd")


func _initialize() -> void:
	var ok := EquipmentWeaponTestScript.run_all()
	quit(0 if ok else 1)