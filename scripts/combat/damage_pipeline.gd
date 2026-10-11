class_name DamagePipeline
extends RefCounted

const _GridLine := preload("res://scripts/combat/grid_line.gd")

const CRIT_DAMAGE_MULT := 1.5

var _bus: CombatEventBus
var _grid: BoardGrid
var defer_death_removal: bool = false
var _effect_resolver: EffectResolver
var _rng: RandomNumberGenerator


func _init(bus: CombatEventBus, grid: BoardGrid) -> void:
	_bus = bus
	_grid = grid
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


func set_effect_resolver(resolver: EffectResolver) -> void:
	_effect_resolver = resolver


func roll_damage(
	source: UnitInstance,
	base_amount: int,
	allow_crit: bool = true,
) -> DamageRoll:
	var result := DamageRoll.new(base_amount, false)
	if base_amount <= 0:
		result.amount = 0
		return result
	if source == null or not allow_crit or _rng == null:
		return result
	var crit_rate := source.get_effective_crit_rate()
	if crit_rate <= 0.0:
		return result
	if _rng.randf() < crit_rate:
		result.is_crit = true
		result.amount = maxi(1, int(round(float(base_amount) * CRIT_DAMAGE_MULT)))
	return result


func apply_damage(
	source: UnitInstance,
	target: UnitInstance,
	amount: int,
	is_crit: bool = false,
) -> void:
	if target == null or not target.is_alive():
		return

	target.current_hp = maxi(0, target.current_hp - amount)

	var payload := CombatEventPayload.new()
	payload.source = source
	payload.target = target
	payload.amount = amount
	payload.is_crit = is_crit

	_bus.emit_event(CombatEvents.ON_DAMAGE_TAKEN, payload)
	_bus.emit_event(CombatEvents.ON_DEAL_DAMAGE, payload)
	if is_crit and source != null:
		_bus.emit_event(CombatEvents.ON_CRIT, payload)

	if not target.is_alive():
		_grid.sync_unit_grid_pos(target)
		if not defer_death_removal:
			_grid.remove_unit(target)
		_bus.emit_event(CombatEvents.ON_DEATH, payload)
		_bus.emit_event(CombatEvents.ON_FRIEND_DEATH, payload)
		if source != null:
			_bus.emit_event(CombatEvents.ON_KILL, payload)


func apply_rolled_damage(
	source: UnitInstance,
	target: UnitInstance,
	base_amount: int,
	allow_crit: bool = true,
) -> void:
	var rolled := roll_damage(source, base_amount, allow_crit)
	apply_damage(source, target, rolled.amount, rolled.is_crit)


func apply_attack_exchange(attacker: UnitInstance, defender: UnitInstance) -> void:
	if attacker == null or defender == null:
		return
	if not attacker.is_alive() or not defender.is_alive():
		return

	_resolve_melee_strike(attacker, defender)
	if attacker.is_alive() and defender.is_alive():
		_resolve_melee_strike(defender, attacker)


func _resolve_melee_strike(attacker: UnitInstance, defender: UnitInstance) -> void:
	if attacker == null or defender == null:
		return
	if not attacker.is_alive() or not defender.is_alive():
		return

	var hit_payload := CombatEventPayload.new()
	hit_payload.source = attacker
	hit_payload.target = defender
	_bus.emit_event(CombatEvents.ON_ATTACK_HIT, hit_payload)

	var damage_target := defender
	if _effect_resolver != null:
		var hit_result := _effect_resolver.process_attack_hit_immediate(hit_payload)
		if hit_result.has("damage_target") and hit_result["damage_target"] != null:
			damage_target = hit_result["damage_target"]

	apply_rolled_damage(attacker, damage_target, attacker.get_effective_attack())


func apply_line_attack(attacker: UnitInstance, axis: int, damage: int) -> void:
	if attacker == null or not attacker.is_alive() or _grid == null:
		return
	if damage <= 0 or axis < 0:
		return

	var origin := _grid.find_cell_of(attacker)
	if origin == Vector2i(-1, -1):
		return

	var line_payload := CombatEventPayload.new()
	line_payload.source = attacker
	line_payload.target = attacker
	line_payload.line_axis = axis
	_bus.emit_event(CombatEvents.ON_LINE_ATTACK, line_payload)

	var enemies: Array[UnitInstance] = _GridLine.enemies_on_axis(_grid, origin, axis, attacker.team)
	for enemy in enemies:
		if enemy != null and enemy.is_alive():
			apply_rolled_damage(attacker, enemy, damage)
