class_name RealtimeAbilityEffectTest
extends RefCounted
## Headless：Content §6 九人挂载 + realtime EffectResolver 接线（MODIFY_STAT / DEAL_DAMAGE / SPAWN_UNIT）。

const ARENA := Vector2i(18, 32)

const MOUNT_TABLE := {
	"knight": "hurt_gain_atk_small",
	"rider": "enemy_death_self_atk_hp_small",
	"mini_pekka": "kill_gain_atk_mid",
	"musketeer": "deal_damage_extra_2",
	"valkyrie": "friend_summon_nearby_ally_atk_hp_1",
	"barbarian": "ally_death_self_atk_mid",
	"archer": "deal_damage_apply_weak",
	"goblin": "death_spawn_pack",
	"spear_goblin": "hurt_heal_self_2",
	"skeleton": "death_heal_random_ally_2",
	"crossbow": "ally_hurt_heal_target_small",
	"maul": "deal_damage_adj_splash_small",
	"apothecary": "turn_start_nearby_enemies_apply_poison",
}

const EMPTY_ABILITY_IDS := ["giant_knight"]


static var _created: Array[RealtimeCombatSim] = []
static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("mount_bindings", _test_mount_bindings())
	_check("ability_merge_value_multiplier", _test_ability_merge_value_multiplier())
	_check("enemy_death_self_atk_hp_small", _test_enemy_death_self_atk_hp_small())
	_check("enemy_death_self_atk_hp_star2_x3", _test_enemy_death_self_atk_hp_star2_x3())
	_check("enemy_death_random_ally_atk_hp_small", _test_enemy_death_random_ally_atk_hp_small())
	_check("enemy_death_random_ally_atk_hp_star2_x3", _test_enemy_death_random_ally_atk_hp_star2_x3())
	_check("enemy_death_nearby_allies_atk_hp_small", _test_enemy_death_nearby_allies_atk_hp_small())
	_check("mend_friar_enemy_death_lr_allies", _test_mend_friar_enemy_death_lr_allies())
	_check("mend_friar_enemy_death_lr_allies_star2", _test_mend_friar_enemy_death_lr_allies_star2())
	_check("dirge_horn_friend_summon_lr_allies", _test_dirge_horn_friend_summon_lr_allies())
	_check("dirge_horn_friend_summon_lr_allies_star2", _test_dirge_horn_friend_summon_lr_allies_star2())
	_check("survive_turn_end_bank_turn_refresh", _test_survive_turn_end_bank_turn_refresh())
	_check("scatter_hex_friend_kill_damage", _test_scatter_hex_friend_kill_damage())
	_check("scatter_hex_friend_kill_damage_star2", _test_scatter_hex_friend_kill_damage_star2())
	_check("arcane_friend_summon_nearby_hp", _test_arcane_friend_summon_nearby_hp())
	_check("arcane_friend_summon_nearby_hp_star2", _test_arcane_friend_summon_nearby_hp_star2())
	_check("valkyrie_friend_summon_nearby_atk_hp", _test_valkyrie_friend_summon_nearby_atk_hp())
	_check("valkyrie_friend_summon_nearby_atk_hp_star2", _test_valkyrie_friend_summon_nearby_atk_hp_star2())
	_check("gravewright_hurt_nearby_weak", _test_gravewright_hurt_nearby_weak())
	_check("gravewright_hurt_nearby_weak_star2", _test_gravewright_hurt_nearby_weak_star2())
	_check("berserker_kill_turn_refresh", _test_berserker_kill_turn_refresh())
	_check("hurt_gain_atk_on_damage", _test_hurt_gain_atk_on_damage())
	_check("deal_damage_gain_atk", _test_deal_damage_gain_atk())
	_check("deal_damage_extra_2", _test_deal_damage_extra_2())
	_check("kill_gain_atk_mid", _test_kill_gain_atk_mid())
	_check("ally_death_self_atk_mid", _test_ally_death_self_atk_mid())
	_check("archer_deal_apply_weak", _test_archer_deal_apply_weak())
	_check("first_hurt_harden_once", _test_first_hurt_harden_once())
	_check("first_hurt_harden_star2", _test_first_hurt_harden_star2())
	_check("hunter_friend_summoned_buff", _test_hunter_friend_summoned_buff())
	_check("hunter_friend_summoned_buff_star2", _test_hunter_friend_summoned_buff_star2())
	_check("deal_damage_adj_splash_small", _test_deal_damage_adj_splash_small())
	_check("turn_start_nearby_enemies_poison", _test_turn_start_nearby_enemies_poison())
	_check("turn_start_nearby_enemies_poison_star2", _test_turn_start_nearby_enemies_poison_star2())
	_check("wardrum_turn_start_nearby_berserk", _test_wardrum_turn_start_nearby_berserk())
	_check("wardrum_turn_start_nearby_berserk_star2", _test_wardrum_turn_start_nearby_berserk_star2())
	_check("death_spawn_pack", _test_death_spawn_pack())
	_check("death_spawn_pack_star2", _test_death_spawn_pack_star2())
	_check("ally_death_spawn_weak", _test_ally_death_spawn_weak())
	_check("ally_death_spawn_merged_triple", _test_ally_death_spawn_merged_triple())
	_check("death_heal_nearby_ally", _test_death_heal_nearby_ally())
	_check("hurt_heal_self_2", _test_hurt_heal_self_2())
	_check("hurt_heal_capped_to_hit", _test_hurt_heal_capped_to_hit())
	_check("blood_acolyte_survive_permanent", _test_blood_acolyte_survive_permanent())
	_check("blood_acolyte_dead_skips_permanent", _test_blood_acolyte_dead_skips_permanent())
	_check("aftershock_attack_kill_only", _test_aftershock_attack_kill_only())
	_check("boomling_kill_damage_all_except_self", _test_boomling_kill_damage_all_except_self())
	_check("boomling_kill_damage_all_star2", _test_boomling_kill_damage_all_star2())
	_check("mirror_warden_kill_convert", _test_mirror_warden_kill_convert())
	_check("ally_hurt_heal_target", _test_ally_hurt_heal_target())
	_check("ally_hurt_heal_target_star2", _test_ally_hurt_heal_target_star2())
	_check("ally_hurt_heal_skips_when_full", _test_ally_hurt_heal_skips_when_full())
	_check("deal_damage_extra_2_star2", _test_deal_damage_extra_2_star2())
	_check("turn_start_strike_weakest_mount", _test_turn_start_strike_weakest_mount())
	_check("turn_start_strike_weakest_damage", _test_turn_start_strike_weakest_damage())
	_check(
		"turn_start_strike_weakest_teleport_deferred",
		_test_turn_start_strike_weakest_teleport_deferred(),
	)
	_check("devour_lr_absorb_and_kill", _test_devour_lr_absorb_and_kill())
	_check("devour_star2_skips_boss", _test_devour_star2_skips_boss())
	_check("devour_rt_defer_kills_left_right", _test_devour_rt_defer_kills_left_right())
	_check("devour_rt_pending_before_attack", _test_devour_rt_pending_before_attack())
	_check("tier_unlock_t2_from_floor_4", _test_tier_unlock_t2_from_floor_4())
	_check("combat_start_iron_heart", _test_combat_start_iron_heart())
	_check("combat_start_edge_hex", _test_combat_start_edge_hex())
	_check("combat_start_shield_boon", _test_combat_start_shield_boon())
	_check("combat_start_banner_nearby", _test_combat_start_banner_nearby())

	for sim in _created:
		sim.dispose()
	_created.clear()
	if _failures == 0:
		print("RealtimeAbilityEffectTest: all passed")
		return true
	push_error("RealtimeAbilityEffectTest: %d failure(s)" % _failures)
	return false


static func _new_sim(bus: CombatEventBus = null) -> RealtimeCombatSim:
	var sim := RealtimeCombatSim.new(bus)
	_created.append(sim)
	return sim


static func _check(name: String, passed: bool) -> void:
	if passed:
		print("  PASS %s" % name)
	else:
		_failures += 1
		push_error("RealtimeAbilityEffectTest: FAIL %s" % name)


static func _load_unit(path: String) -> UnitData:
	return load(path) as UnitData


static func _test_mount_bindings() -> bool:
	for unit_id in MOUNT_TABLE.keys():
		var data := _load_unit("res://resources/units/realtime/%s.tres" % unit_id)
		if data == null:
			push_error("mount: missing unit %s" % unit_id)
			return false
		if data.ability == null:
			push_error("mount: %s ability is null" % unit_id)
			return false
		var expected: String = MOUNT_TABLE[unit_id]
		if data.ability.id != expected:
			push_error(
				"mount: %s ability id=%s expected=%s" % [unit_id, data.ability.id, expected]
			)
			return false
	for unit_id in EMPTY_ABILITY_IDS:
		var blank := _load_unit("res://resources/units/realtime/%s.tres" % unit_id)
		if blank == null:
			push_error("mount: missing blank unit %s" % unit_id)
			return false
		if blank.ability != null:
			push_error("mount: %s should have empty ability, got %s" % [unit_id, blank.ability.id])
			return false
	return true


static func _make_from_data(data: UnitData, team: UnitInstance.Team) -> UnitInstance:
	return UnitInstance.from_unit_data(data, Vector2i.ZERO, team)


static func _dummy(team: UnitInstance.Team, hp: int = 100000, overrides: Dictionary = {}) -> UnitInstance:
	return RealtimeCombatSimTest.make_dummy(team, hp, overrides)


static func _test_ability_merge_value_multiplier() -> bool:
	if UnitInstance.ability_value_multiplier(1) != 1:
		push_error("ability mult: 1★ expected 1")
		return false
	if UnitInstance.ability_value_multiplier(2) != 6:
		push_error("ability mult: 2★ expected 6")
		return false
	if UnitInstance.ability_value_multiplier(3) != 36:
		push_error("ability mult: 3★ expected 36")
		return false
	## 血僧禅心固本：全局升星 ×6；基础 +1/+1 → 2★ 各 +6。
	var blood := load("res://resources/abilities/combat_start_permanent_self_atk_hp_1.tres") as AbilityData
	if blood == null:
		push_error("ability mult: missing combat_start_permanent_self_atk_hp_1")
		return false
	if UnitInstance.ability_value_multiplier_for(blood, 2) != 6:
		push_error("ability mult: blood 2★ scale expected 6")
		return false
	var act: EffectAction = null
	if not blood.effect_specs.is_empty() and blood.effect_specs[0] != null:
		var specs_actions: Array = blood.effect_specs[0].actions
		if not specs_actions.is_empty():
			act = specs_actions[0] as EffectAction
	if act == null or act.value != 1:
		push_error("ability mult: blood base atk value expected 1")
		return false
	if act.value * UnitInstance.ability_value_multiplier_for(blood, 2) != 6:
		push_error("ability mult: blood 2★ effective atk expected +6")
		return false
	return true


static func _test_enemy_death_self_atk_hp_small() -> bool:
	var data := _load_unit("res://resources/units/realtime/rider.tres")
	if data == null or data.ability == null or data.ability.id != "enemy_death_self_atk_hp_small":
		push_error("rider: enemy_death ability not mounted")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("rider: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 42)
	var rider := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	## 友方死亡不应触发。
	var ally := sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 20, {"id": "ally_fodder", "steps_per_turn": 0}), Vector2(8.5, 24.5))
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"id": "enemy_fodder", "steps_per_turn": 0}),
		Vector2(9.5, 8.5),
	)
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sim.begin_combat()
	var base_atk := rider.unit.get_effective_attack()
	var base_hp := rider.unit.get_effective_max_hp()
	if not sim._pipeline.apply_damage(null, ally, 999):
		push_error("rider: failed to kill ally fodder")
		return false
	sim._drain_effects()
	if rider.unit.get_effective_attack() != base_atk or rider.unit.get_effective_max_hp() != base_hp:
		push_error("rider: ally death should not buff")
		return false
	## 敌方死亡：+1/+1
	if not sim._pipeline.apply_damage(null, enemy, 999):
		push_error("rider: failed to kill enemy fodder")
		return false
	sim._drain_effects()
	var after_atk := rider.unit.get_effective_attack()
	var after_hp := rider.unit.get_effective_max_hp()
	if after_atk != base_atk + 1:
		push_error("rider: atk %d -> %d, expected +1" % [base_atk, after_atk])
		return false
	if after_hp != base_hp + 1:
		push_error("rider: max_hp %d -> %d, expected +1" % [base_hp, after_hp])
		return false
	return true


