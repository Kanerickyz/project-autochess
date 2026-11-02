class_name CombatProfessionRulesTest
extends RefCounted
## 行为职业窄测：槽数派生、嘲讽硬锁、刺客优先、远程暴击倍率路径。


static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("profession_slot_counts", _test_profession_slot_counts())
	_check("tank_zero_slots_rejects_attach", _test_tank_zero_slots())
	_check("taunt_locks_non_assassin", _test_taunt_locks_non_assassin())
	_check("assassin_ignores_taunt_priority", _test_assassin_priority())
	_check("ranged_crit_multiplier_path", _test_ranged_crit_path())
	_check("deck_skills_from_ability_equipment", _test_deck_skills_from_equipment())
	_check("enemy_blank_template_ability", _test_enemy_blank_template_ability())
	_check("info_card_profession_rules", _test_info_card_profession_rules())
	if _failures == 0:
		print("CombatProfessionRulesTest: all tests passed")
	else:
		push_error("CombatProfessionRulesTest: %d failure(s)" % _failures)
	return _failures == 0


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("CombatProfessionRulesTest FAIL: %s" % name)


static func _make_rt(
	id: String,
	team: UnitInstance.Team,
	cell: Vector2i,
	prof: UnitData.CombatProfession,
	hp: int = 10,
) -> RtUnit:
	var data := UnitData.new()
	data.id = id
	data.combat_profession = prof
	data.stats = UnitStats.new()
	data.stats.max_hp = hp
	data.stats.attack = 2
	data.stats.attack_reach = 1.0
	data.stats.sight_range = 20.0
	var inst := UnitInstance.from_unit_data(data, cell, team)
	inst.current_hp = hp
	return RtUnit.new(inst, Vector2(cell) + Vector2(0.5, 0.5))


static func _test_profession_slot_counts() -> bool:
	var checks := [
		[UnitData.CombatProfession.TANK, 0],
		[UnitData.CombatProfession.MELEE, 1],
		[UnitData.CombatProfession.ASSASSIN, 2],
		[UnitData.CombatProfession.RANGED, 3],
	]
	for row in checks:
		var prof: UnitData.CombatProfession = row[0]
		var expect: int = row[1]
		if UnitData.equipment_slots_for_profession(prof) != expect:
			return false
		var unit := UnitData.new()
		unit.combat_profession = prof
		var entry := DeckEntry.new()
		entry.unit = unit
		if entry.get_equipment_slot_count() != expect:
			return false
		if unit.get_equipment_slot_count_resolved() != expect:
			return false
	return true


static func _test_tank_zero_slots() -> bool:
	var unit := UnitData.new()
	unit.combat_profession = UnitData.CombatProfession.TANK
	var entry := DeckEntry.new()
	entry.unit = unit
	var eq := EquipmentData.new()
	eq.id = "armor_t1"
	eq.kind = EquipmentData.Kind.ARMOR
	eq.armor_block = 2
	if entry.attach_equipment(eq):
		return false
	return entry.get_equipment_occupied() == 0


static func _test_taunt_locks_non_assassin() -> bool:
	var attacker := _make_rt("melee", UnitInstance.Team.PLAYER, Vector2i(2, 6), UnitData.CombatProfession.MELEE)
	var tank := _make_rt("tank", UnitInstance.Team.ENEMY, Vector2i(4, 2), UnitData.CombatProfession.TANK, 8)
	var ranged := _make_rt("bow", UnitInstance.Team.ENEMY, Vector2i(1, 1), UnitData.CombatProfession.RANGED, 3)
	## 远程更近，但有坦克时非刺客必须锁坦克。
	var picked := RtUnitBrain.acquire_target(attacker, [attacker, tank, ranged])
	return picked == tank


static func _test_assassin_priority() -> bool:
	var assassin := _make_rt("sin", UnitInstance.Team.PLAYER, Vector2i(2, 6), UnitData.CombatProfession.ASSASSIN)
	var tank := _make_rt("tank", UnitInstance.Team.ENEMY, Vector2i(2, 5), UnitData.CombatProfession.TANK, 20)
	var ranged_hi := _make_rt("bow_hi", UnitInstance.Team.ENEMY, Vector2i(0, 0), UnitData.CombatProfession.RANGED, 8)
	var ranged_lo := _make_rt("bow_lo", UnitInstance.Team.ENEMY, Vector2i(4, 0), UnitData.CombatProfession.RANGED, 3)
	## 无视嘲讽；远程优先；同档打当前生命更少。
	var picked := RtUnitBrain.acquire_target(assassin, [assassin, tank, ranged_hi, ranged_lo])
	return picked == ranged_lo


