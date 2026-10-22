extends Control

const GAME_SCENE_PATH := "res://scenes/main/run_game.tscn"
const CODEX_SCENE_PATH := "res://scenes/ui/codex/unit_codex_screen.tscn"
const COMBAT_SANDBOX_PATH := "res://scenes/main/combat_sandbox.tscn"
const ENCHANT_SANDBOX_PATH := "res://scenes/main/enchant_sandbox.tscn"

# 单按钮竖条精灵图：自上而下为常态 / 悬停 / 按下 / …（见 menu_button_sheet.jpg）
const MENU_BUTTON_NORMAL := "res://assets/ui/main_menu/menu_button_0.jpg"
const MENU_BUTTON_HOVER := "res://assets/ui/main_menu/menu_button_1.jpg"
const MENU_BUTTON_PRESSED := "res://assets/ui/main_menu/menu_button_2.jpg"
const MENU_BUTTON_DISABLED := "res://assets/ui/main_menu/menu_button_5.jpg"

const LOGO_TEXTURE_WIDTH := 2123.0
const LOGO_TEXTURE_HEIGHT := 741.0
const LOGO_WIDTH_SCALE := 0.8

const BUTTON_TEXTURE_SIZE := Vector2i(1024, 256)
# 圆角胶囊：左右 slice 约为纹理高度的一半（像素）
const BUTTON_CAP_PX := 128
const BUTTON_TARGET_WIDTH := 328.0

@onready var _title_logo: TextureRect = $SafeMargin/MainVBox/TitleRow/TitleLogo
@onready var _start_button: Button = %StartButton
@onready var _codex_button: Button = %CodexButton
@onready var _combat_sandbox_button: Button = %CombatSandboxButton
@onready var _enchant_sandbox_button: Button = %EnchantSandboxButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _version_label: Label = %VersionLabel
@onready var _settings_panel: SettingsPanel = %SettingsPanel


func _ready() -> void:
	_apply_title_logo_width()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_menu_button_styles()
	_start_button.pressed.connect(_on_start_pressed)
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
	_apply_title_logo_width()
	_apply_menu_button_styles()


func _apply_title_logo_width() -> void:
	if _title_logo == null:
		return
	var view_w := get_viewport().get_visible_rect().size.x
	var side_margin := 40.0
	var target_w := clampf(view_w - side_margin * 2.0, 560.0, 720.0) * LOGO_WIDTH_SCALE
	var target_h := target_w * (LOGO_TEXTURE_HEIGHT / LOGO_TEXTURE_WIDTH)
	_title_logo.custom_minimum_size = Vector2(target_w, target_h)


func _menu_button_pixel_size() -> Vector2:
	var button_w := clampf(
		get_viewport().get_visible_rect().size.x - 64.0,
		BUTTON_TARGET_WIDTH,
		BUTTON_TARGET_WIDTH + 24.0,
	)
	var button_h := button_w * float(BUTTON_TEXTURE_SIZE.y) / float(BUTTON_TEXTURE_SIZE.x)
	return Vector2(button_w, button_h)


func _apply_menu_button_styles() -> void:
	var buttons: Array[Button] = [
		_start_button,
		_codex_button,
		_combat_sandbox_button,
		_enchant_sandbox_button,
		_settings_button,
		_exit_button,
	]
	var pixel_size := _menu_button_pixel_size()
	for button: Button in buttons:
		button.flat = true
		button.custom_minimum_size = pixel_size
		button.add_theme_stylebox_override("normal", _make_menu_button_stylebox(MENU_BUTTON_NORMAL))
		button.add_theme_stylebox_override("hover", _make_menu_button_stylebox(MENU_BUTTON_HOVER))
		button.add_theme_stylebox_override("pressed", _make_menu_button_stylebox(MENU_BUTTON_PRESSED))
		button.add_theme_stylebox_override("focus", _make_menu_button_stylebox(MENU_BUTTON_HOVER))
		button.add_theme_stylebox_override("disabled", _make_menu_button_stylebox(MENU_BUTTON_DISABLED))
		button.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 0.95, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.9, 0.88, 0.82, 1))
		button.add_theme_font_size_override("font_size", 21)


func _make_menu_button_stylebox(texture_path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path) as Texture2D
	style.texture_margin_left = BUTTON_CAP_PX
	style.texture_margin_right = BUTTON_CAP_PX
	style.texture_margin_top = 0
	style.texture_margin_bottom = 0
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 4
	style.content_margin_bottom = 4
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


func _on_combat_sandbox_pressed() -> void:
	get_tree().change_scene_to_file(COMBAT_SANDBOX_PATH)


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
