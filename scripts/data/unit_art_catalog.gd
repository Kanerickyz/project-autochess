class_name UnitArtCatalog
extends Resource
## Run 战场角色贴图：兵种 id → 贴图键 → 我方 / 敌方贴图。
## 主兵种各占一个贴图键；召唤代理可借用来源兵种的贴图键。
## 敌方资源 id 带 `enemy_` 前缀，查表前去掉，与友方共用贴图。

const DEFAULT_PATH := "res://resources/ui/paper_unit_art.tres"
const ENEMY_PREFIX := "enemy_"

## String(unit id) → StringName(贴图键)
@export var archetype_by_unit_id: Dictionary = {}
## 未登记的 id 落到这个贴图键，保证场上不出现无图单位。
@export var default_archetype: StringName = &"spear"
## StringName(贴图键) → Texture2D
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
