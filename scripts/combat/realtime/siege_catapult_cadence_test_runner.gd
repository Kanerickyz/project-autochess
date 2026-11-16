extends SceneTree

const SiegeCatapultCadenceTestScript := preload(
	"res://scripts/combat/realtime/siege_catapult_cadence_test.gd"
)


func _initialize() -> void:
	var ok := SiegeCatapultCadenceTestScript.run_all()
	if ok:
		print("siege_catapult_cadence_test: OK")
		quit(0)
	else:
		push_error("siege_catapult_cadence_test: FAILED")
		quit(1)