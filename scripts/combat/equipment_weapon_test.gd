class_name EquipmentWeaponTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("flat_bonus_on_attack", _test_flat_bonus())
	_check("poison_not_on_lethal", _test_poison_skip_lethal())
	_check("poison_on_surviving_hit", _test_poison_on_hit())
	_check("burn_on_hit", _test_burn_on_hit())
	_check("lifesteal_on_attack", _test_lifesteal())
	_check("weapon_armor_exclusive", _test_weapon_slot())
	if _failures == 0:
		print("EquipmentWeaponTest: all passed")
		return true
	push_error("EquipmentWeaponTest: %d failure(s)" % _failures)
	return false


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("EquipmentWeaponTest FAIL: %s" % name)


static func _test_flat_bonus() -> bool:
	var sim := RealtimeCombatSim.new()
	sim.configure(Vector2i(12, 20), 44)
	var entry := DeckEntry.new()
	entry.unit = load("res://resources/units/realtime/knight.tres") as UnitData
	var weapon := EquipmentWeaponCatalog.get_by_id("weapon_flat_t1")
	entry.attach_equipment(weapon)
	var atk := UnitInstance.from_deck_entry(entry, Vector2i(2, 10), UnitInstance.Team.PLAYER)
	var foe := UnitInstance.from_unit_data(
		load("res://resources/units/realtime/knight.tres") as UnitData,
		Vector2i(4, 10),
		UnitInstance.Team.ENEMY,
	)
	foe.stats.max_hp = 50
	foe.current_hp = 50
	foe.armor_block = 0
	var rt_a := sim.add_unit(atk, Vector2(2.5, 10.5))
	var rt_d := sim.add_unit(foe, Vector2(4.5, 10.5))
	sim.begin_combat()
	var base := atk.get_effective_attack()
	var hp0 := foe.current_hp
	sim._pipeline.resolve_hit(rt_a, rt_d, base, 0.0, sim.get_units())
	if atk.combat_attack_flat_bonus != 2:
		push_error("flat: bonus field=%d" % atk.combat_attack_flat_bonus)
		sim.dispose()
		return false
	var drop := hp0 - foe.current_hp
	if drop != base + 2:
		push_error("flat: drop=%d expected=%d (base=%d)" % [drop, base + 2, base])
	sim.dispose()
	return drop == base + 2


static func _test_poison_skip_lethal() -> bool:
	var sim := RealtimeCombatSim.new()
	sim.configure(Vector2i(8, 12), 45)
	sim.defer_effect_resolve = false
	var entry := DeckEntry.new()
	entry.unit = load("res://resources/units/realtime/knight.tres") as UnitData
	entry.attach_equipment(EquipmentWeaponCatalog.get_by_id("weapon_poison_t1"))
	var atk := UnitInstance.from_deck_entry(entry, Vector2i(1, 6), UnitInstance.Team.PLAYER)
	var foe := UnitInstance.new("f", Vector2i(2, 6), UnitInstance.Team.ENEMY)
	foe.stats = UnitStats.new()
	foe.stats.max_hp = 1
	foe.current_hp = 1
	foe.stats.attack = 0
	var rt_a := sim.add_unit(atk, Vector2(1.5, 6.5))
	var rt_d := sim.add_unit(foe, Vector2(2.5, 6.5))
	sim.begin_combat()
	sim.flush_combat_start_lock()
	sim._pipeline.resolve_hit(rt_a, rt_d, atk.get_effective_attack(), 0.0, sim.get_units())
	while sim.has_pending_effects():
		sim.resolve_next_pending_effect()
	sim.dispose()
	return foe.combat_statuses.get_stacks(CombatStatusStack.ID_POISON) == 0


