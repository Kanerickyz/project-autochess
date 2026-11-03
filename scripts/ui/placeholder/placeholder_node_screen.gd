class_name PlaceholderNodeScreen
extends Control
## 本版未实装的地图节点：只显示节点名与占位说明，点「继续」回地图。

signal continue_pressed

@onready var _title: Label = %TitleLabel
@onready var _desc: Label = %DescLabel
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)


func show_placeholder(node_type: MapNodeType.Type) -> void:
	_title.text = MapNodeType.display_name(node_type)
	_desc.text = "（占位）本节点内容尚未实装，点击继续回到地图。"
	visible = true
	_continue_button.grab_focus()


func hide_placeholder() -> void:
	visible = false


func _on_continue_pressed() -> void:
	continue_pressed.emit()
