class_name RunCombatStatCollector
extends RefCounted

var _ledger: RunStatLedger
var _bus: CombatEventBus
var _connected: bool = false


func configure(ledger: RunStatLedger) -> void:
	_ledger = ledger


func bind_bus(bus: CombatEventBus) -> void:
	unbind_bus()
	if bus == null or _ledger == null:
		return
	_bus = bus
	if not _bus.combat_event.is_connected(_on_combat_event):
		_bus.combat_event.connect(_on_combat_event)
	_connected = true


func unbind_bus() -> void:
	if _bus != null and _connected and _bus.combat_event.is_connected(_on_combat_event):
		_bus.combat_event.disconnect(_on_combat_event)
	_bus = null
	_connected = false


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if _ledger == null or payload == null:
		return
	match event_type:
		CombatEvents.ON_DEAL_DAMAGE:
			_record_player_source(payload.source, payload.amount)
		CombatEvents.ON_KILL:
			var killer := payload.source
			if killer != null and killer.team == UnitInstance.Team.PLAYER:
				_ledger.record_kill(_player_entry_id(killer))
		CombatEvents.ON_FRIEND_SUMMONED:
			var summoner := payload.source
			## 技能生成会带 source=召唤者；锁阵入座 emit 无 source，不计入「召唤单位」。
			if summoner != null and summoner.team == UnitInstance.Team.PLAYER:
				_ledger.record_summon(_player_entry_id(summoner))
		CombatEvents.ON_HEAL_APPLIED:
			var healer := payload.effect_owner if payload.effect_owner != null else payload.source
			if healer != null and healer.team == UnitInstance.Team.PLAYER and payload.amount > 0:
				_ledger.record_healing(_player_entry_id(healer), payload.amount)


func _record_player_source(source: UnitInstance, amount: int) -> void:
	if source == null or source.team != UnitInstance.Team.PLAYER:
		return
	_ledger.record_damage(_player_entry_id(source), amount)


static func _player_entry_id(unit: UnitInstance) -> int:
	if unit == null:
		return -1
	return unit.deck_entry_id
