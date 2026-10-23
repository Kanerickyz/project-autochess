class_name EffectResolver
extends RefCounted

const MAX_CHAIN_DEPTH := 12

var _grid: BoardGrid
var _bus: CombatEventBus
var _pipeline: DamagePipeline
var _rng: RandomNumberGenerator
var _pending_batches: Array[QueuedEffectBatch] = []
var _friend_hurt_this_round: int = 0
var _deck_state: DeckState
var _economy: RunEconomy
## owner.instance_id -> { EffectSpec.get_instance_id(): count }
var _spec_trigger_counts: Dictionary = {}
## 技能 DEAL_DAMAGE 执行期间抑制 OnDealDamage 再入队，避免捎带伤连环刷触发。
var _suppress_deal_damage_triggers: int = 0


func _init(
	grid: BoardGrid,
	bus: CombatEventBus,
	pipeline: DamagePipeline = null,
	rng: RandomNumberGenerator = null,
) -> void:
	_grid = grid
	_bus = bus
	_pipeline = pipeline
	_rng = rng
	if _pipeline != null:
		_pipeline.set_effect_resolver(self)


func set_deck_state(deck_state: DeckState) -> void:
	_deck_state = deck_state


func set_economy(economy: RunEconomy) -> void:
	_economy = economy


func on_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if _bus == null or _grid == null:
		return
	if event_type == CombatEvents.ON_ATTACK_HIT:
		return
	if (
		event_type == CombatEvents.ON_DEAL_DAMAGE
		and _suppress_deal_damage_triggers > 0
	):
		return
	if event_type == CombatEvents.ON_COMBAT_START:
		_spec_trigger_counts.clear()
	if event_type == CombatEvents.ON_ROUND_START:
		_friend_hurt_this_round = 0
	if event_type == CombatEvents.ON_DAMAGE_TAKEN:
		if payload.target != null and payload.target.team == UnitInstance.Team.PLAYER:
			_friend_hurt_this_round += 1
	var start_depth := 0
	if payload != null:
		start_depth = maxi(0, payload.chain_depth)
	_enqueue_for_event(event_type, payload, start_depth)


func has_pending_steps() -> bool:
	return not _pending_batches.is_empty()


## 只读队首批次（用于结算前展示角色+技能介绍卡）；不弹出。
func peek_next_batch() -> QueuedEffectBatch:
	if _pending_batches.is_empty():
		return null
	return _pending_batches[0]


func process_next_step() -> bool:
	if _pending_batches.is_empty():
		return false
	var batch: QueuedEffectBatch = _pending_batches.pop_front()
	var executed: Array = []
	for entry in batch.entries:
		var action: EffectAction = entry.action
		var target: UnitInstance = entry.target
		if action == null:
			continue
		if action.action_type == EffectAction.Type.SPLIT_SELF:
			var split_entries := _split_self(
				batch.owner,
				action,
				batch.payload,
				batch.depth,
			)
			if not split_entries.is_empty():
				executed.append_array(split_entries)
			continue
		if action.action_type == EffectAction.Type.FUSE_EXPLODE:
			var fuse_entries := _execute_fuse_explode_batch(
				batch.owner,
				action,
				batch.payload,
				batch.depth,
				batch.spec,
			)
			if not fuse_entries.is_empty():
				executed.append_array(fuse_entries)
			continue
		if _execute_action(
			action,
			target,
			batch.payload,
			batch.depth,
			batch.owner,
			batch.spec,
			false,
		):
			# Payload / presentation still consume Dictionary entries.
			executed.append({"action": action, "target": target})
	if not executed.is_empty():
		_emit_effect_batch_resolved(batch, executed)
	return true


func clear_pending() -> void:
	_pending_batches.clear()


func _enqueue_for_event(
	event_type: StringName,
	payload: CombatEventPayload,
	depth: int,
) -> void:
	if depth >= MAX_CHAIN_DEPTH:
		return

	var listeners := _collect_listener_units(payload)
	for unit in listeners:
		if not _owner_qualifies_for_event(unit, event_type, payload):
			continue
		for spec in _get_effect_specs(unit):
			if not _spec_trigger_matches(spec, event_type):
				continue
			if not _spec_condition_met(spec, unit, payload):
				continue
			if not _spec_under_trigger_cap(unit, spec):
				continue
			if _spec_uses_cell_targets(spec):
				var applied_cell := false
				for action in spec.actions:
					if action.action_type == EffectAction.Type.APPLY_CELL_EFFECT:
						_apply_cell_effect(action, spec, unit, payload)
						applied_cell = true
				if applied_cell:
					_record_spec_trigger(unit, spec)
				continue
			var targets := _resolve_targets(spec, unit, payload)
			var batch := QueuedEffectBatch.new()
			batch.owner = unit
			batch.spec = spec
			batch.payload = payload
			batch.depth = depth
			for target in targets:
				if target == null:
					continue
				for action in spec.actions:
					if action == null:
						continue
					var step := QueuedEffectStep.new()
					step.action = action
					step.target = target
					step.owner = unit
					step.spec = spec
					step.payload = payload
					step.depth = depth
					batch.entries.append(step)
			if not batch.entries.is_empty():
				_pending_batches.append(batch)
				_record_spec_trigger(unit, spec)


## 仅当技能拥有者是事件的「主体」时才处理（SELF 类效果对应该单位自身经历的事件）。
func _owner_qualifies_for_event(
	owner: UnitInstance,
	event_type: StringName,
	payload: CombatEventPayload,
) -> bool:
	if owner == null:
		return false
	match event_type:
		CombatEvents.ON_DAMAGE_TAKEN, CombatEvents.ON_DEATH:
			return payload.target == owner
		CombatEvents.ON_DEAL_DAMAGE, CombatEvents.ON_KILL:
			return payload.source == owner
		CombatEvents.ON_CRIT:
			return payload.source == owner
		CombatEvents.ON_MOVE:
			return payload.source == owner
		CombatEvents.ON_COMBAT_START:
			return true
		CombatEvents.ON_ROUND_START:
			## 旧全场回合：source 为空，全员可听。回合制「自己回合开始」：source=行动者，仅本人。
			return payload.source == null or payload.source == owner
		CombatEvents.ON_FRIEND_SUMMONED:
			return (
				payload.target != null
				and payload.target != owner
				and payload.target.team == owner.team
			)
		CombatEvents.ON_FRIEND_DEATH, CombatEvents.ON_FRIEND_DAMAGE_TAKEN:
			return (
				payload.target != null
				and payload.target != owner
				and payload.target.team == owner.team
			)
		CombatEvents.ON_ENEMY_DEATH:
			return (
				payload.target != null
				and payload.target != owner
				and payload.target.team != owner.team
			)

		CombatEvents.ON_SUMMONED:
			return payload.target == owner
		CombatEvents.ON_ATTACK_HIT:
			return payload.target == owner
		_:
			return true


