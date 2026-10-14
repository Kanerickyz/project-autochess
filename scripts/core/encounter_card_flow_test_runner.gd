extends SceneTree
## Headless runner for EncounterCardFlowTest.


func _initialize() -> void:
	var script: GDScript = load("res://scripts/core/encounter_card_flow_test.gd") as GDScript
	var ok: bool = script.call("run_all") as bool
	if ok:
		print("EncounterCardFlowTestRunner: all passed")
		quit(0)
	else:
		push_error("EncounterCardFlowTestRunner: FAILED")
		quit(1)
