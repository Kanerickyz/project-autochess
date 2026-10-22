extends SceneTree

## Headless：RunStatLedger 与战斗事件采集口径。


static func run_all() -> bool:
	var ok := true
	ok = _test_ledger_sums() and ok
	ok = _test_collector_damage_heal() and ok
	ok = _test_collector_summon_from_bus() and ok
	ok = _test_orphan_entry_counts_in_sums() and ok
	ok = _test_duplicate_ledger_isolates_reset() and ok
	ok = _test_ledger_accumulates_across_records() and ok
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


## 技能召唤经总线 ON_FRIEND_SUMMONED（带 source）须计入召唤。
static func _test_collector_summon_from_bus() -> bool:
	var ledger := RunStatLedger.new()
	var collector := RunCombatStatCollector.new()
	collector.configure(ledger)
	var bus := CombatEventBus.new()
	collector.bind_bus(bus)
	var summoner := UnitInstance.new("caller", Vector2i.ZERO, UnitInstance.Team.PLAYER)
	summoner.deck_entry_id = 3
	var token := UnitInstance.new("token", Vector2i.ZERO, UnitInstance.Team.PLAYER)
	token.is_combat_summon = true
	var spawn := CombatEventPayload.new()
	spawn.source = summoner
	spawn.target = token
	bus.emit_event(CombatEvents.ON_FRIEND_SUMMONED, spawn)
	## 锁阵入座无 source：不应计入召唤。
	var deploy := CombatEventPayload.new()
	deploy.target = summoner
	bus.emit_event(CombatEvents.ON_FRIEND_SUMMONED, deploy)
	collector.unbind_bus()
	if ledger.sum_summons() != 1:
		push_error("collector: summons=%d expected 1 (skill only)" % ledger.sum_summons())
		return false
	if ledger.get_entry_totals(3).summons != 1:
		push_error("collector: summon not on summoner entry")
		return false
	return true


## 无牌库 id 的友方输出仍计入总和（孤儿桶）。
static func _test_orphan_entry_counts_in_sums() -> bool:
	var ledger := RunStatLedger.new()
	ledger.record_damage(-1, 8)
	ledger.record_healing(-5, 2)
	ledger.record_summon(-1)
	if ledger.sum_damage_dealt() != 8:
		push_error("orphan: damage sum")
		return false
	if ledger.sum_healing_done() != 2:
		push_error("orphan: heal sum")
		return false
	if ledger.sum_summons() != 1:
		push_error("orphan: summon sum")
		return false
	return true


static func _test_duplicate_ledger_isolates_reset() -> bool:
	var live := RunStatLedger.new()
	live.record_damage(1, 10)
	live.record_healing(1, 4)
	live.record_summon(1)
	var snap := live.duplicate_ledger()
	live.reset()
	if live.sum_damage_dealt() != 0:
		push_error("duplicate: live should clear")
		return false
	if snap.sum_damage_dealt() != 10 or snap.sum_healing_done() != 4 or snap.sum_summons() != 1:
		push_error("duplicate: snapshot totals should survive live.reset")
		return false
	return true


## 模拟多场遭遇写入：账本应累加而非只保留最后一场。
static func _test_ledger_accumulates_across_records() -> bool:
	var ledger := RunStatLedger.new()
	## 第一场
	ledger.record_damage(1, 10)
	ledger.record_healing(2, 3)
	ledger.record_summon(1)
	## 第二场
	ledger.record_damage(1, 7)
	ledger.record_healing(2, 5)
	ledger.record_kill(1)
	ledger.record_summon(1)
	if ledger.sum_damage_dealt() != 17:
		push_error("accumulate: damage=%d expected 17" % ledger.sum_damage_dealt())
		return false
	if ledger.sum_healing_done() != 8:
		push_error("accumulate: heal=%d expected 8" % ledger.sum_healing_done())
		return false
	if ledger.sum_kills() != 1 or ledger.sum_summons() != 2:
		push_error("accumulate: kills/summons")
		return false
	return true
