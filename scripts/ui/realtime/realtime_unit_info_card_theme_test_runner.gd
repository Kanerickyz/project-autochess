extends SceneTree
## Headless：介绍卡侧栏主题类名烟测。

const TestScript := preload("res://scripts/ui/realtime/realtime_unit_info_card_theme_test.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = TestScript.run_all(root)
	quit(0 if ok else 1)
