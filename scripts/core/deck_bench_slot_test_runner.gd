extends SceneTree

const DeckBenchSlotTestScript := preload("res://scripts/core/deck_bench_slot_test.gd")


func _initialize() -> void:
	var ok: bool = DeckBenchSlotTestScript.run_all()
	quit(0 if ok else 1)