func _collect_listener_units(payload: CombatEventPayload) -> Array[UnitInstance]:
	var by_id: Dictionary = {}
	for unit in _grid.get_alive_units():
		by_id[unit.instance_id] = unit
	if payload.target != null:
		by_id[payload.target.instance_id] = payload.target
	if payload.source != null:
		by_id[payload.source.instance_id] = payload.source
	var result: Array[UnitInstance] = []
	for unit in by_id.values():
		result.append(unit as UnitInstance)
	result.sort_custom(_sort_listeners)
	return result


static func _sort_listeners(a: UnitInstance, b: UnitInstance) -> bool:
	return a.instance_id < b.instance_id


func _get_effect_specs(unit: UnitInstance) -> Array[EffectSpec]:
	if unit == null:
		return []
	return unit.get_all_effect_specs()


func _resolve_targets(
	spec: EffectSpec,
	owner: UnitInstance,
	payload: CombatEventPayload,
) -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	match spec.target_selector:
		EffectSpec.TargetSelector.SELF:
			if owner != null:
				result.append(owner)
		EffectSpec.TargetSelector.EVENT_TARGET:
			if payload.target != null:
				result.append(payload.target)
		EffectSpec.TargetSelector.RANDOM_ALLY:
			var picked := _pick_random_ally(owner, spec.exclude_owner)
			if picked != null:
				result.append(picked)
		EffectSpec.TargetSelector.ALL_UNITS:
			result.append_array(_grid.get_alive_units())
		EffectSpec.TargetSelector.RANDOM_ENEMY:
			var enemy := _pick_random_enemy(owner)
			if enemy != null:
				result.append(enemy)
		EffectSpec.TargetSelector.HEALTHIEST_ALLY:
			var healthiest := _pick_healthiest_ally(owner, true)
			if healthiest != null:
				result.append(healthiest)
		EffectSpec.TargetSelector.ALL_ALLIES:
			for unit in _grid.get_units_by_team(owner.team, true):
				if spec.exclude_owner and unit.instance_id == owner.instance_id:
					continue
				result.append(unit)
		EffectSpec.TargetSelector.FIRST_ENEMY:
			var first := _pick_first_enemy(owner)
			if first != null:
				result.append(first)
		EffectSpec.TargetSelector.LAST_ENEMY:
			var last := _pick_last_enemy(owner)
			if last != null:
				result.append(last)
		EffectSpec.TargetSelector.NEAREST_ALLY_BEHIND:
			var behind := _pick_nearest_ally_behind(owner)
			if behind != null:
				result.append(behind)
		EffectSpec.TargetSelector.UNIT_AHEAD_OF_MOVE:
			var front := cell_ahead_of_move(payload, _grid)
			if front != Vector2i(-1, -1):
				var ahead_unit := _grid.get_unit(front)
				if (
					ahead_unit != null
					and ahead_unit.is_alive()
					and ahead_unit.team != owner.team
				):
					result.append(ahead_unit)
		EffectSpec.TargetSelector.HIGHEST_CURRENT_HP_ALLY:
			var ally := _pick_highest_current_hp_ally(owner, spec.exclude_owner)
			if ally != null:
				result.append(ally)
		EffectSpec.TargetSelector.ENEMIES_ADJACENT_TO_EVENT_TARGET:
			result.append_array(_pick_enemies_adjacent_to_event_target(owner, payload))
		EffectSpec.TargetSelector.EVENT_SOURCE:
			if payload.source != null and payload.source.is_alive():
				result.append(payload.source)
		EffectSpec.TargetSelector.NEARBY_ALLIES:
			result.append_array(_pick_nearby_allies(owner, spec.exclude_owner))
		EffectSpec.TargetSelector.LOWEST_CURRENT_HP_ALLY:
			var lowest := _pick_lowest_current_hp_ally(owner, spec.exclude_owner)
			if lowest != null:
				result.append(lowest)
		EffectSpec.TargetSelector.LOWEST_CURRENT_HP_NEARBY_ALLY:
			var lowest_near := _pick_lowest_current_hp_nearby_ally(owner, spec.exclude_owner)
			if lowest_near != null:
				result.append(lowest_near)
		EffectSpec.TargetSelector.LOWEST_CURRENT_HP_ENEMY:
			var weakest := _pick_lowest_current_hp_enemy(owner)
			if weakest != null:
				result.append(weakest)
		EffectSpec.TargetSelector.ORTHOGONAL_LEFT_RIGHT_ALLIES:
			result.append_array(_pick_orthogonal_left_right_allies(owner, spec.exclude_owner))
		EffectSpec.TargetSelector.RANDOM_ANY_UNIT:
			var any_unit := _pick_random_any_unit(owner, spec.exclude_owner)
			if any_unit != null:
				result.append(any_unit)
	return result



static func cell_ahead_of_move(payload: CombatEventPayload, grid: BoardGrid) -> Vector2i:
	if payload == null or grid == null:
		return Vector2i(-1, -1)
	var delta := payload.to_cell - payload.from_cell
	if delta == Vector2i.ZERO:
		return Vector2i(-1, -1)
	var dir := Vector2i(signi(delta.x), signi(delta.y))
	var front := payload.to_cell + dir
	if not grid.in_bounds(front):
		return Vector2i(-1, -1)
	return front


func _spec_uses_cell_targets(spec: EffectSpec) -> bool:
	if spec == null:
		return false
	return (
		spec.target_selector == EffectSpec.TargetSelector.CELLS_AROUND_EVENT
		or spec.target_selector == EffectSpec.TargetSelector.RANDOM_CELLS
	)


func _pick_random_ally(owner: UnitInstance, exclude_owner: bool) -> UnitInstance:
	if owner == null:
		return null
	var candidates: Array[UnitInstance] = []
	for unit in _grid.get_units_by_team(owner.team, true):
		if exclude_owner and unit.instance_id == owner.instance_id:
			continue
		candidates.append(unit)
	if candidates.is_empty():
		return null
	if _rng != null:
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return candidates[0]


func _pick_random_enemy(owner: UnitInstance) -> UnitInstance:
	if owner == null:
		return null
	var enemy_team := UnitInstance.Team.ENEMY if owner.team == UnitInstance.Team.PLAYER else UnitInstance.Team.PLAYER
	var candidates := _grid.get_units_by_team(enemy_team, true)
	if candidates.is_empty():
		return null
	if _rng != null:
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return candidates[0]


## 敌我双方存活单位中随机一名；可排除持有者（死亡触发时持有者通常已不在存活池）。
func _pick_random_any_unit(owner: UnitInstance, exclude_owner: bool) -> UnitInstance:
	if _grid == null:
		return null
	var candidates: Array[UnitInstance] = []
	for unit in _grid.get_alive_units():
		if unit == null or not unit.is_alive():
			continue
		if (
			exclude_owner
			and owner != null
			and unit.instance_id == owner.instance_id
		):
			continue
		candidates.append(unit)
	if candidates.is_empty():
		return null
	if _rng != null:
		return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return candidates[0]


