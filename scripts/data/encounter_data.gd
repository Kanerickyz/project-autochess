class_name EncounterData
extends Resource

@export var id: String = ""
@export var display_name: String = "遭遇战"
@export var wave: WaveData
@export_range(0, 32, 1) var board_width: int = 0
@export_range(0, 32, 1) var board_height: int = 0
@export var blocked_cells: Array[Vector2i] = []
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var bonus_gold: int = 0

@export_group("Terrain WFC")
## -1 = 继承 LevelData；0 = 关闭；1 = 开启
@export_enum("Inherit:-1", "Off:0", "On:1") var generate_terrain_override: int = -1
@export var terrain_tileset: TerrainTileset
## 0 = 继承关卡 / 局内 RNG；非 0 = 本遭遇固定种子
@export var terrain_seed: int = 0


func has_board_override() -> bool:
	return board_width > 0 and board_height > 0


func get_board_size(fallback: Vector2i) -> Vector2i:
	if has_board_override():
		return Vector2i(board_width, board_height)
	return fallback


func get_blocked_cells(fallback: Array[Vector2i]) -> Array[Vector2i]:
	if not blocked_cells.is_empty():
		return blocked_cells
	return fallback


func should_generate_terrain(level_default: bool) -> bool:
	if generate_terrain_override == 1:
		return true
	if generate_terrain_override == 0:
		return false
	return level_default


func resolve_terrain_tileset(fallback: TerrainTileset) -> TerrainTileset:
	if terrain_tileset != null:
		return terrain_tileset
	if fallback != null:
		return fallback
	return TerrainTileset.load_or_default()