## 散咒：其他友方击杀 → 对随机存活敌人造成 1（2★ 为 3）。自己的击杀、无来源死亡不触发。
static func _scatter_hex_friend_kill_dealt(level: int) -> int:
	var data := _load_unit("res://resources/units/realtime/scatter_hex.tres")
	if data == null or data.ability == null or data.ability.id != "friend_kill_damage_random_enemy_1":
		push_error("scatter_hex: ability mount")
		return -1
	if data.ability.merge_value_mult != 3:
		push_error("scatter_hex: merge_value_mult expected 3")
		return -1
	var sim := _new_sim()
	sim.configure(ARENA, 4300 + level)
	var caster := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	caster.unit.level = level
	var fodder := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 5, {"id": "fodder", "steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(9.5, 8.5),
	)
	var target := sim.add_unit(
		_dummy(
			UnitInstance.Team.ENEMY,
			500,
			{"id": "target", "steps_per_turn": 0, "sight_range": 0.0, "attack_reach": 0.0},
		),
		Vector2(8.5, 8.5),
	)
	var ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 30, {"id": "ally_killer", "attack": 1, "steps_per_turn": 0}),
		Vector2(8.5, 24.5),
	)
	var ally_fodder := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 5, {"id": "ally_fodder", "steps_per_turn": 0}),
		Vector2(7.5, 24.5),
	)
	var sourceless := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 5, {"id": "sourceless", "steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(10.5, 8.5),
	)
	var fodder2 := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 5, {"id": "fodder2", "steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(11.5, 8.5),
	)
	sim.begin_combat()
	var hp_before := target.unit.current_hp
	if not sim._pipeline.apply_damage(null, ally_fodder, 999):
		push_error("scatter_hex: failed to kill ally")
		return -1
	sim._drain_effects()
	if target.unit.current_hp != hp_before:
		push_error("scatter_hex: ally death should not damage enemy")
		return -1
	## 无击杀者的敌方死亡不触发。
	if not sim._pipeline.apply_damage(null, sourceless, 999):
		push_error("scatter_hex: failed to kill sourceless enemy")
		return -1
	sim._drain_effects()
	if target.unit.current_hp != hp_before:
		push_error("scatter_hex: sourceless death should not damage enemy")
		return -1
	## 持有者自己的击杀不触发。
	if not sim._pipeline.apply_damage(caster.unit, fodder, 999):
		push_error("scatter_hex: failed to self-kill fodder")
		return -1
	sim._drain_effects()
	if target.unit.current_hp != hp_before:
		push_error("scatter_hex: own kill should not damage enemy")
		return -1
	if not sim._pipeline.apply_damage(ally.unit, fodder2, 999):
		push_error("scatter_hex: failed ally kill")
		return -1
	sim._drain_effects()
	return hp_before - target.unit.current_hp


static func _test_scatter_hex_friend_kill_damage() -> bool:
	var dealt := _scatter_hex_friend_kill_dealt(1)
	if dealt != 1:
		push_error("scatter_hex: dealt %d, expected 1" % dealt)
		return false
	return true


static func _test_scatter_hex_friend_kill_damage_star2() -> bool:
	var dealt := _scatter_hex_friend_kill_dealt(2)
	if dealt != 3:
		push_error("scatter_hex star2: dealt %d, expected 3" % dealt)
		return false
	return true


## 持有者周围一格其他友方；战斗随从才触发。返回 holder/near/far/beside。
static func _setup_summon_nearby(unit_path: String, level: int, seed: int) -> Dictionary:
	var data := _load_unit(unit_path)
	if data == null or data.ability == null:
		return {}
	var sim := _new_sim()
	sim.configure(ARENA, seed)
	var holder := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(8.5, 22.5))
	holder.unit.level = level
	var near := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "near_ally", "attack": 3}),
		Vector2(9.5, 22.5),
	)
	var far := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "far_ally", "attack": 3}),
		Vector2(12.5, 22.5),
	)
	var beside := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "beside_summon", "attack": 3}),
		Vector2(5.5, 10.5),
	)
	return {
		"data": data,
		"sim": sim,
		"holder": holder,
		"near": near,
		"far": far,
		"beside": beside,
	}


static func _spawn_combat_minion(sim: RealtimeCombatSim) -> void:
	var minion := _dummy(UnitInstance.Team.PLAYER, 1, {"id": "token_ember", "max_hp": 1, "attack": 1})
	minion.is_combat_summon = true
	sim.add_unit(minion, Vector2(4.5, 10.5))


## 奥术：友方战斗随从被召唤时，持有者周围一格其他友方生命上限 +1（当前同步）。
static func _test_arcane_friend_summon_nearby_hp() -> bool:
	var built := _setup_summon_nearby("res://resources/units/realtime/arcane.tres", 1, 91)
	if built.is_empty():
		push_error("arcane: setup failed")
		return false
	var data: UnitData = built["data"]
	if data.ability.id != "friend_summon_nearby_ally_hp_1" or data.ability.merge_value_mult != 3:
		push_error("arcane: ability not mounted")
		return false
	var sim: RealtimeCombatSim = built["sim"]
	var holder: RtUnit = built["holder"]
	var near: RtUnit = built["near"]
	var far: RtUnit = built["far"]
	var beside: RtUnit = built["beside"]
	var holder_max := holder.unit.get_effective_max_hp()
	var near_max := near.unit.get_effective_max_hp()
	var near_hp := near.unit.current_hp
	var far_max := far.unit.get_effective_max_hp()
	var beside_max := beside.unit.get_effective_max_hp()
	sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 50, {"id": "ally_roster"}), Vector2(8.5, 21.5))
	if near.unit.get_effective_max_hp() != near_max:
		push_error("arcane: roster ally should not buff")
		return false
	_spawn_combat_minion(sim)
	if holder.unit.get_effective_max_hp() != holder_max:
		push_error("arcane: holder should not gain max_hp")
		return false
	if near.unit.get_effective_max_hp() != near_max + 1 or near.unit.current_hp != near_hp + 1:
		push_error(
			"arcane: near hp %d/%d expected +1"
			% [near.unit.current_hp, near.unit.get_effective_max_hp()]
		)
		return false
	if far.unit.get_effective_max_hp() != far_max or beside.unit.get_effective_max_hp() != beside_max:
		push_error("arcane: far or summon-adjacent ally should stay unchanged")
		return false
	return true


static func _test_arcane_friend_summon_nearby_hp_star2() -> bool:
	var built := _setup_summon_nearby("res://resources/units/realtime/arcane.tres", 2, 92)
	if built.is_empty():
		return false
	var near: RtUnit = built["near"]
	var near_max := near.unit.get_effective_max_hp()
	_spawn_combat_minion(built["sim"])
	if near.unit.get_effective_max_hp() != near_max + 3:
		push_error(
			"arcane 2★: max_hp %d -> %d, expected +3"
			% [near_max, near.unit.get_effective_max_hp()]
		)
		return false
	return true


## 链枷：友方战斗随从被召唤时，持有者周围一格其他友方 +1/+1。
static func _test_valkyrie_friend_summon_nearby_atk_hp() -> bool:
	var built := _setup_summon_nearby("res://resources/units/realtime/valkyrie.tres", 1, 93)
	if built.is_empty():
		push_error("valkyrie: setup failed")
		return false
	var data: UnitData = built["data"]
	if data.ability.id != "friend_summon_nearby_ally_atk_hp_1" or data.ability.merge_value_mult != 3:
		push_error("valkyrie: ability not mounted")
		return false
	if data.tier != 3:
		push_error("valkyrie: expected tier 3")
		return false
	var sim: RealtimeCombatSim = built["sim"]
	var holder: RtUnit = built["holder"]
	var near: RtUnit = built["near"]
	var far: RtUnit = built["far"]
	var beside: RtUnit = built["beside"]
	var holder_atk := holder.unit.get_effective_attack()
	var holder_max := holder.unit.get_effective_max_hp()
	var near_atk := near.unit.get_effective_attack()
	var near_max := near.unit.get_effective_max_hp()
	var near_hp := near.unit.current_hp
	var far_atk := far.unit.get_effective_attack()
	var far_max := far.unit.get_effective_max_hp()
	var beside_atk := beside.unit.get_effective_attack()
	var beside_max := beside.unit.get_effective_max_hp()
	sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 50, {"id": "ally_roster"}), Vector2(8.5, 21.5))
	if near.unit.get_effective_attack() != near_atk or near.unit.get_effective_max_hp() != near_max:
		push_error("valkyrie: roster ally should not buff")
		return false
	_spawn_combat_minion(sim)
	if (
		holder.unit.get_effective_attack() != holder_atk
		or holder.unit.get_effective_max_hp() != holder_max
	):
		push_error("valkyrie: holder should not gain atk/hp")
		return false
	if near.unit.get_effective_attack() != near_atk + 1:
		push_error("valkyrie: near atk %d -> %d, expected +1" % [near_atk, near.unit.get_effective_attack()])
		return false
	if near.unit.get_effective_max_hp() != near_max + 1 or near.unit.current_hp != near_hp + 1:
		push_error(
			"valkyrie: near hp %d/%d expected +1"
			% [near.unit.current_hp, near.unit.get_effective_max_hp()]
		)
		return false
	if (
		far.unit.get_effective_attack() != far_atk
		or far.unit.get_effective_max_hp() != far_max
		or beside.unit.get_effective_attack() != beside_atk
		or beside.unit.get_effective_max_hp() != beside_max
	):
		push_error("valkyrie: far or summon-adjacent ally should stay unchanged")
		return false
	return true


static func _test_valkyrie_friend_summon_nearby_atk_hp_star2() -> bool:
	var built := _setup_summon_nearby("res://resources/units/realtime/valkyrie.tres", 2, 94)
	if built.is_empty():
		return false
	var near: RtUnit = built["near"]
	var near_atk := near.unit.get_effective_attack()
	var near_max := near.unit.get_effective_max_hp()
	_spawn_combat_minion(built["sim"])
	if near.unit.get_effective_attack() != near_atk + 3:
		push_error(
			"valkyrie 2★: atk %d -> %d, expected +3"
			% [near_atk, near.unit.get_effective_attack()]
		)
		return false
	if near.unit.get_effective_max_hp() != near_max + 3:
		push_error(
			"valkyrie 2★: max_hp %d -> %d, expected +3"
			% [near_max, near.unit.get_effective_max_hp()]
		)
		return false
	return true


## 掘墓：受伤时对周围一格敌军施加虚弱（1★ 1 层 / 2★+ 3 层）。
static func _test_gravewright_hurt_nearby_weak() -> bool:
	return _gravewright_hurt_nearby_weak_expect(1, 1)


static func _test_gravewright_hurt_nearby_weak_star2() -> bool:
	return _gravewright_hurt_nearby_weak_expect(2, 3)


static func _gravewright_hurt_nearby_weak_expect(star_level: int, expected_weak: int) -> bool:
	var data := _load_unit("res://resources/units/realtime/gravewright.tres")
	if data == null or data.ability == null or data.ability.id != "hurt_nearby_enemies_apply_weak":
		push_error("gravewright_weak: ability not mounted")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("gravewright_weak: merge_value_mult expected 3")
		return false
	var bus := CombatEventBus.new()
	var grid := BoardGrid.new()
	grid.configure(Vector2i(18, 32))
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var digger := UnitInstance.from_unit_data(data, Vector2i(4, 20), UnitInstance.Team.PLAYER)
	digger.level = star_level
	var adjacent := UnitInstance.from_unit_data(
		_load_unit("res://resources/units/enemies/enemy_knight.tres"),
		Vector2i(5, 20),
		UnitInstance.Team.ENEMY,
	)
	var far := UnitInstance.from_unit_data(
		_load_unit("res://resources/units/enemies/enemy_knight.tres"),
		Vector2i(7, 20),
		UnitInstance.Team.ENEMY,
	)
	var attacker := UnitInstance.from_unit_data(
		_load_unit("res://resources/units/enemies/enemy_knight.tres"),
		Vector2i(5, 21),
		UnitInstance.Team.ENEMY,
	)
	grid.place(digger, Vector2i(4, 20))
	grid.place(adjacent, Vector2i(5, 20))
	grid.place(far, Vector2i(7, 20))
	grid.place(attacker, Vector2i(5, 21))
	var payload := CombatEventPayload.new()
	payload.source = attacker
	payload.target = digger
	payload.amount = 1
	resolver.on_event(CombatEvents.ON_DAMAGE_TAKEN, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
	var adj_weak := adjacent.combat_statuses.get_stacks(CombatStatusStack.ID_WEAK)
	var far_weak := far.combat_statuses.get_stacks(CombatStatusStack.ID_WEAK)
	if adj_weak != expected_weak:
		push_error(
			"gravewright_weak %d★: adjacent weak %d expected %d"
			% [star_level, adj_weak, expected_weak]
		)
		return false
	if far_weak != 0:
		push_error("gravewright_weak: far enemy should have 0 weak, got %d" % far_weak)
		return false
	return true


static func _test_berserker_kill_turn_refresh() -> bool:
	var data := _load_unit("res://resources/units/realtime/berserker.tres")
	if data == null or data.ability == null or data.ability.id != "kill_grant_actor_turn_refresh":
		push_error("berserker: ability not mounted")
		return false
	var specs: Array = data.ability.effect_specs
	if specs.is_empty() or specs[0] == null:
		push_error("berserker: missing spec")
		return false
	if int(specs[0].max_triggers_per_combat) > 0:
		push_error("berserker: max_triggers_per_combat must be unlimited (<=0)")
		return false
	const BOARD := Vector2i(5, 8)
	var sim := _new_sim()
	sim.configure(BOARD, 803)
	var killer_rt := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(2.5, 6.5))
	killer_rt.unit.stats.steps_per_turn = 1
	var victim := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 1, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(3.5, 5.5),
	)
	sim.begin_combat()
	var guard := 0
	while victim.unit.is_alive() and guard < 400:
		sim.advance_fixed_step()
		guard += 1
	if victim.unit.is_alive():
		push_error("berserker refresh: victim should die")
		return false
	var actor := sim.get_current_actor()
	if actor == null or actor.unit.id != "berserker":
		push_error(
			"berserker refresh: expected killer still acting, got %s"
			% (actor.unit.id if actor != null and actor.unit != null else "null")
		)
		return false
	return true


