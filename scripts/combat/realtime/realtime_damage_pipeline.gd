class_name RealtimeDamagePipeline
extends RefCounted
## 实时战斗唯一的扣血入口；命中/受伤/死亡全部经 CombatEventBus 广播。

var _bus: CombatEventBus


func _init(bus: CombatEventBus) -> void:
	_bus = bus


## 结算一次命中。splash_radius > 0 时伤害目标周围（含目标）所有敌方单位。
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
	_emit(CombatEvents.ON_ATTACK_HIT, source_instance, primary.unit, 0)

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
	for item in units:
		var other := item as RtUnit
		if other == null or not other.is_alive():
			continue
		if other.get_team() != primary.get_team():
			continue
		if other == primary:
			result.append(other)
			continue
		var edge := primary.position.distance_to(other.position) - other.get_radius()
		if edge <= splash_radius:
			result.append(other)
	return result


## 返回 true 表示目标因本次伤害死亡。
func apply_damage(source: UnitInstance, target: RtUnit, amount: int) -> bool:
	if target == null or not target.is_alive() or amount <= 0:
		return false
	target.unit.current_hp = maxi(0, target.unit.current_hp - amount)
	_emit(CombatEvents.ON_DAMAGE_TAKEN, source, target.unit, amount)
	_emit(CombatEvents.ON_DEAL_DAMAGE, source, target.unit, amount)
	if target.unit.is_alive():
		return false
	target.state = RtUnit.State.DEAD
	target.target = null
	_emit(CombatEvents.ON_DEATH, source, target.unit, amount)
	_emit(CombatEvents.ON_FRIEND_DEATH, source, target.unit, amount)
	if source != null:
		_emit(CombatEvents.ON_KILL, source, target.unit, amount)
	return true


func _emit(event_type: StringName, source: UnitInstance, target: UnitInstance, amount: int) -> void:
	if _bus == null:
		return
	var payload := CombatEventPayload.new()
	payload.source = source
	payload.target = target
	payload.amount = amount
	_bus.emit_event(event_type, payload)
