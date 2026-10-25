class_name RealtimeAbilityEffectTest
extends RefCounted
## Headless：Content §6 九人挂载 + realtime EffectResolver 接线（MODIFY_STAT / DEAL_DAMAGE / SPAWN_UNIT）。

const ARENA := Vector2i(18, 32)

const MOUNT_TABLE := {
	"knight": "hurt_gain_atk_small",
	"rider": "enemy_death_self_atk_hp_small",
	"mini_pekka": "kill_gain_atk_mid",
	"musketeer": "deal_damage_extra_2",
	"valkyrie": "deal_damage_gain_atk_small",
	"barbarian": "ally_death_self_atk_mid",
	"archer": "ally_deploy_self_atk_small",
	"goblin": "death_spawn_pack",
	"spear_goblin": "hurt_heal_self_2",
	"skeleton": "death_heal_random_ally_2",
	"crossbow": "ally_hurt_heal_target_small",
	"maul": "deal_damage_adj_splash_small",
	"apothecary": "turn_start_nearby_hp_small",
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
	_check("arcane_friend_summon_minion_self_hp", _test_arcane_friend_summon_minion_self_hp())
	_check("arcane_friend_summon_minion_self_hp_star2", _test_arcane_friend_summon_minion_self_hp_star2())
	_check("gravewright_kill_spawn_star2", _test_gravewright_kill_spawn_star2())
	_check("berserker_kill_turn_refresh", _test_berserker_kill_turn_refresh())
	_check("hurt_gain_atk_on_damage", _test_hurt_gain_atk_on_damage())
	_check("deal_damage_gain_atk", _test_deal_damage_gain_atk())
	_check("deal_damage_extra_2", _test_deal_damage_extra_2())
	_check("kill_gain_atk_mid", _test_kill_gain_atk_mid())
	_check("ally_death_self_atk_mid", _test_ally_death_self_atk_mid())
	_check("ally_deploy_self_atk_small", _test_ally_deploy_self_atk_small())
	_check("first_hurt_harden_once", _test_first_hurt_harden_once())
	_check("deal_vs_higher_hp_extra", _test_deal_vs_higher_hp_extra())
	_check("deal_damage_adj_splash_small", _test_deal_damage_adj_splash_small())
	_check("turn_start_nearby_hp_radius_1", _test_turn_start_nearby_hp_radius_1())
	_check("wardrum_turn_start_nearby_atk_star2", _test_wardrum_turn_start_nearby_atk_star2())
	_check("death_spawn_pack", _test_death_spawn_pack())
	_check("death_spawn_pack_star2", _test_death_spawn_pack_star2())
	_check("ally_death_spawn_weak", _test_ally_death_spawn_weak())
	_check("ally_death_spawn_merged_triple", _test_ally_death_spawn_merged_triple())
	_check("death_heal_nearby_ally", _test_death_heal_nearby_ally())
	_check("hurt_heal_self_2", _test_hurt_heal_self_2())
	_check("hurt_heal_capped_to_hit", _test_hurt_heal_capped_to_hit())
	_check("blood_acolyte_combat_start_permanent", _test_blood_acolyte_combat_start_permanent())
	_check("ally_hurt_heal_target", _test_ally_hurt_heal_target())
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


## 奥术：仅友方战斗随从上场时自身 max_hp+当前 +2；普通友方入座不触发。
static func _test_arcane_friend_summon_minion_self_hp() -> bool:
	var data := _load_unit("res://resources/units/realtime/arcane.tres")
	if data == null or data.ability == null or data.ability.id != "friend_summon_minion_self_hp_small":
		push_error("arcane: ability not mounted")
		return false
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 91)
	var mage := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(8.5, 22.5))
	var base_max := mage.unit.get_effective_max_hp()
	var base_hp := mage.unit.current_hp
	## 普通友方入座：不应触发。
	sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 50, {"id": "ally_roster"}), Vector2(10.5, 22.5))
	if mage.unit.get_effective_max_hp() != base_max:
		push_error("arcane: roster ally spawn should not buff")
		return false
	## 战斗随从上场：应 +2 上限与当前。
	var minion := _dummy(UnitInstance.Team.PLAYER, 1, {"id": "token_ember", "max_hp": 1, "attack": 1})
	minion.is_combat_summon = true
	sim.add_unit(minion, Vector2(9.5, 20.5))
	var after_max := mage.unit.get_effective_max_hp()
	var after_hp := mage.unit.current_hp
	if after_max != base_max + 2:
		push_error("arcane: max_hp %d -> %d, expected +2" % [base_max, after_max])
		return false
	if after_hp != base_hp + 2:
		push_error("arcane: current_hp %d -> %d, expected +2" % [base_hp, after_hp])
		return false
	return true


