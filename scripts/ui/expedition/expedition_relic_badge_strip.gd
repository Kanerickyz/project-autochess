class_name ExpeditionRelicBadgeStrip
extends HBoxContainer
## 远征行囊 6 槽圆形徽章条；监听 bag_changed；点击占用槽弹出只读详情。

const SLOT_COUNT := 6
const BADGE_DIAMETER := 32.0
const BADGE_GAP := 4.0

signal badge_pressed(slot_index: int, relic: ExpeditionRelicData)

var _bag: ExpeditionRelicBag = null
var _badges: Array[ExpeditionRelicBadge] = []
var _detail_popup: PopupPanel
var _detail_title: Label
var _detail_body: Label
var _detail_meta: Label


func _ready() -> void:
	add_theme_constant_override("separation", int(BADGE_GAP))
	alignment = BoxContainer.ALIGNMENT_END
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_ensure_badges()
	refresh()


func configure(bag: ExpeditionRelicBag) -> void:
	if _bag != null and _bag.bag_changed.is_connected(_on_bag_changed):
		_bag.bag_changed.disconnect(_on_bag_changed)
	_bag = bag
	if _bag != null and not _bag.bag_changed.is_connected(_on_bag_changed):
		_bag.bag_changed.connect(_on_bag_changed)
	refresh()


func get_bag() -> ExpeditionRelicBag:
	return _bag


func get_slot_count() -> int:
	_ensure_badges()
	return _badges.size()


func get_badge(slot_index: int) -> ExpeditionRelicBadge:
	_ensure_badges()
	if slot_index < 0 or slot_index >= _badges.size():
		return null
	return _badges[slot_index]


func get_occupied_count() -> int:
	_ensure_badges()
	var n := 0
	for b in _badges:
		if b != null and b.is_occupied():
			n += 1
	return n


func refresh() -> void:
	_ensure_badges()
	for i in SLOT_COUNT:
		var relic: ExpeditionRelicData = null
		if _bag != null:
			relic = _bag.get_at(i)
		_badges[i].configure(i, relic, BADGE_DIAMETER)


func show_relic_detail(relic: ExpeditionRelicData) -> void:
	if relic == null:
		return
	_ensure_detail_popup()
	if _detail_popup == null or _detail_title == null:
		return
	_detail_title.text = relic.display_name if not relic.display_name.is_empty() else "圣物"
	_detail_body.text = relic.description if not relic.description.is_empty() else "（无效果摘要）"
	_detail_meta.text = "Tier %d · 出售 %d 金" % [
		clampi(relic.tier, 1, 3),
		relic.resolve_sell_gold(),
	]
	_detail_popup.popup_centered(Vector2i(280, 160))


## 关闭详情浮层；可被地图罩层 / 外部调用，避免 root 残留 Popup。
func hide_detail() -> void:
	if _detail_popup != null and is_instance_valid(_detail_popup):
		_detail_popup.hide()
		_detail_popup.queue_free()
	_detail_popup = null
	_detail_title = null
	_detail_body = null
	_detail_meta = null


func has_detail_popup() -> bool:
	return _detail_popup != null and is_instance_valid(_detail_popup)


func get_detail_title_text() -> String:
	if _detail_title == null or not is_instance_valid(_detail_title):
		return ""
	return _detail_title.text


func get_detail_body_text() -> String:
	if _detail_body == null or not is_instance_valid(_detail_body):
		return ""
	return _detail_body.text


func _ensure_badges() -> void:
	if _badges.size() == SLOT_COUNT:
		return
	for child in get_children():
		if child is ExpeditionRelicBadge:
			child.queue_free()
	_badges.clear()
	for i in SLOT_COUNT:
		var badge := ExpeditionRelicBadge.new()
		badge.name = "RelicBadge%d" % i
		badge.configure(i, null, BADGE_DIAMETER)
		badge.pressed.connect(_on_badge_pressed)
		add_child(badge)
		_badges.append(badge)


func _ensure_detail_popup() -> void:
	if _detail_popup != null and is_instance_valid(_detail_popup):
		return
	if not is_inside_tree():
		return
	_detail_popup = PopupPanel.new()
	_detail_popup.name = "RelicDetailPopup"
	_detail_popup.exclusive = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_detail_popup.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	_detail_title = Label.new()
	_detail_title.name = "Title"
	_detail_title.add_theme_font_size_override("font_size", 16)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_title)
	_detail_body = Label.new()
	_detail_body.name = "Body"
	_detail_body.add_theme_font_size_override("font_size", 13)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_detail_body)
	_detail_meta = Label.new()
	_detail_meta.name = "Meta"
	_detail_meta.add_theme_font_size_override("font_size", 12)
	_detail_meta.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55, 1.0))
	box.add_child(_detail_meta)
	## 挂到场景树顶层，避免被 Dock 裁剪。
	get_tree().root.add_child(_detail_popup)


func _on_bag_changed() -> void:
	refresh()


func _on_badge_pressed(slot_index: int, relic: ExpeditionRelicData) -> void:
	badge_pressed.emit(slot_index, relic)
	show_relic_detail(relic)


func _exit_tree() -> void:
	if _bag != null and _bag.bag_changed.is_connected(_on_bag_changed):
		_bag.bag_changed.disconnect(_on_bag_changed)
	hide_detail()
