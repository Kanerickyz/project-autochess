extends Control

const GAME_SCENE_PATH := "res://scenes/main/run_game.tscn"
const SANDBOX_SCENE_PATH := "res://scenes/main/sandbox.tscn"

@onready var _start_button: Button = %StartButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _version_label: Label = %VersionLabel
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_panel.closed.connect(_on_settings_closed)
	_refresh_version_label()
	if OS.has_feature("web"):
		_exit_button.visible = false
	_start_button.grab_focus()


func _refresh_version_label() -> void:
	if _version_label == null:
		return
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if version.is_empty():
		version = "0.0.0"
	_version_label.text = "v%s" % version


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(SANDBOX_SCENE_PATH)


func _on_settings_pressed() -> void:
	_settings_panel.open()


func _on_settings_closed() -> void:
	_settings_button.grab_focus()


func _on_exit_pressed() -> void:
	if OS.has_feature("web"):
		return
	get_tree().quit()
