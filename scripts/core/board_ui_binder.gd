class_name BoardUiBinder
extends RefCounted
## Status label, HUD gold, and tooltip helpers for BoardController.

var status_label: Label
var player_hud: PlayerHUD
var unit_tooltip: UnitTooltip


func configure(
	p_status_label: Label,
	p_player_hud: PlayerHUD,
	p_tooltip: UnitTooltip,
) -> void:
	status_label = p_status_label
	player_hud = p_player_hud
	unit_tooltip = p_tooltip


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func set_gold(amount: int) -> void:
	if player_hud != null:
		player_hud.set_gold(amount)


func hide_tooltip() -> void:
	if unit_tooltip != null:
		unit_tooltip.hide_tooltip()


func show_unit(unit: UnitInstance, screen_pos: Vector2) -> void:
	if unit_tooltip != null:
		unit_tooltip.show_unit(unit, screen_pos)


func show_deck_entry(
	entry: DeckEntry,
	screen_pos: Vector2,
	level_config: LevelConfig,
) -> void:
	if unit_tooltip != null:
		unit_tooltip.show_deck_entry(entry, screen_pos, level_config)
