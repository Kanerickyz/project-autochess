class_name PreparePlacementController
extends RefCounted
## Tracks prepare-phase board drag gesture state for BoardController.

const DRAG_THRESHOLD := 8.0

var enabled: bool = false
var drag_press_pos: Vector2 = Vector2.ZERO
var drag_unit: UnitInstance
var drag_from_cell: Vector2i = Vector2i(-1, -1)
var drag_tracking: bool = false
var last_valid_drop_cell: Vector2i = Vector2i(-1, -1)


func reset_gesture() -> void:
	drag_tracking = false
	drag_unit = null
	drag_from_cell = Vector2i(-1, -1)
	last_valid_drop_cell = Vector2i(-1, -1)


func begin_tracking(unit: UnitInstance, from_cell: Vector2i, press_pos: Vector2) -> void:
	drag_tracking = true
	drag_unit = unit
	drag_from_cell = from_cell
	drag_press_pos = press_pos
	last_valid_drop_cell = from_cell


func should_promote_to_drag(motion_pos: Vector2) -> bool:
	if not drag_tracking or drag_unit == null:
		return false
	return motion_pos.distance_to(drag_press_pos) >= DRAG_THRESHOLD
