class_name UiKit
extends RefCounted
## 统一 UI Kit 工厂（里程碑 B）。
##
## 用法（新 UI 禁止 StyleBoxFlat.new() 当主题）：
##   1. 根 Control：`theme = UiKit.shell_theme()`（或场景 Theme 指向 ui_shell_theme.tres）
##   2. 面板：`var p := UiKit.make_shell_panel()` / `make_dock_panel()` / `make_popup_panel()` …
##   3. 按钮：`UiKit.make_primary_button("开战")`（Primary）/ Secondary / Icon
##   4. Popup：实例化 `res://scenes/ui/kit/game_popup.tscn`，或 `UiKit.instantiate_popup()`
##   5. 色 token：`UiKit.COLOR_HP_ALLY` / `COLOR_HP_ENEMY` / `COLOR_GOLD` / `COLOR_DIM`
##
## Theme 变体名：ShellPanel / FloatingPanel / KitPopupPanel / DockPanel / HeroPanel /
## ToastPanel；Button：Primary / Secondary / Icon。
## 注意：引擎内置类名 PopupPanel 不可作 type variation，故用 KitPopupPanel。

const SHELL_THEME_PATH := "res://resources/ui/ui_shell_theme.tres"
const GAME_POPUP_SCENE_PATH := "res://scenes/ui/kit/game_popup.tscn"

const VAR_SHELL_PANEL := &"ShellPanel"
const VAR_FLOATING_PANEL := &"FloatingPanel"
const VAR_POPUP_PANEL := &"KitPopupPanel"
const VAR_DOCK_PANEL := &"DockPanel"
const VAR_HERO_PANEL := &"HeroPanel"
const VAR_TOAST_PANEL := &"ToastPanel"
const VAR_PRIMARY := &"Primary"
const VAR_SECONDARY := &"Secondary"
const VAR_ICON := &"Icon"

## 敌方血条偏红（勿作唯一通道，仍靠上半场位置区分）。
const COLOR_HP_ENEMY := Color(0.82, 0.32, 0.30, 1.0)
## 我方血条偏绿。
const COLOR_HP_ALLY := Color(0.35, 0.78, 0.48, 1.0)
## 金币 / 资源强调。
const COLOR_GOLD := Color(0.92, 0.78, 0.28, 1.0)
## Popup / Modal 半透明遮罩。
const COLOR_DIM := Color(0.02, 0.04, 0.06, 0.72)
## 描边 / 分割线（青绿纸片风）。
const COLOR_STROKE := Color(0.35, 0.50, 0.45, 1.0)

## 触控主按钮建议最小热区（逻辑像素，对齐 apple-hig ~44）。
const TOUCH_MIN := Vector2(44, 44)
const BUTTON_MIN_PRIMARY := Vector2(160, 48)
const BUTTON_MIN_SECONDARY := Vector2(120, 44)
const BUTTON_MIN_ICON := Vector2(44, 44)

static var _cached_theme: Theme


static func shell_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme
	var loaded := load(SHELL_THEME_PATH)
	if loaded is Theme:
		_cached_theme = loaded as Theme
	else:
		push_error("UiKit: failed to load %s" % SHELL_THEME_PATH)
		_cached_theme = Theme.new()
	return _cached_theme


## 把壳 Theme 挂到控件（及其子树，若未另设 theme）。
static func apply_shell_theme(control: Control) -> void:
	if control == null:
		return
	control.theme = shell_theme()


static func apply_variation(control: Control, variation: StringName) -> void:
	if control == null:
		return
	if control.theme == null:
		control.theme = shell_theme()
	control.theme_type_variation = String(variation)


## 从 Theme 取 StyleBox 并 duplicate，供需要覆盖个别属性时使用（仍禁止私建主题）。
static func stylebox_for(variation: StringName, style_name: StringName = &"panel") -> StyleBox:
	var theme := shell_theme()
	var box: StyleBox = null
	if theme.has_stylebox(style_name, variation):
		box = theme.get_stylebox(style_name, variation)
	elif theme.has_stylebox(style_name, &"PanelContainer"):
		box = theme.get_stylebox(style_name, &"PanelContainer")
	if box == null:
		push_warning("UiKit: missing stylebox %s/%s" % [variation, style_name])
		return StyleBoxEmpty.new()
	return box.duplicate()


static func make_panel(variation: StringName) -> PanelContainer:
	var panel := PanelContainer.new()
	apply_shell_theme(panel)
	apply_variation(panel, variation)
	return panel


static func make_shell_panel() -> PanelContainer:
	return make_panel(VAR_SHELL_PANEL)


static func make_floating_panel() -> PanelContainer:
	return make_panel(VAR_FLOATING_PANEL)


static func make_popup_panel() -> PanelContainer:
	return make_panel(VAR_POPUP_PANEL)


static func make_dock_panel() -> PanelContainer:
	return make_panel(VAR_DOCK_PANEL)


static func make_hero_panel() -> PanelContainer:
	return make_panel(VAR_HERO_PANEL)


static func make_toast_panel() -> PanelContainer:
	return make_panel(VAR_TOAST_PANEL)


static func make_button(text: String, variation: StringName, min_size: Vector2 = TOUCH_MIN) -> Button:
	var button := Button.new()
	apply_shell_theme(button)
	apply_variation(button, variation)
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_ALL
	return button


static func make_primary_button(text: String) -> Button:
	return make_button(text, VAR_PRIMARY, BUTTON_MIN_PRIMARY)


static func make_secondary_button(text: String) -> Button:
	return make_button(text, VAR_SECONDARY, BUTTON_MIN_SECONDARY)


static func make_icon_button(text: String = "") -> Button:
	var button := make_button(text, VAR_ICON, BUTTON_MIN_ICON)
	button.custom_minimum_size = BUTTON_MIN_ICON
	return button


static func instantiate_popup() -> GamePopup:
	var packed := load(GAME_POPUP_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("UiKit: missing GamePopup scene at %s" % GAME_POPUP_SCENE_PATH)
		return GamePopup.new()
	var node := packed.instantiate()
	if node is GamePopup:
		return node as GamePopup
	push_error("UiKit: root of game_popup.tscn is not GamePopup")
	return GamePopup.new()


static func has_required_variations() -> bool:
	var theme := shell_theme()
	var panels: Array[StringName] = [
		VAR_SHELL_PANEL, VAR_FLOATING_PANEL, VAR_POPUP_PANEL,
		VAR_DOCK_PANEL, VAR_HERO_PANEL, VAR_TOAST_PANEL,
	]
	for v in panels:
		if theme.get_type_variation_base(v) != &"PanelContainer":
			return false
		if not theme.has_stylebox(&"panel", v):
			return false
	var buttons: Array[StringName] = [VAR_PRIMARY, VAR_SECONDARY, VAR_ICON]
	for v in buttons:
		if theme.get_type_variation_base(v) != &"Button":
			return false
		if not theme.has_stylebox(&"normal", v):
			return false
	return true
