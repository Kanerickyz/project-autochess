extends Control

const GAME_SCENE_PATH := "res://scenes/main/run_game.tscn"
const ENDLESS_SCENE_PATH := "res://scenes/main/endless_game.tscn"
const CODEX_SCENE_PATH := "res://scenes/ui/codex/unit_codex_screen.tscn"
const COMBAT_SANDBOX_PATH := "res://scenes/main/combat_sandbox.tscn"
const ENCHANT_SANDBOX_PATH := "res://scenes/main/enchant_sandbox.tscn"
const MATCH_HISTORY_PATH := "res://scenes/ui/match_history/match_history_screen.tscn"

const LOGO_TEXTURE_WIDTH := 2123.0
const LOGO_TEXTURE_HEIGHT := 741.0
const LOGO_WIDTH_FRAC := 0.72
const LOGO_WIDTH_MIN := 200.0
const LOGO_WIDTH_MAX := 320.0

## 主按钮（开始）高度；次要/系统略矮，保证 iPhone 14 Pro 一屏可见版本号。
const PRIMARY_BTN_H := 54.0
const SECONDARY_BTN_H := 44.0
const SYSTEM_BTN_H := 40.0
const BTN_CORNER_RADIUS := 14
const BTN_BORDER_W := 2

@onready var _title_logo: TextureRect = $SafeMargin/MainVBox/TitleRow/TitleLogo
@onready var _start_button: Button = %StartButton
@onready var _endless_button: Button = %EndlessButton
@onready var _match_history_button: Button = %MatchHistoryButton
@onready var _codex_button: Button = %CodexButton
@onready var _combat_sandbox_button: Button = %CombatSandboxButton
@onready var _enchant_sandbox_button: Button = %EnchantSandboxButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _version_label: Label = %VersionLabel
@onready var _settings_panel: SettingsPanel = %SettingsPanel
@onready var _safe_margin: MarginContainer = $SafeMargin


func _ready() -> void:
	_apply_responsive_layout()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_start_button.pressed.connect(_on_start_pressed)
	_endless_button.pressed.connect(_on_endless_pressed)
	_match_history_button.pressed.connect(_on_match_history_pressed)
	_codex_button.pressed.connect(_on_codex_pressed)
	_combat_sandbox_button.pressed.connect(_on_combat_sandbox_pressed)
	_enchant_sandbox_button.pressed.connect(_on_enchant_sandbox_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_panel.closed.connect(_on_settings_closed)
	_refresh_version_label()
	if OS.has_feature("web"):
		_exit_button.visible = false
	_start_button.grab_focus()


func _on_viewport_resized() -> void:
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	_apply_title_logo_width()
	_apply_menu_button_styles()
	_apply_safe_margins()


func _apply_safe_margins() -> void:
	if _safe_margin == null:
		return
	var view_h := get_viewport().get_visible_rect().size.y
	## 底边给 Home 指示条留空，版本号不被挡。
	var bottom := 52 if view_h >= 800.0 else 32
	var top := 44 if view_h >= 800.0 else 32
	_safe_margin.add_theme_constant_override("margin_top", top)
	_safe_margin.add_theme_constant_override("margin_bottom", bottom)
	_safe_margin.add_theme_constant_override("margin_left", 20)
	_safe_margin.add_theme_constant_override("margin_right", 20)


func _apply_title_logo_width() -> void:
	if _title_logo == null:
		return
	var view_w := get_viewport().get_visible_rect().size.x
	var target_w := clampf(view_w * LOGO_WIDTH_FRAC, LOGO_WIDTH_MIN, LOGO_WIDTH_MAX)
	## 绝不超出安全区内容宽。
	var max_fit := maxf(160.0, view_w - 40.0)
	target_w = minf(target_w, max_fit)
	var target_h := target_w * (LOGO_TEXTURE_HEIGHT / LOGO_TEXTURE_WIDTH)
	_title_logo.custom_minimum_size = Vector2(target_w, target_h)


func _all_menu_buttons() -> Array[Button]:
	return [
		_start_button,
		_endless_button,
		_match_history_button,
		_codex_button,
		_combat_sandbox_button,
		_enchant_sandbox_button,
		_settings_button,
		_exit_button,
	]


func _apply_menu_button_styles() -> void:
	_style_menu_button(_start_button, PRIMARY_BTN_H, true)
	_style_menu_button(_endless_button, SECONDARY_BTN_H, false)
	for button: Button in [
		_match_history_button,
		_codex_button,
		_combat_sandbox_button,
		_enchant_sandbox_button,
	]:
		_style_menu_button(button, SECONDARY_BTN_H, false)
	_style_menu_button(_settings_button, SYSTEM_BTN_H, false, true)
	_style_menu_button(_exit_button, SYSTEM_BTN_H, false, true)


func _style_menu_button(
	button: Button,
	height: float,
	is_primary: bool,
	is_system: bool = false,
) -> void:
	if button == null:
		return
	## flat=false：确保 StyleBoxFlat 底板一定绘制（部分主题对 flat 按钮会吞样式）。
	button.flat = false
	button.custom_minimum_size = Vector2(0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	var normal_sb := _make_flat_style(_Tone.NORMAL, is_primary, is_system)
	button.add_theme_stylebox_override("normal", normal_sb)
	button.add_theme_stylebox_override("hover", _make_flat_style(_Tone.HOVER, is_primary, is_system))
	button.add_theme_stylebox_override("pressed", _make_flat_style(_Tone.PRESSED, is_primary, is_system))
	button.add_theme_stylebox_override("focus", _make_flat_style(_Tone.FOCUS, is_primary, is_system))
	button.add_theme_stylebox_override("disabled", _make_flat_style(_Tone.DISABLED, is_primary, is_system))
	button.add_theme_stylebox_override("hover_pressed", _make_flat_style(_Tone.PRESSED, is_primary, is_system))
	var font_size := 20 if is_primary else (16 if is_system else 17)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.92, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.92, 0.90, 0.84, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.98, 0.92, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.70, 0.68, 0.64, 0.65))


