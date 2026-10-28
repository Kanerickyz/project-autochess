extends Control

const MAIN_MENU_PATH := "res://scenes/main/main_menu.tscn"
const RUN_STATS_OVERLAY_SCENE := preload("res://scenes/ui/run/run_stats_overlay.tscn")

const LIST_BUTTON_NORMAL := Color(0.12, 0.15, 0.20, 0.95)
const LIST_BUTTON_HOVER := Color(0.16, 0.20, 0.26, 0.98)

@onready var _back_button: Button = %BackButton
@onready var _clear_button: Button = %ClearButton
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _list_vbox: VBoxContainer = %ListVBox
@onready var _empty_label: Label = %EmptyLabel
@onready var _content_root: Control = $Root

var _stats_overlay: RunStatsOverlay


func _ready() -> void:
	_stats_overlay = RUN_STATS_OVERLAY_SCENE.instantiate() as RunStatsOverlay
	if _stats_overlay != null:
		add_child(_stats_overlay)
		_stats_overlay.set_continue_button_text("返回列表")
		_stats_overlay.continue_pressed.connect(_on_stats_back)
	_back_button.pressed.connect(_on_back_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)
	_rebuild_list()
	_back_button.grab_focus()


func _rebuild_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()
	var entries := RunMatchHistoryStore.list_entries()
	_empty_label.visible = entries.is_empty()
	_list_scroll.visible = not entries.is_empty()
	_clear_button.disabled = entries.is_empty()
	for item in entries:
		var row := _make_record_button(item)
		_list_vbox.add_child(row)


func _make_record_button(item: RunMatchHistoryStore.ListEntry) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s\n%s" % [item.title, item.subtitle]
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.98, 1))
	var normal := StyleBoxFlat.new()
	normal.bg_color = LIST_BUTTON_NORMAL
	normal.set_corner_radius_all(10)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.42, 0.36, 0.24, 0.75)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = LIST_BUTTON_HOVER
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(_on_record_pressed.bind(item.id))
	return button


func _on_record_pressed(record_id: String) -> void:
	var snapshot := RunMatchHistoryStore.load_snapshot_by_id(record_id)
	if snapshot == null:
		return
	_stats_overlay.set_continue_button_text("返回列表")
	_stats_overlay.show_snapshot(snapshot)


func _on_stats_back() -> void:
	_stats_overlay.hide_overlay()
	_back_button.grab_focus()


func _on_clear_pressed() -> void:
	RunMatchHistoryStore.clear_all()
	_rebuild_list()


func _on_back_pressed() -> void:
	if SceneTransition.is_busy():
		return
	await SceneTransition.change_scene_to_file(MAIN_MENU_PATH, _content_root)
