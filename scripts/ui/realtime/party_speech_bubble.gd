class_name PartySpeechBubble
extends Control
## 招募上区纸片旁的对话气泡（非模态；纯表现）。

const DEFAULT_TEXTURE := preload(
	"res://assets/sprites/paper_cutout/ui/speech_bubbles/speech_bubble_medium.png"
)
const DISPLAY_SIZE := Vector2(152.0, 108.0)
const FADE_IN := 0.12
const HOLD := 2.6
const FADE_OUT := 0.45

var _panel: TextureRect
var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	custom_minimum_size = DISPLAY_SIZE
	size = DISPLAY_SIZE
	_build()


func _build() -> void:
	_panel = TextureRect.new()
	_panel.name = "BubblePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.texture = DEFAULT_TEXTURE
	_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.stretch_mode = TextureRect.STRETCH_SCALE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	_label = Label.new()
	_label.name = "BubbleLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_color_override("font_color", Color(0.22, 0.14, 0.1, 1.0))
	_label.add_theme_font_size_override("font_size", 15)
	## 尾部在下：文案偏上居中。
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 18.0
	_label.offset_top = 10.0
	_label.offset_right = -18.0
	_label.offset_bottom = -28.0
	add_child(_label)


## tip 指向的本地坐标（相对 parent）；气泡底部尖角对准该点。
func present_at(parent_local_tip: Vector2, text: String) -> void:
	if _label == null:
		_build()
	_label.text = text
	## 尖角约在底边偏左（约 40% 宽）。
	position = parent_local_tip - Vector2(size.x * 0.40, size.y - 6.0)
	visible = true
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.finished.connect(_on_fade_finished, CONNECT_ONE_SHOT)


func dismiss() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	visible = false
	modulate.a = 0.0


func _on_fade_finished() -> void:
	visible = false