enum _Tone { NORMAL, HOVER, PRESSED, FOCUS, DISABLED }


func _make_flat_style(tone: _Tone, is_primary: bool, is_system: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = BTN_CORNER_RADIUS
	style.corner_radius_top_right = BTN_CORNER_RADIUS
	style.corner_radius_bottom_left = BTN_CORNER_RADIUS
	style.corner_radius_bottom_right = BTN_CORNER_RADIUS
	style.border_width_left = BTN_BORDER_W
	style.border_width_top = BTN_BORDER_W
	style.border_width_right = BTN_BORDER_W
	style.border_width_bottom = BTN_BORDER_W
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	## 可读深蓝底 + 羊皮纸描边；悬停仅轻微提亮，不再换 JPG 贴图。
	var fill := Color(0.24, 0.38, 0.58, 0.96)
	var border := Color(0.86, 0.74, 0.48, 1.0)
	if is_primary:
		fill = Color(0.28, 0.46, 0.70, 0.98)
		border = Color(0.94, 0.80, 0.42, 1.0)
	elif is_system:
		fill = Color(0.22, 0.26, 0.32, 0.94)
		border = Color(0.70, 0.64, 0.52, 0.95)

	match tone:
		_Tone.HOVER:
			fill = fill.lightened(0.06)
			border = border.lightened(0.10)
		_Tone.PRESSED:
			fill = fill.darkened(0.14)
			border = border.darkened(0.06)
		_Tone.FOCUS:
			fill = fill.lightened(0.04)
			border = Color(0.98, 0.86, 0.50, 1.0)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
		_Tone.DISABLED:
			fill.a *= 0.45
			border.a *= 0.45
		_:
			pass

	style.bg_color = fill
	style.border_color = border
	return style


func _refresh_version_label() -> void:
	if _version_label == null:
		return
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if version.is_empty():
		version = "0.0.0"
	_version_label.text = "v%s" % version


func _on_start_pressed() -> void:
	_navigate_to_scene(GAME_SCENE_PATH)


func _on_endless_pressed() -> void:
	_navigate_to_scene(ENDLESS_SCENE_PATH)


func _on_codex_pressed() -> void:
	_navigate_to_scene(CODEX_SCENE_PATH)


func _on_match_history_pressed() -> void:
	_navigate_to_scene(MATCH_HISTORY_PATH)


func _on_combat_sandbox_pressed() -> void:
	_navigate_to_scene(COMBAT_SANDBOX_PATH)


func _on_enchant_sandbox_pressed() -> void:
	_navigate_to_scene(ENCHANT_SANDBOX_PATH)


func _navigate_to_scene(scene_path: String) -> void:
	if SceneTransition.is_busy():
		return
	_set_menu_interactive(false)
	await SceneTransition.change_scene_to_file(scene_path, _safe_margin)


func _set_menu_interactive(enabled: bool) -> void:
	for button in _all_menu_buttons():
		if button != null:
			button.disabled = not enabled


func _on_settings_pressed() -> void:
	_settings_panel.open()


func _on_settings_closed() -> void:
	_settings_button.grab_focus()


func _on_exit_pressed() -> void:
	if OS.has_feature("web"):
		return
	get_tree().quit()
