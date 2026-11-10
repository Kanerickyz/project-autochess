extends SceneTree
## Headless：职业计数纯函数。

const SynergyOccupationsTestScript := preload("res://scripts/data/synergy_occupations_test.gd")


func _initialize() -> void:
	var ok: bool = SynergyOccupationsTestScript.run_all()
	if ok:
		print("synergy_occupations_test: OK")
	quit(0 if ok else 1)
