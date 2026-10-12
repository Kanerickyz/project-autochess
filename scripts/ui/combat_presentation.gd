class_name CombatPresentation
extends Node

const _GridLine := preload("res://scripts/combat/grid_line.gd")

signal step_presentation_finished

var _presentation: Node
var _bus: CombatEventBus
var _skill_callout: CombatSkillCallout
var _camera_shake_3d: CameraShake3D
var pace_config: CombatPaceConfig
var _combat_tick: int = 0
var _step_events: Array[Dictionary] = []
var _playing: bool = false
var _active: bool = false
var _paused: bool = false


func setup(presentation: Node) -> void:
	_presentation = presentation


func set_skill_callout(callout: CombatSkillCallout) -> void:
	_skill_callout = callout


func set_camera_shake_3d(shake: CameraShake3D) -> void:
	_camera_shake_3d = shake


func bind_event_bus(bus: CombatEventBus) -> void:
	if _bus != null and _bus.combat_event.is_connected(_on_combat_event):
		_bus.combat_event.disconnect(_on_combat_event)
	_bus = bus
	if _bus != null:
		_bus.combat_event.connect(_on_combat_event)


func begin_combat() -> void:
	_active = true
	_playing = false
	_combat_tick = 0
	_step_events.clear()
	_clear_step_focus()
	if _presentation != null:
		_presentation.sync_units()


func end_combat() -> void:
	_active = false
	_paused = false
	_step_events.clear()
	_clear_step_focus()
	_reset_camera_shake()
	if _presentation != null:
		_purge_dead_grid_units()
		_presentation.sync_units()


func reset() -> void:
	_active = false
	_playing = false
	_paused = false
	_step_events.clear()
	_clear_step_focus()
	_reset_camera_shake()
	if _presentation != null:
		_presentation.sync_units()


func set_combat_tick(combat_tick: int) -> void:
	_combat_tick = combat_tick


func set_paused(paused: bool) -> void:
	_paused = paused
	if _presentation != null:
		_presentation.set_combat_animations_paused(paused)


func play_step() -> void:
	if _playing:
		return
	_playing = true
	_play_step_async()


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if not _active:
		return
	_step_events.append({
		"type": event_type,
		"payload": payload,
	})


func _unit_world(cell: Vector2i) -> Vector2:
	if _presentation == null:
		return Vector2.ZERO
	if _presentation.has_method("grid_to_unit_position"):
		return _presentation.grid_to_unit_position(cell)
	return _presentation.grid_to_world(cell)


func _logic_cell(unit: UnitInstance) -> Vector2i:
	if _presentation == null or unit == null:
		return Vector2i(-1, -1)
	return _presentation.get_logic_cell(unit)


func _presentation_grid() -> BoardGrid:
	if _presentation == null:
		return null
	return _presentation.get_grid()


func _unit_at_cell(cell: Vector2i) -> UnitInstance:
	if _presentation == null:
		return null
	return _presentation.get_unit_at_cell(cell)


func _play_step_async() -> void:
	var events := _step_events.duplicate()
	_step_events.clear()
	if _presentation != null:
		_presentation.set_combat_spawn_duration(_dur(CombatAnimationConfig.DUR_SPAWN))
	var spawn_tweens: Array[Tween] = []
	if _presentation != null:
		spawn_tweens = _presentation.sync_combat_step_units(true)
	await _wait_for_tweens(spawn_tweens)
	if events.is_empty():
		_finish_step()
		return
	await _play_events(events)
	if _presentation != null:
		_presentation.sync_units()
	_finish_step()


func _play_events(events: Array) -> void:
	if _presentation != null:
		_presentation.set_acting_units(_resolve_acting_units_from_events(events))

	var batch_presentation := _build_batch_damage_presentation(events)
	var pending_moves: Array[Dictionary] = []
	var pending_clash: CombatEventPayload = null
	var pending_clash_deferred: bool = false
	var pending_clash_fizzle_deferred: bool = false
	var pending_clash_defender: UnitInstance = null
	var pending_skill_callout_hold: int = -1
	var line_attack_handled_until: int = -1
	var exchange_handled_until: int = -1

	for i in events.size():
		var entry: Dictionary = events[i]
		var event_type: StringName = entry.get("type", &"")
		var payload: CombatEventPayload = entry.get("payload")

		if event_type == CombatEvents.ON_MOVE:
			pending_moves.append(entry)
			continue

		if not pending_moves.is_empty():
			await _play_moves(pending_moves)
			pending_moves.clear()

		match event_type:
			CombatEvents.ON_ATTACK_HIT:
				if pending_clash != null:
					await _play_attack_clash_back(pending_clash, pending_clash_defender)
				pending_clash = null
				pending_clash_deferred = false
				pending_clash_fizzle_deferred = false
				pending_clash_defender = null
				if payload != null:
					var exchange := _collect_melee_exchange(events, i)
					if not exchange.is_empty():
						await _play_attack_exchange(
							exchange["first_hit"],
							exchange["damages"],
						)
						var exchange_deaths: Array = exchange["deaths"]
						if not exchange_deaths.is_empty():
							await _play_deaths_batch_parallel(exchange_deaths)
						exchange_handled_until = exchange["last_index"]
						continue
					pending_clash = payload
					if _strike_has_pre_damage_swap(events, i):
						pending_clash_deferred = true
						_stop_units_animations_and_snap([payload.source, payload.target])
					elif _strike_has_pre_damage_fizzle(events, i):
						pending_clash_fizzle_deferred = true
						_stop_units_animations_and_snap([payload.source, payload.target])
					else:
						await _play_attack_clash_out(payload)
			CombatEvents.ON_LINE_ATTACK:
				if pending_clash != null:
					await _play_attack_clash_back(pending_clash, pending_clash_defender)
					pending_clash = null
					pending_clash_deferred = false
					pending_clash_defender = null
				if payload != null:
					var followups := _collect_line_attack_followups(events, i, payload.source)
					line_attack_handled_until = followups["last_index"]
					await _play_line_attack(payload, followups["damages"])
					var line_deaths: Array = followups["deaths"]
					if not line_deaths.is_empty():
						await _play_deaths_batch_parallel(line_deaths)
			CombatEvents.ON_EFFECT_FIZZLED:
				if payload != null:
					var fizzle_hold := _show_fizzle_callout(payload)
					if pending_clash_fizzle_deferred and pending_clash != null:
						pending_clash_fizzle_deferred = false
						await _play_attack_clash_out(pending_clash, pending_clash_defender)
						pending_skill_callout_hold = fizzle_hold
					else:
						await _finish_skill_callout_hold(fizzle_hold)
			CombatEvents.ON_EFFECT_RESOLVED:
				if payload == null:
					continue
				if (
					payload.effect_action != null
					and payload.effect_action.action_type == EffectAction.Type.SWAP_POSITIONS
				):
					if pending_clash_deferred and pending_clash != null:
						pending_skill_callout_hold = _begin_skill_callout(payload)
						_stop_strike_animations_for_swap(pending_clash, payload)
						await _snap_swap_positions(payload)
						pending_clash_defender = payload.target
						await _play_attack_clash_out(pending_clash, pending_clash_defender)
					else:
						await _play_swap_skill(payload)
				else:
					var is_fuse_batch := not payload.fuse_explosion_cells.is_empty()
					if payload.effect_entries.size() > 1 or is_fuse_batch:
						var batch_owner := (
							payload.effect_owner
							if payload.effect_owner != null
							else payload.source
						)
						var owner_id := batch_owner.instance_id if batch_owner != null else -1
						var deferred_damages := _get_deferred_batch_payloads(
							batch_presentation,
							"deferred_damages",
							owner_id,
						)
						var deferred_deaths := _get_deferred_batch_payloads(
							batch_presentation,
							"deferred_deaths",
							owner_id,
						)
						await _play_effect_batch(
							payload,
							deferred_damages,
							deferred_deaths,
						)
					else:
						await _play_effect(payload)
			CombatEvents.ON_DAMAGE_TAKEN:
				if payload == null:
					continue
				if i <= line_attack_handled_until or i <= exchange_handled_until:
					continue
				if _should_defer_batch_event(payload, batch_presentation):
					var defer_owner_id := payload.source.instance_id
					if not batch_presentation["deferred_damages"].has(defer_owner_id):
						batch_presentation["deferred_damages"][defer_owner_id] = (
							[] as Array[CombatEventPayload]
						)
					(
						batch_presentation["deferred_damages"][defer_owner_id]
						as Array[CombatEventPayload]
					).append(payload)
					continue
				if pending_clash != null:
					var clash_defender := pending_clash_defender
					await _play_melee_strike_damage(payload, pending_clash, clash_defender)
					pending_clash = null
					pending_clash_deferred = false
					pending_clash_fizzle_deferred = false
					pending_clash_defender = null
					if pending_skill_callout_hold >= 0:
						var hold_started := pending_skill_callout_hold
						pending_skill_callout_hold = -1
						await _finish_skill_callout_hold(hold_started)
				else:
					await _play_damage(payload, false)
			CombatEvents.ON_DEATH:
				if payload == null:
					continue
				if i <= line_attack_handled_until or i <= exchange_handled_until:
					continue
				if _should_defer_batch_event(payload, batch_presentation):
					var death_owner_id := (
						payload.source.instance_id if payload.source != null else -1
					)
					if death_owner_id >= 0:
						if not batch_presentation["deferred_deaths"].has(death_owner_id):
							batch_presentation["deferred_deaths"][death_owner_id] = (
								[] as Array[CombatEventPayload]
							)
						(
							batch_presentation["deferred_deaths"][death_owner_id]
							as Array[CombatEventPayload]
						).append(payload)
					continue
				await _play_death(payload)

	if not pending_moves.is_empty():
		await _play_moves(pending_moves)

	if pending_clash != null:
		await _play_attack_clash_back(pending_clash, pending_clash_defender)
	if pending_skill_callout_hold >= 0:
		var hold_started := pending_skill_callout_hold
		pending_skill_callout_hold = -1
		await _finish_skill_callout_hold(hold_started)