static func _test_enemy_death_random_ally_atk_hp_small() -> bool:
	var data := _load_unit("res://resources/units/realtime/horsebow.tres")
	if data == null or data.ability == null or data.ability.id != "enemy_death_random_ally_atk_hp_small":
		push_error("horsebow: ability not mounted")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("horsebow: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 44)
	var bow := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	var ally := sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 20, {"id": "ally_buff_target", "steps_per_turn": 0}), Vector2(8.5, 24.5))
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"id": "enemy_fodder_hb", "steps_per_turn": 0}),
		Vector2(9.5, 8.5),
	)
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sim.begin_combat()
	var bow_atk0 := bow.unit.get_effective_attack()
	var bow_hp0 := bow.unit.get_effective_max_hp()
	var ally_atk0 := ally.unit.get_effective_attack()
	var ally_hp0 := ally.unit.get_effective_max_hp()
	if not sim._pipeline.apply_damage(null, enemy, 999):
		push_error("horsebow: failed to kill enemy")
		return false
	sim._drain_effects()
	var d_bow_atk := bow.unit.get_effective_attack() - bow_atk0
	var d_bow_hp := bow.unit.get_effective_max_hp() - bow_hp0
	var d_ally_atk := ally.unit.get_effective_attack() - ally_atk0
	var d_ally_hp := ally.unit.get_effective_max_hp() - ally_hp0
	## 恰好一名友方得到 +1/+1。
	var buffed_n := 0
	if d_bow_atk == 1 and d_bow_hp == 1:
		buffed_n += 1
	elif d_bow_atk != 0 or d_bow_hp != 0:
		push_error("horsebow: bow got uneven buff atk=%d hp=%d" % [d_bow_atk, d_bow_hp])
		return false
	if d_ally_atk == 1 and d_ally_hp == 1:
		buffed_n += 1
	elif d_ally_atk != 0 or d_ally_hp != 0:
		push_error("horsebow: ally got uneven buff atk=%d hp=%d" % [d_ally_atk, d_ally_hp])
		return false
	if buffed_n != 1:
		push_error("horsebow: expected exactly 1 ally buffed, got %d" % buffed_n)
		return false
	return true


static func _test_enemy_death_random_ally_atk_hp_star2_x3() -> bool:
	var data := _load_unit("res://resources/units/realtime/horsebow.tres")
	if data == null or data.ability == null or data.ability.id != "enemy_death_random_ally_atk_hp_small":
		push_error("horsebow2: ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 45)
	## 场上仅骑弓：随机友方必为自己；2★ → +3/+3。
	var bow := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	bow.unit.level = 2
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"id": "enemy_fodder_hb2", "steps_per_turn": 0}),
		Vector2(9.5, 8.5),
	)
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sim.begin_combat()
	var base_atk := bow.unit.get_effective_attack()
	var base_hp := bow.unit.get_effective_max_hp()
	if not sim._pipeline.apply_damage(null, enemy, 999):
		push_error("horsebow2: failed to kill enemy")
		return false
	sim._drain_effects()
	if bow.unit.get_effective_attack() != base_atk + 3:
		push_error("horsebow2: atk expected +3")
		return false
	if bow.unit.get_effective_max_hp() != base_hp + 3:
		push_error("horsebow2: max_hp expected +3")
		return false
	return true


static func _test_enemy_death_nearby_allies_atk_hp_small() -> bool:
	var data := _load_unit("res://resources/units/realtime/blade_mender.tres")
	if data == null or data.ability == null or data.ability.id != "enemy_death_nearby_allies_atk_hp_small":
		push_error("blade_mender: ability not mounted")
		return false
	if data.tier != 3:
		push_error("blade_mender: expected tier 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 46)
	var mender := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	var near_ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "ally_near_bm", "steps_per_turn": 0}),
		Vector2(8.5, 24.5),
	)
	var far_ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "ally_far_bm", "steps_per_turn": 0}),
		Vector2(6.5, 24.5),
	)
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"id": "enemy_fodder_bm", "steps_per_turn": 0}),
		Vector2(9.5, 8.5),
	)
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sim.begin_combat()
	var near_atk0 := near_ally.unit.get_effective_attack()
	var far_atk0 := far_ally.unit.get_effective_attack()
	if not sim._pipeline.apply_damage(null, enemy, 999):
		push_error("blade_mender: failed to kill enemy")
		return false
	sim._drain_effects()
	if near_ally.unit.get_effective_attack() != near_atk0 + 1:
		push_error("blade_mender: nearby ally expected +1 atk")
		return false
	if far_ally.unit.get_effective_attack() != far_atk0:
		push_error("blade_mender: far ally should not be buffed")
		return false
	return true


static func _test_mend_friar_enemy_death_lr_allies() -> bool:
	return _mend_friar_enemy_death_lr_expect(1, 1)


static func _test_mend_friar_enemy_death_lr_allies_star2() -> bool:
	return _mend_friar_enemy_death_lr_expect(2, 3)


static func _mend_friar_enemy_death_lr_expect(star_level: int, expected_delta: int) -> bool:
	var data := _load_unit("res://resources/units/realtime/mend_friar.tres")
	if data == null or data.ability == null:
		push_error("mend_friar_lr: ability missing")
		return false
	if data.ability.id != "enemy_death_lr_allies_atk_hp_small":
		push_error("mend_friar_lr: wrong ability id %s" % data.ability.id)
		return false
	if data.ability.merge_value_mult != 3:
		push_error("mend_friar_lr: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 461 + star_level)
	var friar := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	friar.unit.level = star_level
	var left := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "lr_left", "steps_per_turn": 0}),
		Vector2(8.5, 24.5),
	)
	var right := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "lr_right", "steps_per_turn": 0}),
		Vector2(10.5, 24.5),
	)
	var up := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "lr_up", "steps_per_turn": 0}),
		Vector2(9.5, 23.5),
	)
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"id": "enemy_fodder_mf", "steps_per_turn": 0}),
		Vector2(9.5, 8.5),
	)
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sim.begin_combat()
	var left_atk0 := left.unit.get_effective_attack()
	var right_atk0 := right.unit.get_effective_attack()
	var up_atk0 := up.unit.get_effective_attack()
	if not sim._pipeline.apply_damage(null, enemy, 999):
		push_error("mend_friar_lr: failed to kill enemy")
		return false
	sim._drain_effects()
	if left.unit.get_effective_attack() != left_atk0 + expected_delta:
		push_error(
			"mend_friar_lr %d★: left atk %d expected %d"
			% [star_level, left.unit.get_effective_attack(), left_atk0 + expected_delta]
		)
		return false
	if right.unit.get_effective_attack() != right_atk0 + expected_delta:
		push_error("mend_friar_lr: right ally expected +%d atk" % expected_delta)
		return false
	if up.unit.get_effective_attack() != up_atk0:
		push_error("mend_friar_lr: up ally should not be buffed")
		return false
	return true


static func _setup_summon_lr(unit_path: String, level: int, seed: int) -> Dictionary:
	var data := _load_unit(unit_path)
	if data == null or data.ability == null:
		return {}
	var sim := _new_sim()
	sim.configure(ARENA, seed)
	var holder := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 22.5))
	holder.unit.level = level
	var left := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "lr_left", "attack": 3}),
		Vector2(8.5, 22.5),
	)
	var right := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "lr_right", "attack": 3}),
		Vector2(10.5, 22.5),
	)
	var up := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "lr_up", "attack": 3}),
		Vector2(9.5, 21.5),
	)
	var far := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "far_ally", "attack": 3}),
		Vector2(12.5, 22.5),
	)
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(9.5, 4.5))
	sim.begin_combat()
	return {
		"data": data,
		"sim": sim,
		"holder": holder,
		"left": left,
		"right": right,
		"up": up,
		"far": far,
	}


static func _test_dirge_horn_friend_summon_lr_allies() -> bool:
	var built := _setup_summon_lr("res://resources/units/realtime/dirge_horn.tres", 1, 95)
	if built.is_empty():
		push_error("dirge_horn_lr: setup failed")
		return false
	var data: UnitData = built["data"]
	if data.ability.id != "friend_summon_lr_allies_atk_hp_1" or data.ability.merge_value_mult != 3:
		push_error("dirge_horn_lr: ability not mounted")
		return false
	var sim: RealtimeCombatSim = built["sim"]
	var holder: RtUnit = built["holder"]
	var left: RtUnit = built["left"]
	var right: RtUnit = built["right"]
	var up: RtUnit = built["up"]
	var far: RtUnit = built["far"]
	var holder_atk := holder.unit.get_effective_attack()
	var left_atk := left.unit.get_effective_attack()
	var right_atk := right.unit.get_effective_attack()
	var up_atk := up.unit.get_effective_attack()
	var far_atk := far.unit.get_effective_attack()
	_spawn_combat_minion(sim)
	sim._drain_effects(true)
	if holder.unit.get_effective_attack() != holder_atk:
		push_error("dirge_horn_lr: holder should not buff self")
		return false
	if left.unit.get_effective_attack() != left_atk + 1 or right.unit.get_effective_attack() != right_atk + 1:
		push_error("dirge_horn_lr: left/right expected +1 atk")
		return false
	if up.unit.get_effective_attack() != up_atk or far.unit.get_effective_attack() != far_atk:
		push_error("dirge_horn_lr: up or far should stay unchanged")
		return false
	return true


static func _test_dirge_horn_friend_summon_lr_allies_star2() -> bool:
	var built := _setup_summon_lr("res://resources/units/realtime/dirge_horn.tres", 2, 96)
	if built.is_empty():
		return false
	var left: RtUnit = built["left"]
	var left_atk := left.unit.get_effective_attack()
	var left_max := left.unit.get_effective_max_hp()
	_spawn_combat_minion(built["sim"])
	built["sim"]._drain_effects(true)
	if left.unit.get_effective_attack() != left_atk + 3:
		push_error("dirge_horn_lr 2★: atk expected +3")
		return false
	if left.unit.get_effective_max_hp() != left_max + 3:
		push_error("dirge_horn_lr 2★: max_hp expected +3")
		return false
	return true


static func _test_survive_turn_end_bank_turn_refresh() -> bool:
	var data := _load_unit("res://resources/units/realtime/vita_keeper.tres")
	if data == null or data.ability == null or data.ability.id != "survive_turn_end_bank_turn_refresh":
		push_error("vita_keeper: ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 47)
	var keeper := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sim.begin_combat()
	if keeper.unit.banked_turn_refresh_charges != 0:
		push_error("vita: expected 0 charges at start")
		return false
	var end_payload := CombatEventPayload.new()
	end_payload.source = keeper.unit
	end_payload.target = keeper.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ACTOR_TURN_END, end_payload)
	sim._drain_effects()
	if keeper.unit.banked_turn_refresh_charges != 1:
		push_error("vita: expected 1 charge after turn end")
		return false
	var start_payload := CombatEventPayload.new()
	start_payload.source = keeper.unit
	start_payload.target = keeper.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ROUND_START, start_payload)
	sim._drain_effects()
	if keeper.unit.banked_turn_refresh_charges != 0:
		push_error("vita: expected 0 charges after consuming on round start")
		return false
	if not keeper.unit.banked_turn_refresh_bonus_pending:
		push_error("vita: expected bonus turn pending after consume")
		return false
	return true


## 2★（一次三合一）merge_value_mult=3：敌亡 +1/+1 → +3/+3。
static func _test_enemy_death_self_atk_hp_star2_x3() -> bool:
	var data := _load_unit("res://resources/units/realtime/rider.tres")
	if data == null or data.ability == null or data.ability.id != "enemy_death_self_atk_hp_small":
		push_error("rider2: ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 43)
	var rider := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	rider.unit.level = 2
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"id": "enemy_fodder2", "steps_per_turn": 0}),
		Vector2(9.5, 8.5),
	)
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sim.begin_combat()
	var base_atk := rider.unit.get_effective_attack()
	var base_hp := rider.unit.get_effective_max_hp()
	if not sim._pipeline.apply_damage(null, enemy, 999):
		push_error("rider2: failed to kill enemy")
		return false
	sim._drain_effects()
	var after_atk := rider.unit.get_effective_attack()
	var after_hp := rider.unit.get_effective_max_hp()
	if after_atk != base_atk + 3:
		push_error("rider2: atk %d -> %d, expected +3" % [base_atk, after_atk])
		return false
	if after_hp != base_hp + 3:
		push_error("rider2: max_hp %d -> %d, expected +3" % [base_hp, after_hp])
		return false
	return true