static func _test_arcane_friend_summon_minion_self_hp_star2() -> bool:
	var data := _load_unit("res://resources/units/realtime/arcane.tres")
	var bus := CombatEventBus.new()
	var sim := _new_sim(bus)
	sim.configure(ARENA, 92)
	var mage := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(8.5, 22.5))
	mage.unit.level = 2
	var base_max := mage.unit.get_effective_max_hp()
	var minion := _dummy(UnitInstance.Team.PLAYER, 1, {"id": "token_ember", "max_hp": 1, "attack": 1})
	minion.is_combat_summon = true
	sim.add_unit(minion, Vector2(9.5, 20.5))
	if mage.unit.get_effective_max_hp() != base_max + 6:
		push_error(
			"arcane 2★: max_hp %d -> %d, expected +6"
			% [base_max, mage.unit.get_effective_max_hp()]
		)
		return false
	return true


static func _test_gravewright_kill_spawn_star2() -> bool:
	var data := _load_unit("res://resources/units/realtime/gravewright.tres")
	if data == null or data.ability == null or data.ability.id != "kill_spawn_weak":
		push_error("grave spawn: ability not mounted")
		return false
	var bus := CombatEventBus.new()
	var grid := BoardGrid.new()
	grid.configure(Vector2i(18, 32))
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var digger := UnitInstance.from_unit_data(data, Vector2i(4, 20), UnitInstance.Team.PLAYER)
	digger.level = 2
	var victim := UnitInstance.from_unit_data(
		_load_unit("res://resources/units/enemies/enemy_knight.tres"),
		Vector2i(6, 18),
		UnitInstance.Team.ENEMY,
	)
	victim.current_hp = 0
	grid.place(digger, Vector2i(4, 20))
	grid.place(victim, Vector2i(6, 18))
	var payload := CombatEventPayload.new()
	payload.source = digger
	payload.target = victim
	resolver.on_event(CombatEvents.ON_KILL, payload)
	while resolver.has_pending_steps():
		resolver.process_next_step()
	var token: UnitInstance = null
	for u in grid.get_all_units():
		if u != null and u.id == "token_weak" and u.is_alive():
			token = u
			break
	if token == null or token.stats == null:
		push_error("grave spawn 2★: missing token_weak")
		return false
	if token.stats.attack != 6 or token.stats.max_hp != 6 or token.current_hp != 6:
		push_error(
			"grave spawn 2★: token %d/%d expected 6/6"
			% [token.stats.attack, token.stats.max_hp]
		)
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
	var data := _load_unit("res://resources/units/realtime/valkyrie.tres")
	if data == null or data.ability == null or data.ability.id != "deal_damage_gain_atk_small":
		push_error("deal: valkyrie ability not mounted")
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
	var bonus := 2 * UnitInstance.ability_value_multiplier_for(data.ability, level)
	var expected := gun.unit.get_effective_attack() + bonus
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
	if dealt != 13:
		push_error("musketeer star2: dealt %d, expected attack 7 + extra 6" % dealt)
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


## 游侠：其他友方生成时自身攻击 +1；自己上场不触发。
static func _test_ally_deploy_self_atk_small() -> bool:
	var data := _load_unit("res://resources/units/realtime/archer.tres")
	if data == null or data.ability == null or data.ability.id != "ally_deploy_self_atk_small":
		push_error("ally_deploy: archer ability not mounted")
		return false
	var expected_base := data.stats.attack if data.stats != null else 0
	var sim := _new_sim()
	sim.configure(ARENA, 19)
	var archer := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	if archer.unit.get_effective_attack() != expected_base:
		push_error(
			"ally_deploy: self spawn should not buff (atk %d, base %d)"
			% [archer.unit.get_effective_attack(), expected_base]
		)
		return false
	sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 50, {"id": "ally_roster"}), Vector2(10.5, 24.5))
	var after := archer.unit.get_effective_attack()
	if after != expected_base + 1:
		push_error(
			"ally_deploy: archer atk %d, expected base %d +1 on OnFriendSummoned"
			% [after, expected_base]
		)
		return false
	return true


static func _test_first_hurt_harden_once() -> bool:
	var data := _load_unit("res://resources/units/realtime/rune_plate.tres")
	if data == null or data.ability == null or data.ability.id != "first_hurt_harden":
		push_error("first_hurt: rune_plate ability not mounted")
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