func _pick_first_enemy(owner: UnitInstance) -> UnitInstance:
	return _pick_enemy_by_line_order(owner, true)


func _pick_last_enemy(owner: UnitInstance) -> UnitInstance:
	return _pick_enemy_by_line_order(owner, false)


func _pick_enemy_by_line_order(owner: UnitInstance, pick_first: bool) -> UnitInstance:
	if owner == null:
		return null
	var enemy_team := UnitInstance.Team.ENEMY if owner.team == UnitInstance.Team.PLAYER else UnitInstance.Team.PLAYER
	var candidates := _grid.get_units_by_team(enemy_team, true)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: UnitInstance, b: UnitInstance) -> bool:
		if a.grid_pos.x != b.grid_pos.x:
			return a.grid_pos.x < b.grid_pos.x if pick_first else a.grid_pos.x > b.grid_pos.x
		return a.grid_pos.y < b.grid_pos.y if pick_first else a.grid_pos.y > b.grid_pos.y
	)
	return candidates[0]


func _pick_nearest_ally_behind(owner: UnitInstance) -> UnitInstance:
	if owner == null:
		return null
	var best: UnitInstance = null
	var best_dist := 999999
	for unit in _grid.get_units_by_team(owner.team, true):
		if unit.instance_id == owner.instance_id:
			continue
		if unit.grid_pos.y <= owner.grid_pos.y:
			continue
		var dist := _grid.combat_distance(owner.grid_pos, unit.grid_pos)
		if dist < best_dist:
			best_dist = dist
			best = unit
	return best


func _pick_healthiest_ally(owner: UnitInstance, exclude_owner: bool) -> UnitInstance:
	if owner == null:
		return null
	var best: UnitInstance = null
	var best_hp := -1
	for unit in _grid.get_units_by_team(owner.team, true):
		if exclude_owner and unit.instance_id == owner.instance_id:
			continue
		var hp := unit.get_effective_max_hp()
		if hp > best_hp:
			best_hp = hp
			best = unit
	return best


func _pick_highest_current_hp_ally(owner: UnitInstance, exclude_owner: bool) -> UnitInstance:
	if owner == null:
		return null
	var best: UnitInstance = null
	var best_hp := -1
	var best_max := -1
	for unit in _grid.get_units_by_team(owner.team, true):
		if exclude_owner and unit.instance_id == owner.instance_id:
			continue
		var hp := unit.current_hp
		var max_hp := unit.get_effective_max_hp()
		if hp > best_hp:
			best_hp = hp
			best_max = max_hp
			best = unit
		elif hp == best_hp:
			if max_hp > best_max:
				best_max = max_hp
				best = unit
			elif max_hp == best_max and best != null and unit.instance_id < best.instance_id:
				best = unit
	return best


func _pick_lowest_current_hp_ally(owner: UnitInstance, exclude_owner: bool) -> UnitInstance:
	if owner == null:
		return null
	var best: UnitInstance = null
	var best_hp := 999999
	var best_max := 999999
	for unit in _grid.get_units_by_team(owner.team, true):
		if exclude_owner and unit.instance_id == owner.instance_id:
			continue
		var hp := unit.current_hp
		var max_hp := unit.get_effective_max_hp()
		if hp < best_hp:
			best_hp = hp
			best_max = max_hp
			best = unit
		elif hp == best_hp:
			if max_hp < best_max:
				best_max = max_hp
				best = unit
			elif max_hp == best_max and best != null and unit.instance_id < best.instance_id:
				best = unit
	return best


func _pick_lowest_current_hp_enemy(owner: UnitInstance) -> UnitInstance:
	if owner == null:
		return null
	var enemy_team := (
		UnitInstance.Team.ENEMY
		if owner.team == UnitInstance.Team.PLAYER
		else UnitInstance.Team.PLAYER
	)
	var best: UnitInstance = null
	var best_hp := 999999
	var best_max := 999999
	for unit in _grid.get_units_by_team(enemy_team, true):
		var hp := unit.current_hp
		var max_hp := unit.get_effective_max_hp()
		if hp < best_hp:
			best_hp = hp
			best_max = max_hp
			best = unit
		elif hp == best_hp:
			if max_hp < best_max:
				best_max = max_hp
				best = unit
			elif max_hp == best_max and best != null and unit.instance_id < best.instance_id:
				best = unit
	return best


func _pick_lowest_current_hp_nearby_ally(owner: UnitInstance, exclude_owner: bool) -> UnitInstance:
	var nearby := _pick_nearby_allies(owner, exclude_owner)
	if nearby.is_empty():
		return null
	var best: UnitInstance = null
	var best_hp := 999999
	var best_max := 999999
	for unit in nearby:
		var hp := unit.current_hp
		var max_hp := unit.get_effective_max_hp()
		if hp < best_hp:
			best_hp = hp
			best_max = max_hp
			best = unit
		elif hp == best_hp:
			if max_hp < best_max:
				best_max = max_hp
				best = unit
			elif max_hp == best_max and best != null and unit.instance_id < best.instance_id:
				best = unit
	return best



static func _spec_trigger_matches(spec: EffectSpec, event_type: StringName) -> bool:
	if spec == null or event_type == StringName():
		return false
	return StringName(spec.trigger) == event_type


func _spec_condition_met(
	spec: EffectSpec,
	owner: UnitInstance,
	payload: CombatEventPayload,
) -> bool:
	if spec == null:
		return false
	match spec.condition:
		EffectSpec.Condition.NONE:
			return true
		EffectSpec.Condition.EVENT_TARGET_HP_GT_OWNER:
			if owner == null or payload == null or payload.target == null:
				return false
			## 用扣血前生命，避免收刀后均血/死亡导致削峰漏触发。
			var target_hp := (
				payload.target_hp_before
				if payload.target_hp_before >= 0
				else payload.target.current_hp
			)
			return target_hp > owner.current_hp
		EffectSpec.Condition.EVENT_TARGET_IS_COMBAT_SUMMON:
			return (
				payload != null
				and payload.target != null
				and payload.target.is_combat_summon
			)
		EffectSpec.Condition.EVENT_TARGET_IS_NOT_COMBAT_SUMMON:
			return (
				payload != null
				and payload.target != null
				and not payload.target.is_combat_summon
			)
		EffectSpec.Condition.EVENT_TARGET_NOT_AT_MAX_HP:
			return _unit_below_max_hp(payload.target if payload != null else null)
		_:
			return true


