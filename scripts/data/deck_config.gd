class_name DeckConfig
extends Resource

## Legacy single starter; ignored when starting_units is non-empty.
@export var starting_unit: UnitData
@export var starting_units: Array[UnitData] = []
@export_range(1, 40, 1) var starting_count: int = 10
@export_range(1, 40, 1) var max_size: int = 20
@export_range(1, 20, 1) var max_board_units: int = 5
## Cards drawn into the per-wave hand on PREPARE (without replacement from constructed deck).
@export_range(1, 20, 1) var draw_count: int = 5
@export var level_config: LevelConfig


func get_starting_units() -> Array[UnitData]:
	if not starting_units.is_empty():
		return starting_units
	var legacy: Array[UnitData] = []
	if starting_unit != null:
		legacy.append(starting_unit)
	return legacy
