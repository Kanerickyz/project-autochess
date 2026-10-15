class_name UnitArtCatalog
extends Resource
## Run 战场角色贴图：兵种 id → 造型 → 我方 / 敌方贴图。
## 敌方资源 id 带 `enemy_` 前缀，查表前去掉，与友方共用造型。

const DEFAULT_PATH := "res://resources/ui/paper_unit_art.tres"
const ENEMY_PREFIX := "enemy_"

## String(unit id) → StringName(archetype)
@export var archetype_by_unit_id: Dictionary = {}
## 未登记的 id 落到这个造型，保证场上不出现无图单位。
@export var default_archetype: StringName = &"spear"
## StringName(archetype) → Texture2D
@export var player_textures: Dictionary = {}
@export var enemy_textures: Dictionary = {}

static var _cached: UnitArtCatalog


static func load_default() -> UnitArtCatalog:
	if _cached == null and ResourceLoader.exists(DEFAULT_PATH):
		_cached = load(DEFAULT_PATH) as UnitArtCatalog
	return _cached


func get_archetype(unit_id: String) -> StringName:
	var id := unit_id.trim_prefix(ENEMY_PREFIX)
	if archetype_by_unit_id.has(id):
		return StringName(archetype_by_unit_id[id])
	return default_archetype


func get_texture(unit_id: String, is_player: bool) -> Texture2D:
	var table := player_textures if is_player else enemy_textures
	return table.get(get_archetype(unit_id)) as Texture2D
