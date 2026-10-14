class_name DeckConfig
extends Resource

## Legacy single starter; ignored when starting_units is non-empty.
@export var starting_unit: UnitData
@export var starting_units: Array[UnitData] = []
@export_range(1, 40, 1) var starting_count: int = 10
@export_range(1, 40, 1) var max_size: int = 20
## Legacy population cap; unused under Features/PLAYER.md (no hard population).
@export_range(1, 20, 1) var max_board_units: int = 5
## Legacy prepare draw count; prefer hand_width for encounter card flow.
@export_range(1, 20, 1) var draw_count: int = 5
## 遭遇内手牌宽度（默认 4，见玩家篇）。
@export_range(1, 20, 1) var hand_width: int = 4
## 牌进入手牌时的冷却秒数（默认 1，见玩家篇）。
@export_range(0.0, 10.0, 0.05) var enter_hand_cooldown: float = 1.0
@export var level_config: LevelConfig


func get_starting_units() -> Array[UnitData]:
	if not starting_units.is_empty():
		return starting_units
	var legacy: Array[UnitData] = []
	if starting_unit != null:
		legacy.append(starting_unit)
	return legacy


func get_hand_width() -> int:
	return hand_width if hand_width > 0 else 4


func get_enter_hand_cooldown() -> float:
	return maxf(0.0, enter_hand_cooldown)