func _collect_line_attack_followups(
	events: Array,
	line_index: int,
	source: UnitInstance,
) -> Dictionary:
	var damages: Array[CombatEventPayload] = []
	var deaths: Array[CombatEventPayload] = []
	var last_index := line_index
	if source == null:
		return {
			"damages": damages,
			"deaths": deaths,
			"last_index": last_index,
		}
	for j in range(line_index + 1, events.size()):
		var entry: Dictionary = events[j]
		var event_type: StringName = entry.get("type", &"")
		var payload: CombatEventPayload = entry.get("payload")
		match event_type:
			CombatEvents.ON_DAMAGE_TAKEN:
				if not _line_attack_payload_from_source(payload, source):
					return {
						"damages": damages,
						"deaths": deaths,
						"last_index": last_index,
					}
				damages.append(payload)
				last_index = j
			CombatEvents.ON_DEATH:
				if not _line_attack_payload_from_source(payload, source):
					return {
						"damages": damages,
						"deaths": deaths,
						"last_index": last_index,
					}
				deaths.append(payload)
				last_index = j
			CombatEvents.ON_DEAL_DAMAGE, CombatEvents.ON_CRIT, CombatEvents.ON_KILL, CombatEvents.ON_FRIEND_DEATH:
				last_index = j
			_:
				return {
					"damages": damages,
					"deaths": deaths,
					"last_index": last_index,
				}
	return {
		"damages": damages,
		"deaths": deaths,
		"last_index": last_index,
	}


func _line_attack_payload_from_source(
	payload: CombatEventPayload,
	source: UnitInstance,
) -> bool:
	if payload == null or source == null:
		return false
	return payload.source != null and payload.source.instance_id == source.instance_id


func _strike_has_pre_damage_swap(events: Array, hit_index: int) -> bool:
	for j in range(hit_index + 1, events.size()):
		var entry: Dictionary = events[j]
		var event_type: StringName = entry.get("type", &"")
		if event_type == CombatEvents.ON_ATTACK_HIT:
			break
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			break
		if event_type == CombatEvents.ON_EFFECT_RESOLVED:
			var swap_payload: CombatEventPayload = entry.get("payload")
			if (
				swap_payload != null
				and swap_payload.effect_action != null
				and swap_payload.effect_action.action_type == EffectAction.Type.SWAP_POSITIONS
			):
				return true
	return false


func _strike_has_pre_damage_fizzle(events: Array, hit_index: int) -> bool:
	for j in range(hit_index + 1, events.size()):
		var entry: Dictionary = events[j]
		var event_type: StringName = entry.get("type", &"")
		if event_type == CombatEvents.ON_ATTACK_HIT:
			break
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			break
		if event_type == CombatEvents.ON_EFFECT_FIZZLED:
			return true
	return false


func _collect_strike_followups(
	events: Array,
	hit_index: int,
	striker: UnitInstance,
) -> Dictionary:
	var damages: Array[CombatEventPayload] = []
	var deaths: Array[CombatEventPayload] = []
	var last_index := hit_index
	var next_hit_index := -1
	if striker == null:
		return {
			"damages": damages,
			"deaths": deaths,
			"last_index": last_index,
			"next_hit_index": next_hit_index,
		}
	for j in range(hit_index + 1, events.size()):
		var entry: Dictionary = events[j]
		var event_type: StringName = entry.get("type", &"")
		var payload: CombatEventPayload = entry.get("payload")
		match event_type:
			CombatEvents.ON_ATTACK_HIT:
				next_hit_index = j
				return {
					"damages": damages,
					"deaths": deaths,
					"last_index": last_index,
					"next_hit_index": next_hit_index,
				}
			CombatEvents.ON_LINE_ATTACK:
				return {
					"damages": damages,
					"deaths": deaths,
					"last_index": last_index,
					"next_hit_index": -1,
				}
			CombatEvents.ON_DAMAGE_TAKEN:
				if payload == null or payload.source != striker:
					return {
						"damages": damages,
						"deaths": deaths,
						"last_index": last_index,
						"next_hit_index": -1,
					}
				damages.append(payload)
				last_index = j
			CombatEvents.ON_DEATH:
				if payload == null or payload.source != striker:
					return {
						"damages": damages,
						"deaths": deaths,
						"last_index": last_index,
						"next_hit_index": -1,
					}
				deaths.append(payload)
				last_index = j
			CombatEvents.ON_EFFECT_RESOLVED, CombatEvents.ON_EFFECT_FIZZLED, CombatEvents.ON_MOVE:
				return {
					"damages": damages,
					"deaths": deaths,
					"last_index": last_index,
					"next_hit_index": -1,
				}
			CombatEvents.ON_DEAL_DAMAGE, CombatEvents.ON_CRIT, CombatEvents.ON_KILL, CombatEvents.ON_FRIEND_DEATH:
				last_index = j
			_:
				return {
					"damages": damages,
					"deaths": deaths,
					"last_index": last_index,
					"next_hit_index": -1,
				}
	return {
		"damages": damages,
		"deaths": deaths,
		"last_index": last_index,
		"next_hit_index": next_hit_index,
	}


