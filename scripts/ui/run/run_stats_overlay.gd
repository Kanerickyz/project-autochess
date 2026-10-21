class_name RunStatsOverlay
extends Control

signal continue_pressed

@onready var _title: Label = %TitleLabel
@onready var _body: Label = %BodyLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	visible = false


func show_stats(lines: PackedStringArray) -> void:
	_title.text = "远征统计"
	_body.text = "\n".join(lines)
	visible = true
	_continue_button.grab_focus()


func hide_overlay() -> void:
	visible = false


func _on_continue_pressed() -> void:
	continue_pressed.emit()
