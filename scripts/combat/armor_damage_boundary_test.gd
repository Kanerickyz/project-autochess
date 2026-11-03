class_name ArmorDamageBoundaryTest
extends RefCounted
## MAP_SHOP §5.1：最终扣血 0 不发受伤事件；>0 仍发。
## 致死扣血只发死亡，不发「受到伤害 / 友方受伤」。

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("full_block_no_hurt_event", _test_full_block())
	_check("overflow_block_no_hp", _test_overflow_block_no_hp())
	_check("partial_armor_no_hp_no_hurt", _test_partial_block())
	_check("realtime_full_block", _test_realtime_full_block())
	_check("armor_depletes_keeps_equipment", _test_armor_depletes())
	_check("armor_refills_after_deplete", _test_armor_refill())
	_check("partial_hit_leaves_remaining_armor", _test_armor_partial_deplete())
	_check("combat_temp_armor_stacks_and_depletes_first", _test_combat_temp_armor_depletes_before_equipment())
	_check("lethal_skips_hurt", _test_lethal_skips_hurt())
	_check("realtime_lethal_skips_hurt", _test_realtime_lethal_skips_hurt())
	_check("nonlethal_still_hurts", _test_nonlethal_still_hurts())
	if _failures == 0:
		print("ArmorDamageBoundaryTest: all tests passed")
	else:
		push_error("ArmorDamageBoundaryTest: %d failure(s)" % _failures)
	return _failures == 0


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("ArmorDamageBoundaryTest FAIL: %s" % name)


static func _test_full_block() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var target := UnitInstance.new("tank", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	target.stats = UnitStats.new()
	target.stats.max_hp = 20
	target.current_hp = 20
	target.armor_block = 5
	grid.place(target, Vector2i(1, 0))

	var hurt_count := [0]
	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DAMAGE_TAKEN or event_type == CombatEvents.ON_FRIEND_DAMAGE_TAKEN:
			hurt_count[0] = int(hurt_count[0]) + 1
	)

	pipeline.apply_damage(null, target, 5)
	if target.current_hp != 20:
		return false
	if int(hurt_count[0]) != 0:
		return false
	## 全额抵挡仍消耗护甲。
	if target.get_armor_block() != 0:
		return false
	return true


static func _test_overflow_block_no_hp() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var target := UnitInstance.new("tank", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	target.stats = UnitStats.new()
	target.stats.max_hp = 5
	target.current_hp = 5
	target.armor_block = 2
	grid.place(target, Vector2i(1, 0))

	var hurt_count := [0]
	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			hurt_count[0] = int(hurt_count[0]) + 1
	)

	pipeline.apply_damage(null, target, 99)
	if target.current_hp != 5:
		return false
	if target.get_armor_block() != 0:
		return false
	if int(hurt_count[0]) != 0:
		return false
	return true


static func _test_partial_block() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var target := UnitInstance.new("tank", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	target.stats = UnitStats.new()
	target.stats.max_hp = 20
	target.current_hp = 20
	target.armor_block = 2
	grid.place(target, Vector2i(1, 0))

	var hurt_count := [0]
	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			hurt_count[0] = int(hurt_count[0]) + 1
	)

	pipeline.apply_damage(null, target, 5)
	if target.current_hp != 20:
		return false
	if target.get_armor_block() != 0:
		return false
	if int(hurt_count[0]) != 0:
		return false
	return true


static func _test_realtime_full_block() -> bool:
	var bus := CombatEventBus.new()
	var pipeline := RealtimeDamagePipeline.new(bus)
	var unit := UnitInstance.new("tank", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = 10
	unit.current_hp = 10
	unit.armor_block = 10
	var rt := RtUnit.new(unit, Vector2(0.5, 0.5))
	rt.skip_deploy()

	var hurt_count := [0]
	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			hurt_count[0] = int(hurt_count[0]) + 1
	)

	var died := pipeline.apply_damage(null, rt, 8)
	if died:
		return false
	if unit.current_hp != 10:
		return false
	if int(hurt_count[0]) != 0:
		return false
	if unit.get_armor_block() != 2:
		return false
	return true


static func _test_armor_depletes() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var eq := EquipmentData.new()
	eq.id = "armor_t1"
	eq.display_name = "护甲 I"
	eq.armor_block = 5
	var entry := DeckEntry.new()
	entry.entry_id = 1
	entry.attach_equipment(eq)
	var target := UnitInstance.new("tank", Vector2i(1, 0), UnitInstance.Team.PLAYER)
	target.stats = UnitStats.new()
	target.stats.max_hp = 20
	target.current_hp = 20
	target.deck_entry_id = entry.entry_id
	target._deck_entry_ref = weakref(entry)
	target.armor_block = entry.get_armor_block()
	grid.place(target, Vector2i(1, 0))

	pipeline.apply_damage(null, target, 5)
	if target.get_armor_block() != 0:
		return false
	if entry.equipment == null:
		return false
	if entry.get_armor_block() != 0:
		return false
	entry.refill_equipment_armor()
	if entry.get_armor_block() != 5:
		return false
	if target.current_hp != 20:
		return false
	return true