func _collect_melee_exchange(events: Array, hit_index: int) -> Dictionary:
	var first_entry: Dictionary = events[hit_index]
	if first_entry.get("type") != CombatEvents.ON_ATTACK_HIT:
		return {}
	var first_hit: CombatEventPayload = first_entry.get("payload")
	if first_hit == null or first_hit.source == null or first_hit.target == null:
		return {}
	if _strike_has_pre_damage_swap(events, hit_index):
		return {}
	if _strike_has_pre_damage_fizzle(events, hit_index):
		return {}

	var attacker := first_hit.source
	var defender := first_hit.target
	var first_strike := _collect_strike_followups(events, hit_index, attacker)
	if first_strike["next_hit_index"] < 0:
		return {}

	var counter_index: int = first_strike["next_hit_index"]
	var counter_entry: Dictionary = events[counter_index]
	if counter_entry.get("type") != CombatEvents.ON_ATTACK_HIT:
		return {}
	var counter_hit: CombatEventPayload = counter_entry.get("payload")
	if (
		counter_hit == null
		or counter_hit.source != defender
		or counter_hit.target != attacker
	):
		return {}
	if _strike_has_pre_damage_swap(events, counter_index):
		return {}
	if _strike_has_pre_damage_fizzle(events, counter_index):
		return {}

	var counter_strike := _collect_strike_followups(events, counter_index, defender)
	var damages: Array[CombatEventPayload] = []
	damages.append_array(first_strike["damages"])
	damages.append_array(counter_strike["damages"])
	if damages.size() < 2:
		return {}

	var deaths: Array[CombatEventPayload] = []
	deaths.append_array(first_strike["deaths"])
	deaths.append_array(counter_strike["deaths"])
	var last_index: int = maxi(first_strike["last_index"], counter_strike["last_index"])

	return {
		"first_hit": first_hit,
		"damages": damages,
		"deaths": deaths,
		"last_index": last_index,
	}


func _play_moves(move_events: Array) -> void:
	if move_events.is_empty() or _presentation == null:
		return

	var by_unit: Dictionary = {}
	var unit_order: Array[int] = []
	for move_entry in move_events:
		var payload: CombatEventPayload = move_entry.get("payload")
		if payload == null or payload.source == null:
			continue
		var unit_id: int = payload.source.instance_id
		if not by_unit.has(unit_id):
			by_unit[unit_id] = []
			unit_order.append(unit_id)
		(by_unit[unit_id] as Array).append(payload)

	if unit_order.is_empty():
		return

	if unit_order.size() == 1:
		await _play_unit_moves(by_unit[unit_order[0]])
		return

	var remaining := unit_order.size()
	for unit_id in unit_order:
		_play_unit_moves(by_unit[unit_id], func() -> void:
			remaining -= 1
		)

	while remaining > 0:
		await get_tree().process_frame


func _play_unit_moves(payloads: Array, on_finished: Callable = Callable()) -> void:
	if payloads.is_empty():
		if on_finished.is_valid():
			on_finished.call()
		return

	var first_payload: CombatEventPayload = payloads[0]
	if first_payload == null or first_payload.source == null:
		if on_finished.is_valid():
			on_finished.call()
		return

	var unit: UnitInstance = first_payload.source
	var node := _presentation.get_unit_node(unit.instance_id) as Node

	if _uses_sliding_move_presentation(unit) and payloads.size() > 1:
		var last_payload: CombatEventPayload = payloads[payloads.size() - 1]
		var from_cell := first_payload.from_cell
		var to_cell := last_payload.to_cell
		var duration := _dur(CombatAnimationConfig.DUR_SLIDE_CHARGE_PER_CELL) * float(payloads.size())
		duration = maxf(duration, _dur(CombatAnimationConfig.DUR_MOVE))
		var tween: Tween = _presentation.animate_unit_move(unit, from_cell, to_cell, duration)
		await _wait_for_tween(tween)
		_finalize_move(node, to_cell)
	elif _uses_sliding_move_presentation(unit):
		var payload: CombatEventPayload = first_payload
		var duration := _dur(CombatAnimationConfig.DUR_SLIDE_CHARGE_PER_CELL)
		duration = maxf(duration, _dur(CombatAnimationConfig.DUR_MOVE))
		var tween: Tween = _presentation.animate_unit_move(
			unit,
			payload.from_cell,
			payload.to_cell,
			duration,
		)
		await _wait_for_tween(tween)
		_finalize_move(node, payload.to_cell)
	elif _uses_teleport_move_presentation(unit):
		for payload in payloads:
			if payload == null or payload.source == null:
				continue
			var step_node := _presentation.get_unit_node(payload.source.instance_id) as Node
			if step_node == null:
				continue
			var from_world := _unit_world(payload.from_cell)
			var to_world := _unit_world(payload.to_cell)
			var move_dur := _dur(CombatAnimationConfig.DUR_MOVE)
			var depart_dur := move_dur * CombatAnimationConfig.DUR_TELEPORT_DEPART_FRAC
			var arrive_dur := maxf(move_dur - depart_dur, 0.04)
			var pulse_dur := arrive_dur * CombatAnimationConfig.TELEPORT_CELL_PULSE_FRAC
			step_node.stop_active_tweens(false)
			_presentation.spawn_teleport_afterimage(from_world, depart_dur)
			var to_cell: Vector2i = payload.to_cell
			var move_tween: Tween = step_node.play_teleport_move(
				from_world,
				to_world,
				move_dur,
				func() -> void:
					_presentation.pulse_cell_teleport(to_cell, pulse_dur),
			)
			await _wait_for_tween(move_tween)
			_finalize_move(step_node, payload.to_cell)
	else:
		for payload in payloads:
			if payload == null or payload.source == null:
				continue
			var step_node := _presentation.get_unit_node(payload.source.instance_id) as Node
			var tween: Tween = _presentation.animate_unit_move(
				payload.source,
				payload.from_cell,
				payload.to_cell,
				_dur(CombatAnimationConfig.DUR_MOVE),
			)
			await _wait_for_tween(tween)
			_finalize_move(step_node, payload.to_cell)

	if on_finished.is_valid():
		on_finished.call()


func _uses_sliding_move_presentation(unit: UnitInstance) -> bool:
	return unit != null and unit.uses_sliding_move_presentation()


func _uses_teleport_move_presentation(unit: UnitInstance) -> bool:
	return unit != null and unit.uses_teleport_move_presentation()


func _finalize_move(node: Node, to_cell: Vector2i) -> void:
	if node == null or _presentation == null:
		return
	node.stop_active_tweens(false)
	node.update_home_position(_unit_world(to_cell))
	_reset_unit_scale(node)
	node.refresh_display()


func _reset_unit_scale(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).scale = Vector3.ONE
	elif node is Node2D:
		(node as Node2D).scale = Vector2.ONE


