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


func on_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if _bus == null or _grid == null:
		return
	if event_type == CombatEvents.ON_ATTACK_HIT:
		return
	if event_type == CombatEvents.ON_ROUND_START:
		_friend_hurt_this_round = 0
	if event_type == CombatEvents.ON_DAMAGE_TAKEN:
		if payload.target != null and payload.target.team == UnitInstance.Team.PLAYER:
			_friend_hurt_this_round += 1
	_enqueue_for_event(event_type, payload, 0)


func has_pending_steps() -> bool:
	return not _pending_batches.is_empty()


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
			if _spec_uses_cell_targets(spec):
				for action in spec.actions:
					if action.action_type == EffectAction.Type.APPLY_CELL_EFFECT:
						_apply_cell_effect(action, spec, unit, payload)
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
		CombatEvents.ON_COMBAT_START, CombatEvents.ON_ROUND_START:
			return true
		CombatEvents.ON_FRIEND_SUMMONED:
			return (
				payload.target != null
				and payload.target != owner
				and payload.target.team == owner.team
			)
		CombatEvents.ON_FRIEND_DEATH:
			return (
				payload.target != null
				and payload.target != owner
				and payload.target.team == owner.team
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


static func _spec_trigger_matches(spec: EffectSpec, event_type: StringName) -> bool:
	if spec == null or event_type == StringName():
		return false
	return StringName(spec.trigger) == event_type


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
			var before := target.current_hp
			var heal_value := _scaled_action_value(owner, action.value)
			target.current_hp = mini(
				target.get_effective_max_hp(),
				target.current_hp + heal_value,
			)
			print("[Effect] %s heal %d->%d" % [target.id, before, target.current_hp])
			executed = true
		EffectAction.Type.SPAWN_UNIT:
			executed = _spawn_unit(action, payload, depth)
		EffectAction.Type.SPLIT_SELF:
			executed = not _split_self(owner, action, payload, depth).is_empty()
		EffectAction.Type.DEAL_DAMAGE:
			if _pipeline == null or target == null or not target.is_alive():
				return false
			var damage_value := _resolve_damage_value(owner, action)
			_pipeline.apply_rolled_damage(owner, target, damage_value)
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
			var scaled_percent := action.value * maxi(1, owner.level)
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


func _scaled_action_value(owner: UnitInstance, value: int) -> int:
	if owner == null:
		return value
	return value * maxi(1, owner.level)


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

	for i in count:
		var cell := _pick_spawn_cell(origin, i == 0)
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


func _spawn_unit(action: EffectAction, payload: CombatEventPayload, depth: int) -> bool:
	if action.spawn_unit == null or payload.target == null:
		return false
	if payload.target.is_alive():
		return false

	var team := payload.target.team
	var origin := _grid.find_cell_of(payload.target)
	if origin == Vector2i(-1, -1):
		origin = payload.target.grid_pos
	var spawn_total := maxi(1, action.spawn_count)
	var spawned_any := false
	for i in spawn_total:
		var cell := _pick_spawn_cell(origin, i == 0)
		if cell == Vector2i(-1, -1):
			break
		var spawned := UnitInstance.from_unit_data(action.spawn_unit, cell, team)
		if action.spawn_hp_override > 0:
			spawned.current_hp = action.spawn_hp_override
			if spawned.stats != null:
				spawned.stats.max_hp = maxi(spawned.stats.max_hp, action.spawn_hp_override)
		if not _grid.place(spawned, cell):
			continue
		spawned_any = true
		print("[Effect] spawn %s at %s hp=%d" % [spawned.id, str(cell), spawned.current_hp])
		_emit_friend_summoned(spawned, payload.target, depth)
		_emit_summoned(spawned, depth)
	return spawned_any


func _pick_spawn_cell(origin: Vector2i, prefer_origin: bool) -> Vector2i:
	if prefer_origin and _grid.can_place_at(origin):
		return origin
	var candidates := _grid.get_empty_cells()
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
	if spawned == null or _bus == null:
		return
	var summoned_payload := CombatEventPayload.new()
	summoned_payload.target = spawned
	summoned_payload.to_cell = spawned.grid_pos
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
	_enqueue_for_event(CombatEvents.ON_FRIEND_SUMMONED, summon_payload, depth + 1)
