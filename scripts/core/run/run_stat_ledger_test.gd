extends SceneTree

## Headless：RunStatLedger 与战斗事件采集口径。


static func run_all() -> bool:
	var ok := true
	ok = _test_ledger_sums() and ok
	ok = _test_collector_damage_heal() and ok
	return ok


static func _test_ledger_sums() -> bool:
	var ledger := RunStatLedger.new()
	ledger.record_damage(1, 10)
	ledger.record_damage(1, 5)
	ledger.record_healing(2, 7)
	ledger.record_kill(1)
	ledger.record_summon(2)
	if ledger.sum_damage_dealt() != 15:
		push_error("ledger: damage sum")
		return false
	if ledger.sum_healing_done() != 7:
		push_error("ledger: heal sum")
		return false
	if ledger.sum_kills() != 1 or ledger.sum_summons() != 1:
		push_error("ledger: kill/summon")
		return false
	return true


static func _test_collector_damage_heal() -> bool:
	var ledger := RunStatLedger.new()
	var collector := RunCombatStatCollector.new()
	collector.configure(ledger)
	var bus := CombatEventBus.new()
	collector.bind_bus(bus)
	var attacker := UnitInstance.new("a", Vector2i.ZERO, UnitInstance.Team.PLAYER)
	attacker.deck_entry_id = 9
	var target := UnitInstance.new("b", Vector2i.ZERO, UnitInstance.Team.ENEMY)
	var dmg := CombatEventPayload.new()
	dmg.source = attacker
	dmg.target = target
	dmg.amount = 4
	bus.emit_event(CombatEvents.ON_DEAL_DAMAGE, dmg)
	var heal := CombatEventPayload.new()
	heal.effect_owner = attacker
	heal.amount = 3
	bus.emit_event(CombatEvents.ON_HEAL_APPLIED, heal)
	collector.unbind_bus()
	if ledger.get_entry_totals(9).damage_dealt != 4:
		push_error("collector: damage attribution")
		return false
	if ledger.get_entry_totals(9).healing_done != 3:
		push_error("collector: heal attribution")
		return false
	return true