func _play_melee_strike_damage(
	payload: CombatEventPayload,
	attack_hit: CombatEventPayload,
	clash_defender: UnitInstance = null,
) -> void:
	if _presentation == null:
		return
	if attack_hit != null:
		_set_attack_highlight(_cells_for_melee_attack([payload]))
	var tweens := _start_damage(payload, false, true)
	await _wait_for_tweens(tweens)
	if attack_hit != null:
		var back_tweens := _start_attack_clash_back_tweens(attack_hit, clash_defender)
		await _wait_for_tweens(back_tweens)
		_clear_attack_highlight()
	var node := _ensure_display(payload.target)
	if node != null:
		node.refresh_display()
		await _wait_for_tween(node.tween_hp_visual(_pace_scale()))


func _play_attack_clash_out(
	attack_hit: CombatEventPayload,
	clash_defender: UnitInstance = null,
) -> void:
	if _presentation == null or attack_hit == null:
		return
	var attacker := attack_hit.source
	var defender := clash_defender if clash_defender != null else attack_hit.target
	if attacker == null or defender == null:
		return
	_stop_units_animations_and_snap([attacker, defender])
	var attacker_node := _ensure_display(attacker)
	var defender_node := _ensure_display(defender)
	var defender_cell := _logic_cell(defender)
	var attacker_cell := _logic_cell(attacker)
	var clash := _unit_world(attacker_cell).lerp(
		_unit_world(defender_cell),
		0.5,
	)
	var out_dur := _dur(CombatAnimationConfig.DUR_ATTACK_OUT)
	var out_tweens: Array[Tween] = []
	if attacker_node != null:
		out_tweens.append(
			attacker_node.play_clash_out(
				clash,
				out_dur,
				CombatAnimationConfig.CLASH_TRAVEL_RATIO_ATTACK,
				CombatAnimationConfig.CLASH_ATTACK_IMPACT_SCALE,
			)
		)
	if defender_node != null:
		out_tweens.append(
			defender_node.play_clash_out(
				clash,
				out_dur,
				CombatAnimationConfig.CLASH_TRAVEL_RATIO_DEFEND,
			)
		)
	await _wait_for_tweens(out_tweens)
	_play_melee_clash_contact_fx(attacker_cell, defender_cell, clash)


func _play_attack_clash_back(
	attack_hit: CombatEventPayload,
	clash_defender: UnitInstance = null,
) -> void:
	if _presentation == null or attack_hit == null:
		return
	await _wait_for_tweens(_start_attack_clash_back_tweens(attack_hit, clash_defender))


func _start_attack_clash_back_tweens(
	attack_hit: CombatEventPayload,
	clash_defender: UnitInstance = null,
) -> Array[Tween]:
	var tweens: Array[Tween] = []
	if _presentation == null or attack_hit == null:
		return tweens
	var defender := clash_defender if clash_defender != null else attack_hit.target
	var back_dur := _dur(CombatAnimationConfig.DUR_ATTACK_BACK)
	var attacker_node := _ensure_display(attack_hit.source)
	var defender_node := _ensure_display(defender) if defender != null else null
	if attacker_node != null:
		tweens.append(attacker_node.play_clash_back(back_dur))
	if defender_node != null:
		tweens.append(defender_node.play_clash_back(back_dur))
	return tweens


func _play_attack_exchange(
	attack_hit: CombatEventPayload,
	damage_events: Array[CombatEventPayload],
) -> void:
	if _presentation == null:
		return
	var attacker := attack_hit.source
	var defender := attack_hit.target
	if attacker == null or defender == null:
		return

	_set_attack_highlight(_cells_for_melee_attack(damage_events))

	var attacker_node := _ensure_display(attacker)
	var defender_node := _ensure_display(defender)
	var defender_cell := _logic_cell(defender)
	var attacker_cell := _logic_cell(attacker)
	var attacker_world := _unit_world(attacker_cell)
	var defender_world := _unit_world(defender_cell)
	var clash := attacker_world.lerp(defender_world, 0.5)
	var out_dur := _dur(CombatAnimationConfig.DUR_ATTACK_OUT)
	var back_dur := _dur(CombatAnimationConfig.DUR_ATTACK_BACK)

	var out_tweens: Array[Tween] = []
	if attacker_node != null:
		out_tweens.append(
			attacker_node.play_clash_out(
				clash,
				out_dur,
				CombatAnimationConfig.CLASH_TRAVEL_RATIO_ATTACK,
				CombatAnimationConfig.CLASH_ATTACK_IMPACT_SCALE,
			)
		)
	if defender_node != null:
		out_tweens.append(
			defender_node.play_clash_out(
				clash,
				out_dur,
				CombatAnimationConfig.CLASH_TRAVEL_RATIO_DEFEND,
			)
		)
	await _wait_for_tweens(out_tweens)
	_play_melee_clash_contact_fx(attacker_cell, defender_cell, clash)

	var damage_tweens := _start_damages(damage_events, false, true)
	var back_tweens: Array[Tween] = []
	if attacker_node != null:
		back_tweens.append(attacker_node.play_clash_back(back_dur))
	if defender_node != null:
		back_tweens.append(defender_node.play_clash_back(back_dur))
	await _wait_for_tweens(damage_tweens + back_tweens)

	for payload in damage_events:
		if payload == null or payload.target == null:
			continue
		var node := _ensure_display(payload.target)
		if node != null:
			node.refresh_display()
			await _wait_for_tween(node.tween_hp_visual(_pace_scale()))

	_clear_attack_highlight()


func _play_damage(payload: CombatEventPayload, skill_style: bool) -> void:
	if payload == null or payload.target == null or _presentation == null:
		return
	var tweens := _start_damage(payload, skill_style)
	await _wait_for_tweens(tweens)
	var node := _ensure_display(payload.target)
	if node == null:
		return
	node.refresh_display()
	await _wait_for_tween(node.tween_hp_visual(_pace_scale()))


func _start_damages(
	damage_events: Array[CombatEventPayload],
	skill_style: bool,
	suppress_knockback: bool = false,
) -> Array[Tween]:
	var tweens: Array[Tween] = []
	for payload in damage_events:
		tweens.append_array(_start_damage(payload, skill_style, suppress_knockback))
	return tweens


func _start_damage(
	payload: CombatEventPayload,
	skill_style: bool,
	suppress_knockback: bool = false,
) -> Array[Tween]:
	var tweens: Array[Tween] = []
	if payload == null or payload.target == null or _presentation == null:
		return tweens
	var node := _ensure_display(payload.target)
	if node == null:
		return tweens

	var pace_scale := _pace_scale()
	var is_crit := payload.is_crit
	if payload.amount > 0:
		_request_damage_shake(payload.amount, skill_style, is_crit)
		var pop: Tween = node.pop_damage_number(
			payload.amount,
			_dur(CombatAnimationConfig.DUR_DAMAGE_POPUP),
			is_crit,
		)
		if pop != null:
			tweens.append(pop)
		if is_crit:
			var target_cell := _logic_cell(payload.target)
			if target_cell != Vector2i(-1, -1):
				_presentation.spawn_crit_hit_spark(
					_presentation.grid_to_world(target_cell),
					_dur(CombatAnimationConfig.DUR_CRIT_HIT_SPARK),
				)

	var knockback := Vector2.ZERO
	if not suppress_knockback:
		knockback = _knockback_dir(payload.source, payload.target)
	var impact: Tween = null
	if skill_style:
		impact = node.play_skill_damage_flash(pace_scale, knockback, payload.amount)
	else:
		impact = node.play_hit_impact(pace_scale, knockback, payload.amount, is_crit)
	if impact != null:
		tweens.append(impact)
	return tweens


