class_name RealtimeDamagePipeline
extends RefCounted
## 战斗唯一的扣血入口；命中/受伤/死亡全部经 CombatEventBus 广播。
## 出手命中时可与主目标对砍：双方同批扣血，无先后手。

const CRIT_DAMAGE_MULT := 1.5

var _bus: CombatEventBus
var _rng: RandomNumberGenerator


func _init(bus: CombatEventBus, rng: RandomNumberGenerator = null) -> void:
	_bus = bus
	_rng = rng if rng != null else RandomNumberGenerator.new()


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## 结算一次命中（含可选反打）。splash_radius > 0 时按目标格切比雪夫溅射敌方。
## 若 source 也在 primary 的攻击距离内，primary 反打 source（单体、同批扣血）。
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

	var counter := can_counterattack(primary, source)
	if counter:
		_emit(CombatEvents.ON_ATTACK_HIT, primary.unit, source_instance, 0, false)

	## 同批打击表：先全部扣血，再统一标死，避免「先打死对方导致无法反打」。
	var pending: Array[Dictionary] = []
	var victims: Array[RtUnit] = [primary]
	if splash_radius > 0.0:
		victims = collect_splash_victims(primary, splash_radius, units)
	for victim in victims:
		pending.append({
			"source": source_instance,
			"target": victim,
			"amount": damage,
		})
	if counter and source != null and source.is_alive():
		pending.append({
			"source": primary.unit,
			"target": source,
			"amount": primary.unit.get_effective_attack(),
		})

	var death_pending: Array[Dictionary] = []
	for strike in pending:
		var tgt: RtUnit = strike["target"]
		var src: UnitInstance = strike["source"]
		var amount: int = int(strike["amount"])
		if tgt == null or not tgt.is_alive() or amount <= 0:
			continue
		var rolled := amount
		var is_crit := false
		if src != null and _rng != null:
			var crit_rate := src.get_effective_crit_rate()
			if crit_rate > 0.0 and _rng.randf() < crit_rate:
				is_crit = true
				rolled = maxi(1, int(round(float(amount) * CRIT_DAMAGE_MULT)))
		tgt.unit.current_hp = maxi(0, tgt.unit.current_hp - rolled)
		_emit(CombatEvents.ON_DAMAGE_TAKEN, src, tgt.unit, rolled, is_crit)
		_emit(CombatEvents.ON_DEAL_DAMAGE, src, tgt.unit, rolled, is_crit)
		if is_crit and src != null:
			_emit(CombatEvents.ON_CRIT, src, tgt.unit, rolled, true)
		if not tgt.unit.is_alive() and tgt.state != RtUnit.State.DEAD:
			death_pending.append({
				"source": src,
				"target": tgt,
				"rolled": rolled,
				"is_crit": is_crit,
			})

	death_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: RtUnit = a["target"]
		var tb: RtUnit = b["target"]
		return ta.get_id() < tb.get_id()
	)
	for death in death_pending:
		var tgt2: RtUnit = death["target"]
		if tgt2.state == RtUnit.State.DEAD:
			continue
		var src2: UnitInstance = death["source"]
		var rolled2: int = int(death["rolled"])
		var is_crit2: bool = bool(death["is_crit"])
		tgt2.state = RtUnit.State.DEAD
		tgt2.target = null
		_emit(CombatEvents.ON_DEATH, src2, tgt2.unit, rolled2, is_crit2)
		_emit(CombatEvents.ON_FRIEND_DEATH, src2, tgt2.unit, rolled2, is_crit2)
		if src2 != null:
			_emit(CombatEvents.ON_KILL, src2, tgt2.unit, rolled2, is_crit2)
		killed.append(tgt2)
	return killed


## 防守方能否对行动者反打：双方存活、防守方未在部署、行动者在其攻距内。
static func can_counterattack(defender: RtUnit, attacker: RtUnit) -> bool:
	if defender == null or attacker == null:
		return false
	if not defender.is_alive() or not attacker.is_alive():
		return false
	if defender.is_deploying():
		return false
	var reach := RtUnitBrain.grid_reach(defender.get_stats().attack_reach)
	var dist := float(defender.cell_distance_to(attacker))
	return dist <= reach + RtUnitBrain.REACH_EPSILON


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
## 单体直伤入口（效果等）；普攻主路径走 resolve_hit。
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
