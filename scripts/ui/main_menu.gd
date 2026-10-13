extends Control

## preload 以便 Web「按场景导出」能收依赖；沙盒仅桌面入口使用。
const GAME_SCENE: PackedScene = preload("res://scenes/main/run_game.tscn")
const SANDBOX_SCENE_PATH := "res://scenes/main/sandbox.tscn"

@onready var _start_button: Button = %StartButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_sandbox_button.pressed.connect(_on_sandbox_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_panel.closed.connect(_on_settings_closed)
	if OS.has_feature("web"):
		# Web 试玩只走 Run 主路径，避免把沙盒/旧 3D 棋盘与动物池打进 Pages 包。
		_exit_button.visible = false
		_sandbox_button.visible = false
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_packed(GAME_SCENE)


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
