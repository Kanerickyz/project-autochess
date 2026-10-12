class_name BoardHalf
extends RefCounted
## Hard half-field helpers for combat levels (COMBATLEVEL).
## Player deploy = bottom rows (higher y, nearer camera at yaw 0).
## Enemy spawn = top rows (lower y). Midline is a row boundary only.


static func midline_row(height: int) -> int:
	return maxi(0, height / 2)


static func is_player_deploy_cell(cell: Vector2i, height: int) -> bool:
	return cell.y >= midline_row(height)


static func is_enemy_spawn_cell(cell: Vector2i, height: int) -> bool:
	return cell.y < midline_row(height)


static func filter_cells(
	cells: Array[Vector2i],
	height: int,
	for_player: bool,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		if for_player:
			if is_player_deploy_cell(cell, height):
				out.append(cell)
		elif is_enemy_spawn_cell(cell, height):
			out.append(cell)
	return out
