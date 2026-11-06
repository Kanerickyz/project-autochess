class_name GameToast
extends PanelContainer
## 短暂提示（层级解锁等）：不抢操作，自动消失。样式用 ToastPanel 变体。
##
## 用法：
##   var toast := GameToast.new()
##   hud.add_child(toast)
##   toast.show_message("已解锁 T2", "本层起可招募")

const SHOW_SEC := 2.0

var _title: Label
var _subtitle: Label
var _tween: Tween


func _ready() -> void:
	UiKit.apply_shell_theme(self)
	theme_type_variation = String(UiKit.VAR_TOAST_PANEL)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	_ensure_labels()


func _ensure_labels() -> void:
	if _title != null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", UiKit.COLOR_GOLD)
	box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_subtitle)


func show_message(title: String, subtitle: String = "") -> void:
	_ensure_labels()
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	visible = true
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = Vector2(0.94, 0.94)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, UiMotion.PANEL_FADE_SEC)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "scale", Vector2.ONE, UiMotion.PANEL_FADE_SEC)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.chain().tween_interval(SHOW_SEC)
	_tween.chain().tween_property(self, "modulate:a", 0.0, UiMotion.PANEL_FADE_SEC)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.chain().tween_callback(func() -> void: visible = false)
