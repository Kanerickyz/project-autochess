class_name MainMenuParallaxBackground
extends PhaseGridBackground
## 主菜单动态背景：复用 PhaseGridBackground，固定 MENU 色板。


func _ready() -> void:
	initial_theme = PhaseGridPalettes.ThemeId.MENU
	enable_pointer_parallax = true
	super._ready()
