class_name TierUnlockToast
extends PanelContainer

const SHOW_SEC := 2.0
const FADE_SEC := 0.28

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel

var _active_tween: Tween


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func show_unlock(tier: int) -> void:
	if tier <= 1:
		return
	if _title_label == null:
		_title_label = get_node_or_null("%TitleLabel") as Label
	if _subtitle_label == null:
		_subtitle_label = get_node_or_null("%SubtitleLabel") as Label
	if _title_label != null:
		_title_label.text = "T%d 角色已解锁" % tier
	if _subtitle_label != null:
		_subtitle_label.text = "本层起招募可抽到 T%d 角色" % tier
	_kill_tween()
	visible = true
	modulate.a = 0.0
	call_deferred("_play_show_animation")


func _play_show_animation() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.94, 0.94)
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "modulate:a", 1.0, FADE_SEC)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_active_tween.tween_property(self, "scale", Vector2.ONE, FADE_SEC)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_active_tween.chain().tween_interval(SHOW_SEC)
	_active_tween.chain().tween_property(self, "modulate:a", 0.0, FADE_SEC)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_active_tween.chain().tween_callback(_on_hide_finished)


func hide_immediately() -> void:
	_kill_tween()
	visible = false
	modulate.a = 0.0
	scale = Vector2.ONE


func _on_hide_finished() -> void:
	visible = false
	modulate.a = 0.0
	scale = Vector2.ONE


func _kill_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
