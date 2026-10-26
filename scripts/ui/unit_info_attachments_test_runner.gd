extends SceneTree

const UnitInfoAttachmentsTestScript := preload("res://scripts/ui/unit_info_attachments_test.gd")


func _initialize() -> void:
	var ok := UnitInfoAttachmentsTestScript.run_all()
	quit(0 if ok else 1)
