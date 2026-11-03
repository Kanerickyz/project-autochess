class_name ThemeBondCatalog
extends Resource
## 八主题羁绊表；默认从 resources/theme_bonds/default_theme_bonds.tres 加载。

const DEFAULT_PATH := "res://resources/theme_bonds/default_theme_bonds.tres"

@export var bonds: Array[ThemeBondDef] = []


static func load_default() -> ThemeBondCatalog:
	var loaded := load(DEFAULT_PATH)
	if loaded is ThemeBondCatalog:
		return loaded as ThemeBondCatalog
	push_warning("ThemeBondCatalog: missing or invalid %s" % DEFAULT_PATH)
	return ThemeBondCatalog.new()


func get_bond(theme_id: StringName) -> ThemeBondDef:
	for bond in bonds:
		if bond != null and bond.theme_id == theme_id:
			return bond
	return null


func all_theme_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for bond in bonds:
		if bond != null and bond.theme_id != &"":
			out.append(bond.theme_id)
	return out