func _request_damage_shake(amount: int, skill_style: bool, is_crit: bool = false) -> void:
	if amount <= 0:
		return
	var intensity := CombatAnimationConfig.shake_intensity(amount, skill_style)
	if is_crit:
		intensity += CombatAnimationConfig.CRIT_SHAKE_BONUS
	_add_camera_impulse(intensity)


func _add_camera_impulse(intensity: float) -> void:
	if intensity <= 0.0:
		return
	intensity *= CombatAnimationConfig.SHAKE_AMPLITUDE_SCALE
	if _camera_shake_3d != null:
		_camera_shake_3d.add_impulse(intensity)


func _reset_camera_shake() -> void:
	if _camera_shake_3d != null:
		_camera_shake_3d.reset()


func _play_melee_clash_contact_fx(
	attacker_cell: Vector2i,
	defender_cell: Vector2i,
	clash_world: Vector2,
) -> void:
	if _presentation == null:
		return
	var spark_dur := _dur(CombatAnimationConfig.DUR_MELEE_CLASH_SPARK)
	var pulse_dur := _dur(CombatAnimationConfig.DUR_MELEE_CLASH_CELL_PULSE)
	_presentation.spawn_melee_clash_spark(clash_world, spark_dur)
	var cells: Array[Vector2i] = []
	if attacker_cell != Vector2i(-1, -1):
		cells.append(attacker_cell)
	if defender_cell != Vector2i(-1, -1) and defender_cell != attacker_cell:
		cells.append(defender_cell)
	_presentation.pulse_cells_impact(
		cells,
		CombatAnimationConfig.MELEE_CLASH_CELL_PULSE_TINT,
		pulse_dur,
	)
	_add_camera_impulse(CombatAnimationConfig.MELEE_CLASH_SHAKE)


func _knockback_dir(source: UnitInstance, target: UnitInstance) -> Vector2:
	if source == null or target == null or _presentation == null:
		return Vector2.ZERO
	var from_cell := _logic_cell(source)
	var to_cell := _logic_cell(target)
	var delta := Vector2(to_cell - from_cell)
	if delta.length_squared() < 0.01:
		return Vector2.RIGHT
	return delta.normalized()


func _play_line_attack(
	payload: CombatEventPayload,
	damage_events: Array[CombatEventPayload],
) -> void:
	if payload == null or payload.source == null or _presentation == null:
		return
	_set_attack_highlight(_cells_for_line_attack(payload))
	await _wait_paced_seconds(_dur(CombatAnimationConfig.DUR_ATTACK_OUT))
	if not damage_events.is_empty():
		await _play_damage_batch_parallel(damage_events, true)
	_clear_attack_highlight()


func _play_effect(payload: CombatEventPayload) -> void:
	if payload == null or payload.effect_action == null or _presentation == null:
		return
	var hold_started := Time.get_ticks_msec()
	var owner := payload.effect_owner if payload.effect_owner != null else payload.source
	_show_skill_callout(owner, payload.effect_spec, payload.effect_action)
	var action := payload.effect_action
	var target := payload.target
	var pace_scale := _pace_scale()
	match action.action_type:
		EffectAction.Type.MODIFY_STAT:
			if target != null:
				var node := _ensure_display(target)
				if node != null:
					var tween: Tween = node.play_buff_pop(pace_scale)
					if tween != null:
						await _wait_for_tween(tween)
					node.refresh_display()
		EffectAction.Type.HEAL:
			if target != null:
				var heal_node := _ensure_display(target)
				if heal_node != null:
					var heal_tween: Tween = heal_node.play_heal_pulse(pace_scale)
					if heal_tween != null:
						await _wait_for_tween(heal_tween)
					heal_node.refresh_display()
					var hp_tween: Tween = heal_node.tween_hp_visual(pace_scale)
					await _wait_for_tween(hp_tween)
		EffectAction.Type.DEAL_DAMAGE:
			await _play_damage(payload, true)
		EffectAction.Type.SPAWN_UNIT:
			await _play_spawn_pop_for_unit(target)
		EffectAction.Type.SPLIT_SELF:
			if payload.removed_owner_instance_id >= 0:
				_presentation.remove_unit_node(payload.removed_owner_instance_id)
			await _play_spawn_pop_for_unit(target)
		EffectAction.Type.SWAP_POSITIONS:
			await _snap_swap_positions(payload)
		EffectAction.Type.FUSE_EXPLODE:
			if not payload.fuse_explosion_cells.is_empty():
				await _play_fuse_explosion_preview(payload.fuse_explosion_cells)
			_clear_attack_highlight()
	var elapsed_sec := (Time.get_ticks_msec() - hold_started) / 1000.0
	var remaining := _skill_callout_hold_sec() - elapsed_sec
	if remaining > 0.0:
		await _wait_paced_seconds(remaining)
	_hide_skill_callout()