static func _test_deal_vs_higher_hp_extra() -> bool:
	var data := _load_unit("res://resources/units/realtime/hunter.tres")
	if data == null or data.ability == null or data.ability.id != "deal_vs_higher_hp_extra":
		push_error("vs_higher: hunter ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 29)
	var hunter := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	hunter.unit.stats.attack_windup = 0.0
	hunter.unit.stats.attack_interval = 0.3
	hunter.unit.stats.steps_per_turn = 0
	hunter.unit.stats.attack_reach = 2.0
	## 目标当前生命高于猎人 → 条件成立；远处木桩避免清场。
	var fat := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 50, {"steps_per_turn": 0, "sight_range": 0.0, "body_radius": 0.3}),
		Vector2(9.5, 20.0),
	)
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(2.5, 4.5),
	)
	var hp_before := fat.unit.current_hp
	var base_atk := hunter.unit.get_effective_attack()
	var guard := 0
	while fat.unit.current_hp > hp_before - (base_atk + 2) and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	var dealt := hp_before - fat.unit.current_hp
	## 普攻 + 削峰额外（资源 value=2）；至少应超过裸攻。
	if dealt < base_atk + 2:
		push_error(
			"vs_higher: dealt %d, expected >= atk(%d)+extra(2)" % [dealt, base_atk]
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


## 药师固脉：附近=周围一格；距 1 受益、距 2 不受益。
static func _test_turn_start_nearby_hp_radius_1() -> bool:
	if EffectSpec.NEARBY_ALLY_RADIUS != 1:
		push_error(
			"nearby_hp_radius: NEARBY_ALLY_RADIUS=%d expected 1"
			% EffectSpec.NEARBY_ALLY_RADIUS
		)
		return false
	var data := _load_unit("res://resources/units/realtime/apothecary.tres")
	if data == null or data.ability == null or data.ability.id != "turn_start_nearby_hp_small":
		push_error("nearby_hp_radius: apothecary must mount turn_start_nearby_hp_small")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 510)
	var medic := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	medic.unit.stats.steps_per_turn = 0
	var near := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(10.5, 20.5),
	)
	var far := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(11.5, 20.5),
	)
	sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 100000, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(9.5, 8.5),
	)
	sim.begin_combat()
	var near_max_before := near.unit.get_effective_max_hp()
	var far_max_before := far.unit.get_effective_max_hp()
	var payload := CombatEventPayload.new()
	payload.source = medic.unit
	payload.target = medic.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ROUND_START, payload)
	sim._drain_effects()
	if near.unit.get_effective_max_hp() != near_max_before + 2:
		push_error(
			"nearby_hp_radius: near max_hp=%d expected %d"
			% [near.unit.get_effective_max_hp(), near_max_before + 2]
		)
		return false
	if far.unit.get_effective_max_hp() != far_max_before:
		push_error(
			"nearby_hp_radius: far max_hp=%d expected unchanged %d (2 cells)"
			% [far.unit.get_effective_max_hp(), far_max_before]
		)
		return false
	return true


## 鼓手 2★：自己回合开始周围一格其他友方攻击 +6（merge_value_mult=3）。
static func _test_wardrum_turn_start_nearby_atk_star2() -> bool:
	var data := _load_unit("res://resources/units/realtime/wardrum.tres")
	if data == null or data.ability == null or data.ability.id != "turn_start_nearby_atk_small":
		push_error("wardrum_atk: ability not mounted")
		return false
	if data.ability.merge_value_mult != 3:
		push_error("wardrum_atk: merge_value_mult expected 3")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 511)
	var drum := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	drum.unit.level = 2
	drum.unit.stats.steps_per_turn = 0
	var near := sim.add_unit(
		_dummy(UnitInstance.Team.PLAYER, 10, {"steps_per_turn": 0, "sight_range": 0.0}),
		Vector2(10.5, 20.5),
	)
	sim.begin_combat()
	var self_atk_before := drum.unit.get_effective_attack()
	var near_atk_before := near.unit.get_effective_attack()
	var payload := CombatEventPayload.new()
	payload.source = drum.unit
	payload.target = drum.unit
	sim.get_event_bus().emit_event(CombatEvents.ON_ROUND_START, payload)
	sim._drain_effects()
	if drum.unit.get_effective_attack() != self_atk_before:
		push_error("wardrum_atk: owner must not buff self")
		return false
	if near.unit.get_effective_attack() != near_atk_before + 6:
		push_error(
			"wardrum_atk 2★: near atk=%d expected %d"
			% [near.unit.get_effective_attack(), near_atk_before + 6]
		)
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


## 血僧：开战永久 +1/+1；须写入 DeckEntry（2★ +6/+6）。
static func _test_blood_acolyte_combat_start_permanent() -> bool:
	var data := _load_unit("res://resources/units/realtime/blood_acolyte.tres")
	if data == null or data.ability == null or data.ability.id != "combat_start_permanent_self_atk_hp_1":
		push_error("blood_perm: ability mount")
		return false
	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 10
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	var entry := deck.add_entry(data)
	entry.level = 2
	var sim := _new_sim()
	sim.configure(ARENA, 4202)
	sim.set_deck_state(deck)
	var monk := sim.add_unit(
		UnitInstance.from_deck_entry(entry, Vector2i(9, 20), UnitInstance.Team.PLAYER),
		Vector2(9.5, 20.5),
	)
	var base_atk := monk.unit.get_effective_attack()
	var base_hp := monk.unit.get_effective_max_hp()
	sim.begin_combat()
	sim.flush_combat_start_lock()
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


## 弩手：友方受伤 → 疗该友方 2。
static func _test_ally_hurt_heal_target() -> bool:
	var data := _load_unit("res://resources/units/realtime/crossbow.tres")
	if data == null or data.ability == null or data.ability.id != "ally_hurt_heal_target_small":
		push_error("ally_hurt_heal: crossbow ability not mounted")
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

