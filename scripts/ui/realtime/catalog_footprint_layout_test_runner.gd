extends SceneTree

const GHOST := "res://resources/units/realtime/ghost_graveyard.tres"
const KNIGHT := "res://resources/units/realtime/knight.tres"

var _failures: int = 0


func _initialize() -> void:
	_run()
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("CatalogFootprintLayoutTest: FAIL %s" % label)


func _run() -> void:
	var ghost := load(GHOST) as UnitData
	var knight := load(KNIGHT) as UnitData
	_expect(ghost != null and ghost.footprint_w >= 2, "ghost_graveyard 2-wide")
	var units: Array = [ghost, knight, knight]
	var layout := RealtimeArenaView.layout_catalog_cells_for_units(units, 5)
	_expect(layout.size() == 3, "layout keeps three entries")
	if layout.size() >= 1:
		var g: Dictionary = layout[0]
		_expect((g.get("cell") as Vector2i) == Vector2i(0, 0), "ghost at col0")
		_expect(g.get("source_index") == 0, "ghost source_index")
	if layout.size() >= 2:
		var k0: Dictionary = layout[1]
		_expect((k0.get("cell") as Vector2i) == Vector2i(2, 0), "knight0 skips col1 (ghost span)")
	if layout.size() >= 3:
		var k1: Dictionary = layout[2]
		_expect((k1.get("cell") as Vector2i) == Vector2i(3, 0), "knight1 at col3")
	var tile := RealtimeArenaView.new().footprint_center_tile(Vector2i(0, 0), ghost)
	_expect(is_equal_approx(tile.x, 1.0) and is_equal_approx(tile.y, 0.5), "draw center spans 2 cols")
	if _failures == 0:
		print("CatalogFootprintLayoutTest: all passed")