static func _test_hurt_gain_atk_on_damage() -> bool:
	var data := _load_unit("res://resources/units/realtime/knight.tres")
	if data == null or data.ability == null or data.ability.id != "hurt_gain_atk_small":
		push_error("hurt: knight ability not mounted")
		return false
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 7)
	var shield := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	## 当前骑士资源 max_hp 较低：测试内抬高生命，保证能挨多次打
	shield.unit.stats.max_hp = 1000
	shield.unit.current_hp = 1000
	# 邻格出手（一格一体）；盾兵挨打叠攻
	sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.ENEMY,
			{
				"attack": 10,
				"max_hp": 100000,
				"steps_per_turn": 0,
				"attack_windup": 0.0,
				"attack_interval": 0.5,
				"attack_reach": 2.0,
				"sight_range": 10.0,
			},
		),
		Vector2(9.5, 21.5),
	)
	var base_atk := shield.unit.get_effective_attack()
	var hits: Array[int] = [0]
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if event_type == CombatEvents.ON_DAMAGE_TAKEN and payload.target == shield.unit:
				hits[0] += 1
	)
	var guard := 0
	while hits[0] < 2 and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	if hits[0] < 2:
		push_error("hurt: expected >=2 hits, got %d" % hits[0])
		return false
	var after := shield.unit.get_effective_attack()
	## hurt_gain_atk_small：每次受伤 +1
	if after < base_atk + 2:
		push_error("hurt: atk %d -> %d, expected at least +2 (2x1)" % [base_atk, after])
		return false
	return true


static func _test_deal_damage_gain_atk() -> bool:
	var data := _load_unit("res://resources/units/realtime/boss_minion_t5.tres")
	if data == null or data.ability == null or data.ability.id != "deal_damage_gain_atk_small":
		push_error("deal: boss minion ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 11)
	var flail := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"body_radius": 0.4}), Vector2(9.5, 21.5))
	# 强制近身出手；关掉溅射避免单次出手多段 ON_DEAL_DAMAGE
	flail.unit.stats.attack_windup = 0.0
	flail.unit.stats.attack_interval = 0.4
	flail.unit.stats.steps_per_turn = 0
	flail.unit.stats.attack_reach = 2.0
	flail.unit.stats.sight_range = 10.0
	flail.unit.stats.splash_radius = 0.0
	var base_atk := flail.unit.get_effective_attack()
	## deal_damage_gain_atk_small：每次出手 +1，本场软顶 5。
	var guard := 0
	while flail.unit.get_effective_attack() < base_atk + 5 and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	var after := flail.unit.get_effective_attack()
	if after < base_atk + 5:
		push_error("deal: atk %d -> %d, expected at least +5 (soft cap)" % [base_atk, after])
		return false
	return true



static func _musketeer_extra_damage(level: int) -> int:
	var data := _load_unit("res://resources/units/realtime/musketeer.tres")
	if data == null or data.ability == null or data.ability.id != "deal_damage_extra_2":
		push_error("musketeer: ability deal_damage_extra_2 not mounted")
		return -1
	if data.ability.merge_value_mult != 3:
		push_error("musketeer: merge_value_mult expected 3")
		return -1
	var sim := _new_sim()
	sim.configure(ARENA, 99)
	var gun := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 500, {"steps_per_turn": 0, "sight_range": 0.0, "attack_reach": 0.0}),
		Vector2(9.5, 18.5),
	)
	gun.unit.level = level
	gun.unit.stats.projectile_speed = 0.0
	gun.unit.stats.attack_windup = 0.0
	gun.unit.stats.attack_interval = 8.0
	gun.unit.stats.attack_reach = 3.0
	gun.unit.stats.steps_per_turn = 0
	var per_shot := 2 * UnitInstance.ability_value_multiplier_for(data.ability, level)
	var shots := mini(maxi(level, 1), 3)
	var expected := gun.unit.get_effective_attack() + per_shot * shots
	var hp_before := enemy.unit.current_hp
	var guard := 0
	while enemy.unit.current_hp > hp_before - expected and guard < 400:
		sim.advance_fixed_step()
		guard += 1
	return hp_before - enemy.unit.current_hp


static func _test_deal_damage_extra_2() -> bool:
	var dealt := _musketeer_extra_damage(1)
	if dealt != 9:
		push_error("musketeer: dealt %d, expected attack 7 + extra 2" % dealt)
		return false
	return true


static func _test_deal_damage_extra_2_star2() -> bool:
	var dealt := _musketeer_extra_damage(2)
	if dealt != 19:
		push_error("musketeer star2: dealt %d, expected attack 7 + 2 shots x6" % dealt)
		return false
	return true


static func _test_deal_damage_extra_2_star3() -> bool:
	var dealt := _musketeer_extra_damage(3)
	if dealt != 61:
		push_error("musketeer star3: dealt %d, expected attack 7 + 3 shots x18" % dealt)
		return false
	return true


static func _test_kill_gain_atk_mid() -> bool:
	var data := _load_unit("res://resources/units/realtime/mini_pekka.tres")
	if data == null or data.ability == null or data.ability.id != "kill_gain_atk_mid":
		push_error("kill: mini_pekka ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 13)
	var sword := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 50, {"steps_per_turn": 0, "body_radius": 0.3}),
		Vector2(9.5, 20.0),
	)
	# 远处再挂一个敌方，避免杀光立刻结束
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sword.unit.stats.attack_windup = 0.0
	sword.unit.stats.attack_interval = 0.3
	sword.unit.stats.steps_per_turn = 0
	sword.unit.stats.attack_reach = 2.0
	var base_atk := sword.unit.get_effective_attack()
	var guard := 0
	while sword.unit.get_effective_attack() <= base_atk and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	var after := sword.unit.get_effective_attack()
	if after <= base_atk:
		push_error("kill: atk unchanged %d (expected OnKill buff)" % after)
		return false
	return true


static func _test_ally_death_self_atk_mid() -> bool:
	var data := _load_unit("res://resources/units/realtime/barbarian.tres")
	if data == null or data.ability == null or data.ability.id != "ally_death_self_atk_mid":
		push_error("ally_death: barbarian ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 17)
	var axe := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 22.5))
	var fodder := sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.PLAYER,
			{"max_hp": 20, "attack": 1, "steps_per_turn": 0, "sight_range": 0.0, "attack_reach": 0.0},
		),
		Vector2(9.5, 20.5),
	)
	sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.ENEMY,
			{
				"attack": 500,
				"max_hp": 100000,
				"steps_per_turn": 0,
				"attack_windup": 0.0,
				"attack_interval": 0.2,
				"attack_reach": 2.0,
				"sight_range": 10.0,
			},
		),
		Vector2(9.5, 20.0),
	)
	var base_atk := axe.unit.get_effective_attack()
	var guard := 0
	while fodder.is_alive() and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	sim._drain_effects()
	var after := axe.unit.get_effective_attack()
	if after <= base_atk:
		push_error("ally_death: axe atk %d -> %d, expected buff on friend death" % [base_atk, after])
		return false
	return true


## 游侠：造成伤害时对目标施加 1 层虚弱。
static func _test_archer_deal_apply_weak() -> bool:
	var data := _load_unit("res://resources/units/realtime/archer.tres")
	if data == null or data.ability == null or data.ability.id != "deal_damage_apply_weak":
		push_error("archer_weak: archer ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 55)
	var archer := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	archer.unit.stats.attack_windup = 0.0
	archer.unit.stats.attack_interval = 0.4
	var enemy := sim.add_unit(
		_dummy(
			UnitInstance.Team.ENEMY,
			500,
			{"steps_per_turn": 0, "sight_range": 0.0, "attack_reach": 0.0},
		),
		Vector2(9.5, 22.5),
	)
	var guard := 0
	while (
		enemy.unit.combat_statuses.get_stacks(CombatStatusStack.ID_WEAK) < 1
		and guard < 400
	):
		sim.advance_fixed_step()
		guard += 1
	sim._drain_effects()
	var weak_stacks := enemy.unit.combat_statuses.get_stacks(CombatStatusStack.ID_WEAK)
	if weak_stacks < 1:
		push_error("archer_weak: expected weak on target, got %d stacks" % weak_stacks)
		return false
	return true


static func _test_first_hurt_harden_once() -> bool:
	var data := _load_unit("res://resources/units/realtime/rune_plate.tres")
	if data == null or data.ability == null or data.ability.id != "first_hurt_harden":
		push_error("first_hurt: rune_plate ability not mounted")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("first_hurt: merge_value_mult expected 3")
		return false
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 23)
	var rt := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	rt.unit.stats.max_hp = 20
	rt.unit.current_hp = 20
	sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.ENEMY,
			{
				"attack": 1,
				"max_hp": 100000,
				"steps_per_turn": 0,
				"attack_windup": 0.0,
				"attack_interval": 0.2,
				"attack_reach": 2.0,
				"sight_range": 10.0,
			},
		),
		Vector2(9.5, 21.5),
	)
	var base_max := rt.unit.get_effective_max_hp()
	var plate_hits: Array[int] = [0]
	var plate_id := rt.unit.instance_id
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if (
				event_type == CombatEvents.ON_DAMAGE_TAKEN
				and payload.target != null
				and payload.target.instance_id == plate_id
			):
				plate_hits[0] += 1
	)
	var guard := 0
	while plate_hits[0] < 2 and guard < 400:
		sim.advance_fixed_step()
		guard += 1
	if plate_hits[0] < 2:
		push_error("first_hurt: expected >=2 plate hits, got %d" % plate_hits[0])
		return false
	var after_max := rt.unit.get_effective_max_hp()
	if after_max != base_max + 1:
		push_error(
			"first_hurt: max_hp %d -> %d, expected +1 once (max_triggers=1)"
			% [base_max, after_max]
		)
		return false
	return true


static func _test_first_hurt_harden_star2() -> bool:
	var data := _load_unit("res://resources/units/realtime/rune_plate.tres")
	if data == null or data.ability == null or data.ability.id != "first_hurt_harden":
		push_error("first_hurt star2: ability mount")
		return false
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 24)
	var rt := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	rt.unit.level = 2
	rt.unit.stats.max_hp = 20
	rt.unit.current_hp = 20
	sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.ENEMY,
			{
				"attack": 1,
				"max_hp": 100000,
				"steps_per_turn": 0,
				"attack_windup": 0.0,
				"attack_interval": 0.2,
				"attack_reach": 2.0,
				"sight_range": 10.0,
			},
		),
		Vector2(9.5, 21.5),
	)
	var base_max := rt.unit.get_effective_max_hp()
	var plate_hits: Array[int] = [0]
	var plate_id := rt.unit.instance_id
	bus.combat_event.connect(
		func(event_type: StringName, payload: CombatEventPayload) -> void:
			if (
				event_type == CombatEvents.ON_DAMAGE_TAKEN
				and payload.target != null
				and payload.target.instance_id == plate_id
			):
				plate_hits[0] += 1
	)
	var guard := 0
	while plate_hits[0] < 1 and guard < 400:
		sim.advance_fixed_step()
		guard += 1
	if plate_hits[0] < 1:
		push_error("first_hurt star2: expected a hit")
		return false
	var after_max := rt.unit.get_effective_max_hp()
	if after_max != base_max + 3:
		push_error(
			"first_hurt star2: max_hp %d -> %d, expected +3"
			% [base_max, after_max]
		)
		return false
	return true


## 猎手：友方战斗随从被召唤时，该随从 +1/+1；普通入座不触发。
static func _test_hunter_friend_summoned_buff() -> bool:
	var data := _load_unit("res://resources/units/realtime/hunter.tres")
	if data == null or data.ability == null or data.ability.id != "friend_summoned_buff_atk_hp_1":
		push_error("hunter: friend_summoned_buff_atk_hp_1 not mounted")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("hunter: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 29)
	sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(8.5, 22.5))
	var roster := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "roster_ally", "attack": 3, "max_hp": 5}),
		Vector2(9.5, 22.5),
	)
	if roster.unit.get_effective_attack() != 3 or roster.unit.get_effective_max_hp() != 5:
		push_error("hunter: roster ally should not be buffed on seat")
		return false
	var minion := _dummy(
		UnitInstance.Team.PLAYER, 1, {"id": "token_ember", "max_hp": 1, "attack": 1}
	)
	minion.is_combat_summon = true
	sim.add_unit(minion, Vector2(4.5, 10.5))
	if minion.get_effective_attack() != 2 or minion.get_effective_max_hp() != 2:
		push_error(
			"hunter: summon atk/hp %d/%d expected 2/2"
			% [minion.get_effective_attack(), minion.get_effective_max_hp()]
		)
		return false
	if minion.current_hp != 2:
		push_error("hunter: summon current_hp %d expected 2 (sync with max)" % minion.current_hp)
		return false
	return true