static func _unit_below_max_hp(unit: UnitInstance) -> bool:
	if unit == null or not unit.is_alive():
		return false
	return unit.current_hp < unit.get_effective_max_hp()


func _spec_under_trigger_cap(owner: UnitInstance, spec: EffectSpec) -> bool:
	if spec == null or spec.max_triggers_per_combat <= 0:
		return true
	if owner == null:
		return false
	var by_spec: Dictionary = _spec_trigger_counts.get(owner.instance_id, {})
	var used: int = int(by_spec.get(spec.get_instance_id(), 0))
	return used < spec.max_triggers_per_combat


func _record_spec_trigger(owner: UnitInstance, spec: EffectSpec) -> void:
	if owner == null or spec == null or spec.max_triggers_per_combat <= 0:
		return
	var by_spec: Dictionary = _spec_trigger_counts.get(owner.instance_id, {})
	var key := spec.get_instance_id()
	by_spec[key] = int(by_spec.get(key, 0)) + 1
	_spec_trigger_counts[owner.instance_id] = by_spec


func _pick_enemies_adjacent_to_event_target(
	owner: UnitInstance,
	payload: CombatEventPayload,
) -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	if owner == null or payload == null or payload.target == null or _grid == null:
		return result
	var center := payload.target.grid_pos
	var found := _grid.find_cell_of(payload.target)
	if found != Vector2i(-1, -1):
		center = found
	for unit in _grid.get_alive_units():
		if unit == null or not unit.is_alive():
			continue
		if unit.instance_id == payload.target.instance_id:
			continue
		if unit.team == owner.team:
			continue
		var cell := unit.grid_pos
		var unit_cell := _grid.find_cell_of(unit)
		if unit_cell != Vector2i(-1, -1):
			cell = unit_cell
		if _grid.combat_distance(center, cell) == EffectSpec.NEARBY_ENEMY_RADIUS:
			result.append(unit)
	result.sort_custom(_sort_listeners)
	return result


## 持有者附近友方（切比雪夫 ≤ EffectSpec.NEARBY_ALLY_RADIUS；现为周围一格）。
func _pick_nearby_allies(owner: UnitInstance, exclude_owner: bool) -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	if owner == null or _grid == null:
		return result
	var center := owner.grid_pos
	var found := _grid.find_cell_of(owner)
	if found != Vector2i(-1, -1):
		center = found
	for unit in _grid.get_units_by_team(owner.team, true):
		if unit == null or not unit.is_alive():
			continue
		if exclude_owner and unit.instance_id == owner.instance_id:
			continue
		var cell := unit.grid_pos
		var unit_cell := _grid.find_cell_of(unit)
		if unit_cell != Vector2i(-1, -1):
			cell = unit_cell
		if _grid.chebyshev_distance(center, cell) <= EffectSpec.NEARBY_ALLY_RADIUS:
			result.append(unit)
	result.sort_custom(_sort_listeners)
	return result


## 正交左右邻格友方（同一行、列 ±1；不含上下/斜）。2★+ 跳过首领。
## 按友方足迹格判定邻接，避免只查中心格漏掉占位。
func _pick_orthogonal_left_right_allies(
	owner: UnitInstance,
	exclude_owner: bool,
) -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	if owner == null or _grid == null:
		return result
	var center := owner.grid_pos
	var found := _grid.find_cell_of(owner)
	if found != Vector2i(-1, -1):
		center = found
	var skip_boss := owner.level >= 2
	var left_cell := Vector2i(center.x - 1, center.y)
	var right_cell := Vector2i(center.x + 1, center.y)
	var seen: Dictionary = {}
	for unit in _grid.get_units_by_team(owner.team, true):
		if unit == null or not unit.is_alive():
			continue
		if exclude_owner and unit.instance_id == owner.instance_id:
			continue
		if skip_boss and unit.is_boss_leader():
			continue
		if seen.has(unit.instance_id):
			continue
		var cells := _unit_footprint_cells(unit)
		var touches := false
		for cell in cells:
			if cell == left_cell or cell == right_cell:
				touches = true
				break
		if not touches:
			continue
		seen[unit.instance_id] = true
		result.append(unit)
	result.sort_custom(_sort_listeners)
	return result


func _unit_footprint_cells(unit: UnitInstance) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if unit == null or _grid == null:
		return cells
	var origin := _grid.find_cell_of(unit)
	if origin == Vector2i(-1, -1):
		origin = unit.grid_pos
	var size := unit.get_footprint_size()
	for dy in size.y:
		for dx in size.x:
			cells.append(Vector2i(origin.x + dx, origin.y + dy))
	if cells.is_empty():
		cells.append(origin)
	return cells


func process_attack_hit_immediate(payload: CombatEventPayload) -> Dictionary:
	var result := {
		"swapped": false,
		"fizzled": false,
		"damage_target": payload.target if payload != null else null,
	}
	if payload == null or payload.target == null:
		return result

	var defender := payload.target
	if not defender.is_alive():
		return result

	for spec in _get_effect_specs(defender):
		if not _spec_trigger_matches(spec, CombatEvents.ON_ATTACK_HIT):
			continue
		if not _owner_qualifies_for_event(defender, CombatEvents.ON_ATTACK_HIT, payload):
			continue

		var targets := _resolve_targets(spec, defender, payload)
		var ally: UnitInstance = targets[0] if not targets.is_empty() else null
		if ally == null:
			_emit_effect_fizzled(
				defender,
				spec,
				payload,
				"技能失败：没有其他队友可换位",
			)
			result["fizzled"] = true
			result["owner"] = defender
			result["spec"] = spec
			return result

		var defender_cell := _grid.find_cell_of(defender)
		var did_swap := false
		for action in spec.actions:
			if action == null:
				continue
			if action.action_type == EffectAction.Type.SWAP_POSITIONS:
				if _execute_action(action, ally, payload, 0, defender, spec):
					did_swap = true

		if not did_swap:
			push_warning(
				"[Effect] %s ON_ATTACK_HIT swap failed (cells %s / %s)"
				% [defender.id, str(defender_cell), str(_grid.find_cell_of(ally))]
			)
			_emit_effect_fizzled(
				defender,
				spec,
				payload,
				"技能失败：换位未生效",
			)
			result["fizzled"] = true
			result["owner"] = defender
			result["spec"] = spec
			return result

		if defender_cell != Vector2i(-1, -1):
			var damage_target := _grid.get_unit(defender_cell)
			if damage_target != null:
				result["damage_target"] = damage_target

		result["swapped"] = true
		result["owner"] = defender
		result["spec"] = spec
		return result

	return result