func _play_effect_batch(
	payload: CombatEventPayload,
	deferred_damages: Array[CombatEventPayload] = [],
	deferred_deaths: Array[CombatEventPayload] = [],
) -> void:
	if payload == null or payload.effect_entries.is_empty() or _presentation == null:
		return
	var hold_started := Time.get_ticks_msec()
	var owner := payload.effect_owner if payload.effect_owner != null else payload.source
	_show_skill_callout(owner, payload.effect_spec, payload.effect_action)
	var pace_scale := _pace_scale()

	if not payload.fuse_explosion_cells.is_empty():
		await _play_fuse_explosion_preview(payload.fuse_explosion_cells)

	if _batch_has_action_type(payload, EffectAction.Type.DEAL_DAMAGE):
		if not deferred_damages.is_empty():
			await _play_damage_batch_parallel(deferred_damages, true)
		else:
			for entry in payload.effect_entries:
				var action: EffectAction = entry.get("action")
				var target: UnitInstance = entry.get("target")
				if action == null or action.action_type != EffectAction.Type.DEAL_DAMAGE:
					continue
				var dmg_payload := CombatEventPayload.new()
				dmg_payload.source = owner
				dmg_payload.target = target
				dmg_payload.effect_action = action
				dmg_payload.effect_owner = owner
				await _play_damage(dmg_payload, true)

	if not deferred_deaths.is_empty():
		await _play_deaths_batch_parallel(deferred_deaths)

	if payload.removed_owner_instance_id >= 0:
		_presentation.remove_unit_node(payload.removed_owner_instance_id)

	for entry in payload.effect_entries:
		var action: EffectAction = entry.get("action")
		var target: UnitInstance = entry.get("target")
		if action == null:
			continue
		match action.action_type:
			EffectAction.Type.DEAL_DAMAGE:
				pass
			EffectAction.Type.SPAWN_UNIT:
				await _play_spawn_pop_for_unit(target)
			EffectAction.Type.SPLIT_SELF:
				await _play_spawn_pop_for_unit(target)
			EffectAction.Type.SWAP_POSITIONS:
				var swap_payload := CombatEventPayload.new()
				swap_payload.source = owner
				swap_payload.target = target
				swap_payload.effect_action = action
				swap_payload.effect_owner = owner
				swap_payload.effect_spec = payload.effect_spec
				await _snap_swap_positions(swap_payload)

	var by_target: Dictionary = {}
	for entry in payload.effect_entries:
		var action: EffectAction = entry.get("action")
		var target: UnitInstance = entry.get("target")
		if action == null or target == null:
			continue
		match action.action_type:
			EffectAction.Type.MODIFY_STAT, EffectAction.Type.HEAL:
				var target_id: int = target.instance_id
				if not by_target.has(target_id):
					by_target[target_id] = {
						"target": target,
						"has_buff": false,
						"has_heal": false,
					}
				var group: Dictionary = by_target[target_id]
				if action.action_type == EffectAction.Type.MODIFY_STAT:
					group["has_buff"] = true
				else:
					group["has_heal"] = true

	var pulse_tweens: Array = []
	var heal_target_ids: Dictionary = {}
	var sequential_targets: Array = []
	for target_id in by_target:
		var group: Dictionary = by_target[target_id]
		var target: UnitInstance = group.get("target")
		if target == null:
			continue
		var node := _ensure_display(target)
		if node == null:
			continue
		var has_buff: bool = group.get("has_buff", false)
		var has_heal: bool = group.get("has_heal", false)
		if has_buff and has_heal:
			sequential_targets.append({
				"node": node,
				"target_id": target_id,
			})
			continue
		if has_buff:
			var buff_tween: Tween = node.play_buff_pop(pace_scale)
			if buff_tween != null:
				pulse_tweens.append(buff_tween)
		if has_heal:
			var heal_tween: Tween = node.play_heal_pulse(pace_scale)
			if heal_tween != null:
				pulse_tweens.append(heal_tween)
			heal_target_ids[target_id] = node

	var sequential_remaining: Array[int] = [sequential_targets.size()]
	if sequential_remaining[0] > 0:
		for entry in sequential_targets:
			var node: Node = entry.get("node")
			var target_id: int = entry.get("target_id", -1)
			_play_batch_target_pulse(node, pace_scale, target_id, heal_target_ids, func() -> void:
				sequential_remaining[0] -= 1
			)
		while sequential_remaining[0] > 0:
			await get_tree().process_frame

	await _wait_for_tweens_parallel(pulse_tweens)

	var hp_tweens: Array = []
	for target_id in by_target:
		var target: UnitInstance = (by_target[target_id] as Dictionary).get("target")
		var node := _ensure_display(target)
		if node != null:
			node.refresh_display()
		if heal_target_ids.has(target_id) and node != null:
			var hp_tween: Tween = node.tween_hp_visual(pace_scale)
			if hp_tween != null:
				hp_tweens.append(hp_tween)
	await _wait_for_tweens_parallel(hp_tweens)

	var elapsed_sec := (Time.get_ticks_msec() - hold_started) / 1000.0
	var remaining := _skill_callout_hold_sec() - elapsed_sec
	if remaining > 0.0:
		await _wait_paced_seconds(remaining)
	if not payload.fuse_explosion_cells.is_empty():
		_clear_attack_highlight()
	_hide_skill_callout()


func _build_batch_damage_presentation(events: Array) -> Dictionary:
	var owner_targets: Dictionary = {}
	var fuse_owner_ids: Dictionary = {}
	for entry in events:
		if entry.get("type") != CombatEvents.ON_EFFECT_RESOLVED:
			continue
		var payload: CombatEventPayload = entry.get("payload")
		if payload == null:
			continue
		var owner := (
			payload.effect_owner if payload.effect_owner != null else payload.source
		)
		if owner == null:
			continue
		if not payload.fuse_explosion_cells.is_empty():
			fuse_owner_ids[owner.instance_id] = true
			var fuse_targets: Dictionary = {}
			for batch_entry in payload.effect_entries:
				var fuse_action: EffectAction = batch_entry.get("action")
				var fuse_target: UnitInstance = batch_entry.get("target")
				if fuse_action == null or fuse_target == null:
					continue
				if fuse_action.action_type != EffectAction.Type.DEAL_DAMAGE:
					continue
				fuse_targets[fuse_target.instance_id] = true
			owner_targets[owner.instance_id] = fuse_targets
			continue
		if payload.effect_entries.size() <= 1:
			continue
		var targets: Dictionary = {}
		var has_damage := false
		for batch_entry in payload.effect_entries:
			var action: EffectAction = batch_entry.get("action")
			var target: UnitInstance = batch_entry.get("target")
			if action == null or target == null:
				continue
			if action.action_type != EffectAction.Type.DEAL_DAMAGE:
				continue
			has_damage = true
			targets[target.instance_id] = true
		if has_damage:
			owner_targets[owner.instance_id] = targets
	return {
		"owner_targets": owner_targets,
		"deferred_damages": {},
		"deferred_deaths": {},
		"fuse_owner_ids": fuse_owner_ids,
	}


func _should_defer_batch_event(
	payload: CombatEventPayload,
	batch_presentation: Dictionary,
) -> bool:
	if _should_defer_batch_damage(payload, batch_presentation):
		return true
	if payload == null or payload.source == null or payload.target == null:
		return false
	var fuse_owner_ids: Dictionary = batch_presentation.get("fuse_owner_ids", {})
	if not fuse_owner_ids.has(payload.source.instance_id):
		return false
	return payload.source.instance_id == payload.target.instance_id


func _should_defer_batch_damage(
	payload: CombatEventPayload,
	batch_presentation: Dictionary,
) -> bool:
	if payload == null or payload.source == null or payload.target == null:
		return false
	var owner_targets: Dictionary = batch_presentation.get("owner_targets", {})
	var targets: Dictionary = owner_targets.get(payload.source.instance_id, {})
	return targets.has(payload.target.instance_id)


func _play_spawn_pop_for_unit(spawned: UnitInstance) -> void:
	if spawned == null or _presentation == null:
		return
	var cell := _logic_cell(spawned)
	var unit := _unit_at_cell(cell)
	if unit == null:
		unit = spawned
	var spawn_node := _presentation.ensure_unit_node(unit) as Node
	if spawn_node == null:
		return
	spawn_node.update_home_position(_unit_world(cell))
	spawn_node.bind_unit(unit)
	var spawn_tween: Tween = spawn_node.play_spawn_pop(_dur(CombatAnimationConfig.DUR_SPAWN))
	await _wait_for_tween(spawn_tween)


func _batch_has_action_type(payload: CombatEventPayload, action_type: EffectAction.Type) -> bool:
	if payload == null:
		return false
	for entry in payload.effect_entries:
		var action: EffectAction = entry.get("action")
		if action != null and action.action_type == action_type:
			return true
	return false


func _get_deferred_batch_payloads(
	batch_presentation: Dictionary,
	key: StringName,
	owner_id: int,
) -> Array[CombatEventPayload]:
	var by_owner: Dictionary = batch_presentation.get(key, {})
	if owner_id < 0 or not by_owner.has(owner_id):
		return [] as Array[CombatEventPayload]
	return by_owner[owner_id] as Array[CombatEventPayload]


func _play_damage_batch_parallel(
	payloads: Array[CombatEventPayload],
	skill_style: bool,
) -> void:
	if payloads.is_empty():
		return
	var tweens := _start_damages(payloads, skill_style)
	await _wait_for_tweens_parallel(tweens)
	var seen_targets: Dictionary = {}
	var hp_tweens: Array = []
	for damage_payload in payloads:
		var target: UnitInstance = damage_payload.target
		if target == null or seen_targets.has(target.instance_id):
			continue
		seen_targets[target.instance_id] = true
		var node := _ensure_display(target)
		if node == null:
			continue
		node.refresh_display()
		var hp_tween: Tween = node.tween_hp_visual(_pace_scale())
		if hp_tween != null:
			hp_tweens.append(hp_tween)
	await _wait_for_tweens_parallel(hp_tweens)