## 猎手 2★：被召唤随从 +3/+3。
static func _test_hunter_friend_summoned_buff_star2() -> bool:
	var data := _load_unit("res://resources/units/realtime/hunter.tres")
	if data == null or data.ability == null:
		push_error("hunter 2★: missing ability")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 30)
	var hunter := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(8.5, 22.5))
	hunter.unit.level = 2
	var minion := _dummy(
		UnitInstance.Team.PLAYER, 1, {"id": "token_ember", "max_hp": 1, "attack": 1}
	)
	minion.is_combat_summon = true
	sim.add_unit(minion, Vector2(4.5, 10.5))
	if minion.get_effective_attack() != 4 or minion.get_effective_max_hp() != 4:
		push_error(
			"hunter 2★: summon atk/hp %d/%d expected 4/4"
			% [minion.get_effective_attack(), minion.get_effective_max_hp()]
		)
		return false
	return true


static func _test_deal_damage_adj_splash_small() -> bool:
	var data := _load_unit("res://resources/units/realtime/maul.tres")
	if data == null or data.ability == null or data.ability.id != "deal_damage_adj_splash_small":
		push_error("adj_splash: maul ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 31)
	var maul := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	maul.unit.stats.attack_windup = 0.0
	maul.unit.stats.attack_interval = 0.3
	maul.unit.stats.steps_per_turn = 0
	maul.unit.stats.attack_reach = 2.0
	maul.unit.stats.splash_radius = 0.0
	var primary := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100, {"steps_per_turn": 0, "sight_range": 0.0, "body_radius": 0.3}),
		Vector2(9.5, 20.0),
	)
	## 邻格敌人（不含主目标）；应吃到 ENEMIES_ADJACENT_TO_EVENT_TARGET 溅射。
	var neighbor := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100, {"steps_per_turn": 0, "sight_range": 0.0, "body_radius": 0.3}),
		Vector2(10.5, 20.0),
	)
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(2.5, 4.5),
	)
	var neigh_before := neighbor.unit.current_hp
	var guard := 0
	while neighbor.unit.current_hp >= neigh_before and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	if neighbor.unit.current_hp >= neigh_before:
		push_error(
			"adj_splash: neighbor hp unchanged (%d); primary hp=%d"
			% [neighbor.unit.current_hp, primary.unit.current_hp]
		)
		return false
	return true


## 药师：自己回合开始周围一格敌军中毒 1 层；距 2 不受益。
static func _test_turn_start_nearby_enemies_poison() -> bool:
	return _turn_start_nearby_enemies_poison_expect(1, 1)


static func _test_turn_start_nearby_enemies_poison_star2() -> bool:
	return _turn_start_nearby_enemies_poison_expect(2, 3)


static func _turn_start_nearby_enemies_poison_expect(star_level: int, expected_poison: int) -> bool:
	if EffectSpec.NEARBY_ENEMY_RADIUS != 1:
		push_error(
			"nearby_poison: NEARBY_ENEMY_RADIUS=%d expected 1" % EffectSpec.NEARBY_ENEMY_RADIUS
		)
		return false
	var data := _load_unit("res://resources/units/realtime/apothecary.tres")
	if data == null or data.ability == null:
		push_error("nearby_poison: apothecary ability missing")
		return false
	if data.ability.id != "turn_start_nearby_enemies_apply_poison":
		push_error("nearby_poison: wrong ability id %s" % data.ability.id)
		return false
	if data.ability.merge_value_mult != 3:
		push_error("nearby_poison: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 510 + star_level)
	var medic := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	medic.unit.level = star_level
	medic.unit.stats.steps_per_turn = 0
	var near_enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 50, {"steps_per_turn": 0, "sight_range": 0.0, "id": "near_foe"}),
		Vector2(10.5, 20.5),
	)
	var far_enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 50, {"steps_per_turn": 0, "sight_range": 0.0, "id": "far_foe"}),
		Vector2(11.5, 20.5),
	)
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(9.5, 8.5),
	)
	sim.begin_combat()
	var payload := CombatEventPayload.new()
	payload.source = medic.unit
	payload.target = medic.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ROUND_START, payload)
	sim._drain_effects(true)
	var near_p := near_enemy.unit.combat_statuses.get_stacks(CombatStatusStack.ID_POISON)
	var far_p := far_enemy.unit.combat_statuses.get_stacks(CombatStatusStack.ID_POISON)
	if near_p != expected_poison:
		push_error(
			"nearby_poison %d★: near poison=%d expected %d"
			% [star_level, near_p, expected_poison]
		)
		return false
	if far_p != 0:
		push_error("nearby_poison: far enemy poison=%d expected 0" % far_p)
		return false
	return true


## 鼓手：自己回合开始周围一格友方狂暴 1 层（不含自身）；2★ 三合一倍率后 3 层。
static func _test_wardrum_turn_start_nearby_berserk() -> bool:
	return _wardrum_nearby_berserk_expect(1, 1)


static func _test_wardrum_turn_start_nearby_berserk_star2() -> bool:
	return _wardrum_nearby_berserk_expect(2, 3)


static func _wardrum_nearby_berserk_expect(star_level: int, expected_berserk: int) -> bool:
	var data := _load_unit("res://resources/units/realtime/wardrum.tres")
	if data == null or data.ability == null:
		push_error("wardrum_berserk: ability missing")
		return false
	if data.ability.id != "turn_start_nearby_allies_apply_berserk":
		push_error("wardrum_berserk: wrong ability id %s" % data.ability.id)
		return false
	if data.ability.merge_value_mult != 3:
		push_error("wardrum_berserk: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 511 + star_level)
	var drum := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	drum.unit.level = star_level
	drum.unit.stats.steps_per_turn = 0
	var near := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(10.5, 20.5),
	)
	var far := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(11.5, 20.5),
	)
	sim.begin_combat()
	var payload := CombatEventPayload.new()
	payload.source = drum.unit
	payload.target = drum.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ROUND_START, payload)
	sim._drain_effects(true)
	if drum.unit.combat_statuses.get_stacks(CombatStatusStack.ID_BERSERK) != 0:
		push_error("wardrum_berserk: owner must not buff self")
		return false
	var near_b := near.unit.combat_statuses.get_stacks(CombatStatusStack.ID_BERSERK)
	if near_b != expected_berserk:
		push_error(
			"wardrum_berserk %d★: near berserk=%d expected %d"
			% [star_level, near_b, expected_berserk]
		)
		return false
	if far.unit.combat_statuses.get_stacks(CombatStatusStack.ID_BERSERK) != 0:
		push_error("wardrum_berserk: far ally should have 0 berserk")
		return false
	return true


static func _test_death_spawn_pack() -> bool:
	var data := _load_unit("res://resources/units/realtime/goblin.tres")
	if data == null or data.ability == null or data.ability.id != "death_spawn_pack":
		push_error("spawn: goblin ability not mounted")
		return false
	if data.ability.merge_value_mult != 4:
		push_error("spawn: death_spawn_pack merge_value_mult expected 4")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 3)
	var light := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	# 敌方立刻打死轻步兵，触发 death_spawn_pack
	var killer := sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.ENEMY,
			{
				"attack": 500,
				"max_hp": 100000,
				"steps_per_turn": 0,
				"attack_windup": 0.0,
				"attack_interval": 0.2,
				"attack_reach": 2.0,
				"sight_range": 10.0,
			},
		),
		Vector2(9.5, 20.0),
	)
	# 保留一个远处木桩，避免杀光后立刻结束战斗
	sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 100000, {"steps_per_turn": 0, "sight_range": 0.0}), Vector2(2.5, 28.5))
	var guard := 0
	while light.is_alive() and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	if light.is_alive():
		push_error("spawn: light infantry should have died (killer atk=%d)" % killer.unit.get_effective_attack())
		return false
	var token: RtUnit = null
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt.unit.id == "token_ember" and rt.is_alive():
			token = rt
			break
	if token == null:
		push_error("spawn: expected token_ember on field (units=%d)" % sim.get_units().size())
		return false
	if token.unit.stats.attack != 1 or token.unit.stats.max_hp != 1:
		push_error(
			"spawn 1★: token %d/%d expected 1/1"
			% [token.unit.stats.attack, token.unit.stats.max_hp]
		)
		return false
	return true


## 余烬 2★：死亡生成 4/4 随从（merge_value_mult=4）。
static func _test_death_spawn_pack_star2() -> bool:
	var data := _load_unit("res://resources/units/realtime/goblin.tres")
	if data == null or data.ability == null or data.ability.id != "death_spawn_pack":
		push_error("ember 2★: ability not mounted")
		return false
	var bus := CombatEventBus.new()
	var grid := BoardGrid.new()
	grid.configure(Vector2i(18, 32))
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var ember := UnitInstance.from_unit_data(data, Vector2i(9, 20), UnitInstance.Team.PLAYER)
	ember.level = 2
	ember.current_hp = 0
	grid.place(ember, Vector2i(9, 20))
	var payload := CombatEventPayload.new()
	payload.source = ember
	payload.target = ember
	resolver.on_event(CombatEvents.ON_DEATH, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
	var token: UnitInstance = null
	for u in grid.get_all_units():
		if u != null and u.id == "token_ember" and u.is_alive():
			token = u
			break
	if token == null or token.stats == null:
		push_error("ember 2★: missing token_ember")
		return false
	if token.stats.attack != 4 or token.stats.max_hp != 4 or token.current_hp != 4:
		push_error(
			"ember 2★: token %d/%d expected 4/4"
			% [token.stats.attack, token.stats.max_hp]
		)
		return false
	return true


## 召魂：仅友方角色（非随从/代理）死亡触发；可多次生成；随从立即接敌。
static func _test_ally_death_spawn_weak() -> bool:
	var data := _load_unit("res://resources/units/realtime/soulcaller.tres")
	if data == null or data.ability == null or data.ability.id != "ally_death_spawn_weak":
		push_error("ally_death_spawn: soulcaller ability not mounted")
		return false
	var specs: Array = data.ability.effect_specs
	if specs.is_empty() or specs[0] == null:
		push_error("ally_death_spawn: missing effect spec")
		return false
	if int(specs[0].max_triggers_per_combat) > 0:
		push_error("ally_death_spawn: max_triggers_per_combat must be unlimited (<=0)")
		return false
	if specs[0].condition != EffectSpec.Condition.EVENT_TARGET_IS_NOT_COMBAT_SUMMON:
		push_error("ally_death_spawn: must require non-summon friend death")
		return false
	## 用正式棋盘规格，避免大沙盘掩盖半场落点问题。
	const BOARD := Vector2i(5, 8)
	var sim := _new_sim()
	sim.configure(BOARD, 11)
	var caller := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(0.5, 7.5))
	var fodder_a := sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.PLAYER,
			{
				"id": "fodder_a",
				"max_hp": 5,
				"attack": 1,
				"steps_per_turn": 0,
				"sight_range": 0.0,
				"attack_reach": 0.0,
			},
		),
		Vector2(4.5, 5.5),
	)
	var fodder_b := sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.PLAYER,
			{
				"id": "fodder_b",
				"max_hp": 5,
				"attack": 1,
				"steps_per_turn": 0,
				"sight_range": 0.0,
				"attack_reach": 0.0,
			},
		),
		Vector2(3.5, 5.5),
	)
	## 木桩敌人：避免清场；不用近身杀手误伤召魂。
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(0.5, 0.5),
	)
	sim.begin_combat()
	if not sim._pipeline.apply_damage(null, fodder_a, 999):
		push_error("ally_death_spawn: fodder_a should have died")
		return false
	sim._drain_effects()
	if not sim._pipeline.apply_damage(null, fodder_b, 999):
		push_error("ally_death_spawn: fodder_b should have died")
		return false
	sim._drain_effects()
	var tokens: Array[RtUnit] = []
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt != null and rt.is_alive() and rt.unit.id == "token_weak":
			tokens.append(rt)
	if tokens.size() != 2:
		push_error(
			"ally_death_spawn: expected 2 token_weak after character deaths, got %d (summons_spawned=%d)"
			% [tokens.size(), caller.unit.combat_summons_spawned]
		)
		return false
	for token_rt in tokens:
		if token_rt.is_deploying():
			push_error("ally_death_spawn: token must be on field same round (not deploying)")
			return false
		if token_rt.action_eligible_from_round <= sim.get_round_index():
			push_error(
				"ally_death_spawn: token must wait until next round to act (eligible=%d round=%d)"
				% [token_rt.action_eligible_from_round, sim.get_round_index()]
			)
			return false
	if caller.unit.combat_summons_spawned != 2:
		push_error("ally_death_spawn: combat_summons_spawned=%d, expected 2" % caller.unit.combat_summons_spawned)
		return false
	## 随从死亡不得再触发义士应召（避免连环生成）。
	var first_token := tokens[0]
	if not sim._pipeline.apply_damage(null, first_token, 999):
		push_error("ally_death_spawn: token should have died")
		return false
	sim._drain_effects()
	var tokens_after: Array[RtUnit] = []
	for item2 in sim.get_units():
		var rt2 := item2 as RtUnit
		if rt2 != null and rt2.is_alive() and rt2.unit.id == "token_weak":
			tokens_after.append(rt2)
	if tokens_after.size() != 1:
		push_error(
			"ally_death_spawn: summon death must not spawn; alive tokens=%d summons_spawned=%d"
			% [tokens_after.size(), caller.unit.combat_summons_spawned]
		)
		return false
	if caller.unit.combat_summons_spawned != 2:
		push_error(
			"ally_death_spawn: summons_spawned should stay 2 after summon death, got %d"
			% caller.unit.combat_summons_spawned
		)
		return false
	for token in tokens_after:
		if token.is_deploying() or token.get_stats().deploy_time > 0.0:
			push_error(
				"ally_death_spawn: token should skip deploy (state=%d deploy_time=%s)"
				% [token.state, token.get_stats().deploy_time]
			)
			return false
		if not BoardHalf.is_player_deploy_cell(token.get_cell(), BOARD.y):
			push_error("ally_death_spawn: token should land on player half, cell=%s" % token.get_cell())
			return false
	return true


