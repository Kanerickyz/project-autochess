class_name RealtimeDamagePipeline
extends RefCounted
## 实时战斗唯一的扣血入口；命中/受伤/死亡全部经 CombatEventBus 广播。

const CRIT_DAMAGE_MULT := 1.5

var _bus: CombatEventBus
var _rng: RandomNumberGenerator


func _init(bus: CombatEventBus, rng: RandomNumberGenerator = null) -> void:
	_bus = bus
	_rng = rng if rng != null else RandomNumberGenerator.new()


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## 结算一次命中。splash_radius > 0 时按目标格切比雪夫格距溅射敌方。
## 返回本次被击杀的单位（按 instance_id 升序）。
func resolve_hit(
	source: RtUnit,
	primary: RtUnit,
	damage: int,
	splash_radius: float,
	units: Array,
) -> Array[RtUnit]:
	var killed: Array[RtUnit] = []
	if primary == null or not primary.is_alive():
		return killed
	var source_instance: UnitInstance = source.unit if source != null else null
	_emit(CombatEvents.ON_ATTACK_HIT, source_instance, primary.unit, 0, false)

	var victims: Array[RtUnit] = [primary]
	if splash_radius > 0.0:
		victims = collect_splash_victims(primary, splash_radius, units)
	for victim in victims:
		if apply_damage(source_instance, victim, damage):
			killed.append(victim)
	return killed


static func collect_splash_victims(
	primary: RtUnit,
	splash_radius: float,
	units: Array,
) -> Array[RtUnit]:
	var result: Array[RtUnit] = []
	var reach := RtUnitBrain.grid_reach(splash_radius)
	for item in units:
		var other := item as RtUnit
		if other == null or not other.is_alive():
			continue
		if other.get_team() != primary.get_team():
			continue
		if other == primary:
			result.append(other)
			continue
		var dist := float(primary.cell_distance_to(other))
		if dist <= reach:
			result.append(other)
	return result


## 返回 true 表示目标因本次伤害死亡。
func apply_damage(source: UnitInstance, target: RtUnit, amount: int) -> bool:
	if target == null or not target.is_alive() or amount <= 0:
		return false
	var rolled := amount
	var is_crit := false
	if source != null and _rng != null:
		var crit_rate := source.get_effective_crit_rate()
		if crit_rate > 0.0 and _rng.randf() < crit_rate:
			is_crit = true
			rolled = maxi(1, int(round(float(amount) * CRIT_DAMAGE_MULT)))
	target.unit.current_hp = maxi(0, target.unit.current_hp - rolled)
	_emit(CombatEvents.ON_DAMAGE_TAKEN, source, target.unit, rolled, is_crit)
	_emit(CombatEvents.ON_DEAL_DAMAGE, source, target.unit, rolled, is_crit)
	if is_crit and source != null:
		_emit(CombatEvents.ON_CRIT, source, target.unit, rolled, true)
	if target.unit.is_alive():
		return false
	target.state = RtUnit.State.DEAD
	target.target = null
	_emit(CombatEvents.ON_DEATH, source, target.unit, rolled, is_crit)
	_emit(CombatEvents.ON_FRIEND_DEATH, source, target.unit, rolled, is_crit)
	if source != null:
		_emit(CombatEvents.ON_KILL, source, target.unit, rolled, is_crit)
	return true


func _emit(
	event_type: StringName,
	source: UnitInstance,
	target: UnitInstance,
	amount: int,
	is_crit: bool = false,
) -> void:
	if _bus == null:
		return
	var payload := CombatEventPayload.new()
	payload.source = source
	payload.target = target
	payload.amount = amount
	payload.is_crit = is_crit
	_bus.emit_event(event_type, payload)
