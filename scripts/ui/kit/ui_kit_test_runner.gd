extends SceneTree
## Headless runner：UiKit Theme / 工厂 / GamePopup 契约。

const UiKitTestScript := preload("res://scripts/ui/kit/ui_kit_test.gd")


func _initialize() -> void:
	var ok := UiKitTestScript.run_all()
	var packed := load("res://scenes/ui/kit/game_popup.tscn")
	if packed == null:
		push_error("UiKitTestRunner: game_popup.tscn failed to load")
		ok = false
	else:
		var node := (packed as PackedScene).instantiate()
		root.add_child(node)
		await process_frame
		if not (node is GamePopup):
			push_error("UiKitTestRunner: root is not GamePopup")
			ok = false
		else:
			var popup := node as GamePopup
			popup.configure("Runner", "load ok", "确定", "取消")
			popup.open()
			await process_frame
			if popup.get_secondary_button() == null or popup.get_primary_button() == null:
				push_error("UiKitTestRunner: buttons missing after open")
				ok = false
			elif popup.get_secondary_button().get_index() >= popup.get_primary_button().get_index():
				push_error("UiKitTestRunner: secondary must be left of primary")
				ok = false
			popup.close(false)
		node.queue_free()
	if ok:
		print("UiKitTestRunner: PASS")
		quit(0)
	else:
		print("UiKitTestRunner: FAIL")
		quit(1)
