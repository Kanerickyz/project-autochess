extends SceneTree

const DeckTripleMergeHintTestScript := preload("res://scripts/core/deck_triple_merge_hint_test.gd")


func _initialize() -> void:
	var ok: bool = DeckTripleMergeHintTestScript.run_all()
	quit(0 if ok else 1)
