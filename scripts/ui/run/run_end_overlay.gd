class_name RunEndOverlay
extends Control

signal action_pressed(action: StringName)

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _primary_button: Button = %PrimaryButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_primary_button.pressed.connect(_on_primary_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	visible = false


func show_victory() -> void:
	_title.text = "远征完成！"
	_subtitle.text = "你击败了 Boss。可再来一局，或返回主菜单"
	_primary_button.text = "再来一局"
	visible = true
	_primary_button.grab_focus()


func show_defeat() -> void:
	_title.text = "远征失败"
	_subtitle.text = "牌库与进度已重置，可重新出发"
	_primary_button.text = "重新出发"
	visible = true
	_primary_button.grab_focus()


func hide_overlay() -> void:
	visible = false


func _on_primary_pressed() -> void:
	action_pressed.emit(&"restart")


func _on_menu_pressed() -> void:
	action_pressed.emit(&"menu")
