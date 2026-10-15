extends SceneTree
## 每个 Run 兵种（友方、敌方与召唤代理）都必须显式映射造型并解析到蓝 / 红两张贴图；
## 战场布局在不同宽高比下坐标可往返、棋盘不越出控件。

const UNIT_DIRS := [
	"res://resources/units/realtime",
	"res://resources/units/enemies",
	"res://resources/units/tokens",
]
const LAYOUT_SIZES := [Vector2(393, 852), Vector2(320, 852), Vector2(720, 1280), Vector2(1080, 1280)]

var _failures := 0


func _initialize() -> void:
	var catalog := UnitArtCatalog.load_default()
	_expect(catalog != null, "catalog loads from %s" % UnitArtCatalog.DEFAULT_PATH)
	if catalog == null:
		quit(1)
		return
	var checked := 0
	for dir_path in UNIT_DIRS:
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".tres"):
				continue
			var unit := load("%s/%s" % [dir_path, file]) as UnitData
			if unit == null:
				continue
			checked += 1
			var base_id := unit.id.trim_prefix(UnitArtCatalog.ENEMY_PREFIX)
			_expect(catalog.archetype_by_unit_id.has(base_id), "%s has explicit archetype" % unit.id)
			_expect(catalog.get_texture(unit.id, true) != null, "%s has player sprite" % unit.id)
			_expect(catalog.get_texture(unit.id, false) != null, "%s has enemy sprite" % unit.id)
	_expect(checked >= 40, "checked %d unit resources" % checked)
	_expect(catalog.get_archetype("enemy_knight") == catalog.get_archetype("knight"), "enemy_ prefix shares archetype")
	_expect(catalog.get_texture("unknown_unit", true) != null, "unknown id falls back to default sprite")
	_expect(
		catalog.get_texture("knight", true) != catalog.get_texture("knight", false),
		"player and enemy sprites differ",
	)
	_check_layout()
	if _failures == 0:
		print("UnitArtCatalogTest: all passed (%d units)" % checked)
	quit(0 if _failures == 0 else 1)


func _check_layout() -> void:
	var view := RealtimeArenaView.new()
	for view_size: Vector2 in LAYOUT_SIZES:
		view.size = view_size
		var rect := view.get_board_rect()
		var tag := "%dx%d" % [int(view_size.x), int(view_size.y)]
		_expect(rect.position.x >= 0.0 and rect.end.x <= view_size.x + 0.01, "%s board fits width" % tag)
		_expect(rect.position.y >= -0.01 and rect.end.y <= view_size.y + 0.01, "%s board fits height" % tag)
		for tile: Vector2 in [Vector2.ZERO, Vector2(4.5, 8.5), Vector2(8.99, 15.99)]:
			var back := view.local_to_tile(view.tile_to_local(tile))
			_expect(back.distance_to(tile) < 0.001, "%s tile %s round-trips" % [tag, tile])
	_expect(
		is_equal_approx(view.get_board_rect().get_center().x, 540.0),
		"board centered horizontally",
	)
	view.free()


func _expect(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		push_error("UnitArtCatalogTest: FAIL %s" % label)
