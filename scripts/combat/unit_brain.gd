class_name UnitBrain
extends RefCounted

const _GridLine := preload("res://scripts/combat/grid_line.gd")

enum ActionType { IDLE, MOVE, ATTACK, LINE_ATTACK, BUMP }


class CombatAction:
	var type: ActionType = ActionType.IDLE
	var move_to: Vector2i = Vector2i.ZERO
	var move_path: Array[Vector2i] = []
	var attack_target: UnitInstance
	var line_axis: int = -1
	var bump_from: Vector2i = Vector2i.ZERO
	var bump_to: Vector2i = Vector2i.ZERO


static func decide(grid: BoardGrid, unit: UnitInstance) -> CombatAction:
	var action := CombatAction.new()
	if unit == null or not unit.is_alive():
		return action

	grid.sync_unit_grid_pos(unit)
	var unit_cell := grid.find_cell_of(unit)
	if unit_cell == Vector2i(-1, -1):
		return action

	if unit.uses_line_attack():
		var axis := _GridLine.pick_best_axis(grid, unit_cell, unit.team)
		if axis >= 0:
			action.type = ActionType.LINE_ATTACK
			action.line_axis = axis
			return action

	var enemy := grid.find_nearest_enemy(unit_cell, unit.team)
	if enemy == null:
		return action

	var dist := grid.combat_distance(unit_cell, grid.find_cell_of(enemy))
	if unit.can_perform_normal_attack() and dist <= unit.get_attack_range():
		action.type = ActionType.ATTACK
		action.attack_target = enemy
		return action

	if not unit.cannot_move:
		var enemy_cell := grid.find_cell_of(enemy)
		var move_path := GridMovement.plan_move_path(
			grid,
			unit_cell,
			enemy_cell,
			unit.get_movement_pattern(),
			unit.get_steps_per_turn(),
		)
		if not move_path.is_empty():
			action.type = ActionType.MOVE
			action.move_path = move_path
			action.move_to = move_path[move_path.size() - 1]
			return action

		var bump := _try_bump_action(grid, unit, unit_cell, enemy, enemy_cell)
		if bump != null:
			return bump

	return action


static func _try_bump_action(
	grid: BoardGrid,
	unit: UnitInstance,
	unit_cell: Vector2i,
	enemy: UnitInstance,
	enemy_cell: Vector2i,
) -> CombatAction:
	if not unit.can_move_ahead_damage():
		return null
	var delta := enemy_cell - unit_cell
	if absi(delta.x) + absi(delta.y) != 1:
		return null
	if enemy == null or not enemy.is_alive() or enemy.team == unit.team:
		return null
	if not grid.is_occupied(enemy_cell):
		return null
	var action := CombatAction.new()
	action.type = ActionType.BUMP
	action.bump_from = unit_cell - delta
	action.bump_to = unit_cell
	return action
