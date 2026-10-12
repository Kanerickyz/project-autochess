class_name BoardTheme
extends RefCounted

enum CellHighlight { NONE, HOVER, PLACEABLE, HOVER_PLACEABLE, INVALID, ATTACK, ATTACK_RANGE }

const DEFAULT_CONFIG_PATH := "res://resources/ui/default_board_theme.tres"

static var _config: BoardThemeConfig


static func get_config() -> BoardThemeConfig:
	if _config == null:
		set_config(null)
	return _config


static func set_config(config: BoardThemeConfig) -> void:
	if config != null:
		_config = config
		return
	var loaded := load(DEFAULT_CONFIG_PATH)
	_config = loaded as BoardThemeConfig if loaded != null else BoardThemeConfig.new()


static func is_light_square(cell: Vector2i) -> bool:
	return (cell.x + cell.y) % 2 == 0


static func get_base_color(cell: Vector2i, blocked: bool, board_height: int = -1) -> Color:
	var theme := get_config()
	if blocked:
		return theme.color_blocked
	var color := theme.color_light if is_light_square(cell) else theme.color_dark
	return _tint_half_field(color, cell, board_height)


static func get_terrain_color(
	cell: Vector2i,
	terrain: TerrainType.Type,
	blocked: bool,
	board_height: int = -1,
) -> Color:
	var theme := get_config()
	var color: Color
	match terrain:
		TerrainType.Type.GRASS:
			color = theme.color_grass_light if is_light_square(cell) else theme.color_grass_dark
		TerrainType.Type.JUNGLE:
			color = theme.color_jungle
		TerrainType.Type.LAKE:
			color = theme.color_lake
		TerrainType.Type.SHORE:
			color = theme.color_shore
		TerrainType.Type.ROCK:
			color = theme.color_rock
		TerrainType.Type.DENSE_JUNGLE:
			color = theme.color_dense_jungle
		_:
			return get_base_color(cell, blocked, board_height)
	return _tint_half_field(color, cell, board_height)


static func _tint_half_field(color: Color, cell: Vector2i, board_height: int) -> Color:
	if board_height <= 0:
		return color
	# Clash Royale–style read: red-leaning enemy (top), green player (bottom), soft midline band.
	var mid := BoardHalf.midline_row(board_height)
	if cell.y == mid - 1 or cell.y == mid:
		return color.lerp(Color(0.22, 0.42, 0.72, 1.0), 0.28)
	if BoardHalf.is_enemy_spawn_cell(cell, board_height):
		return color.lerp(Color(0.72, 0.42, 0.36, 1.0), 0.20)
	return color.lerp(Color(0.42, 0.68, 0.36, 1.0), 0.18)


static func get_border_color(cell: Vector2i, blocked: bool) -> Color:
	var theme := get_config()
	if blocked:
		return theme.color_blocked.darkened(theme.blocked_border_darken_amount)
	var base := get_base_color(cell, false)
	return base.darkened(theme.border_darken_amount)


static func get_blocked_modulate() -> Color:
	return get_config().blocked_modulate


static func apply_highlight(base: Color, highlight: CellHighlight) -> Color:
	var theme := get_config()
	match highlight:
		CellHighlight.HOVER:
			return base.lerp(theme.color_hover_tint, theme.color_hover_tint.a)
		CellHighlight.PLACEABLE:
			return base.lerp(theme.color_placeable_tint, theme.color_placeable_tint.a)
		CellHighlight.HOVER_PLACEABLE:
			var with_place := base.lerp(theme.color_placeable_tint, theme.color_placeable_tint.a)
			return with_place.lerp(theme.color_hover_tint, theme.color_hover_tint.a * 0.6)
		CellHighlight.INVALID:
			return base.lerp(theme.color_invalid_tint, theme.color_invalid_tint.a)
		CellHighlight.ATTACK:
			return base.lerp(theme.color_attack_tint, theme.color_attack_tint.a)
		CellHighlight.ATTACK_RANGE:
			return base.lerp(theme.color_attack_range_tint, theme.color_attack_range_tint.a)
	return base


static func apply_burn_overlay(base: Color) -> Color:
	var theme := get_config()
	return base.lerp(theme.color_burn_overlay, theme.burn_overlay_strength)