func _execute_action(
	action: EffectAction,
	target: UnitInstance,
	payload: CombatEventPayload,
	depth: int,
	owner: UnitInstance,
	spec: EffectSpec,
	emit_resolved: bool = true,
) -> bool:
	if action == null:
		return false

	var executed := false
	match action.action_type:
		EffectAction.Type.MODIFY_STAT:
			if not target.is_alive():
				return false
			var stat_value := _scaled_action_value(owner, action.value)
			target.stat_modifiers.add_flat(action.stat_name, stat_value)
			## 临时抬 max_hp 时同步抬当前生命（承伤感近似；负值只 clamp）。
			if action.stat_name == &"max_hp" and stat_value > 0:
				target.current_hp = mini(
					target.get_effective_max_hp(),
					target.current_hp + stat_value,
				)
			else:
				target.current_hp = clampi(target.current_hp, 0, target.get_effective_max_hp())
			print(
				"[Effect] %s +%d %s (eff atk=%d hp=%d/%d)"
				% [
					target.id,
					stat_value,
					action.stat_name,
					target.get_effective_attack(),
					target.current_hp,
					target.get_effective_max_hp(),
				]
			)
			executed = true
		EffectAction.Type.HEAL:
			if not target.is_alive() or target.stats == null:
				return false
			if (
				spec != null
				and spec.condition == EffectSpec.Condition.EVENT_TARGET_NOT_AT_MAX_HP
				and not _unit_below_max_hp(target)
			):
				return false
			var before := target.current_hp
			var heal_value := _scaled_action_value(owner, action.value)
			## 受击触发且疗本事件受伤单位：疗量不超过本次伤害（切断伤<疗净回血）。
			if (
				payload != null
				and payload.target == target
				and payload.amount > 0
			):
				heal_value = mini(heal_value, payload.amount)
			var remaining := (
				UnitInstance.COMBAT_SKILL_HEAL_BUDGET - target.combat_skill_heal_received
			)
			if remaining <= 0:
				return false
			heal_value = mini(heal_value, remaining)
			if heal_value <= 0:
				return false
			target.current_hp = mini(
				target.get_effective_max_hp(),
				target.current_hp + heal_value,
			)
			var healed := target.current_hp - before
			if healed > 0:
				target.combat_skill_heal_received += healed
				if _bus != null:
					var heal_payload := CombatEventPayload.new()
					heal_payload.effect_owner = owner
					heal_payload.source = owner
					heal_payload.target = target
					heal_payload.amount = healed
					_bus.emit_event(CombatEvents.ON_HEAL_APPLIED, heal_payload)
			print("[Effect] %s heal %d->%d" % [target.id, before, target.current_hp])
			executed = true
		EffectAction.Type.SPAWN_UNIT:
			executed = _spawn_unit(action, payload, depth, owner)
		EffectAction.Type.SPLIT_SELF:
			executed = not _split_self(owner, action, payload, depth).is_empty()
		EffectAction.Type.DEAL_DAMAGE:
			if _pipeline == null or target == null or not target.is_alive():
				return false
			var damage_value := _resolve_damage_value(owner, action)
			_suppress_deal_damage_triggers += 1
			_pipeline.apply_rolled_damage(owner, target, damage_value)
			_suppress_deal_damage_triggers = maxi(0, _suppress_deal_damage_triggers - 1)
			print(
				"[Effect] %s deals %d to %s (hp=%d)"
				% [
					owner.id if owner != null else "?",
					damage_value,
					target.id,
					target.current_hp,
				]
			)
			executed = true
		EffectAction.Type.SET_HP_FROM_ALLY_PERCENT:
			if owner == null or target == null or not owner.is_alive():
				return false
			var ability: AbilityData = owner.unit_data.ability if owner.unit_data != null else null
			var scaled_percent := (
				action.value * UnitInstance.ability_value_multiplier_for(ability, owner.level)
			)
			var new_hp := maxi(
				1,
				target.get_effective_max_hp() * scaled_percent / 100,
			)
			owner.current_hp = mini(new_hp, owner.get_effective_max_hp())
			print(
				"[Effect] %s copies %d%% hp from %s -> %d/%d"
				% [
					owner.id,
					scaled_percent,
					target.id,
					owner.current_hp,
					owner.get_effective_max_hp(),
				]
			)
			executed = true
		EffectAction.Type.FRIENDS_HURT_AOE:
			if _pipeline == null or owner == null:
				return false
			var need := maxi(1, action.threshold)
			if _friend_hurt_this_round < need:
				return false
			for enemy in _grid.get_units_by_team(
				UnitInstance.Team.ENEMY if owner.team == UnitInstance.Team.PLAYER else UnitInstance.Team.PLAYER,
				true,
			):
				var dmg := _scaled_action_value(owner, action.value)
				_pipeline.apply_rolled_damage(owner, enemy, dmg)
			executed = true
		EffectAction.Type.PERMANENT_DECK_STAT:
			var stat_unit := target if target != null else owner
			if stat_unit == null or stat_unit.stats == null:
				return false
			var stat_value := _scaled_action_value(owner, action.value)
			match action.stat_name:
				&"attack":
					if stat_unit.deck_entry_id >= 0 and _deck_state != null:
						var atk_entry := _deck_state.get_entry(stat_unit.deck_entry_id)
						if atk_entry != null:
							atk_entry.bonus_attack += stat_value
							_deck_state.deck_changed.emit()
					stat_unit.stats.attack += stat_value
					executed = true
				&"max_hp":
					if stat_unit.deck_entry_id >= 0 and _deck_state != null:
						var hp_entry := _deck_state.get_entry(stat_unit.deck_entry_id)
						if hp_entry != null:
							hp_entry.bonus_max_hp += stat_value
							_deck_state.deck_changed.emit()
					stat_unit.stats.max_hp += stat_value
					stat_unit.current_hp += stat_value
					executed = true
				&"crit_rate_percent":
					if stat_unit.deck_entry_id >= 0 and _deck_state != null:
						var crit_entry := _deck_state.get_entry(stat_unit.deck_entry_id)
						if crit_entry != null:
							crit_entry.bonus_crit_rate_percent += stat_value
							_deck_state.deck_changed.emit()
					stat_unit.stats.crit_rate_percent += stat_value
					executed = true
			if executed:
				print(
					"[Effect] %s permanent +%d %s (crit=%d%%)"
					% [
						stat_unit.id,
						stat_value,
						action.stat_name,
						int(round(stat_unit.get_effective_crit_rate() * 100.0)),
					]
				)
		EffectAction.Type.SWAP_POSITIONS:
			if owner == null or target == null or not owner.is_alive():
				return false
			var owner_cell := _grid.find_cell_of(owner)
			var target_cell := _grid.find_cell_of(target)
			if owner_cell == Vector2i(-1, -1) or target_cell == Vector2i(-1, -1):
				return false
			if not _grid.swap_units_at(owner_cell, target_cell):
				return false
			print(
				"[Effect] %s swaps with %s (%s <-> %s)"
				% [owner.id, target.id, str(owner_cell), str(target_cell)]
			)
			executed = true
		EffectAction.Type.GRANT_ACTOR_TURN_REFRESH:
			if owner == null or not owner.is_alive() or _bus == null:
				return false
			var refresh := CombatEventPayload.new()
			refresh.source = owner
			refresh.target = owner
			_bus.emit_event(CombatEvents.ON_ACTOR_TURN_REFRESH, refresh)
			print("[Effect] %s granted actor turn refresh" % owner.id)
			executed = true
		EffectAction.Type.TELEPORT_ADJACENT_TO_TARGET:
			if owner == null or target == null or not owner.is_alive() or not target.is_alive():
				return false
			var from_cell := _grid.find_cell_of(owner)
			var dest := _pick_teleport_cell_adjacent_to_target(owner, target)
			if dest == Vector2i(-1, -1):
				return false
			if from_cell != dest:
				if not _grid.move_unit_for(owner, dest):
					return false
				owner.grid_pos = dest
				if payload != null:
					payload.from_cell = from_cell
					payload.to_cell = dest
				print(
					"[Effect] %s teleports adjacent to %s -> %s"
					% [owner.id, target.id, str(dest)]
				)
			executed = true
		EffectAction.Type.ABSORB_STATS_AND_KILL:
			executed = _absorb_stats_and_kill(owner, target)
		EffectAction.Type.GRANT_GOLD:
			## 仅玩家友方产金；敌方镜像空转。金额走升星倍率（经济技能常用 merge_value_mult=3）。
			if owner == null or owner.team != UnitInstance.Team.PLAYER:
				return false
			if _economy == null:
				return false
			var gold_amount := _scaled_action_value(owner, action.value)
			if gold_amount <= 0:
				return false
			_economy.grant(gold_amount)
			print("[Effect] %s grants +%d gold (now=%d)" % [owner.id, gold_amount, _economy.gold])
			executed = true
		EffectAction.Type.BUFF_STATS_FROM_GOLD_HALF:
			## 开战读金加身：不扣金、不加升星倍率；敌方空转。
			if owner == null or owner.team != UnitInstance.Team.PLAYER:
				return false
			if target == null or not target.is_alive():
				return false
			var gold_now := _economy.gold if _economy != null else 0
			var half := gold_now / 2
			if half <= 0:
				return false
			target.stat_modifiers.add_flat(&"attack", half)
			target.stat_modifiers.add_flat(&"max_hp", half)
			target.current_hp = mini(
				target.get_effective_max_hp(),
				target.current_hp + half,
			)
			print(
				"[Effect] %s gold-half buff +%d/+%d (gold=%d eff %d/%d)"
				% [
					target.id,
					half,
					half,
					gold_now,
					target.get_effective_attack(),
					target.get_effective_max_hp(),
				]
			)
			executed = true

	if executed and emit_resolved:
		_emit_effect_resolved(owner, action, target, payload, spec)
	return executed