func _play_deaths_batch_parallel(death_payloads: Array[CombatEventPayload]) -> void:
	if death_payloads.is_empty():
		return
	var death_tweens: Array[Tween] = []
	for payload in death_payloads:
		death_tweens.append_array(_start_death_tweens(payload))
	await _wait_for_tweens_parallel(death_tweens)
	for payload in death_payloads:
		_finalize_death(payload)


func _start_death_tweens(payload: CombatEventPayload) -> Array[Tween]:
	var tweens: Array[Tween] = []
	if payload == null or payload.target == null or _presentation == null:
		return tweens
	var node := _presentation.get_unit_node(payload.target.instance_id) as Node
	if node == null:
		return tweens
	var cell := _logic_cell(payload.target)
	var team := payload.target.team
	var pace := _pace_scale()
	if cell != Vector2i(-1, -1):
		_presentation.pulse_cell_death(
			cell,
			team,
			_dur(CombatAnimationConfig.DUR_DEATH_CELL_PULSE),
		)
		_presentation.spawn_death_spark(
			_presentation.grid_to_world(cell),
			team,
			_dur(CombatAnimationConfig.DUR_DEATH_SPARK),
		)
	_add_camera_impulse(CombatAnimationConfig.DEATH_SHAKE * pace)
	if node.has_method("prepare_death_visual"):
		node.prepare_death_visual()
	elif node.has_method("stop_active_tweens"):
		node.stop_active_tweens(false)
	var fade_tween: Tween = node.play_death_fade(
		_dur(CombatAnimationConfig.DUR_DEATH),
		_dur(CombatAnimationConfig.DUR_DEATH_FLASH),
	)
	if fade_tween != null:
		tweens.append(fade_tween)
	if node is UnitDisplay3D:
		var sprite_tween := (node as UnitDisplay3D).get_death_sprite_tween()
		if sprite_tween != null:
			tweens.append(sprite_tween)
	return tweens


func _finalize_death(payload: CombatEventPayload) -> void:
	if payload == null or payload.target == null or _presentation == null:
		return
	_presentation.remove_unit_node(payload.target.instance_id)
	_presentation.remove_grid_unit(payload.target)


func _play_death_deferred(payload: CombatEventPayload, on_finished: Callable) -> void:
	_play_death_deferred_async(payload, on_finished)


func _play_death_deferred_async(payload: CombatEventPayload, on_finished: Callable) -> void:
	await _play_death(payload)
	if on_finished.is_valid():
		on_finished.call()


func _play_batch_target_pulse(
	node: Node,
	pace_scale: float,
	target_id: int,
	heal_target_ids: Dictionary,
	on_finished: Callable,
) -> void:
	_play_batch_target_pulse_async(node, pace_scale, target_id, heal_target_ids, on_finished)


func _play_batch_target_pulse_async(
	node: Node,
	pace_scale: float,
	target_id: int,
	heal_target_ids: Dictionary,
	on_finished: Callable,
) -> void:
	if node == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	var buff_tween: Tween = node.play_buff_pop(pace_scale)
	await _wait_for_tween(buff_tween)
	var heal_tween: Tween = node.play_heal_pulse(pace_scale)
	await _wait_for_tween(heal_tween)
	if target_id >= 0:
		heal_target_ids[target_id] = node
	if on_finished.is_valid():
		on_finished.call()


func _play_fizzle(payload: CombatEventPayload) -> void:
	var hold_started := _show_fizzle_callout(payload)
	await _finish_skill_callout_hold(hold_started)


func _play_swap_skill(payload: CombatEventPayload) -> void:
	var hold_started := _begin_skill_callout(payload)
	await _snap_swap_positions(payload)
	await _finish_skill_callout_hold(hold_started)


func _show_fizzle_callout(payload: CombatEventPayload) -> int:
	if payload == null or _presentation == null:
		return -1
	var owner := _skill_owner_from_payload(payload)
	if owner == null:
		return -1
	var message := payload.fizzle_message
	if message.is_empty() and payload.effect_spec != null:
		message = UnitInfoText.format_effect_spec(payload.effect_spec)
	if message.is_empty():
		message = "技能失败"
	if _skill_callout != null:
		_skill_callout.show_failed(
			owner,
			message,
			_presentation.get_unit_global_anchor(owner),
		)
		return Time.get_ticks_msec()
	return -1


func _begin_skill_callout(payload: CombatEventPayload) -> int:
	if payload == null:
		return -1
	var owner := _skill_owner_from_payload(payload)
	if owner == null:
		return -1
	_show_skill_callout(owner, payload.effect_spec, payload.effect_action)
	return Time.get_ticks_msec()


func _finish_skill_callout_hold(hold_started: int) -> void:
	if hold_started < 0:
		return
	var elapsed_sec := (Time.get_ticks_msec() - hold_started) / 1000.0
	var remaining := _skill_callout_hold_sec() - elapsed_sec
	if remaining > 0.0:
		await _wait_paced_seconds(remaining)
	_hide_skill_callout()


func _skill_owner_from_payload(payload: CombatEventPayload) -> UnitInstance:
	if payload == null:
		return null
	if payload.effect_owner != null:
		return payload.effect_owner
	return payload.source


func _snap_swap_positions(payload: CombatEventPayload) -> void:
	if payload == null or _presentation == null:
		return
	var owner := _skill_owner_from_payload(payload)
	var ally := payload.target
	if owner != null:
		var owner_node := _ensure_display(owner)
		if owner_node != null:
			owner_node.stop_active_tweens(false)
			var owner_cell := _logic_cell(owner)
			owner_node.update_home_position(_unit_world(owner_cell))
			_reset_unit_scale(owner_node)
			owner_node.refresh_display()
	if ally != null:
		var ally_node := _ensure_display(ally)
		if ally_node != null:
			ally_node.stop_active_tweens(false)
			var ally_cell := _logic_cell(ally)
			ally_node.update_home_position(_unit_world(ally_cell))
			_reset_unit_scale(ally_node)
			ally_node.refresh_display()


func _play_death(payload: CombatEventPayload) -> void:
	if payload == null or payload.target == null or _presentation == null:
		return
	var tweens := _start_death_tweens(payload)
	await _wait_for_tweens_parallel(tweens)
	_finalize_death(payload)


func _stop_strike_animations_for_swap(
	clash: CombatEventPayload,
	swap: CombatEventPayload,
) -> void:
	var units: Array = []
	if clash != null:
		units.append(clash.source)
		units.append(clash.target)
	if swap != null:
		units.append(swap.effect_owner if swap.effect_owner != null else swap.source)
		units.append(swap.target)
	_stop_units_animations_and_snap(units)


func _stop_units_animations_and_snap(units: Array) -> void:
	if _presentation == null:
		return
	var seen: Dictionary = {}
	for unit in units:
		var inst := unit as UnitInstance
		if inst == null or seen.has(inst.instance_id):
			continue
		seen[inst.instance_id] = true
		var node := _presentation.get_unit_node(inst.instance_id) as Node
		if node == null:
			continue
		node.stop_active_tweens(false)
		var cell := _logic_cell(inst)
		if cell != Vector2i(-1, -1):
			node.update_home_position(_unit_world(cell))
		_reset_unit_scale(node)
		node.refresh_display()