static func _test_ranged_crit_path() -> bool:
	var base := 10
	var no_crit := RealtimeCombatSim.apply_ranged_basic_crit(base, true, 0.05)
	var crit := RealtimeCombatSim.apply_ranged_basic_crit(base, true, 0.0)
	var melee := RealtimeCombatSim.apply_ranged_basic_crit(base, false, 0.0)
	if no_crit != 10:
		return false
	if crit != 15:
		return false
	if melee != 10:
		return false
	return true


static func _test_deck_skills_from_equipment() -> bool:
	var data := UnitData.new()
	data.id = "melee_u"
	data.combat_profession = UnitData.CombatProfession.MELEE
	data.stats = UnitStats.new()
	data.stats.max_hp = 5
	data.stats.attack = 1
	var ab := AbilityData.new()
	ab.id = "test_skill"
	data.ability = ab
	var entry := DeckEntry.new()
	entry.unit = data
	var empty := UnitInstance.from_deck_entry(entry, Vector2i.ZERO, UnitInstance.Team.PLAYER)
	if empty == null or empty.get_all_effect_specs().size() != 0:
		return false
	var skill_eq := EquipmentData.new()
	skill_eq.id = "skill_test"
	skill_eq.kind = EquipmentData.Kind.ABILITY
	skill_eq.ability = ab
	if not entry.attach_equipment(skill_eq):
		return false
	var armed := UnitInstance.from_deck_entry(entry, Vector2i.ZERO, UnitInstance.Team.PLAYER)
	## Ability 无 effect_specs 时 size 仍为 0；至少主技能应来自装备（duplicate 后比 id）。
	if armed == null or armed.get_main_ability() == null:
		return false
	if armed.get_main_ability().id != "test_skill":
		return false
	## 同 id 两件：远程 3 槽挂两件技能装。
	data.combat_profession = UnitData.CombatProfession.RANGED
	entry.equipments.clear()
	entry.equipment_piece_max.clear()
	entry.equipment_armor_max = 0
	var eq1 := EquipmentData.new()
	eq1.id = "skill_a"
	eq1.kind = EquipmentData.Kind.ABILITY
	eq1.ability = ab
	var eq2 := EquipmentData.new()
	eq2.id = "skill_a"
	eq2.kind = EquipmentData.Kind.ABILITY
	eq2.ability = ab
	if not entry.attach_equipment(eq1):
		return false
	if not entry.attach_equipment(eq2):
		return false
	var abs := entry.get_equipment_abilities()
	return abs.size() == 2


## 敌方 / 无牌库：模板 ability 不生效（与友方空装对齐）。
static func _test_enemy_blank_template_ability() -> bool:
	var data := UnitData.new()
	data.id = "enemy_with_template"
	data.combat_profession = UnitData.CombatProfession.RANGED
	data.stats = UnitStats.new()
	data.stats.max_hp = 4
	data.stats.attack = 2
	var ab := AbilityData.new()
	ab.id = "should_not_auto_bind"
	data.ability = ab
	var enemy := UnitInstance.from_unit_data(data, Vector2i(1, 1), UnitInstance.Team.ENEMY)
	if enemy.get_main_ability() != null:
		return false
	if not enemy.get_all_effect_specs().is_empty():
		return false
	enemy.bind_template_ability_for_tests()
	return enemy.get_main_ability() != null and enemy.get_main_ability().id == "should_not_auto_bind"


## 长按介绍卡技能区展示职业词条，且不把模板 ability 当自带技能。
static func _test_info_card_profession_rules() -> bool:
	var data := UnitData.new()
	data.id = "info_u"
	data.combat_profession = UnitData.CombatProfession.ASSASSIN
	data.stats = UnitStats.new()
	var ab := AbilityData.new()
	ab.id = "catalog_only"
	ab.display_name = "不该出现的自带技"
	data.ability = ab
	var from_data := UnitInfoText.get_skills_block_from_unit_data(data, 1, false)
	if not from_data.contains("【职业·刺客】"):
		return false
	if from_data.contains("不该出现的自带技") or from_data.contains("技能装（图鉴）"):
		return false
	var unit := UnitInstance.from_unit_data(data, Vector2i.ZERO, UnitInstance.Team.ENEMY)
	var from_inst := UnitInfoText.get_skills_block(unit, false)
	if not from_inst.contains("【职业·刺客】"):
		return false
	if from_inst.contains("不该出现的自带技"):
		return false
	return true