## 召魂 2★（三合一）：友方角色死亡生成 1 只 6/6 随从（merge_value_mult=3）。
static func _test_ally_death_spawn_merged_triple() -> bool:
	var data := _load_unit("res://resources/units/realtime/soulcaller.tres")
	if data == null:
		push_error("merged_spawn: missing soulcaller")
		return false
	const BOARD := Vector2i(5, 8)
	var sim := _new_sim()
	sim.configure(BOARD, 12)
	var caller := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(2.5, 7.5))
	if caller == null or caller.unit == null:
		push_error("merged_spawn: caller null")
		return false
	caller.unit.level = 2
	var fodder := sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.PLAYER,
			{
				"id": "fodder",
				"max_hp": 5,
				"attack": 1,
				"steps_per_turn": 0,
				"sight_range": 0.0,
				"attack_reach": 0.0,
			},
		),
		Vector2(1.5, 5.5),
	)
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(0.5, 0.5),
	)
	sim.begin_combat()
	if not sim._pipeline.apply_damage(null, fodder, 999):
		push_error("merged_spawn: fodder should die")
		return false
	sim._drain_effects()
	var tokens: Array[RtUnit] = []
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt == null or not rt.is_alive() or rt.unit == null:
			continue
		if rt.unit.id != "token_weak":
			continue
		if rt.get_stats().attack != 6 or rt.get_stats().max_hp != 6:
			push_error(
				"merged_spawn: token stats %d/%d expected 6/6"
				% [rt.get_stats().attack, rt.get_stats().max_hp]
			)
			return false
		tokens.append(rt)
	if tokens.size() != 1:
		push_error(
			"merged_spawn: expected 1 token_weak 6/6, got %d (summons=%d)"
			% [tokens.size(), caller.unit.combat_summons_spawned]
		)
		return false
	if caller.unit.combat_summons_spawned != 1:
		push_error("merged_spawn: summons_spawned=%d" % caller.unit.combat_summons_spawned)
		return false
	return true


## 枯骨死亡 → 随机友方回血 2。
static func _test_death_heal_nearby_ally() -> bool:
	var data := _load_unit("res://resources/units/realtime/skeleton.tres")
	if data == null or data.ability == null or data.ability.id != "death_heal_random_ally_2":
		push_error("death_heal: skeleton ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 41)
	var bone := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	var ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(10.5, 20.5),
	)
	ally.unit.current_hp = 3
	sim.begin_combat()
	var hp_before := ally.unit.current_hp
	var killed: bool = sim._pipeline.apply_damage(null, bone, 999)
	if not killed:
		push_error("death_heal: apply_damage should kill skeleton")
		return false
	sim._drain_effects()
	if ally.unit.current_hp != hp_before + 2:
		push_error(
			"death_heal: ally hp %d → %d, expected +2"
			% [hp_before, ally.unit.current_hp]
		)
		return false
	return true


## 标枪受伤 → 自身恢复 1 生命（软顶；merge_value_mult=4 → 三合一后 4）。
static func _test_hurt_heal_self_2() -> bool:
	var data := _load_unit("res://resources/units/realtime/spear_goblin.tres")
	if data == null or data.ability == null or data.ability.id != "hurt_heal_self_2":
		push_error("hurt_heal_self_2: spear_goblin ability not mounted")
		return false
	if data.ability.merge_value_mult != 4:
		push_error("hurt_heal_self_2: merge_value_mult expected 4")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 42)
	var spear := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	## 抬高上限以便非致死受伤后验证回血。
	spear.unit.stats.max_hp = 10
	spear.unit.current_hp = 6
	sim.begin_combat()
	var hp_mid := spear.unit.current_hp
	sim._pipeline.apply_damage(null, spear, 2)
	sim._drain_effects()
	## 扣 2 后疗回 1 → 净 −1
	if spear.unit.current_hp != hp_mid - 2 + 1:
		push_error(
			"hurt_heal_self_2: hp after hurt+heal=%d, expected %d"
			% [spear.unit.current_hp, hp_mid - 1]
		)
		return false
	return true


## 伤 = 疗：受击疗截断为本击伤害，不能净回血。
static func _test_hurt_heal_capped_to_hit() -> bool:
	var data := _load_unit("res://resources/units/realtime/spear_goblin.tres")
	if data == null or data.ability == null or data.ability.id != "hurt_heal_self_2":
		push_error("hurt_heal_capped: spear_goblin ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 4201)
	var spear := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	spear.unit.stats.max_hp = 20
	spear.unit.current_hp = 6
	sim.begin_combat()
	var hp_before := spear.unit.current_hp
	sim._pipeline.apply_damage(null, spear, 1)
	sim._drain_effects()
	## 技能写 1，本次伤 1 → 回 1，净 0。
	if spear.unit.current_hp != hp_before:
		push_error(
			"hurt_heal_capped: hp=%d expected %d (net 0 after 1 dmg)"
			% [spear.unit.current_hp, hp_before]
		)
		return false
	if spear.unit.combat_skill_heal_received != 1:
		push_error(
			"hurt_heal_capped: combat_skill_heal_received=%d expected 1"
			% spear.unit.combat_skill_heal_received
		)
		return false
	return true


## 余震：普攻击杀才点残；技能击杀不再连锁。
static func _test_aftershock_attack_kill_only() -> bool:
	var data := _load_unit("res://resources/units/realtime/aftershock.tres")
	if data == null or data.ability == null or data.ability.id != "kill_damage_random_enemy_1":
		push_error("aftershock: ability mount")
		return false
	var specs: Array = data.ability.effect_specs
	if (
		specs.is_empty()
		or specs[0] == null
		or specs[0].trigger != CombatEvents.ON_KILL
		or specs[0].condition != EffectSpec.Condition.KILL_FROM_ATTACK
	):
		push_error("aftershock: kill must be attack-only")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 77)
	var shock := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(4.5, 20.5))
	var foes: Array[RtUnit] = []
	for i in 4:
		foes.append(sim.add_unit(
			_dummy(UnitInstance.Team.ENEMY, 1, {"id": "fodder_%d" % i, "attack": 0}),
			Vector2(4.5 + float(i), 8.5),
		))
	if shock == null:
		push_error("aftershock: missing unit")
		return false
	sim.begin_combat()
	sim.flush_combat_start_lock()
	## 技能直伤击杀不算「攻击击杀」。
	if not sim._pipeline.apply_damage(shock.unit, foes[0], 5):
		push_error("aftershock: skill-like hit should kill fodder 0")
		return false
	sim._drain_effects(true)
	if not foes[1].is_alive() or not foes[2].is_alive() or not foes[3].is_alive():
		push_error("aftershock: non-attack kill must not splash")
		return false
	var killed := sim._pipeline.resolve_hit(shock, foes[1], shock.get_effective_attack(), 0.0, sim.get_units())
	if killed.is_empty():
		push_error("aftershock: attack should kill fodder 1")
		return false
	sim._drain_effects(true)
	var alive := 0
	if foes[0].is_alive():
		alive += 1
	if foes[1].is_alive():
		alive += 1
	if foes[2].is_alive():
		alive += 1
	if foes[3].is_alive():
		alive += 1
	## 非攻击击杀不触发；普攻打死 1 个后再点残 1 个，应剩 1 个。
	if alive != 1:
		push_error("aftershock: expected 1 foe left, alive=%d" % alive)
		return false
	return true


static func _test_boomling_kill_damage_all_except_self() -> bool:
	return _boomling_kill_aoe_expect(1, 2)


static func _test_boomling_kill_damage_all_star2() -> bool:
	return _boomling_kill_aoe_expect(2, 6)


static func _boomling_kill_aoe_expect(star_level: int, expected_dmg: int) -> bool:
	var data := _load_unit("res://resources/units/realtime/boomling.tres")
	if data == null or data.ability == null or data.ability.id != "kill_damage_all_except_self_2":
		push_error("boomling: ability mount")
		return false
	if data.tier != 3:
		push_error("boomling: expected tier 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 880 + star_level)
	var boom := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	boom.unit.level = star_level
	var ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"id": "ally_near", "steps_per_turn": 0}),
		Vector2(10.5, 20.5),
	)
	var fodder_a := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 1, {"id": "fodder_a", "attack": 0, "steps_per_turn": 0}),
		Vector2(9.5, 8.5),
	)
	var fodder_b := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 1, {"id": "fodder_b", "attack": 0, "steps_per_turn": 0}),
		Vector2(11.5, 8.5),
	)
	var bystander := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"id": "bystander", "attack": 0, "steps_per_turn": 0}),
		Vector2(7.5, 8.5),
	)
	sim.begin_combat()
	sim.flush_combat_start_lock()
	var ally_hp0 := ally.unit.current_hp
	var by_hp0 := bystander.unit.current_hp
	var boom_hp0 := boom.unit.current_hp
	if not sim._pipeline.apply_damage(boom.unit, fodder_a, 5):
		push_error("boomling: skill damage should kill fodder_a")
		return false
	sim._drain_effects(true)
	if ally.unit.current_hp != ally_hp0 or bystander.unit.current_hp != by_hp0:
		push_error("boomling: non-attack kill must not shockwave")
		return false
	var killed := sim._pipeline.resolve_hit(boom, fodder_b, boom.get_effective_attack(), 0.0, sim.get_units())
	if killed.is_empty():
		push_error("boomling: attack should kill fodder_b")
		return false
	sim._drain_effects(true)
	if boom.unit.current_hp != boom_hp0:
		push_error("boomling: self must not take shockwave")
		return false
	if ally.unit.current_hp != ally_hp0 - expected_dmg:
		push_error(
			"boomling: ally hp %d expected %d"
			% [ally.unit.current_hp, ally_hp0 - expected_dmg]
		)
		return false
	if bystander.unit.current_hp != by_hp0 - expected_dmg:
		push_error("boomling: bystander expected -%d dmg" % expected_dmg)
		return false
	return true


static func _test_mirror_warden_kill_convert() -> bool:
	var data := _load_unit("res://resources/units/realtime/mirror_warden.tres")
	if data == null or data.ability == null or data.ability.id != "kill_convert_event_target_to_ally":
		push_error("mirror_warden: ability mount")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 901)
	var warden := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(4.5, 20.5))
	var foe := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 4, {"id": "fodder", "attack": 0}),
		Vector2(4.5, 8.5),
	)
	if warden == null or foe == null:
		push_error("mirror_warden: spawn failed")
		return false
	sim.begin_combat()
	sim.flush_combat_start_lock()
	var atk := warden.get_effective_attack()
	if atk < 4:
		push_error("mirror_warden: atk too low %d" % atk)
		return false
	sim._pipeline.resolve_hit(warden, foe, atk, 0.0, sim.get_units())
	sim._drain_effects(true)
	if not foe.is_alive():
		push_error("mirror_warden: foe should survive as ally")
		return false
	if foe.get_team() != UnitInstance.Team.PLAYER:
		push_error("mirror_warden: foe team not player")
		return false
	if foe.unit.current_hp != foe.unit.get_effective_max_hp():
		push_error("mirror_warden: foe not at max hp")
		return false
	if not foe.unit.is_battle_converted:
		push_error("mirror_warden: missing battle_converted flag")
		return false
	var fodder2 := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 3, {"id": "fodder2", "attack": 0}),
		Vector2(3.5, 8.5),
	)
	sim._pipeline.apply_damage(warden.unit, fodder2, 99)
	sim._drain_effects(true)
	if fodder2.is_alive():
		push_error("mirror_warden: skill-like kill should not convert")
		return false
	var boss := sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.ENEMY,
			{"id": "boss", "is_boss_leader": true, "footprint_w": 2, "footprint_h": 2},
		),
		Vector2(6.5, 6.5),
	)
	sim._pipeline.resolve_hit(warden, boss, 9999, 0.0, sim.get_units())
	sim._drain_effects(true)
	if boss.is_alive() or boss.get_team() == UnitInstance.Team.PLAYER:
		push_error("mirror_warden: boss should die, not convert")
		return false
	return true


