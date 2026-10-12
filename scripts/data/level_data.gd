class_name LevelData
extends Resource

## 棋盘横向格子数（列）
@export_range(1, 32, 1) var board_width: int = 6
## 棋盘纵向格子数（行）
@export_range(1, 32, 1) var board_height: int = 6
@export var blocked_cells: Array[Vector2i] = []
## 线性开发关波次表；爬塔 Run 模式请改用 EncounterData 池
@export var waves: Array[WaveData] = []
## Optional enemy spawn pool (decoupled from shop). Empty → fall back to ShopPoolConfig.
@export var enemy_pool: Array[UnitData] = []

@export_group("Terrain WFC")
## 为 true 时用 WFC 生成地形（覆盖 blocked_cells）
@export var generate_terrain: bool = false
@export var terrain_tileset: TerrainTileset
## 0 = 使用局内 RNG；非 0 = 固定种子可复现
@export var terrain_seed: int = 0


func get_board_size() -> Vector2i:
	return Vector2i(
		maxi(1, board_width),
		maxi(1, board_height),
	)


func resolve_terrain_tileset() -> TerrainTileset:
	if terrain_tileset != null:
		return terrain_tileset
	return TerrainTileset.load_or_default()
