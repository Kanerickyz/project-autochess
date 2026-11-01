extends SceneTree

const DeckCommanderTestScript := preload("res://scripts/core/deck_commander_test.gd")


func _initialize() -> void:
	var ok := DeckCommanderTestScript.run_all()
	if ok:
		print("DeckCommanderTest: all passed")
	else:
		push_error("DeckCommanderTest: failures detected")
	quit(0 if ok else 1)
