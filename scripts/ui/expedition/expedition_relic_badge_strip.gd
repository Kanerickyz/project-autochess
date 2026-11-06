class_name ExpeditionRelicBadgeStrip
extends HBoxContainer
## 远征行囊 6 槽圆形徽章条；监听 bag_changed；长按占用槽 → 统一信息卡（由战斗壳接线）。

const SLOT_COUNT := 6
const BADGE_DIAMETER := 32.0
const BADGE_GAP := 4.0

signal badge_pressed(slot_index: int, relic: ExpeditionRelicData)
signal badge_long_press(slot_index: int, relic: ExpeditionRelicData)
signal badge_long_press_ended(slot_index: int, relic: ExpeditionRelicData)

var _bag: ExpeditionRelicBag = null
var _badges: Array[ExpeditionRelicBadge] = []
## 详情已改走 Arena RealtimeUnitInfoCard；保留回调兼容旧 hide_detail 调用点。
var _detail_visible: bool = false
var _detail_relic: ExpeditionRelicData = null


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


## 兼容旧 API：仅标记详情状态（真正展示走 badge_long_press → Arena 信息卡）。
func show_relic_detail(relic: ExpeditionRelicData) -> void:
	if relic == null:
		return
	_detail_visible = true
	_detail_relic = relic


## 关闭详情；地图罩层 / 外部调用。
func hide_detail() -> void:
	_detail_visible = false
	_detail_relic = null


func has_detail_popup() -> bool:
	## 旧 Popup 已移除；用「详情打开中」语义兼容测试/调用方。
	return _detail_visible


func get_detail_title_text() -> String:
	if _detail_relic == null:
		return ""
	return _detail_relic.display_name if not _detail_relic.display_name.is_empty() else "圣物"


func get_detail_body_text() -> String:
	if _detail_relic == null:
		return ""
	return ExpeditionRelicInfo.detail_text(_detail_relic)


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
		badge.long_press.connect(_on_badge_long_press)
		badge.long_press_ended.connect(_on_badge_long_press_ended)
		add_child(badge)
		_badges.append(badge)


func _on_bag_changed() -> void:
	refresh()


func _on_badge_pressed(slot_index: int, relic: ExpeditionRelicData) -> void:
	badge_pressed.emit(slot_index, relic)


func _on_badge_long_press(slot_index: int, relic: ExpeditionRelicData) -> void:
	_detail_visible = true
	_detail_relic = relic
	badge_long_press.emit(slot_index, relic)


func _on_badge_long_press_ended(slot_index: int, relic: ExpeditionRelicData) -> void:
	_detail_visible = false
	_detail_relic = null
	badge_long_press_ended.emit(slot_index, relic)


func _exit_tree() -> void:
	if _bag != null and _bag.bag_changed.is_connected(_on_bag_changed):
		_bag.bag_changed.disconnect(_on_bag_changed)
	hide_detail()
