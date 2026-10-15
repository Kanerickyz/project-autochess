extends SceneTree
## 每个 Run 兵种（友方与敌方资源）都必须解析到蓝 / 红两张贴图。

const UNIT_DIRS := ["res://resources/units/realtime", "res://resources/units/enemies"]

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
			_expect(catalog.get_texture(unit.id, true) != null, "%s has player sprite" % unit.id)
			_expect(catalog.get_texture(unit.id, false) != null, "%s has enemy sprite" % unit.id)
	_expect(checked >= 30, "checked %d unit resources" % checked)
	_expect(catalog.get_archetype("enemy_knight") == catalog.get_archetype("knight"), "enemy_ prefix shares archetype")
	_expect(catalog.get_texture("unknown_unit", true) != null, "unknown id falls back to default sprite")
	_expect(
		catalog.get_texture("knight", true) != catalog.get_texture("knight", false),
		"player and enemy sprites differ",
	)
	if _failures == 0:
		print("UnitArtCatalogTest: all passed (%d units)" % checked)
	quit(0 if _failures == 0 else 1)


func _expect(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		push_error("UnitArtCatalogTest: FAIL %s" % label)
