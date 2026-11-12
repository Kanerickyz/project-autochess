class_name BadgeCombatEffectTest
extends RefCounted
## 徽章开战效果：坦克生命、同盟放大、远程命中加伤字段。


static func run_all() -> bool:
	var passed := true
	passed = _test_tank_hp_on_combat_start() and passed
	passed = _test_alliance_amplifies_tank() and passed
	passed = _test_no_badge_no_team_stats() and passed
	passed = _test_ranged_hit_bonus_field() and passed
	passed = _test_warrior_melee_only() and passed
	passed = _test_artisan_armor_and_band_rage() and passed
	return passed


static func _make_unit(unit_id: String, occupation: String, team: UnitInstance.Team, ranged: bool = false) -> UnitInstance:
	var data := UnitData.new()
	data.id = unit_id
	data.display_name = unit_id
	data.occupation = occupation
	data.stats = UnitStats.new()
	data.stats.attack = 3
	data.stats.max_hp = 10
	data.stats.projectile_speed = 8.0 if ranged else 0.0
	var unit := UnitInstance.from_unit_data(data, Vector2i(0, 0), team)
	return unit


static func _test_tank_hp_on_combat_start() -> bool:
	var a := _make_unit("tank_a", SynergyOccupations.TANK, UnitInstance.Team.PLAYER)
	var b := _make_unit("tank_b", SynergyOccupations.TANK, UnitInstance.Team.PLAYER)
	var foe := _make_unit("foe", SynergyOccupations.WARRIOR, UnitInstance.Team.ENEMY)
	var owned := PackedStringArray(["badge_tank_hp_2"])
	var before := a.get_effective_max_hp()
	var result := BadgeCombatApplier.apply_combat_start(owned, [a, b], [foe], null)
	if not ("badge_tank_hp_2" in result["applied_ids"]):
		push_error("tank hp: badge not applied")
		return false
	if a.get_effective_max_hp() != before + 3:
		push_error("tank hp: max_hp expected +3 got %d" % a.get_effective_max_hp())
		return false
	if a.current_hp != before + 3:
		push_error("tank hp: current_hp should sync +3")
		return false
	if b.get_effective_max_hp() != before + 3:
		push_error("tank hp: both allies should gain")
		return false
	return true


static func _test_alliance_amplifies_tank() -> bool:
	var a := _make_unit("tank_a", SynergyOccupations.TANK, UnitInstance.Team.PLAYER)
	var b := _make_unit("tank_b", SynergyOccupations.TANK, UnitInstance.Team.PLAYER)
	var owned := PackedStringArray(["badge_tank_hp_2", "badge_alliance_amp"])
	var before := a.get_effective_max_hp()
	var result := BadgeCombatApplier.apply_combat_start(owned, [a, b], [], null)
	if int(result.get("amp", 0)) != 1:
		push_error("alliance: amp should be 1")
		return false
	## +3 基础 +1 同盟 = +4
	if a.get_effective_max_hp() != before + 4:
		push_error(
			"alliance: expected +4 hp got delta %d"
			% (a.get_effective_max_hp() - before)
		)
		return false
	return true


static func _test_no_badge_no_team_stats() -> bool:
	var a := _make_unit("tank_a", SynergyOccupations.TANK, UnitInstance.Team.PLAYER)
	var b := _make_unit("tank_b", SynergyOccupations.TANK, UnitInstance.Team.PLAYER)
	var before := a.get_effective_max_hp()
	var result := BadgeCombatApplier.apply_combat_start(PackedStringArray(), [a, b], [], null)
	if not (result["applied_ids"] as PackedStringArray).is_empty():
		push_error("no badge: should apply nothing")
		return false
	if a.get_effective_max_hp() != before:
		push_error("no badge: hp must stay")
		return false
	return true


static func _test_ranged_hit_bonus_field() -> bool:
	var archer := _make_unit("archer_a", SynergyOccupations.RANGED, UnitInstance.Team.PLAYER, true)
	var melee := _make_unit("knight_a", SynergyOccupations.WARRIOR, UnitInstance.Team.PLAYER, false)
	## 远程 ×2 需要两种远程 id；再塞一只假远程以满足门槛。
	var archer2 := _make_unit("archer_b", SynergyOccupations.RANGED, UnitInstance.Team.PLAYER, true)
	var owned := PackedStringArray(["badge_ranged_hit_1"])
	BadgeCombatApplier.apply_combat_start(owned, [archer, archer2, melee], [], null)
	if archer.combat_ranged_hit_bonus != 1:
		push_error("ranged hit: archer bonus expected 1 got %d" % archer.combat_ranged_hit_bonus)
		return false
	if melee.combat_ranged_hit_bonus != 0:
		push_error("ranged hit: melee must stay 0")
		return false
	return true


static func _test_warrior_melee_only() -> bool:
	## 战士 ×3：三名战士种类；含一只远程战士应不加攻。
	var w1 := _make_unit("w1", SynergyOccupations.WARRIOR, UnitInstance.Team.PLAYER, false)
	var w2 := _make_unit("w2", SynergyOccupations.WARRIOR, UnitInstance.Team.PLAYER, false)
	var w3 := _make_unit("w3", SynergyOccupations.WARRIOR, UnitInstance.Team.PLAYER, true)
	var atk_melee_before := w1.get_effective_attack()
	var atk_ranged_before := w3.get_effective_attack()
	BadgeCombatApplier.apply_combat_start(
		PackedStringArray(["badge_warrior_melee_atk_3"]),
		[w1, w2, w3],
		[],
		null,
	)
	if w1.get_effective_attack() != atk_melee_before + 1:
		push_error("warrior: melee should +1")
		return false
	if w3.get_effective_attack() != atk_ranged_before:
		push_error("warrior: ranged projectile should not get melee atk")
		return false
	return true


static func _test_artisan_armor_and_band_rage() -> bool:
	var a1 := _make_unit("art_a", SynergyOccupations.ARTISAN, UnitInstance.Team.PLAYER)
	var a2 := _make_unit("art_b", SynergyOccupations.ARTISAN, UnitInstance.Team.PLAYER)
	var b1 := _make_unit("band_a", SynergyOccupations.BAND, UnitInstance.Team.PLAYER)
	var b2 := _make_unit("band_b", SynergyOccupations.BAND, UnitInstance.Team.PLAYER)
	BadgeCombatApplier.apply_combat_start(
		PackedStringArray(["badge_artisan_armor_2", "badge_band_rage_2"]),
		[a1, a2, b1, b2],
		[],
		null,
	)
	if a1.combat_temp_armor != 2:
		push_error("artisan: temp armor expected 2 got %d" % a1.combat_temp_armor)
		return false
	if a1.combat_statuses.get_stacks(CombatStatusStack.ID_BERSERK) != 2:
		push_error("band: berserk expected 2")
		return false
	return true
