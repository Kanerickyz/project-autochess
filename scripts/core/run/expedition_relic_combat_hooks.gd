class_name ExpeditionRelicCombatHooks
extends RefCounted

## 复杂圣物运行时钩子：鼓点耳饰、邻旗丝绦、铁扉反栓、盾回/血宴每回合顶。
## 绑定 CombatEventBus；战斗结束须 unbind。

const RELIC_ABILITY_PREFIX := "expedition_relic_"

var _bus: CombatEventBus
var _bag: ExpeditionRelicBag
var _bound: bool = false
var _units: Array = []
var _rng := RandomNumberGenerator.new()
## Callable(source: UnitInstance, target: UnitInstance, amount: int) → 经战斗管线扣血。
var _deal_damage: Callable = Callable()

## instance_id → 本回合鼓点已加攻次数
var _drum_counts: Dictionary = {}
## instance_id → 本回合反伤次数
var _reflect_counts: Dictionary = {}
## instance_id → 本回合血宴次数
var _cleave_counts: Dictionary = {}
## instance_id → 本场血宴次数
var _cleave_combat_counts: Dictionary = {}
## instance_id → 本回合伤害过自己的攻击者 instance_id（铁扉）
var _revenge_attacker: Dictionary = {}
## 铁扉追加伤进行中，避免再记仇/再触发
var _iron_resolving: bool = false

var _has_drum: bool = false
var _drum_bonus: int = 0
var _drum_cap: int = 0
var _has_neighbor: bool = false
var _neighbor_atk: int = 0
var _neighbor_hp: int = 0
var _has_iron: bool = false
var _iron_bonus: int = 0
var _has_reflect: bool = false
var _reflect_dmg: int = 0
var _reflect_cap: int = 0
var _has_cleave: bool = false
var _cleave_dmg: int = 0
var _cleave_round_cap: int = 0
var _cleave_combat_cap: int = 0


func bind(
	bus: CombatEventBus,
	bag: ExpeditionRelicBag,
	units: Array = [],
	seed_value: int = 0,
	deal_damage: Callable = Callable(),
) -> void:
	unbind()
	_bus = bus
	_bag = bag
	_units = units.duplicate()
	_deal_damage = deal_damage
	_rng.seed = seed_value if seed_value != 0 else hash(Time.get_ticks_msec())
	_reset_round_counters()
	_cleave_combat_counts.clear()
	_scan_bag()
	if _bus != null and not _bus.combat_event.is_connected(_on_combat_event):
		_bus.combat_event.connect(_on_combat_event)
	_bound = _bus != null


func unbind() -> void:
	if _bus != null and _bus.combat_event.is_connected(_on_combat_event):
		_bus.combat_event.disconnect(_on_combat_event)
	_bus = null
	_bag = null
	_units.clear()
	_deal_damage = Callable()
	_bound = false
	_drum_counts.clear()
	_reflect_counts.clear()
	_cleave_counts.clear()
	_cleave_combat_counts.clear()
	_revenge_attacker.clear()
	_iron_resolving = false


func _reset_round_counters() -> void:
	_drum_counts.clear()
	_reflect_counts.clear()
	_cleave_counts.clear()
	_revenge_attacker.clear()


func _reset_unit_round_counters(unit_id: int) -> void:
	_drum_counts.erase(unit_id)
	_reflect_counts.erase(unit_id)
	_cleave_counts.erase(unit_id)
	_revenge_attacker.erase(unit_id)


func _scan_bag() -> void:
	_has_drum = false
	_has_neighbor = false
	_has_iron = false
	_has_reflect = false
	_has_cleave = false
	if _bag == null:
		return
	for r in _bag.get_relics():
		var relic := r as ExpeditionRelicData
		if relic == null:
			continue
		if relic.bonus_temp_attack_after_hurt_ability > 0:
			_has_drum = true
			_drum_bonus = relic.bonus_temp_attack_after_hurt_ability
			_drum_cap = maxi(1, relic.cap_per_unit_per_round)
		if relic.neighbor_buff_extra_attack > 0 or relic.neighbor_buff_extra_max_hp > 0:
			_has_neighbor = true
			_neighbor_atk = relic.neighbor_buff_extra_attack
			_neighbor_hp = relic.neighbor_buff_extra_max_hp
		if relic.revenge_next_hit_damage_bonus > 0:
			_has_iron = true
			_iron_bonus = relic.revenge_next_hit_damage_bonus
		if relic.reflect_damage > 0:
			_has_reflect = true
			_reflect_dmg = relic.reflect_damage
			_reflect_cap = maxi(1, relic.cap_per_ally_per_round)
		if relic.kill_cleave_damage > 0:
			_has_cleave = true
			_cleave_dmg = relic.kill_cleave_damage
			_cleave_round_cap = maxi(1, relic.cap_per_ally_per_round)
			_cleave_combat_cap = maxi(1, relic.cap_per_combat)


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if not _bound or payload == null:
		return
	match event_type:
		CombatEvents.ON_ROUND_START:
			## 串行行动：只清「本动单位」的每回合顶，避免全场误清。
			if payload.source != null:
				_reset_unit_round_counters(payload.source.instance_id)
		CombatEvents.ON_DAMAGE_TAKEN:
			_on_damage_taken(payload)
		CombatEvents.ON_EFFECT_RESOLVED:
			_on_effect_resolved(payload)
		CombatEvents.ON_DEAL_DAMAGE:
			_on_deal_damage(payload)
		CombatEvents.ON_KILL:
			_on_kill(payload)


