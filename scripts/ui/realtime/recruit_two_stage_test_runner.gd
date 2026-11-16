extends SceneTree

const RecruitTwoStageTestScript := preload(
	"res://scripts/ui/realtime/recruit_two_stage_test.gd"
)


func _initialize() -> void:
	var ok := RecruitTwoStageTestScript.run_all()
	if ok:
		print("recruit_two_stage_test: OK")
		quit(0)
	else:
		push_error("recruit_two_stage_test: FAILED")
		quit(1)