func _emit_effect_resolved(
	owner: UnitInstance,
	action: EffectAction,
	target: UnitInstance,
	payload: CombatEventPayload,
	spec: EffectSpec,
) -> void:
	var step := QueuedEffectStep.new()
	step.action = action
	step.target = target
	step.owner = owner
	step.spec = spec
	step.payload = payload
	var steps: Array[QueuedEffectStep] = [step]
	_emit_effect_batch_resolved(
		_make_batch(owner, spec, payload, steps),
		[{"action": action, "target": target}],
	)


func _make_batch(
	owner: UnitInstance,
	spec: EffectSpec,
	payload: CombatEventPayload,
	entries: Array[QueuedEffectStep],
) -> QueuedEffectBatch:
	var batch := QueuedEffectBatch.new()
	batch.owner = owner
	batch.spec = spec
	batch.payload = payload
	batch.entries = entries
	return batch


func _emit_effect_batch_resolved(batch: QueuedEffectBatch, executed: Array) -> void:
	if _bus == null or executed.is_empty():
		return
	var first: Dictionary = executed[0]
	var first_action: EffectAction = first.get("action")
	var first_target: UnitInstance = first.get("target")
	var resolved := CombatEventPayload.new()
	resolved.source = batch.owner
	resolved.target = first_target
	resolved.effect_action = first_action
	resolved.effect_owner = batch.owner
	resolved.effect_spec = batch.spec
	resolved.effect_entries = executed.duplicate()
	if batch.payload != null:
		resolved.from_cell = batch.payload.from_cell
		resolved.to_cell = batch.payload.to_cell
		resolved.removed_owner_instance_id = batch.payload.removed_owner_instance_id
		resolved.fuse_explosion_cells = batch.payload.fuse_explosion_cells.duplicate()
	_bus.emit_event(CombatEvents.ON_EFFECT_RESOLVED, resolved)


func _emit_effect_fizzled(
	owner: UnitInstance,
	spec: EffectSpec,
	payload: CombatEventPayload,
	message: String,
) -> void:
	if _bus == null:
		return
	var fizzled := CombatEventPayload.new()
	fizzled.source = owner
	fizzled.target = owner
	fizzled.effect_owner = owner
	fizzled.effect_spec = spec
	fizzled.fizzle_message = message
	fizzled.from_cell = payload.from_cell
	fizzled.to_cell = payload.to_cell
	_bus.emit_event(CombatEvents.ON_EFFECT_FIZZLED, fizzled)


func _execute_fuse_explode_batch(
	owner: UnitInstance,
	action: EffectAction,
	payload: CombatEventPayload,
	depth: int,
	spec: EffectSpec,
) -> Array:
	if _pipeline == null or owner == null or not owner.is_alive() or payload == null:
		return []
	var explode_round := maxi(1, action.threshold)
	if payload.amount != explode_round:
		return []
	var center := _grid.find_cell_of(owner)
	if center == Vector2i(-1, -1):
		return []
	var radius := maxi(0, owner.current_hp)
	var damage := owner.get_effective_attack()
	payload.fuse_explosion_cells = _cells_in_radius(center, radius, true)
	var enemy_team := (
		UnitInstance.Team.ENEMY
		if owner.team == UnitInstance.Team.PLAYER
		else UnitInstance.Team.PLAYER
	)
	var damage_action := EffectAction.new()
	damage_action.action_type = EffectAction.Type.DEAL_DAMAGE
	damage_action.value = damage
	var executed: Array = []
	var hit_count := 0
	for enemy in _grid.get_units_by_team(enemy_team, true):
		var enemy_cell := _grid.find_cell_of(enemy)
		if enemy_cell == Vector2i(-1, -1):
			continue
		if _grid.chebyshev_distance(center, enemy_cell) > radius:
			continue
		_pipeline.apply_rolled_damage(owner, enemy, damage)
		executed.append({"action": damage_action, "target": enemy})
		hit_count += 1
	if owner.is_alive():
		_pipeline.apply_damage(owner, owner, owner.current_hp, false)
	if hit_count == 0:
		executed.append({"action": action, "target": owner})
	print(
		"[Effect] %s fuse explodes (round=%d radius=%d dmg=%d hits=%d)"
		% [owner.id, explode_round, radius, damage, hit_count]
	)
	return executed


