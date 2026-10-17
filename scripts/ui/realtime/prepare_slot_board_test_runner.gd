extends SceneTree

const PrepareSlotBoardTestScript := preload("res://scripts/ui/realtime/prepare_slot_board_test.gd")


func _initialize() -> void:
	var ok: bool = PrepareSlotBoardTestScript.run_all()
	quit(0 if ok else 1)
