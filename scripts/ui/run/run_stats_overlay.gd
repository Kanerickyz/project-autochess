class_name RunStatsOverlay
extends Control

signal continue_pressed

const ROSTER_HINT := "长按查看技能 · 上下滑动浏览本页"
const ROSTER_COLUMNS := 5
const PEAK_COLUMNS := 3
## 统计条目标格边长；高度按行数匹配，避免「一行棋盘」把剪影撑满屏。
const CATALOG_CELL_TARGET_PX := 56.0
const CATALOG_STRIP_VISUAL_SCALE := 0.72

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _journey_grid: GridContainer = %JourneyGrid
@onready var _combat_grid: GridContainer = %CombatGrid
@onready var _roster_hint: Label = %RosterHint
@onready var _roster_arena: RealtimeArenaView = %RosterArena
@onready var _peak_attack_arena: RealtimeArenaView = %PeakAttackArena
@onready var _peak_hp_arena: RealtimeArenaView = %PeakHpArena
@onready var _continue_button: Button = %ContinueButton
@onready var _scroll: ScrollContainer = $Root/Column/Scroll


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	visible = false
	_style_panels()
	_configure_arena(_roster_arena)
	_configure_arena(_peak_attack_arena)
	_configure_arena(_peak_hp_arena)


func _style_panels() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.13, 0.18, 0.92)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.42, 0.36, 0.24, 0.85)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	for path in [
		"Root/Column/Scroll/Page/JourneyPanel",
		"Root/Column/Scroll/Page/CombatPanel",
		"Root/Column/Scroll/Page/RosterPanel",
		"Root/Column/Scroll/Page/PeakPanel",
	]:
		var panel := get_node_or_null(path) as PanelContainer
		if panel != null:
			panel.add_theme_stylebox_override("panel", style)


func show_snapshot(snapshot: RunStatsSnapshot) -> void:
	if snapshot == null:
		return
	_title.text = "远征统计"
	_subtitle.text = "远征完成" if snapshot.victory else "远征失败"
	_fill_metric_grid(_journey_grid, _journey_rows(snapshot))
	_fill_metric_grid(_combat_grid, _combat_rows(snapshot))
	if _roster_hint != null:
		_roster_hint.text = ROSTER_HINT
	_paint_roster(_roster_arena, snapshot.roster, ROSTER_COLUMNS)
	_paint_roster(_peak_attack_arena, snapshot.highest_attack_entries, PEAK_COLUMNS)
	_paint_roster(_peak_hp_arena, snapshot.highest_max_hp_entries, PEAK_COLUMNS)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	visible = true
	_continue_button.grab_focus()
	_fit_all_arenas.call_deferred()


func hide_overlay() -> void:
	visible = false
	_clear_arena(_roster_arena)
	_clear_arena(_peak_attack_arena)
	_clear_arena(_peak_hp_arena)


static func _journey_rows(snapshot: RunStatsSnapshot) -> Array:
	return [
		["战斗胜利", "%d 场" % snapshot.encounters_won],
		["造访商店", "%d 次" % snapshot.shop_visits],
		["战斗用时", _format_duration(snapshot.combat_seconds)],
		["剩余金币", "%d" % snapshot.gold],
	]


static func _combat_rows(snapshot: RunStatsSnapshot) -> Array:
	var ledger := snapshot.ledger
	return [
		["造成伤害", "%d" % ledger.sum_damage_dealt()],
		["恢复生命", "%d" % ledger.sum_healing_done()],
		["击杀单位", "%d" % ledger.sum_kills()],
		["召唤单位", "%d" % ledger.sum_summons()],
	]


static func _format_duration(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _fill_metric_grid(grid: GridContainer, rows: Array) -> void:
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	for row in rows:
		var label := String(row[0])
		var value := String(row[1])
		var name_l := Label.new()
		name_l.text = label
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.modulate = Color(0.78, 0.82, 0.88, 1.0)
		var value_l := Label.new()
		value_l.text = value
		value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_l.add_theme_font_size_override("font_size", 18)
		grid.add_child(name_l)
		grid.add_child(value_l)


static func _configure_arena(arena: RealtimeArenaView) -> void:
	if arena == null:
		return
	arena.mouse_filter = Control.MOUSE_FILTER_STOP
	arena.focus_mode = Control.FOCUS_NONE
	arena.catalog_visual_scale_override = CATALOG_STRIP_VISUAL_SCALE


static func _clear_arena(arena: RealtimeArenaView) -> void:
	if arena != null:
		arena.clear_catalog_mode()


func _paint_roster(arena: RealtimeArenaView, entries: Array[DeckEntry], columns: int) -> void:
	if arena == null:
		return
	arena.catalog_visual_scale_override = CATALOG_STRIP_VISUAL_SCALE
	if entries.is_empty():
		arena.clear_catalog_mode()
		arena.custom_minimum_size.y = CATALOG_CELL_TARGET_PX
		return
	var cols := maxi(1, columns)
	arena.set_catalog_deck_entries(entries, cols)
	_fit_catalog_arena(arena, entries.size(), cols)


func _fit_catalog_arena(arena: RealtimeArenaView, count: int, columns: int) -> void:
	if arena == null:
		return
	var cols := maxi(1, columns)
	var rows := maxi(1, int(ceili(float(maxi(1, count)) / float(cols))))
	var width := arena.size.x
	if width < 8.0:
		width = arena.get_parent_area_size().x if arena.get_parent() != null else 0.0
	var cell := CATALOG_CELL_TARGET_PX
	if width >= 8.0:
		cell = minf(CATALOG_CELL_TARGET_PX, width / float(cols))
	arena.custom_minimum_size.y = rows * cell + 4.0
	arena.queue_redraw()


func _fit_all_arenas() -> void:
	_fit_catalog_arena(
		_roster_arena,
		_roster_arena.catalog_units.size() if _roster_arena != null else 0,
		ROSTER_COLUMNS,
	)
	_fit_catalog_arena(
		_peak_attack_arena,
		_peak_attack_arena.catalog_units.size() if _peak_attack_arena != null else 0,
		PEAK_COLUMNS,
	)
	_fit_catalog_arena(
		_peak_hp_arena,
		_peak_hp_arena.catalog_units.size() if _peak_hp_arena != null else 0,
		PEAK_COLUMNS,
	)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
