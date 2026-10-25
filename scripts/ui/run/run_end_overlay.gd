class_name RunEndOverlay
extends Control

signal action_pressed(action: StringName)

enum Mode { HIDDEN, RESULT_INTRO, CHOICES }

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _primary_button: Button = %PrimaryButton
@onready var _menu_button: Button = %MenuButton

var _mode: Mode = Mode.HIDDEN
var _victory: bool = false
var _reached_floor: int = 0
var _endless: bool = false


func _ready() -> void:
	_primary_button.pressed.connect(_on_primary_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	visible = false


## 结局宣告：仅「继续」，随后进入远征统计。
## reached_floor / endless：无尽败局展示「到达第 N 层」。
func show_result_intro(victory: bool, reached_floor: int = 0, endless: bool = false) -> void:
	_victory = victory
	_reached_floor = maxi(0, reached_floor)
	_endless = endless
	_mode = Mode.RESULT_INTRO
	if victory:
		_title.text = "远征完成！"
		_subtitle.text = "你击败了 Boss"
	elif _endless and _reached_floor > 0:
		_title.text = "无尽挑战结束"
		_subtitle.text = "到达第 %d 层" % _reached_floor
	else:
		_title.text = "远征失败"
		_subtitle.text = "本局已结束"
	_primary_button.text = "继续"
	_menu_button.visible = false
	visible = true
	_primary_button.grab_focus()


## 统计看完后：再来一局 / 返回主菜单。
func show_choices(victory: bool, reached_floor: int = 0, endless: bool = false) -> void:
	_victory = victory
	_reached_floor = maxi(0, reached_floor)
	_endless = endless
	_mode = Mode.CHOICES
	if victory:
		_title.text = "远征完成！"
		_subtitle.text = "可再来一局，或返回主菜单"
		_primary_button.text = "再来一局"
	elif _endless and _reached_floor > 0:
		_title.text = "无尽挑战结束"
		_subtitle.text = "到达第 %d 层 · 可再来一局或返回主菜单" % _reached_floor
		_primary_button.text = "再来一局"
	else:
		_title.text = "远征失败"
		_subtitle.text = "进度已重置，可重新出发或返回主菜单"
		_primary_button.text = "重新出发"
	_menu_button.visible = true
	_menu_button.text = "返回主菜单"
	visible = true
	_primary_button.grab_focus()


func show_victory() -> void:
	show_choices(true)


func show_defeat() -> void:
	show_choices(false)


func hide_overlay() -> void:
	_mode = Mode.HIDDEN
	visible = false


func _on_primary_pressed() -> void:
	if _mode == Mode.RESULT_INTRO:
		action_pressed.emit(&"continue")
		return
	action_pressed.emit(&"restart")


func _on_menu_pressed() -> void:
	action_pressed.emit(&"menu")