## 血僧：开战不加；战斗结束且自身存活才永久 +1/+1（2★ +6/+6，写入 DeckEntry）。
static func _test_blood_acolyte_survive_permanent() -> bool:
	var built := _blood_acolyte_setup(4202)
	if built.is_empty():
		return false
	var sim: RealtimeCombatSim = built["sim"]
	var monk: RtUnit = built["monk"]
	var entry: DeckEntry = built["entry"]
	var base_atk: int = built["base_atk"]
	var base_hp: int = built["base_hp"]
	sim.begin_combat()
	sim.flush_combat_start_lock()
	if entry.bonus_attack != 0 or entry.bonus_max_hp != 0:
		push_error("blood_perm: combat start must not grant bonus")
		return false
	if not _wipe_team_and_finish(sim, UnitInstance.Team.ENEMY):
		push_error("blood_perm: combat did not finish")
		return false
	if not monk.unit.is_alive():
		push_error("blood_perm: monk should survive")
		return false
	var expected := 6
	if monk.unit.get_effective_attack() != base_atk + expected:
		push_error(
			"blood_perm 2★: atk %d -> %d expected +%d"
			% [base_atk, monk.unit.get_effective_attack(), expected]
		)
		return false
	if monk.unit.get_effective_max_hp() != base_hp + expected:
		push_error(
			"blood_perm 2★: max_hp %d -> %d expected +%d"
			% [base_hp, monk.unit.get_effective_max_hp(), expected]
		)
		return false
	if entry.bonus_attack != expected or entry.bonus_max_hp != expected:
		push_error(
			"blood_perm: deck entry bonus atk/hp expected %d/%d got %d/%d"
			% [expected, expected, entry.bonus_attack, entry.bonus_max_hp]
		)
		return false
	return true


## 血僧阵亡则战斗结束不加永久攻血。
static func _test_blood_acolyte_dead_skips_permanent() -> bool:
	var built := _blood_acolyte_setup(4203)
	if built.is_empty():
		return false
	var sim: RealtimeCombatSim = built["sim"]
	var monk: RtUnit = built["monk"]
	var entry: DeckEntry = built["entry"]
	sim.begin_combat()
	sim.flush_combat_start_lock()
	if not _wipe_team_and_finish(sim, UnitInstance.Team.PLAYER):
		push_error("blood_perm dead: combat did not finish")
		return false
	if monk.unit.is_alive():
		push_error("blood_perm dead: monk should be dead")
		return false
	if entry.bonus_attack != 0 or entry.bonus_max_hp != 0:
		push_error(
			"blood_perm dead: bonus %d/%d expected 0/0"
			% [entry.bonus_attack, entry.bonus_max_hp]
		)
		return false
	return true


static func _blood_acolyte_setup(seed: int) -> Dictionary:
	var data := _load_unit("res://resources/units/realtime/blood_acolyte.tres")
	if data == null or data.ability == null or data.ability.id != "combat_start_permanent_self_atk_hp_1":
		push_error("blood_perm: ability mount")
		return {}
	var specs: Array = data.ability.effect_specs
	if specs.is_empty() or specs[0] == null or specs[0].trigger != CombatEvents.ON_COMBAT_END:
		push_error("blood_perm: trigger must be combat end")
		return {}
	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 10
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	var entry := deck.add_entry(data)
	entry.level = 2
	var sim := _new_sim()
	sim.configure(ARENA, seed)
	sim.set_deck_state(deck)
	var monk := sim.add_unit(
		UnitInstance.from_deck_entry(entry, Vector2i(9, 20), UnitInstance.Team.PLAYER),
		Vector2(9.5, 20.5),
	)
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"steps_per_turn": 0, "sight_range": 0.0, "attack_reach": 0.0}),
		Vector2(9.5, 8.5),
	)
	if monk == null or monk.unit == null:
		push_error("blood_perm: monk missing")
		return {}
	return {
		"sim": sim,
		"monk": monk,
		"entry": entry,
		"base_atk": monk.unit.get_effective_attack(),
		"base_hp": monk.unit.get_effective_max_hp(),
	}


static func _wipe_team_and_finish(sim: RealtimeCombatSim, team: UnitInstance.Team) -> bool:
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt == null or rt.unit == null or rt.get_team() != team:
			continue
		rt.unit.current_hp = 0
		rt.state = RtUnit.State.DEAD
	var guard := 0
	while not sim.is_finished() and guard < 8:
		sim.advance_fixed_step()
		guard += 1
	return sim.is_finished()


## 弩手：友方受伤 → 疗该友方 2。
static func _test_ally_hurt_heal_target() -> bool:
	var data := _load_unit("res://resources/units/realtime/crossbow.tres")
	if data == null or data.ability == null or data.ability.id != "ally_hurt_heal_target_small":
		push_error("ally_hurt_heal: crossbow ability not mounted")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("ally_hurt_heal: merge_value_mult expected 3")
		return false
	var specs: Array = data.ability.effect_specs
	if specs.is_empty() or specs[0] == null:
		push_error("ally_hurt_heal: missing effect spec")
		return false
	if specs[0].condition != EffectSpec.Condition.EVENT_TARGET_NOT_AT_MAX_HP:
		push_error("ally_hurt_heal: must skip when event target is at max hp")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 43)
	sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 22.5))
	var ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(9.5, 20.5),
	)
	ally.unit.current_hp = 5
	sim.begin_combat()
	var hp_mid := ally.unit.current_hp
	sim._pipeline.apply_damage(null, ally, 2)
	sim._drain_effects()
	## 扣 2 后应被疗回 2 → 净 0
	if ally.unit.current_hp != hp_mid - 2 + 2:
		push_error(
			"ally_hurt_heal: ally hp after hurt+heal=%d, expected %d"
			% [ally.unit.current_hp, hp_mid]
		)
		return false
	return true


## 弩手 2★：友伤疗 6（merge_value_mult=3）。
static func _test_ally_hurt_heal_target_star2() -> bool:
	var data := _load_unit("res://resources/units/realtime/crossbow.tres")
	if data == null or data.ability == null or data.ability.id != "ally_hurt_heal_target_small":
		push_error("ally_hurt_heal star2: ability mount")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 45)
	var xbow := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 22.5))
	xbow.unit.level = 2
	var ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 20, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(9.5, 20.5),
	)
	ally.unit.current_hp = 12
	sim.begin_combat()
	var hp_mid := ally.unit.current_hp
	sim._pipeline.apply_damage(null, ally, 6)
	sim._drain_effects()
	if ally.unit.current_hp != hp_mid - 6 + 6:
		push_error(
			"ally_hurt_heal star2: ally hp after hurt+heal=%d, expected %d"
			% [ally.unit.current_hp, hp_mid]
		)
		return false
	return true


## 双弩手：第一只疗满后，第二只不再对已满血目标执行治疗。
static func _test_ally_hurt_heal_skips_when_full() -> bool:
	var data := _load_unit("res://resources/units/realtime/crossbow.tres")
	if data == null:
		push_error("ally_hurt_heal_full: missing crossbow")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 44)
	sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(8.5, 22.5))
	sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(10.5, 22.5))
	var ally := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 4, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(9.5, 20.5),
	)
	ally.unit.current_hp = 4
	sim.begin_combat()
	sim._pipeline.apply_damage(null, ally, 2)
	sim._drain_effects()
	## 4→2，+2 疗回 4；第二弩手不应再抬血或刷多余治疗。
	if ally.unit.current_hp != 4:
		push_error(
			"ally_hurt_heal_full: ally hp=%d expected 4 after single heal"
			% ally.unit.current_hp
		)
		return false
	return true


static func _test_turn_start_strike_weakest_mount() -> bool:
	var data := _load_unit("res://resources/units/realtime/shinobi.tres")
	if data == null or data.ability == null:
		push_error("shinobi: missing unit or ability")
		return false
	if data.ability.id != "turn_start_strike_weakest":
		push_error("shinobi: wrong ability id %s" % data.ability.id)
		return false
	if data.tier != 2 or data.stats.max_hp != 4 or data.stats.attack != 4:
		push_error("shinobi: body stats mismatch")
		return false
	return true


static func _test_turn_start_strike_weakest_damage() -> bool:
	var data := _load_unit("res://resources/units/realtime/shinobi.tres")
	var sim := _new_sim()
	sim.configure(ARENA, 501)
	var shinobi := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(4.5, 26.5))
	shinobi.unit.stats.steps_per_turn = 0
	var weak := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(12.5, 10.5),
	)
	weak.unit.current_hp = 5
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(5.5, 25.5),
	)
	sim.begin_combat()
	var hp_before := weak.unit.current_hp
	var guard := 0
	while weak.unit.current_hp == hp_before and guard < 400:
		sim.advance_fixed_step()
		guard += 1
	if weak.unit.current_hp != hp_before - 2:
		push_error(
			"strike_weakest: weak hp %d -> %d, expected -2"
			% [hp_before, weak.unit.current_hp]
		)
		return false
	var bus := CombatEventBus.new()
	var grid := BoardGrid.new()
	grid.configure(Vector2i(18, 32))
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var assailant := UnitInstance.from_unit_data(data, Vector2i(4, 26), UnitInstance.Team.PLAYER)
	assailant.level = 2
	## 用占位敌，避免依赖敌镜像身体预算（盾卫已降为 T1 4/1）。
	var victim := _dummy(UnitInstance.Team.ENEMY, 20, {"steps_per_turn": 0, "sight_range": 0.0})
	victim.stats.max_hp = 20
	victim.current_hp = 20
	grid.place(assailant, Vector2i(4, 26))
	grid.place(victim, Vector2i(12, 10))
	var payload := CombatEventPayload.new()
	payload.source = assailant
	payload.target = assailant
	resolver.on_event(CombatEvents.ON_ROUND_START, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
	if victim.current_hp != 13:
		push_error(
			"strike_weakest L2: victim hp expected 13, got %d" % victim.current_hp
		)
		return false
	return true


## 2★ + defer 结算：走位后效果格须对齐，瞬移应落到最弱敌邻格。
static func _test_turn_start_strike_weakest_teleport_deferred() -> bool:
	var data := _load_unit("res://resources/units/realtime/shinobi.tres")
	var sim := _new_sim()
	sim.defer_effect_resolve = true
	sim.configure(ARENA, 502)
	var shinobi_rt := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(2.5, 26.5))
	shinobi_rt.unit.level = 2
	shinobi_rt.unit.stats.steps_per_turn = 0
	var weak_rt := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 20, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(14.5, 8.5),
	)
	weak_rt.unit.current_hp = 20
	sim.begin_combat()
	shinobi_rt.snap_to_cell(Vector2i(8, 22))
	var payload := CombatEventPayload.new()
	payload.source = shinobi_rt.unit
	payload.target = shinobi_rt.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ROUND_START, payload)
	if not sim.has_pending_effects():
		push_error("teleport deferred: expected pending skill batch")
		return false
	if not sim.resolve_next_pending_effect():
		push_error("teleport deferred: resolve_next_pending_effect failed")
		return false
	var dist := shinobi_rt.cell_distance_to(weak_rt)
	if dist > 1:
		push_error(
			"teleport deferred: shinobi dist to weak=%d expected <=1 (cell %s)"
			% [dist, str(shinobi_rt.get_cell())]
		)
		return false
	if weak_rt.unit.current_hp != 13:
		push_error(
			"teleport deferred: weak hp=%d expected 13 (7 dmg at 2★)"
			% weak_rt.unit.current_hp
		)
		return false
	return true


static func _test_tier_unlock_t2_from_floor_4() -> bool:
	const FC := 15
	if TierUnlock.get_max_unlocked_tier(3, FC) != 1:
		push_error("tier_unlock: floor 3 should be T1")
		return false
	if TierUnlock.get_max_unlocked_tier(4, FC) != 2:
		push_error("tier_unlock: floor 4 should unlock T2")
		return false
	## 倒数 6 层前仍最高 T2（floor 9 with fc=15）。
	if TierUnlock.get_max_unlocked_tier(9, FC) != 2:
		push_error("tier_unlock: floor 9/15 should still be max T2")
		return false
	if TierUnlock.get_min_unlocked_tier(9, FC) != 1:
		push_error("tier_unlock: floor 9/15 should still allow T1")
		return false
	## 倒数 6 层起 T3，且最低 T2。
	if TierUnlock.get_max_unlocked_tier(10, FC) != 3:
		push_error("tier_unlock: floor 10/15 should unlock T3")
		return false
	if TierUnlock.get_min_unlocked_tier(10, FC) != 2:
		push_error("tier_unlock: floor 10/15 should drop T1")
		return false
	return true