func _on_damage_taken(payload: CombatEventPayload) -> void:
	if payload.target == null or payload.target.team != UnitInstance.Team.PLAYER:
		return
	if not payload.target.is_alive():
		return
	## 铁扉：记下本回合仇敌（跳过铁扉自身追加伤）。
	if _has_iron and not _iron_resolving and payload.source != null:
		if payload.source.team != UnitInstance.Team.PLAYER:
			_revenge_attacker[payload.target.instance_id] = payload.source.instance_id
	## 盾回：受伤未死 → 反伤攻击者（每友方每回合顶）。
	if not _has_reflect or _reflect_dmg <= 0:
		return
	if payload.source == null or payload.source == payload.target:
		return
	if not payload.source.is_alive():
		return
	var used := int(_reflect_counts.get(payload.target.instance_id, 0))
	if used >= _reflect_cap:
		return
	_reflect_counts[payload.target.instance_id] = used + 1
	_apply_direct_damage(payload.target, payload.source, _reflect_dmg)


func _on_effect_resolved(payload: CombatEventPayload) -> void:
	if payload.effect_spec == null or payload.effect_owner == null:
		return
	var owner := payload.effect_owner
	if owner.team != UnitInstance.Team.PLAYER:
		return
	## 鼓点：非圣物挂载的受伤触发技能结算后，持有者再 +攻。
	if _has_drum and payload.effect_spec.trigger == CombatEvents.ON_DAMAGE_TAKEN:
		if not _spec_from_relic_attachment(owner, payload.effect_spec):
			var used := int(_drum_counts.get(owner.instance_id, 0))
			if used < _drum_cap and owner.is_alive():
				owner.stat_modifiers.add_flat(&"attack", _drum_bonus)
				_drum_counts[owner.instance_id] = used + 1
	## 邻旗：邻格/周围友方增益结算后，对受益目标再同属性 +1。
	if _has_neighbor and _is_neighbor_buff_spec(payload.effect_spec):
		_amplify_neighbor_entries(payload)


func _spec_from_relic_attachment(owner: UnitInstance, spec: EffectSpec) -> bool:
	if owner == null or spec == null:
		return false
	for ab in owner.attached_abilities:
		if ab == null or not String(ab.id).begins_with(RELIC_ABILITY_PREFIX):
			continue
		for owned in ab.effect_specs:
			if owned == spec:
				return true
	return false


func _is_neighbor_buff_spec(spec: EffectSpec) -> bool:
	if spec == null:
		return false
	return (
		spec.target_selector == EffectSpec.TargetSelector.NEARBY_ALLIES
		or spec.target_selector == EffectSpec.TargetSelector.ORTHOGONAL_LEFT_RIGHT_ALLIES
	)


func _amplify_neighbor_entries(payload: CombatEventPayload) -> void:
	if payload.effect_action == null:
		return
	if payload.effect_action.action_type != EffectAction.Type.MODIFY_STAT:
		return
	var stat := payload.effect_action.stat_name
	for entry in payload.effect_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var tgt: UnitInstance = entry.get("target") as UnitInstance
		if tgt == null or not tgt.is_alive() or tgt.team != UnitInstance.Team.PLAYER:
			continue
		if stat == &"attack" and _neighbor_atk > 0:
			tgt.stat_modifiers.add_flat(&"attack", _neighbor_atk)
		elif stat == &"max_hp" and _neighbor_hp > 0:
			tgt.stat_modifiers.add_flat(&"max_hp", _neighbor_hp)
			tgt.current_hp = mini(
				tgt.get_effective_max_hp(), tgt.current_hp + _neighbor_hp
			)


func _on_deal_damage(payload: CombatEventPayload) -> void:
	if _iron_resolving:
		return
	if payload.source == null or payload.target == null:
		return
	if payload.source.team != UnitInstance.Team.PLAYER:
		return
	if not _has_iron or _iron_bonus <= 0:
		return
	var foe_id := int(_revenge_attacker.get(payload.source.instance_id, -1))
	if foe_id < 0 or payload.target.instance_id != foe_id:
		return
	_revenge_attacker.erase(payload.source.instance_id)
	if not payload.target.is_alive():
		return
	_iron_resolving = true
	_apply_direct_damage(payload.source, payload.target, _iron_bonus)
	_iron_resolving = false


func _on_kill(payload: CombatEventPayload) -> void:
	if not _has_cleave or payload.source == null:
		return
	if payload.source.team != UnitInstance.Team.PLAYER or not payload.source.is_alive():
		return
	var sid := payload.source.instance_id
	var round_used := int(_cleave_counts.get(sid, 0))
	if round_used >= _cleave_round_cap:
		return
	var combat_used := int(_cleave_combat_counts.get(sid, 0))
	if combat_used >= _cleave_combat_cap:
		return
	var victim := _pick_random_living_enemy(payload.source)
	if victim == null:
		return
	_cleave_counts[sid] = round_used + 1
	_cleave_combat_counts[sid] = combat_used + 1
	_apply_direct_damage(payload.source, victim, _cleave_dmg)


func _pick_random_living_enemy(attacker: UnitInstance) -> UnitInstance:
	var enemies: Array[UnitInstance] = []
	for item in _units:
		var u := item as UnitInstance
		if u == null or not u.is_alive():
			continue
		if attacker != null and u.team == attacker.team:
			continue
		enemies.append(u)
	if enemies.is_empty():
		return null
	return enemies[_rng.randi_range(0, enemies.size() - 1)]


func _apply_direct_damage(source: UnitInstance, target: UnitInstance, amount: int) -> void:
	if target == null or not target.is_alive() or amount <= 0:
		return
	if _deal_damage.is_valid():
		_deal_damage.call(source, target, amount)
		return
	## 无管线时（单测）：只扣血，不发致死链，避免幽灵单位。
	target.current_hp = maxi(1, target.current_hp - amount)
