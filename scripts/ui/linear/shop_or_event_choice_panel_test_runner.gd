extends SceneTree
## Headless：战后店|事|跳过选项卡契约。


func _initialize() -> void:
	var ok := ShopOrEventChoicePanelTest.run_all()
	quit(0 if ok else 1)