static func _test_poison_on_hit() -> bool:
	var sim := RealtimeCombatSim.new()
	sim.configure(Vector2i(8, 12), 46)
	sim.defer_effect_resolve = false
	var entry := DeckEntry.new()
	entry.unit = load("res://resources/units/realtime/knight.tres") as UnitData
	entry.attach_equipment(EquipmentWeaponCatalog.get_by_id("weapon_poison_t1"))
	var atk := UnitInstance.from_deck_entry(entry, Vector2i(1, 6), UnitInstance.Team.PLAYER)
	var foe := UnitInstance.new("f", Vector2i(2, 6), UnitInstance.Team.ENEMY)
	foe.stats = UnitStats.new()
	foe.stats.max_hp = 40
	foe.current_hp = 40
	var rt_a := sim.add_unit(atk, Vector2(1.5, 6.5))
	var rt_d := sim.add_unit(foe, Vector2(2.5, 6.5))
	sim.begin_combat()
	sim.flush_combat_start_lock()
	sim._pipeline.resolve_hit(rt_a, rt_d, atk.get_effective_attack(), 0.0, sim.get_units())
	while sim.has_pending_effects():
		sim.resolve_next_pending_effect()
	var stacks := foe.combat_statuses.get_stacks(CombatStatusStack.ID_POISON)
	sim.dispose()
	return stacks >= 1


static func _test_burn_on_hit() -> bool:
	var sim := RealtimeCombatSim.new()
	sim.configure(Vector2i(8, 12), 47)
	sim.defer_effect_resolve = false
	var entry := DeckEntry.new()
	entry.unit = load("res://resources/units/realtime/knight.tres") as UnitData
	entry.attach_equipment(EquipmentWeaponCatalog.get_by_id("weapon_burn_t2"))
	var atk := UnitInstance.from_deck_entry(entry, Vector2i(1, 6), UnitInstance.Team.PLAYER)
	var foe := UnitInstance.new("f", Vector2i(2, 6), UnitInstance.Team.ENEMY)
	foe.stats = UnitStats.new()
	foe.stats.max_hp = 40
	foe.current_hp = 40
	var rt_a := sim.add_unit(atk, Vector2(1.5, 6.5))
	var rt_d := sim.add_unit(foe, Vector2(2.5, 6.5))
	sim.begin_combat()
	sim.flush_combat_start_lock()
	sim._pipeline.resolve_hit(rt_a, rt_d, atk.get_effective_attack(), 0.0, sim.get_units())
	while sim.has_pending_effects():
		sim.resolve_next_pending_effect()
	var stacks := foe.combat_statuses.get_stacks(CombatStatusStack.ID_BURN)
	sim.dispose()
	return stacks >= 2


static func _test_lifesteal() -> bool:
	var sim := RealtimeCombatSim.new()
	sim.configure(Vector2i(8, 12), 48)
	sim.defer_effect_resolve = false
	var entry := DeckEntry.new()
	entry.unit = load("res://resources/units/realtime/knight.tres") as UnitData
	entry.attach_equipment(EquipmentWeaponCatalog.get_by_id("weapon_leech_t1"))
	var atk := UnitInstance.from_deck_entry(entry, Vector2i(1, 6), UnitInstance.Team.PLAYER)
	atk.current_hp = maxi(1, atk.get_effective_max_hp() - 5)
	var foe := UnitInstance.new("f", Vector2i(2, 6), UnitInstance.Team.ENEMY)
	foe.stats = UnitStats.new()
	foe.stats.max_hp = 40
	foe.current_hp = 40
	var hp_before := atk.current_hp
	var rt_a := sim.add_unit(atk, Vector2(1.5, 6.5))
	var rt_d := sim.add_unit(foe, Vector2(2.5, 6.5))
	sim.begin_combat()
	sim.flush_combat_start_lock()
	sim._pipeline.resolve_hit(rt_a, rt_d, atk.get_effective_attack(), 0.0, sim.get_units())
	while sim.has_pending_effects():
		sim.resolve_next_pending_effect()
	var gained := atk.current_hp - hp_before
	sim.dispose()
	return gained >= 3


static func _test_weapon_slot() -> bool:
	var entry := DeckEntry.new()
	entry.unit = load("res://resources/units/realtime/knight.tres") as UnitData
	var armor := EquipmentData.new()
	armor.id = "armor_t2"
	armor.armor_block = 6
	entry.attach_equipment(armor)
	var weapon := EquipmentWeaponCatalog.get_by_id("weapon_flat_t1")
	entry.attach_equipment(weapon)
	if entry.get_armor_block() != 0:
		return false
	if entry.equipment == null or not entry.equipment.is_weapon():
		return false
	return true