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
	ok = _test_note_combat_atk_hp_peak_and_tie() and ok
	ok = _test_duplicate_peak_isolates_reset() and ok
	ok = _test_collector_samples_on_effect_resolved() and ok
	return ok


static func _make_player_unit(unit_id: String, base_atk: int, base_hp: int) -> UnitInstance:
	var data := UnitData.new()
	data.id = unit_id
	data.display_name = unit_id
	data.stats = UnitStats.new()
	data.stats.attack = base_atk
	data.stats.max_hp = base_hp
	var unit := UnitInstance.from_unit_data(data, Vector2i.ZERO, UnitInstance.Team.PLAYER)
	return unit


static func _test_note_combat_atk_hp_peak_and_tie() -> bool:
	var ledger := RunStatLedger.new()
	var a := _make_player_unit("a", 5, 10)
	a.stat_modifiers.add_flat(&"attack", 3)
	a.stat_modifiers.add_flat(&"max_hp", 2)
	## effective 8+12=20
	ledger.note_combat_atk_hp(a)
	if ledger.peak_combat_atk_hp_sum != 20 or ledger.peak_combat_entries.size() != 1:
		push_error("peak: first note sum/entries")
		return false
	var frozen := ledger.peak_combat_entries[0]
	if frozen.bonus_attack != 3 or frozen.bonus_max_hp != 2:
		push_error(
			"peak: freeze bonus atk=%d hp=%d expected 3/2"
			% [frozen.bonus_attack, frozen.bonus_max_hp]
		)
		return false
	## 同 instance 再采不堆
	ledger.note_combat_atk_hp(a)
	if ledger.peak_combat_entries.size() != 1:
		push_error("peak: same instance should not stack")
		return false
	## 更高峰值替换
	var b := _make_player_unit("b", 10, 20)
	b.stat_modifiers.add_flat(&"attack", 5)
	## 15+20=35
	ledger.note_combat_atk_hp(b)
	if ledger.peak_combat_atk_hp_sum != 35 or ledger.peak_combat_entries.size() != 1:
		push_error("peak: higher should replace")
		return false
	if ledger.peak_combat_entries[0].unit == null or ledger.peak_combat_entries[0].unit.id != "b":
		push_error("peak: replaced entry should be b")
		return false
	## 并列
	var c := _make_player_unit("c", 15, 20)
	ledger.note_combat_atk_hp(c)
	if ledger.peak_combat_entries.size() != 2:
		push_error("peak: tie should keep both, got %d" % ledger.peak_combat_entries.size())
		return false
	## 敌方不计
	var enemy := _make_player_unit("e", 99, 99)
	enemy.team = UnitInstance.Team.ENEMY
	ledger.note_combat_atk_hp(enemy)
	if ledger.peak_combat_entries.size() != 2 or ledger.peak_combat_atk_hp_sum != 35:
		push_error("peak: enemy must not count")
		return false
	return true


static func _test_duplicate_peak_isolates_reset() -> bool:
	var live := RunStatLedger.new()
	var u := _make_player_unit("peak", 4, 6)
	u.stat_modifiers.add_flat(&"attack", 1)
	live.note_combat_atk_hp(u)
	var snap := live.duplicate_ledger()
	live.reset()
	if live.peak_combat_atk_hp_sum != 0 or not live.peak_combat_entries.is_empty():
		push_error("duplicate peak: live should clear")
		return false
	if snap.peak_combat_atk_hp_sum != 11 or snap.peak_combat_entries.size() != 1:
		push_error("duplicate peak: snapshot should survive")
		return false
	## 深拷贝：改 snapshot 条目不影响（活账本已空）；再 note live 不冲 snapshot
	live.note_combat_atk_hp(_make_player_unit("other", 1, 1))
	if snap.peak_combat_atk_hp_sum != 11:
		push_error("duplicate peak: live note must not mutate snapshot sum")
		return false
	if snap.peak_combat_entries[0].unit == null or snap.peak_combat_entries[0].unit.id != "peak":
		push_error("duplicate peak: snapshot entry identity")
		return false
	return true


static func _test_collector_samples_on_effect_resolved() -> bool:
	var ledger := RunStatLedger.new()
	var collector := RunCombatStatCollector.new()
	collector.configure(ledger)
	var bus := CombatEventBus.new()
	collector.bind_bus(bus)
	var unit := _make_player_unit("buffed", 3, 5)
	unit.stat_modifiers.add_flat(&"attack", 7)
	unit.stat_modifiers.add_flat(&"max_hp", 4)
	## 10+9=19
	var payload := CombatEventPayload.new()
	payload.target = unit
	bus.emit_event(CombatEvents.ON_EFFECT_RESOLVED, payload)
	collector.unbind_bus()
	if ledger.peak_combat_atk_hp_sum != 19 or ledger.peak_combat_entries.size() != 1:
		push_error(
			"collector peak: sum=%d entries=%d"
			% [ledger.peak_combat_atk_hp_sum, ledger.peak_combat_entries.size()]
		)
		return false
	## sample_player_units 路径
	var ledger2 := RunStatLedger.new()
	var collector2 := RunCombatStatCollector.new()
	collector2.configure(ledger2)
	var other := _make_player_unit("sampled", 2, 2)
	other.stat_modifiers.add_flat(&"max_hp", 8)
	collector2.sample_player_units([other])
	if ledger2.peak_combat_atk_hp_sum != 12:
		push_error("sample_player_units: sum=%d expected 12" % ledger2.peak_combat_atk_hp_sum)
		return false
	return true


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
