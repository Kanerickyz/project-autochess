class_name DeckConfig
extends Resource

const DEFAULT_HAND_WIDTH := 4
const DEFAULT_DEPLOY_CAP := 4
const DEFAULT_SEAT_ROWS := 2
const DEFAULT_SEAT_COLS := 5

## Legacy single starter; ignored when starting_units is non-empty.
@export var starting_unit: UnitData
@export var starting_units: Array[UnitData] = []
@export_range(1, 40, 1) var starting_count: int = 10
@export_range(1, 40, 1) var max_size: int = 20
## 本场上场人数上限（deploy_cap；空座可保留，不等于座位数）。
@export_range(1, 20, 1) var max_board_units: int = DEFAULT_DEPLOY_CAP
## Legacy prepare draw count; prefer hand_width for encounter card flow.
@export_range(1, 20, 1) var draw_count: int = DEFAULT_HAND_WIDTH
## 遭遇准备阶段手牌宽度（默认与上场人数上限同值；不要求大于座位数）。
@export_range(1, 20, 1) var hand_width: int = DEFAULT_HAND_WIDTH
## 友方/敌方角色座位行数（默认 2；前排近中线、后排靠己方底）。
@export_range(1, 4, 1) var seat_rows: int = DEFAULT_SEAT_ROWS
## 友方/敌方角色座位列数（默认 5）。
@export_range(1, 10, 1) var seat_cols: int = DEFAULT_SEAT_COLS
## Legacy 座位总数；优先用 seat_rows × seat_cols。保留以便旧 .tres 可读。
@export_range(0, 20, 1) var slot_count: int = 0
## 准备阶段刷新未入槽手牌的次数上限（默认 3；免费）。
@export_range(0, 10, 1) var max_refresh: int = 3
## 牌进入手牌时的冷却秒数（准备入槽不依赖冷却；默认 0）。
@export_range(0.0, 10.0, 0.05) var enter_hand_cooldown: float = 0.0
@export var level_config: LevelConfig


func get_starting_units() -> Array[UnitData]:
	if not starting_units.is_empty():
		return starting_units
	var legacy: Array[UnitData] = []
	if starting_unit != null:
		legacy.append(starting_unit)
	return legacy


func get_hand_width() -> int:
	return hand_width if hand_width > 0 else DEFAULT_HAND_WIDTH


## 本场上场人数上限（语义：deploy_cap，非人口成长条）。
func get_deploy_cap() -> int:
	return max_board_units if max_board_units > 0 else DEFAULT_DEPLOY_CAP


func get_seat_rows() -> int:
	return seat_rows if seat_rows > 0 else DEFAULT_SEAT_ROWS


func get_seat_cols() -> int:
	return seat_cols if seat_cols > 0 else DEFAULT_SEAT_COLS


## 单侧座位总数（默认 2×5=10）。旧 slot_count 仅作兼容回退。
func get_slot_count() -> int:
	var from_grid := get_seat_rows() * get_seat_cols()
	if from_grid > 0:
		return from_grid
	return slot_count if slot_count > 0 else DEFAULT_SEAT_ROWS * DEFAULT_SEAT_COLS


func get_max_refresh() -> int:
	return maxi(0, max_refresh)


func get_enter_hand_cooldown() -> float:
	return maxf(0.0, enter_hand_cooldown)
