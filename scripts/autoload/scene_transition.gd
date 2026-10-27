extends CanvasLayer
## 全局场景切换：淡出 → change_scene → 淡入。Autoload 跨场景保留遮罩。

const FADE_OUT_SECONDS := 0.28
const FADE_IN_SECONDS := 0.34
const OVERLAY_COLOR := Color(0.08, 0.1, 0.12, 1.0)

var _overlay: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(OVERLAY_COLOR.r, OVERLAY_COLOR.g, OVERLAY_COLOR.b, 0.0)
	add_child(_overlay)


func is_busy() -> bool:
	return _busy


## 可选 content：切换前对当前场景根内容做轻微下沉淡出（主菜单 / 角色库等）。
func change_scene_to_file(scene_path: String, content: Control = null) -> void:
	if scene_path.is_empty():
		return
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if content != null and is_instance_valid(content):
		await _animate_content_out(content)
	await _fade_to(1.0, FADE_OUT_SECONDS, Tween.EASE_IN, Tween.TRANS_CUBIC)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: change_scene_to_file failed (%s): %s" % [str(err), scene_path])
		await _fade_to(0.0, FADE_IN_SECONDS, Tween.EASE_OUT, Tween.TRANS_CUBIC)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, FADE_IN_SECONDS, Tween.EASE_OUT, Tween.TRANS_CUBIC)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _animate_content_out(content: Control) -> void:
	if content == null or not is_instance_valid(content):
		return
	var start_y := content.position.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(content, "modulate:a", 0.0, 0.22)
	tween.tween_property(content, "position:y", start_y + 18.0, 0.22)
	await tween.finished


func _fade_to(alpha: float, duration: float, ease: Tween.EaseType, trans: Tween.TransitionType) -> void:
	if duration <= 0.0:
		_overlay.color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", alpha, duration).set_ease(ease).set_trans(trans)
	await tween.finished