static func _test_armor_refill() -> bool:
	var eq := EquipmentData.new()
	eq.armor_block = 3
	var entry := DeckEntry.new()
	entry.attach_equipment(eq)
	entry.apply_armor_remaining(0)
	if entry.equipment == null:
		return false
	entry.refill_equipment_armor()
	return entry.get_armor_block() == 3


static func _test_armor_partial_deplete() -> bool:
	var eq := EquipmentData.new()
	eq.id = "armor_t3"
	eq.armor_block = 10
	var entry := DeckEntry.new()
	entry.entry_id = 2
	entry.attach_equipment(eq)
	var unit := UnitInstance.new("tank", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = 20
	unit.current_hp = 20
	unit._deck_entry_ref = weakref(entry)
	unit.armor_block = entry.get_armor_block()
	var leftover := unit.mitigate_incoming_damage(4)
	if leftover != 0:
		return false
	if unit.get_armor_block() != 6:
		return false
	if entry.get_armor_block() != 6:
		return false
	if entry.equipment == null:
		return false
	return true


static func _test_combat_temp_armor_depletes_before_equipment() -> bool:
	var eq := EquipmentData.new()
	eq.id = "armor_t1"
	eq.armor_block = 5
	var entry := DeckEntry.new()
	entry.entry_id = 3
	entry.attach_equipment(eq)
	var unit := UnitInstance.new("tank", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = 20
	unit.current_hp = 20
	unit._deck_entry_ref = weakref(entry)
	unit.armor_block = entry.get_armor_block()
	unit.grant_combat_temp_armor(2)
	if unit.get_armor_block() != 7:
		return false
	var leftover := unit.mitigate_incoming_damage(2)
	if leftover != 0:
		return false
	if unit.combat_temp_armor != 0:
		return false
	if unit.armor_block != 5:
		return false
	if entry.get_armor_block() != 5:
		return false
	unit.grant_combat_temp_armor(2)
	leftover = unit.mitigate_incoming_damage(4)
	if leftover != 0:
		return false
	if unit.combat_temp_armor != 0:
		return false
	if unit.armor_block != 3:
		return false
	if entry.get_armor_block() != 3:
		return false
	return true


static func _count_events(bus: CombatEventBus) -> Dictionary:
	var counts := {
		CombatEvents.ON_DAMAGE_TAKEN: 0,
		CombatEvents.ON_FRIEND_DAMAGE_TAKEN: 0,
		CombatEvents.ON_DEAL_DAMAGE: 0,
		CombatEvents.ON_DEATH: 0,
	}
	bus.combat_event.connect(func(event_type: StringName, _payload: CombatEventPayload) -> void:
		if counts.has(event_type):
			counts[event_type] = int(counts[event_type]) + 1
	)
	return counts


static func _test_lethal_skips_hurt() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var target := UnitInstance.new("fodder", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	target.stats = UnitStats.new()
	target.stats.max_hp = 4
	target.current_hp = 4
	grid.place(target, Vector2i(1, 0))
	var counts := _count_events(bus)
	pipeline.apply_damage(null, target, 9)
	if target.is_alive() or target.current_hp != 0:
		return false
	if int(counts[CombatEvents.ON_DAMAGE_TAKEN]) != 0:
		return false
	if int(counts[CombatEvents.ON_FRIEND_DAMAGE_TAKEN]) != 0:
		return false
	if int(counts[CombatEvents.ON_DEATH]) != 1:
		return false
	if int(counts[CombatEvents.ON_DEAL_DAMAGE]) != 1:
		return false
	return true


static func _test_realtime_lethal_skips_hurt() -> bool:
	var bus := CombatEventBus.new()
	var pipeline := RealtimeDamagePipeline.new(bus)
	var unit := UnitInstance.new("fodder", Vector2i(0, 0), UnitInstance.Team.ENEMY)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = 4
	unit.current_hp = 4
	var rt := RtUnit.new(unit, Vector2(0.5, 0.5))
	rt.skip_deploy()
	var counts := _count_events(bus)
	if not pipeline.apply_damage(null, rt, 9):
		return false
	if unit.is_alive() or rt.is_alive():
		return false
	if int(counts[CombatEvents.ON_DAMAGE_TAKEN]) != 0:
		return false
	if int(counts[CombatEvents.ON_FRIEND_DAMAGE_TAKEN]) != 0:
		return false
	if int(counts[CombatEvents.ON_DEATH]) != 1:
		return false
	if int(counts[CombatEvents.ON_DEAL_DAMAGE]) != 1:
		return false
	return true


static func _test_nonlethal_still_hurts() -> bool:
	var bus := CombatEventBus.new()
	var pipeline := RealtimeDamagePipeline.new(bus)
	var unit := UnitInstance.new("tank", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = 8
	unit.current_hp = 8
	var rt := RtUnit.new(unit, Vector2(0.5, 0.5))
	rt.skip_deploy()
	var counts := _count_events(bus)
	if pipeline.apply_damage(null, rt, 3):
		return false
	if unit.current_hp != 5:
		return false
	if int(counts[CombatEvents.ON_DAMAGE_TAKEN]) != 1:
		return false
	if int(counts[CombatEvents.ON_FRIEND_DAMAGE_TAKEN]) != 1:
		return false
	if int(counts[CombatEvents.ON_DEATH]) != 0:
		return false
	return true
