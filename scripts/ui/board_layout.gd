class_name BoardLayout
extends RefCounted

## Portrait reference (iPhone 14 Pro logical).
## Clash Royale: playable tiles are an *inset* fenced field; bottom band is the card dock.
const VIEWPORT_WIDTH := 393
const VIEWPORT_HEIGHT := 852

## Bottom card dock share of screen height (CR hand + elixir ≈ 24–28%).
const HAND_DOCK_RATIO := 0.26
## Top chrome (status / name).
const TOP_CHROME_RATIO := 0.075
## Per-side inset so the tile field is narrower than the screen (CR fences / scenery).
const ARENA_SIDE_INSET_RATIO := 0.11

## Derived for the reference resolution (legacy int call sites).
const PLAY_MARGIN_TOP := 64
const PLAY_MARGIN_BOTTOM := 222
const PLAY_MARGIN_H := 86

const MIN_CELL_SIZE := 40
const MAX_CELL_SIZE := 68


static func hand_dock_height(viewport_height: float = VIEWPORT_HEIGHT) -> float:
	return maxf(176.0, viewport_height * HAND_DOCK_RATIO)


static func play_margin_top(viewport_height: float = VIEWPORT_HEIGHT) -> float:
	return maxf(48.0, viewport_height * TOP_CHROME_RATIO)


static func play_margin_bottom(viewport_height: float = VIEWPORT_HEIGHT) -> float:
	return hand_dock_height(viewport_height)


static func play_margin_h(viewport_width: float = VIEWPORT_WIDTH) -> float:
	return maxf(56.0, viewport_width * ARENA_SIDE_INSET_RATIO * 2.0)


static func compute_cell_size(
	grid: BoardGrid,
	viewport_size: Vector2 = Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT),
) -> int:
	if grid == null:
		return MIN_CELL_SIZE
	var size := grid.get_size()
	var available_w := viewport_size.x - play_margin_h(viewport_size.x)
	var available_h := (
		viewport_size.y
		- play_margin_top(viewport_size.y)
		- play_margin_bottom(viewport_size.y)
	)
	var from_w := available_w / maxi(1, size.x)
	var from_h := available_h / maxi(1, size.y)
	return clampi(mini(from_w, from_h), MIN_CELL_SIZE, MAX_CELL_SIZE)
