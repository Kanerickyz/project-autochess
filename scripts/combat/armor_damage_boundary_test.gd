class_name ArmorDamageBoundaryTest
extends RefCounted
## MAP_SHOP §5.1：最终扣血 0 不发受伤事件；>0 仍发。

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("full_block_no_hurt_event", _test_full_block())
	_check("partial_block_emits_hurt", _test_partial_block())
	_check("realtime_full_block", _test_realtime_full_block())
	_check("armor_depletes_and_destroys_equipment", _test_armor_depletes())
	_check("partial_hit_leaves_remaining_armor", _test_armor_partial_deplete())
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

	pipeline.apply_damage(null, target, 5, false)
	if target.current_hp != 20:
		return false
	if int(hurt_count[0]) != 0:
		return false
	## 全额抵挡仍消耗护甲。
	if target.get_armor_block() != 0:
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

	var captured: Array = [null]
	bus.combat_event.connect(func(event_type: StringName, payload: CombatEventPayload) -> void:
		if event_type == CombatEvents.ON_DAMAGE_TAKEN:
			captured[0] = payload
	)

	pipeline.apply_damage(null, target, 5, false)
	if target.current_hp != 17:
		return false
	var payload: CombatEventPayload = captured[0]
	if payload == null:
		return false
	if payload.amount != 3:
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

	pipeline.apply_damage(null, target, 5, false)
	if target.get_armor_block() != 0:
		return false
	if entry.equipment != null:
		return false
	if target.current_hp != 20:
		return false
	return true


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
