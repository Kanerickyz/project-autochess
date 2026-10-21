extends Control

const GAME_SCENE_PATH := "res://scenes/main/run_game.tscn"
const CODEX_SCENE_PATH := "res://scenes/ui/codex/unit_codex_screen.tscn"
const ENCHANT_SANDBOX_PATH := "res://scenes/main/enchant_sandbox.tscn"

const MENU_BUTTON_NORMAL := "res://assets/ui/main_menu/menu_button_0.jpg"
const MENU_BUTTON_HOVER := "res://assets/ui/main_menu/menu_button_1.jpg"
const MENU_BUTTON_PRESSED := "res://assets/ui/main_menu/menu_button_2.jpg"

@onready var _start_button: Button = %StartButton
@onready var _codex_button: Button = %CodexButton
@onready var _enchant_sandbox_button: Button = %EnchantSandboxButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _version_label: Label = %VersionLabel
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	_apply_menu_button_styles()
	_start_button.pressed.connect(_on_start_pressed)
	_codex_button.pressed.connect(_on_codex_pressed)
	_enchant_sandbox_button.pressed.connect(_on_enchant_sandbox_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_panel.closed.connect(_on_settings_closed)
	_refresh_version_label()
	if OS.has_feature("web"):
		_exit_button.visible = false
	_start_button.grab_focus()


func _apply_menu_button_styles() -> void:
	var buttons: Array[Button] = [
		_start_button,
		_codex_button,
		_enchant_sandbox_button,
		_settings_button,
		_exit_button,
	]
	var normal := _make_menu_button_stylebox(MENU_BUTTON_NORMAL)
	var hover := _make_menu_button_stylebox(MENU_BUTTON_HOVER)
	var pressed := _make_menu_button_stylebox(MENU_BUTTON_PRESSED)
	for button: Button in buttons:
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 0.95, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.9, 0.88, 0.82, 1))
		button.add_theme_font_size_override("font_size", 20)


func _make_menu_button_stylebox(texture_path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path) as Texture2D
	style.texture_margin_left = 72
	style.texture_margin_top = 18
	style.texture_margin_right = 72
	style.texture_margin_bottom = 18
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.draw_center = true
	return style


func _refresh_version_label() -> void:
	if _version_label == null:
		return
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if version.is_empty():
		version = "0.0.0"
	_version_label.text = "v%s" % version


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_codex_pressed() -> void:
	get_tree().change_scene_to_file(CODEX_SCENE_PATH)


func _on_enchant_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(ENCHANT_SANDBOX_PATH)


func _on_settings_pressed() -> void:
	_settings_panel.open()


func _on_settings_closed() -> void:
	_settings_button.grab_focus()


func _on_exit_pressed() -> void:
	if OS.has_feature("web"):
		return
	get_tree().quit()
