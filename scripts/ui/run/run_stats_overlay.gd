class_name RunStatsOverlay
extends Control

signal continue_pressed

@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _stats: Label = %StatsLabel
@onready var _roster_arena: RealtimeArenaView = %RosterArena
@onready var _peak_attack_arena: RealtimeArenaView = %PeakAttackArena
@onready var _peak_hp_arena: RealtimeArenaView = %PeakHpArena
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	visible = false


func show_snapshot(snapshot: RunStatsSnapshot) -> void:
	if snapshot == null:
		return
	_title.text = "远征统计"
	_subtitle.text = "远征完成" if snapshot.victory else "远征失败"
	_stats.text = _format_stats_block(snapshot)
	_paint_roster(_roster_arena, snapshot.roster)
	_paint_roster(_peak_attack_arena, snapshot.highest_attack_entries)
	_paint_roster(_peak_hp_arena, snapshot.highest_max_hp_entries)
	visible = true
	_continue_button.grab_focus()


func hide_overlay() -> void:
	visible = false
	if _roster_arena != null:
		_roster_arena.clear_catalog_mode()
	if _peak_attack_arena != null:
		_peak_attack_arena.clear_catalog_mode()
	if _peak_hp_arena != null:
		_peak_hp_arena.clear_catalog_mode()


func _format_stats_block(snapshot: RunStatsSnapshot) -> String:
	var ledger := snapshot.ledger
	var lines: PackedStringArray = []
	lines.append("战斗胜利：%d 场" % snapshot.encounters_won)
	lines.append("造访商店：%d 次" % snapshot.shop_visits)
	lines.append("战斗用时：%s" % _format_duration(snapshot.combat_seconds))
	lines.append("剩余金币：%d" % snapshot.gold)
	lines.append("造成伤害：%d" % ledger.sum_damage_dealt())
	lines.append("恢复生命：%d" % ledger.sum_healing_done())
	lines.append("击杀单位：%d" % ledger.sum_kills())
	lines.append("召唤单位：%d" % ledger.sum_summons())
	return "\n".join(lines)


static func _format_duration(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


static func _paint_roster(arena: RealtimeArenaView, entries: Array[DeckEntry]) -> void:
	if arena == null:
		return
	if entries.is_empty():
		arena.clear_catalog_mode()
		return
	var cols := maxi(1, entries.size())
	arena.set_catalog_deck_entries(entries, cols)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
