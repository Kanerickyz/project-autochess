class_name BoardLayout
extends RefCounted

## Portrait-first (iPhone 14 Pro logical 393×852). Clash Royale–style: thin top chrome, bottom card dock.
const VIEWPORT_WIDTH := 393
const VIEWPORT_HEIGHT := 852
const PLAY_MARGIN_H := 8
const PLAY_MARGIN_TOP := 52
const PLAY_MARGIN_BOTTOM := 196

const MIN_CELL_SIZE := 48
const MAX_CELL_SIZE := 96


static func compute_cell_size(
	grid: BoardGrid,
	viewport_size: Vector2 = Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT),
) -> int:
	if grid == null:
		return MIN_CELL_SIZE
	var size := grid.get_size()
	var available_w := viewport_size.x - PLAY_MARGIN_H
	var available_h := viewport_size.y - PLAY_MARGIN_TOP - PLAY_MARGIN_BOTTOM
	var from_w := available_w / maxi(1, size.x)
	var from_h := available_h / maxi(1, size.y)
	return clampi(mini(from_w, from_h), MIN_CELL_SIZE, MAX_CELL_SIZE)
