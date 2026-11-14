extends SceneTree

const GhostGraveyardCadenceTestScript := preload(
	"res://scripts/combat/realtime/ghost_graveyard_cadence_test.gd"
)


func _initialize() -> void:
	var ok := GhostGraveyardCadenceTestScript.run_all()
	if ok:
		print("ghost_graveyard_cadence_test: OK")
	quit(0)
	else:
		push_error("ghost_graveyard_cadence_test: FAILED")
		quit(1)