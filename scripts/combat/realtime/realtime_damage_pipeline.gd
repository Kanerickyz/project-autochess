class_name RealtimeDamagePipeline
extends RefCounted
## 战斗唯一的扣血入口；命中/受伤/死亡全部经 CombatEventBus 广播。
## 出手只单向扣血：行动者伤目标（含溅射），目标不因被打而反打。

var _bus: CombatEventBus
var _rng: RandomNumberGenerator
## 致死但未发 OnDeath 的条目；须在 OnKill 效果排空后由模拟层 finalize（策反等可撤销死亡）。
var _pending_death_finalizations: Array[Dictionary] = []


func _init(bus: CombatEventBus, rng: RandomNumberGenerator = null) -> void:
	_bus = bus
	_rng = rng if rng != null else RandomNumberGenerator.new()


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## 结算一次命中（单向）。splash_radius > 0 时按目标格切比雪夫溅射敌方。
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

	## 同批打击表：主目标 + 溅射一并扣血，再统一标死。
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

	## 整次出手只掷一次暴击（溅射共享），避免多目标重复推进保底。
	var attack_roll := _roll_attack_crit(source_instance, damage)
	var death_pending: Array[Dictionary] = []
	for strike in pending:
		var tgt: RtUnit = strike["target"]
		var src: UnitInstance = strike["source"]
		if tgt == null or not tgt.is_alive():
			continue
		var rolled: int = attack_roll.amount
		var is_crit: bool = attack_roll.is_crit
		if rolled <= 0:
			continue
		if src != null:
			rolled = CombatStatusStack.adjust_attack_damage(rolled, src)
		rolled = CombatStatusStack.adjust_incoming_before_armor(rolled, tgt.unit)
		## MAP_SHOP §5.1：护甲全额挡住 → 不扣血、不发受伤类事件。
		var final_amount := tgt.unit.mitigate_incoming_damage(rolled)
		if final_amount <= 0:
			continue
		var hp_before := tgt.unit.current_hp
		tgt.unit.current_hp = maxi(0, tgt.unit.current_hp - final_amount)
		## 致死一击只走死亡，不触发「受到伤害 / 友方受伤」。
		if tgt.unit.is_alive():
			_emit(CombatEvents.ON_DAMAGE_TAKEN, src, tgt.unit, final_amount, hp_before, false, is_crit)
			_emit(CombatEvents.ON_FRIEND_DAMAGE_TAKEN, src, tgt.unit, final_amount, hp_before, false, is_crit)
		_emit(CombatEvents.ON_DEAL_DAMAGE, src, tgt.unit, final_amount, hp_before, false, is_crit)
		if not tgt.unit.is_alive() and tgt.state != RtUnit.State.DEAD:

			death_pending.append({
				"source": src,
				"target": tgt,
				"rolled": final_amount,
				"hp_before": hp_before,
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
		_stage_lethal_kill(death, true)
		killed.append(tgt2)
	return killed


func take_pending_death_finalizations() -> Array[Dictionary]:
	var out := _pending_death_finalizations.duplicate()
	_pending_death_finalizations.clear()
	return out


## 致死已 staging、OnKill/策反尚未 finalize：表现层仍应绘制活体剪影。
func has_pending_death_presentation(rt: RtUnit) -> bool:
	if rt == null:
		return false
	for entry in _pending_death_finalizations:
		if entry.get("target") == rt:
			return true
	return false


func emit_post_kill_death_events(death: Dictionary) -> void:
	var tgt2: RtUnit = death.get("target")
	if tgt2 == null:
		return
	var src2: UnitInstance = death.get("source")
	var rolled2: int = int(death.get("rolled", 0))
	var hp_before2: int = int(death.get("hp_before", -1))
	var is_crit2: bool = bool(death.get("is_crit", false))
	_emit(CombatEvents.ON_DEATH, src2, tgt2.unit, rolled2, hp_before2, false, is_crit2)
	_emit(CombatEvents.ON_FRIEND_DEATH, src2, tgt2.unit, rolled2, hp_before2, false, is_crit2)
	_emit(CombatEvents.ON_ENEMY_DEATH, src2, tgt2.unit, rolled2, hp_before2, false, is_crit2)


func _stage_lethal_kill(death: Dictionary, from_attack: bool) -> void:
	var tgt2: RtUnit = death["target"]
	var src2: UnitInstance = death["source"]
	var rolled2: int = int(death["rolled"])
	var hp_before2: int = int(death.get("hp_before", -1))
	var is_crit2: bool = bool(death.get("is_crit", false))
	tgt2.state = RtUnit.State.DEAD
	tgt2.target = null
	if src2 != null:
		_emit(CombatEvents.ON_KILL, src2, tgt2.unit, rolled2, hp_before2, from_attack, is_crit2)
		_emit(CombatEvents.ON_FRIEND_KILL, src2, tgt2.unit, rolled2, hp_before2, from_attack, is_crit2)
	death["from_attack"] = from_attack
	_pending_death_finalizations.append(death)


## 普攻掷暴击（含保底递增）；整次出手调用一次。
func _roll_attack_crit(source: UnitInstance, base_amount: int) -> DamageRoll:
	return CritRoll.roll_attack(source, base_amount, _rng)


## 已废止对砍反打：出手一律单向，保留函数供旧调用方恒返回 false。
static func can_counterattack(_defender: RtUnit, _attacker: RtUnit) -> bool:
	return false


static func collect_splash_victims(
	primary: RtUnit,
	splash_radius: float,
	units: Array,
) -> Array[RtUnit]:
	var result: Array[RtUnit] = []
	var reach := maxf(0.0, splash_radius)
	for item in units:
		var other := item as RtUnit
		if other == null or not other.is_alive():
			continue
		if other.get_team() != primary.get_team():
			continue
		if other == primary:
			result.append(other)
			continue
		var dist := primary.position.distance_to(other.position)
		if dist <= reach + RtUnitBrain.REACH_EPSILON:
			result.append(other)
	return result


## 返回 true 表示目标因本次伤害死亡。
## 单体直伤入口（效果等）；普攻主路径走 resolve_hit。
func apply_damage(source: UnitInstance, target: RtUnit, amount: int) -> bool:
	if target == null or not target.is_alive() or amount <= 0:
		return false
	var rolled := CombatStatusStack.adjust_incoming_before_armor(amount, target.unit)
	## MAP_SHOP §5.1：护甲全额挡住 → 不扣血、不发受伤类事件。
	var final_amount := target.unit.mitigate_incoming_damage(rolled)
	if final_amount <= 0:
		return false
	var hp_before := target.unit.current_hp
	target.unit.current_hp = maxi(0, target.unit.current_hp - final_amount)
	## 致死一击只走死亡，不触发「受到伤害 / 友方受伤」。
	if target.unit.is_alive():
		_emit(CombatEvents.ON_DAMAGE_TAKEN, source, target.unit, final_amount, hp_before)
		_emit(CombatEvents.ON_FRIEND_DAMAGE_TAKEN, source, target.unit, final_amount, hp_before)
	_emit(CombatEvents.ON_DEAL_DAMAGE, source, target.unit, final_amount, hp_before)
	if target.unit.is_alive():
		return false

	_stage_lethal_kill(
		{
			"source": source,
			"target": target,
			"rolled": final_amount,
			"hp_before": hp_before,
		},
		false,
	)
	return true


## 中毒等：直扣生命，不走护甲与虚弱。
func apply_direct_hp_loss(source: UnitInstance, target: RtUnit, amount: int) -> bool:
	if target == null or not target.is_alive() or amount <= 0:
		return false
	var hp_before := target.unit.current_hp
	target.unit.current_hp = maxi(0, target.unit.current_hp - amount)
	if target.unit.is_alive():
		_emit(CombatEvents.ON_DAMAGE_TAKEN, source, target.unit, amount, hp_before)
		_emit(CombatEvents.ON_FRIEND_DAMAGE_TAKEN, source, target.unit, amount, hp_before)
	_emit(CombatEvents.ON_DEAL_DAMAGE, source, target.unit, amount, hp_before)
	if target.unit.is_alive():
		return false
	_stage_lethal_kill(
		{
			"source": source,
			"target": target,
			"rolled": amount,
			"hp_before": hp_before,
		},
		false,
	)
	return true


func _emit(
	event_type: StringName,
	source: UnitInstance,
	target: UnitInstance,
	amount: int,
	target_hp_before: int = -1,
	from_attack: bool = false,
	is_crit: bool = false,
) -> void:
	if _bus == null:
		return
	var payload := CombatEventPayload.new()
	payload.source = source
	payload.target = target
	payload.amount = amount
	payload.target_hp_before = target_hp_before
	payload.from_attack = from_attack
	payload.is_crit = is_crit
	_bus.emit_event(event_type, payload)