func _pick_teleport_cell_adjacent_to_target(
	owner: UnitInstance,
	target: UnitInstance,
) -> Vector2i:
	if owner == null or target == null or _grid == null:
		return Vector2i(-1, -1)
	var owner_cell := _grid.find_cell_of(owner)
	var target_cell := _grid.find_cell_of(target)
	if owner_cell == Vector2i(-1, -1) or target_cell == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_dist := 999999
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var cell := target_cell + Vector2i(dx, dy)
			if not _grid.can_place_at(cell):
				continue
			var occupant := _grid.get_unit(cell)
			if occupant != null and occupant != owner and occupant.is_alive():
				continue
			var dist := BoardGrid._chebyshev(owner_cell, cell)
			if dist < best_dist:
				best_dist = dist
				best = cell
			elif dist == best_dist and best != Vector2i(-1, -1):
				if cell.x < best.x or (cell.x == best.x and cell.y < best.y):
					best = cell
	if best == Vector2i(-1, -1) and _grid.chebyshev_distance(owner_cell, target_cell) <= 1:
		return owner_cell
	return best


## 吞噬：读目标有效攻/生命上限 → 加到持有者本场临时层 → 经管线消灭目标（触发死亡/友亡）。
## 转移量不套技能星级倍率。
func _absorb_stats_and_kill(owner: UnitInstance, target: UnitInstance) -> bool:
	if owner == null or not owner.is_alive() or target == null or not target.is_alive():
		return false
	if target.instance_id == owner.instance_id:
		return false
	var atk_gain := target.get_effective_attack()
	var hp_gain := target.get_effective_max_hp()
	if atk_gain != 0:
		owner.stat_modifiers.add_flat(&"attack", atk_gain)
	if hp_gain > 0:
		owner.stat_modifiers.add_flat(&"max_hp", hp_gain)
		owner.current_hp = mini(
			owner.get_effective_max_hp(),
			owner.current_hp + hp_gain,
		)
	else:
		owner.current_hp = clampi(owner.current_hp, 0, owner.get_effective_max_hp())
	var lethal := maxi(1, target.current_hp)
	if _pipeline != null:
		_suppress_deal_damage_triggers += 1
		_pipeline.apply_damage(owner, target, lethal, false)
		_suppress_deal_damage_triggers = maxi(0, _suppress_deal_damage_triggers - 1)
	else:
		target.current_hp = 0
	print(
		"[Effect] %s absorbs +%d atk +%d max_hp from %s then kills (owner atk=%d hp=%d/%d)"
		% [
			owner.id,
			atk_gain,
			hp_gain,
			target.id,
			owner.get_effective_attack(),
			owner.current_hp,
			owner.get_effective_max_hp(),
		]
	)
	return true


func _scaled_action_value(owner: UnitInstance, value: int) -> int:
	if owner == null:
		return value
	var ability: AbilityData = owner.get_main_ability()
	if ability != null and ability.id == "turn_start_strike_weakest":
		## 影刺：1★ 2 点；三合一升星后（2★+）7 点（不走全局 ×6）。
		return 2 if owner.level <= 1 else 7
	return value * UnitInstance.ability_value_multiplier_for(ability, owner.level)


func _resolve_damage_value(owner: UnitInstance, action: EffectAction) -> int:
	if action.damage_mode == EffectAction.DamageMode.OWNER_ATTACK_PERCENT:
		if owner == null:
			return 0
		return maxi(1, owner.get_effective_attack() * action.percent / 100)
	return _scaled_action_value(owner, action.value)


func _split_self(
	owner: UnitInstance,
	action: EffectAction,
	payload: CombatEventPayload,
	depth: int,
) -> Array:
	var entries: Array = []
	if owner == null or not owner.is_alive() or action.spawn_unit == null:
		return entries
	var count := owner.current_hp
	if count <= 0:
		return entries

	var origin := _grid.find_cell_of(owner)
	if origin == Vector2i(-1, -1):
		origin = owner.grid_pos
	var team := owner.team
	var inherited_atk := owner.get_effective_attack()
	var level := owner.level
	var split_hp := maxi(1, action.spawn_hp_override if action.spawn_hp_override > 0 else 1)

	if payload != null:
		payload.removed_owner_instance_id = owner.instance_id
	_grid.remove_unit(owner)

	var prefer_player_half := team == UnitInstance.Team.PLAYER
	if not _has_spawn_cell_available(prefer_player_half):
		return entries
	for i in count:
		var cell := _pick_spawn_cell(origin, i == 0, prefer_player_half)
		if cell == Vector2i(-1, -1):
			break
		var spawned := UnitInstance.from_unit_data(action.spawn_unit, cell, team)
		spawned.level = level
		if spawned.stats != null:
			spawned.stats.attack = inherited_atk
			spawned.stats.max_hp = split_hp
		spawned.current_hp = split_hp
		if not _grid.place(spawned, cell):
			continue
		print(
			"[Effect] split %s at %s atk=%d hp=%d"
			% [spawned.id, str(cell), inherited_atk, split_hp]
		)
		_emit_friend_summoned(spawned, owner, depth)
		_emit_summoned(spawned, depth)
		entries.append({"action": action, "target": spawned})
	return entries