func _ensure_display(unit: UnitInstance) -> Node:
	if unit == null or _presentation == null:
		return null
	var node := _presentation.ensure_unit_node(unit) as Node
	if node != null:
		var cell := _logic_cell(unit)
		node.update_home_position(_unit_world(cell))
		if node.has_method("bind_unit"):
			node.bind_unit(unit)
	return node


func _wait_for_tween(tween: Tween) -> void:
	if tween == null or not tween.is_valid():
		return
	if tween.is_running():
		await tween.finished


func _wait_for_tweens(tweens: Array) -> void:
	for tween in tweens:
		await _wait_for_tween(tween)


func _wait_for_tweens_parallel(tweens: Array) -> void:
	if tweens.is_empty():
		return
	var remaining: Array[int] = [0]
	for tween in tweens:
		if tween == null:
			continue
		if not tween.is_valid():
			continue
		if not tween.is_running():
			continue
		remaining[0] += 1
		tween.finished.connect(func() -> void:
			remaining[0] -= 1
		, CONNECT_ONE_SHOT)
	if remaining[0] <= 0:
		return
	while remaining[0] > 0:
		await get_tree().process_frame


func _finish_step() -> void:
	_playing = false
	_clear_step_focus()
	step_presentation_finished.emit()


func _clear_step_focus() -> void:
	if _presentation != null:
		_presentation.clear_acting_units()
	_hide_skill_callout()


func _play_fuse_explosion_preview(cells: Array[Vector2i]) -> void:
	if _presentation == null or cells.is_empty():
		return
	_set_attack_highlight(cells)
	var pulse_dur := _dur(CombatAnimationConfig.DUR_FUSE_EXPLODE_CELL_PULSE)
	_presentation.pulse_cells_impact(
		cells,
		CombatAnimationConfig.FUSE_EXPLODE_CELL_TINT,
		pulse_dur,
	)
	_add_camera_impulse(CombatAnimationConfig.MELEE_CLASH_SHAKE * 0.85)
	await _wait_paced_seconds(_dur(CombatAnimationConfig.DUR_FUSE_EXPLODE_PREVIEW))


func _set_attack_highlight(cells: Array[Vector2i]) -> void:
	if _presentation == null or cells.is_empty():
		return
	_presentation.set_attack_highlight_cells(cells)


func _clear_attack_highlight() -> void:
	if _presentation == null:
		return
	_presentation.clear_attack_highlight_cells()


func _cells_for_melee_attack(damage_events: Array[CombatEventPayload]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen: Dictionary = {}
	for payload in damage_events:
		if payload == null or payload.target == null or _presentation == null:
			continue
		var cell := _logic_cell(payload.target)
		if cell == Vector2i(-1, -1) or seen.has(cell):
			continue
		seen[cell] = true
		cells.append(cell)
	return cells


func _cells_for_line_attack(payload: CombatEventPayload) -> Array[Vector2i]:
	if payload == null or payload.source == null or _presentation == null:
		return []
	var grid := _presentation_grid()
	if grid == null or payload.line_axis < 0:
		return []
	var origin := _logic_cell(payload.source)
	if origin == Vector2i(-1, -1):
		return []
	return _GridLine.cells_on_axis(origin, payload.line_axis, grid)


func _show_skill_callout(
	owner: UnitInstance,
	spec: EffectSpec,
	action: EffectAction,
) -> void:
	if _skill_callout == null or _presentation == null or owner == null:
		return
	if spec == null and action == null:
		return
	_skill_callout.show_skill(
		owner,
		spec,
		action,
		_presentation.get_unit_global_anchor(owner),
	)


func _hide_skill_callout() -> void:
	if _skill_callout != null:
		_skill_callout.hide_callout()


func _resolve_acting_units_from_events(events: Array) -> Array[UnitInstance]:
	var by_id: Dictionary = {}
	for entry in events:
		var event_type: StringName = entry.get("type", &"")
		var payload: CombatEventPayload = entry.get("payload")
		if payload == null:
			continue
		match event_type:
			CombatEvents.ON_MOVE:
				if payload.source != null:
					by_id[payload.source.instance_id] = payload.source
			CombatEvents.ON_ATTACK_HIT, CombatEvents.ON_LINE_ATTACK:
				if payload.source != null:
					by_id[payload.source.instance_id] = payload.source
				if payload.target != null:
					by_id[payload.target.instance_id] = payload.target
			CombatEvents.ON_EFFECT_RESOLVED, CombatEvents.ON_EFFECT_FIZZLED:
				var owner := payload.effect_owner if payload.effect_owner != null else payload.source
				if owner != null:
					by_id[owner.instance_id] = owner
				if payload.target != null:
					by_id[payload.target.instance_id] = payload.target
				for batch_entry in payload.effect_entries:
					var batch_target: UnitInstance = batch_entry.get("target")
					if batch_target != null:
						by_id[batch_target.instance_id] = batch_target
			CombatEvents.ON_DAMAGE_TAKEN:
				if payload.source != null:
					by_id[payload.source.instance_id] = payload.source
				if payload.target != null:
					by_id[payload.target.instance_id] = payload.target
	var result: Array[UnitInstance] = []
	for unit in by_id.values():
		result.append(unit as UnitInstance)
	return result


func _resolve_acting_units(
	move_events: Array,
	attack_hit: CombatEventPayload,
	effect_events: Array[CombatEventPayload],
	line_attack: CombatEventPayload = null,
) -> Array[UnitInstance]:
	var by_id: Dictionary = {}
	for move_entry in move_events:
		var payload: CombatEventPayload = move_entry.get("payload")
		if payload != null and payload.source != null:
			by_id[payload.source.instance_id] = payload.source
	if attack_hit != null and attack_hit.source != null:
		by_id[attack_hit.source.instance_id] = attack_hit.source
	if line_attack != null and line_attack.source != null:
		by_id[line_attack.source.instance_id] = line_attack.source
	for payload in effect_events:
		if payload == null:
			continue
		var owner := payload.effect_owner if payload.effect_owner != null else payload.source
		if owner != null:
			by_id[owner.instance_id] = owner
	var result: Array[UnitInstance] = []
	for unit in by_id.values():
		result.append(unit as UnitInstance)
	return result


func _pace_scale() -> float:
	return CombatPresentationFx.pace_scale(pace_config, _combat_tick)


func _dur(base: float) -> float:
	return CombatPresentationFx.scaled_duration(base, pace_config, _combat_tick)


func _skill_callout_hold_sec() -> float:
	## No in-combat skill callout UI: skip hold so pacing is not gated on a hidden panel.
	if _skill_callout == null:
		return 0.0
	if pace_config == null:
		return 1.2
	return pace_config.skill_callout_hold_sec


func _wait_paced_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var active_ms := 0
	var last_tick := Time.get_ticks_msec()
	var target_ms := int(seconds * 1000.0)
	while active_ms < target_ms:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if not _paused:
			active_ms += now - last_tick
		last_tick = now


func _purge_dead_grid_units() -> void:
	var grid := _presentation_grid()
	if grid == null:
		return
	var to_remove: Array[UnitInstance] = []
	for unit in grid.get_all_units():
		var inst := unit as UnitInstance
		if inst != null and not inst.is_alive():
			to_remove.append(inst)
	for unit in to_remove:
		_presentation.remove_grid_unit(unit)