## 吞噬：左右邻格友方被消灭并吞满攻血；上下邻格不受影响。
static func _test_devour_lr_absorb_and_kill() -> bool:
	var data := _load_unit("res://resources/units/realtime/devour.tres")
	if data == null or data.ability == null or data.ability.id != "turn_start_devour_lr_allies":
		push_error("devour: ability not mounted")
		return false
	if data.ability.merge_value_mult != 1:
		push_error("devour: merge_value_mult expected 1")
		return false
	var fodder_data := _load_unit("res://resources/units/realtime/skeleton.tres")
	if fodder_data == null:
		push_error("devour: missing skeleton fodder")
		return false
	var bus := CombatEventBus.new()
	var grid := BoardGrid.new()
	grid.configure(Vector2i(18, 32))
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var devourer := UnitInstance.from_unit_data(data, Vector2i(9, 20), UnitInstance.Team.PLAYER)
	var left := UnitInstance.from_unit_data(fodder_data, Vector2i(8, 20), UnitInstance.Team.PLAYER)
	left.stats.attack = 3
	left.stats.max_hp = 5
	left.current_hp = 5
	var up := UnitInstance.from_unit_data(fodder_data, Vector2i(9, 19), UnitInstance.Team.PLAYER)
	up.stats.attack = 7
	up.stats.max_hp = 7
	up.current_hp = 7
	grid.place(devourer, Vector2i(9, 20))
	grid.place(left, Vector2i(8, 20))
	grid.place(up, Vector2i(9, 19))
	var atk0 := devourer.get_effective_attack()
	var hp0 := devourer.get_effective_max_hp()
	var payload := CombatEventPayload.new()
	payload.source = devourer
	payload.target = devourer
	resolver.on_event(CombatEvents.ON_ROUND_START, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
	if left.is_alive():
		push_error("devour: left ally should be dead")
		return false
	if not up.is_alive():
		push_error("devour: up ally must not be eaten (not left/right)")
		return false
	if devourer.get_effective_attack() != atk0 + 3:
		push_error(
			"devour: atk=%d expected %d"
			% [devourer.get_effective_attack(), atk0 + 3]
		)
		return false
	if devourer.get_effective_max_hp() != hp0 + 5:
		push_error(
			"devour: max_hp=%d expected %d"
			% [devourer.get_effective_max_hp(), hp0 + 5]
		)
		return false
	return true


## 实时 + defer：介绍卡路径下左右友方仍被消灭；上下不受影响。
static func _test_devour_rt_defer_kills_left_right() -> bool:
	var data := _load_unit("res://resources/units/realtime/devour.tres")
	var fodder := _load_unit("res://resources/units/realtime/skeleton.tres")
	if data == null or fodder == null:
		push_error("devour_rt: missing units")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 77)
	sim.defer_effect_resolve = true
	var devourer := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	var left := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 5, {"id": "fodder_l", "attack": 2, "steps_per_turn": 0}),
		Vector2(8.5, 24.5),
	)
	var right := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 6, {"id": "fodder_r", "attack": 3, "steps_per_turn": 0}),
		Vector2(10.5, 24.5),
	)
	var up := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 8, {"id": "fodder_up", "steps_per_turn": 0}),
		Vector2(9.5, 23.5),
	)
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(9.5, 4.5),
	)
	devourer.unit.stats.steps_per_turn = 0
	sim.begin_combat()
	var guard := 0
	while not sim.has_pending_effects() and guard < 400:
		sim.advance_fixed_step()
		guard += 1
	if not sim.has_pending_effects():
		push_error("devour_rt: expected pending OnRoundStart batch")
		return false
	## 模拟介绍卡结算：一次 process 整批。
	while sim.has_pending_effects():
		sim.resolve_next_pending_effect()
	sim._remove_dead()
	if left.is_alive() or right.is_alive():
		push_error(
			"devour_rt: L/R should die (L=%s R=%s)"
			% [left.is_alive(), right.is_alive()]
		)
		return false
	if not up.is_alive():
		push_error("devour_rt: up neighbor must survive")
		return false
	## 吞噬基础攻 6（T3 偏厚 10/6）+ 左右友方攻 2+3。
	if devourer.unit.get_effective_attack() != 6 + 2 + 3:
		push_error(
			"devour_rt: atk=%d expected 11"
			% devourer.unit.get_effective_attack()
		)
		return false
	return true


## defer 时回合开始吞噬入队后，同一步不得先出手；邻格须等结算后才被吃。
static func _test_devour_rt_pending_before_attack() -> bool:
	var data := _load_unit("res://resources/units/realtime/devour.tres")
	if data == null or data.ability == null:
		push_error("devour_order: missing devour")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 78)
	sim.defer_effect_resolve = true
	var devourer := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	var left := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 5, {"id": "fodder_l", "attack": 2, "steps_per_turn": 0}),
		Vector2(8.5, 20.5),
	)
	var right := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 6, {"id": "fodder_r", "attack": 3, "steps_per_turn": 0}),
		Vector2(10.5, 20.5),
	)
	var enemy := sim.add_unit(
		_dummy(
			UnitInstance.Team.ENEMY,
			50,
			{"steps_per_turn": 0, "sight_range": 0.0, "body_radius": 0.3},
		),
		Vector2(9.5, 19.5),
	)
	devourer.unit.stats.steps_per_turn = 0
	devourer.unit.stats.attack_windup = 0.0
	devourer.unit.stats.attack_reach = 2.0
	sim.begin_combat()
	var guard := 0
	while not sim.has_pending_effects() and guard < 400:
		sim.advance_fixed_step()
		guard += 1
	if not sim.has_pending_effects():
		push_error("devour_order: expected pending OnRoundStart")
		return false
	## 入队当下不得已出手、左右须仍存活。
	if sim._actor_has_attacked:
		push_error("devour_order: must not attack before turn-start devour resolves")
		return false
	if not left.is_alive() or not right.is_alive():
		push_error("devour_order: L/R must still be alive while pending")
		return false
	var enemy_hp := enemy.unit.current_hp
	## 再推进多步：有 pending 时应卡住，仍不攻不吃。
	for _i in 8:
		sim.advance_fixed_step()
	if sim._actor_has_attacked or enemy.unit.current_hp != enemy_hp:
		push_error("devour_order: pending must block further attack")
		return false
	if not left.is_alive() or not right.is_alive():
		push_error("devour_order: L/R must stay alive until resolve")
		return false
	while sim.has_pending_effects():
		sim.resolve_next_pending_effect()
	sim._remove_dead()
	if left.is_alive() or right.is_alive():
		push_error("devour_order: L/R should die after resolve")
		return false
	return true


## 2★ 吞噬：左右邻格首领不被吃。
static func _test_devour_star2_skips_boss() -> bool:
	var data := _load_unit("res://resources/units/realtime/devour.tres")
	var fodder_data := _load_unit("res://resources/units/realtime/skeleton.tres")
	if data == null or fodder_data == null:
		push_error("devour2: missing units")
		return false
	var bus := CombatEventBus.new()
	var grid := BoardGrid.new()
	grid.configure(Vector2i(18, 32))
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var devourer := UnitInstance.from_unit_data(data, Vector2i(9, 20), UnitInstance.Team.PLAYER)
	devourer.level = 2
	var boss_data := fodder_data.duplicate(true) as UnitData
	boss_data.is_boss_leader = true
	var boss := UnitInstance.from_unit_data(boss_data, Vector2i(8, 20), UnitInstance.Team.PLAYER)
	boss.stats.attack = 9
	boss.stats.max_hp = 9
	boss.current_hp = 9
	grid.place(devourer, Vector2i(9, 20))
	grid.place(boss, Vector2i(8, 20))
	var atk0 := devourer.get_effective_attack()
	var payload := CombatEventPayload.new()
	payload.source = devourer
	payload.target = devourer
	resolver.on_event(CombatEvents.ON_ROUND_START, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
	if not boss.is_alive():
		push_error("devour2: boss ally must survive at 2★")
		return false
	if devourer.get_effective_attack() != atk0:
		push_error("devour2: should not absorb boss stats")
		return false
	return true


static func _test_combat_start_iron_heart() -> bool:
	var data := _load_unit("res://resources/units/realtime/iron_heart.tres")
	if data == null or data.ability == null or data.ability.id != "combat_start_self_max_hp_mid":
		push_error("iron_heart: ability mount")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("iron_heart: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 501)
	var rt := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(2.5, 6.5))
	var base := rt.unit.get_effective_max_hp()
	sim.begin_combat()
	if rt.unit.get_effective_max_hp() != base + 12:
		push_error(
			"iron_heart: max_hp %d -> %d expected +12"
			% [base, rt.unit.get_effective_max_hp()]
		)
		return false
	## 三合一（2★）：merge_value_mult=3 → +36
	var sim2 := _new_sim()
	sim2.configure(ARENA, 511)
	var merged := _make_from_data(data, UnitInstance.Team.PLAYER)
	merged.level = 2
	var rt2 := sim2.add_unit(merged, Vector2(2.5, 6.5))
	var base2 := rt2.unit.get_effective_max_hp()
	sim2.begin_combat()
	if rt2.unit.get_effective_max_hp() != base2 + 36:
		push_error(
			"iron_heart 2★: max_hp %d -> %d expected +36"
			% [base2, rt2.unit.get_effective_max_hp()]
		)
		return false
	return true


static func _test_combat_start_edge_hex() -> bool:
	var data := _load_unit("res://resources/units/realtime/edge_hex.tres")
	if data == null or data.ability == null or data.ability.id != "combat_start_nearby_ally_atk_1":
		push_error("edge_hex: ability mount")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("edge_hex: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 502)
	var edge := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(2.5, 6.5))
	var nearby := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"id": "near", "attack": 3}),
		Vector2(3.5, 6.5),
	)
	var far := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"id": "far", "attack": 3}),
		Vector2(2.5, 8.5),
	)
	var near0 := nearby.unit.get_effective_attack()
	var far0 := far.unit.get_effective_attack()
	var edge0 := edge.unit.get_effective_attack()
	sim.begin_combat()
	if nearby.unit.get_effective_attack() != near0 + 1:
		push_error(
			"edge_hex: nearby atk %d -> %d expected +1"
			% [near0, nearby.unit.get_effective_attack()]
		)
		return false
	if far.unit.get_effective_attack() != far0:
		push_error("edge_hex: far ally buffed unexpectedly")
		return false
	if edge.unit.get_effective_attack() != edge0:
		push_error("edge_hex: owner should not self-buff")
		return false
	return true


static func _test_combat_start_shield_boon() -> bool:
	var data := _load_unit("res://resources/units/realtime/shield_boon.tres")
	if data == null or data.ability == null or data.ability.id != "combat_start_nearby_ally_hp_1":
		push_error("shield_boon: ability mount")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("shield_boon: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 503)
	var owner := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(2.5, 6.5))
	var nearby := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"id": "near", "max_hp": 5}),
		Vector2(3.5, 6.5),
	)
	var far := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"id": "far", "max_hp": 5}),
		Vector2(2.5, 8.5),
	)
	var near_hp0 := nearby.unit.get_effective_max_hp()
	var near_cur0 := nearby.unit.current_hp
	var far_hp0 := far.unit.get_effective_max_hp()
	var owner_hp0 := owner.unit.get_effective_max_hp()
	sim.begin_combat()
	if (
		nearby.unit.get_effective_max_hp() != near_hp0 + 1
		or nearby.unit.current_hp != near_cur0 + 1
	):
		push_error(
			"shield_boon: nearby hp %d/%d -> %d/%d expected +1/+1"
			% [
				near_hp0,
				near_cur0,
				nearby.unit.get_effective_max_hp(),
				nearby.unit.current_hp,
			]
		)
		return false
	if far.unit.get_effective_max_hp() != far_hp0:
		push_error("shield_boon: far ally buffed unexpectedly")
		return false
	if owner.unit.get_effective_max_hp() != owner_hp0:
		push_error("shield_boon: owner should not self-buff")
		return false
	return true


static func _test_combat_start_banner_nearby() -> bool:
	var data := _load_unit("res://resources/units/realtime/banner.tres")
	if data == null or data.ability == null or data.ability.id != "combat_start_buff_nearby_allies_mid":
		push_error("banner: ability mount")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 504)
	sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(2.5, 6.5))
	var nearby := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"id": "near", "attack": 2}),
		Vector2(3.5, 6.5),
	)
	var far := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"id": "far", "attack": 2}),
		Vector2(2.5, 8.5),
	)
	var near0 := nearby.unit.get_effective_attack()
	var far0 := far.unit.get_effective_attack()
	sim.begin_combat()
	if nearby.unit.get_effective_attack() != near0 + 4:
		push_error(
			"banner: nearby atk %d -> %d expected +4"
			% [near0, nearby.unit.get_effective_attack()]
		)
		return false
	if far.unit.get_effective_attack() != far0:
		push_error("banner: far ally buffed unexpectedly")
		return false
	return true