func _spawn_unit(
	action: EffectAction,
	payload: CombatEventPayload,
	depth: int,
	owner: UnitInstance,
) -> bool:
	if action.spawn_unit == null or payload.target == null:
		return false
	if payload.target.is_alive():
		return false

	## 击杀生成须跟技能持有者阵营；死亡/友亡的 owner 与死者同队。
	var team := owner.team if owner != null else payload.target.team
	var origin := _grid.find_cell_of(payload.target)
	if origin == Vector2i(-1, -1):
		origin = payload.target.grid_pos
	var prefer_player_half := team == UnitInstance.Team.PLAYER
	if not _has_spawn_cell_available(prefer_player_half):
		return false
	var summon_context := owner if owner != null else payload.target
	## 每次数以 spawn_count 为准；召魂 2★+ 见 AllyDeathSpawnRules。
	var spawn_total := AllyDeathSpawnRules.spawn_count_for_owner(action, owner)
	var spawned_any := false
	for i in spawn_total:
		var cell := _pick_spawn_cell(origin, i == 0, prefer_player_half)
		if cell == Vector2i(-1, -1):
			break
		var spawned := UnitInstance.from_unit_data(action.spawn_unit, cell, team)
		spawned.is_combat_summon = true
		if owner != null:
			spawned.level = owner.level
		## 战中技能随从立即接敌（与 Boss 衍生一致）；勿沿用 token 资源上的部署等待。
		if spawned.stats != null:
			spawned.stats.deploy_time = 0.0
		if (
			owner != null
			and spawned.stats != null
			and action.spawn_unit != null
			and action.spawn_unit.stats != null
		):
			## merge_value_mult>0 时按星级放大随从攻/血（如掘墓×3、余烬×4）；0 仍用 token 底值。
			var spawn_ability: AbilityData = owner.get_main_ability()
			if spawn_ability != null and spawn_ability.merge_value_mult > 0:
				var stat_mult := UnitInstance.ability_value_multiplier_for(
					spawn_ability, owner.level
				)
				spawned.stats.attack = action.spawn_unit.stats.attack * stat_mult
				spawned.stats.max_hp = action.spawn_unit.stats.max_hp * stat_mult
				spawned.current_hp = spawned.stats.max_hp
		if action.spawn_owner_base_percent > 0 and payload.target.stats != null and spawned.stats != null:
			## 按死者基础身体（忽略本场临时层）百分比缩放攻/血。
			var pct := action.spawn_owner_base_percent
			var base_atk := payload.target.stats.attack
			var base_hp := payload.target.stats.max_hp
			spawned.stats.attack = maxi(1, base_atk * pct / 100)
			spawned.stats.max_hp = maxi(1, base_hp * pct / 100)
			spawned.current_hp = spawned.stats.max_hp
		elif action.spawn_hp_override > 0:
			spawned.current_hp = action.spawn_hp_override
			if spawned.stats != null:
				spawned.stats.max_hp = maxi(spawned.stats.max_hp, action.spawn_hp_override)
		if not _grid.place(spawned, cell):
			continue
		spawned_any = true
		if summon_context != null:
			summon_context.combat_summons_spawned += 1
		print("[Effect] spawn %s at %s hp=%d" % [spawned.id, str(cell), spawned.current_hp])
		_emit_friend_summoned(spawned, summon_context, depth)
		_emit_summoned(spawned, depth)
	return spawned_any


func _has_spawn_cell_available(prefer_player_half: bool) -> bool:
	if _grid == null:
		return false
	var height := _grid.get_size().y
	var candidates := BoardHalf.filter_cells(_grid.get_empty_cells(), height, prefer_player_half)
	if candidates.is_empty():
		candidates = _grid.get_empty_cells()
	return not candidates.is_empty()


func _pick_spawn_cell(origin: Vector2i, prefer_origin: bool, prefer_player_half: bool) -> Vector2i:
	var height := _grid.get_size().y
	if (
		prefer_origin
		and _grid.can_place_at(origin)
		and (
			BoardHalf.is_player_deploy_cell(origin, height)
			if prefer_player_half
			else BoardHalf.is_enemy_spawn_cell(origin, height)
		)
	):
		return origin
	var candidates := BoardHalf.filter_cells(_grid.get_empty_cells(), height, prefer_player_half)
	if candidates.is_empty():
		candidates = _grid.get_empty_cells()
	if candidates.is_empty():
		return Vector2i(-1, -1)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _grid.path_cost(origin, a) < _grid.path_cost(origin, b)
	)
	if _rng != null and candidates.size() > 1:
		var best_dist := _grid.path_cost(origin, candidates[0])
		var close: Array[Vector2i] = []
		for cell in candidates:
			if _grid.path_cost(origin, cell) == best_dist:
				close.append(cell)
		return close[_rng.randi_range(0, close.size() - 1)]
	return candidates[0]


func _apply_cell_effect(
	action: EffectAction,
	spec: EffectSpec,
	owner: UnitInstance,
	payload: CombatEventPayload,
) -> void:
	if action.cell_effect == null or _grid == null:
		return
	var cells := _resolve_effect_cells(action, spec, owner, payload)
	for cell in cells:
		_grid.cell_effects.add_effect(cell, action.cell_effect)
		print("[Effect] cell %s +%s" % [str(cell), action.cell_effect.id])


func _resolve_effect_cells(
	action: EffectAction,
	spec: EffectSpec,
	owner: UnitInstance,
	payload: CombatEventPayload,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match spec.target_selector:
		EffectSpec.TargetSelector.CELLS_AROUND_EVENT:
			var center := payload.target.grid_pos if payload.target != null else owner.grid_pos
			if payload.target != null:
				var found := _grid.find_cell_of(payload.target)
				if found != Vector2i(-1, -1):
					center = found
			var radius := action.radius if action != null else 1
			var include_center := action.include_center if action != null else true
			result.append_array(_cells_in_radius(center, radius, include_center))
		EffectSpec.TargetSelector.RANDOM_CELLS:
			var pool: Array[Vector2i] = []
			var size := _grid.get_size()
			for y in size.y:
				for x in size.x:
					var cell := Vector2i(x, y)
					if _grid.in_bounds(cell) and not _grid.is_blocked(cell):
						pool.append(cell)
			var count := mini(spec.target_count, pool.size())
			for i in count:
				if pool.is_empty():
					break
				var pick_idx := _rng.randi_range(0, pool.size() - 1) if _rng != null else 0
				result.append(pool[pick_idx])
				pool.remove_at(pick_idx)
	return result


func _cells_in_radius(center: Vector2i, radius: int, include_center: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if not include_center and dx == 0 and dy == 0:
				continue
			if maxi(absi(dx), absi(dy)) > radius:
				continue
			var cell := center + Vector2i(dx, dy)
			if _grid.in_bounds(cell) and not _grid.is_blocked(cell):
				result.append(cell)
	return result


func _emit_summoned(spawned: UnitInstance, depth: int) -> void:
	if spawned == null:
		return
	var summoned_payload := CombatEventPayload.new()
	summoned_payload.target = spawned
	summoned_payload.to_cell = spawned.grid_pos
	summoned_payload.chain_depth = depth + 1
	## 走总线：EffectResolver 入队技能链，RunCombatStatCollector 等旁路可统计。
	if _bus != null:
		_bus.emit_event(CombatEvents.ON_SUMMONED, summoned_payload)
	else:
		_enqueue_for_event(CombatEvents.ON_SUMMONED, summoned_payload, depth + 1)


func _emit_friend_summoned(
	spawned: UnitInstance,
	summon_context: UnitInstance,
	depth: int,
) -> void:
	if spawned == null:
		return
	var summon_payload := CombatEventPayload.new()
	summon_payload.source = summon_context
	summon_payload.target = spawned
	summon_payload.to_cell = spawned.grid_pos
	summon_payload.chain_depth = depth + 1
	if _bus != null:
		_bus.emit_event(CombatEvents.ON_FRIEND_SUMMONED, summon_payload)
	else:
		_enqueue_for_event(CombatEvents.ON_FRIEND_SUMMONED, summon_payload, depth + 1)
