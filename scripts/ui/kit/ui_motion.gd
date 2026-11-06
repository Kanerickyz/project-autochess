class_name UiMotion
extends RefCounted
## 全项目共用的短反馈 Tween 参数（apple-hig §5.3）。
## 表现层专用；勿写入 EffectResolver。

const PRESS_SCALE := 0.97
const PRESS_SEC := 0.06
const RELEASE_SEC := 0.10
const PANEL_FADE_SEC := 0.18
const PANEL_SLIDE_PX := 18.0
const ERROR_SHAKE_PX := 6.0
const ERROR_SHAKE_SEC := 0.08


static func tween_press(control: Control) -> Tween:
	if control == null:
		return null
	control.pivot_offset = control.size * 0.5
	var tw := control.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(control, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), PRESS_SEC)
	return tw


static func tween_release(control: Control) -> Tween:
	if control == null:
		return null
	control.pivot_offset = control.size * 0.5
	var tw := control.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(control, "scale", Vector2.ONE, RELEASE_SEC)
	return tw


static func tween_panel_show(control: Control, from_below: bool = true) -> Tween:
	if control == null:
		return null
	control.modulate.a = 0.0
	var start_y := control.position.y + (PANEL_SLIDE_PX if from_below else -PANEL_SLIDE_PX)
	var end_y := control.position.y
	control.position.y = start_y
	var tw := control.create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(control, "modulate:a", 1.0, PANEL_FADE_SEC)
	tw.tween_property(control, "position:y", end_y, PANEL_FADE_SEC)
	return tw


static func tween_panel_hide(control: Control, downward: bool = true) -> Tween:
	if control == null:
		return null
	var end_y := control.position.y + (PANEL_SLIDE_PX if downward else -PANEL_SLIDE_PX)
	var tw := control.create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(control, "modulate:a", 0.0, PANEL_FADE_SEC)
	tw.tween_property(control, "position:y", end_y, PANEL_FADE_SEC)
	return tw
