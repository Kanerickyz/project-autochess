class_name RealtimeAbilityEffectTest
extends RefCounted
## Headless：Content §6 九人挂载 + realtime EffectResolver 接线（MODIFY_STAT / DEAL_DAMAGE / SPAWN_UNIT）。

const ARENA := Vector2i(18, 32)

const MOUNT_TABLE := {
	"knight": "hurt_gain_atk_small",
	"rider": "combat_start_charge",
	"mini_pekka": "kill_gain_atk_mid",
	"musketeer": "crit_extra_damage_mid",
	"valkyrie": "deal_damage_gain_atk_small",
	"barbarian": "ally_death_self_atk_mid",
	"archer": "ally_deploy_self_atk_small",
	"goblin": "death_spawn_pack",
	"spear_goblin": "death_aoe_mid",
}

const EMPTY_ABILITY_IDS := ["skeleton", "giant_knight"]

static var _created: Array[RealtimeCombatSim] = []
static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("mount_bindings", _test_mount_bindings())
	_check("combat_start_charge_atk", _test_combat_start_charge_atk())
	_check("hurt_gain_atk_on_damage", _test_hurt_gain_atk_on_damage())
	_check("deal_damage_gain_atk", _test_deal_damage_gain_atk())
	_check("crit_extra_damage_mid", _test_crit_extra_damage_mid())
	_check("kill_gain_atk_mid", _test_kill_gain_atk_mid())
	_check("ally_death_self_atk_mid", _test_ally_death_self_atk_mid())
	_check("ally_deploy_self_atk_small", _test_ally_deploy_self_atk_small())
	_check("death_spawn_pack", _test_death_spawn_pack())
	_check("death_aoe_deal_damage", _test_death_aoe_deal_damage())
	_check("musketeer_has_nonzero_crit", _test_musketeer_has_nonzero_crit())
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


static func _test_combat_start_charge_atk() -> bool:
	var data := _load_unit("res://resources/units/realtime/rider.tres")
	if data == null or data.ability == null or data.ability.id != "combat_start_charge":
		push_error("charge: rider ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 42)
	var rider := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY), Vector2(9.5, 8.5))
	var base_atk := rider.unit.get_effective_attack()
	sim.begin_combat()
	var after := rider.unit.get_effective_attack()
	## combat_start_charge：开战自身攻击 +2（与 ability 资源一致）
	if after != base_atk + 2:
		push_error("charge: atk %d -> %d, expected +2" % [base_atk, after])
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
				"move_speed": 0.0,
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
	flail.unit.stats.move_speed = 0.0
	flail.unit.stats.attack_reach = 2.0
	flail.unit.stats.sight_range = 10.0
	flail.unit.stats.splash_radius = 0.0
	var base_atk := flail.unit.get_effective_attack()
	var guard := 0
	while flail.unit.get_effective_attack() < base_atk + 16 and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	var after := flail.unit.get_effective_attack()
	if after < base_atk + 16:
		push_error("deal: atk %d -> %d, expected at least +16 (2x8)" % [base_atk, after])
		return false
	return true


static func _test_musketeer_has_nonzero_crit() -> bool:
	var data := _load_unit("res://resources/units/realtime/musketeer.tres")
	if data == null or data.stats == null:
		push_error("crit_rate: musketeer missing")
		return false
	if data.stats.crit_rate_percent <= 0:
		push_error("crit_rate: musketeer crit_rate_percent=%d, expected >0 for OnCrit skill" % data.stats.crit_rate_percent)
		return false
	return true


static func _test_crit_extra_damage_mid() -> bool:
	var data := _load_unit("res://resources/units/realtime/musketeer.tres")
	if data == null or data.ability == null or data.ability.id != "crit_extra_damage_mid":
		push_error("crit: musketeer ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 99)
	var gun := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 500, {"move_speed": 0.0, "sight_range": 0.0, "attack_reach": 0.0}),
		Vector2(9.5, 18.5),
	)
	# 强制必暴，验证 OnCrit → DEAL_DAMAGE 55
	gun.unit.stats.crit_rate_percent = 100
	gun.unit.stats.projectile_speed = 0.0
	gun.unit.stats.attack_windup = 0.0
	gun.unit.stats.attack_interval = 0.3
	gun.unit.stats.attack_reach = 3.0
	gun.unit.stats.move_speed = 0.0
	var hp_before := enemy.unit.current_hp
	var guard := 0
	while enemy.unit.current_hp > hp_before - 55 and guard < 200:
		sim.advance_fixed_step()
		guard += 1
	var dealt := hp_before - enemy.unit.current_hp
	# 普攻 + 暴击额外伤；至少应包含 +55
	if dealt < 55:
		push_error("crit: dealt %d, expected at least 55 bonus path" % dealt)
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
		_dummy(UnitInstance.Team.ENEMY, 50, {"move_speed": 0.0, "body_radius": 0.3}),
		Vector2(9.5, 20.0),
	)
	# 远处再挂一个敌方，避免杀光立刻结束
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"move_speed": 0.0, "sight_range": 0.0}), Vector2(2.5, 4.5))
	sword.unit.stats.attack_windup = 0.0
	sword.unit.stats.attack_interval = 0.3
	sword.unit.stats.move_speed = 0.0
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
			{"max_hp": 20, "attack": 1, "move_speed": 0.0, "sight_range": 0.0, "attack_reach": 0.0},
		),
		Vector2(9.5, 20.5),
	)
	sim.add_unit(
		RealtimeCombatSimTest.make_unit(
			UnitInstance.Team.ENEMY,
			{
				"attack": 500,
				"max_hp": 100000,
				"move_speed": 0.0,
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


static func _test_ally_deploy_self_atk_small() -> bool:
	var data := _load_unit("res://resources/units/realtime/archer.tres")
	if data == null or data.ability == null or data.ability.id != "ally_deploy_self_atk_small":
		push_error("ally_deploy: archer ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 19)
	var archer := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 24.5))
	sim.add_unit(_dummy(UnitInstance.Team.ENEMY, 100000, {"move_speed": 0.0, "sight_range": 0.0}), Vector2(9.5, 4.5))
	sim.begin_combat()
	var base_atk := archer.unit.get_effective_attack()
	# 战中补人：走 deploy，结束时发 ON_FRIEND_SUMMONED
	var reinforce := RealtimeCombatSimTest.make_unit(
		UnitInstance.Team.PLAYER,
		{"max_hp": 100, "attack": 1, "deploy_time": 0.1, "move_speed": 0.0, "sight_range": 0.0},
	)
	sim.add_unit(reinforce, Vector2(8.5, 24.5))
	var guard := 0
	while archer.unit.get_effective_attack() <= base_atk and guard < 100:
		sim.advance_fixed_step()
		guard += 1
	var after := archer.unit.get_effective_attack()
	if after <= base_atk:
		push_error("ally_deploy: archer atk %d -> %d, expected buff on friend summon" % [base_atk, after])
		return false
	return true


static func _test_death_spawn_pack() -> bool:
	var data := _load_unit("res://resources/units/realtime/goblin.tres")
	if data == null or data.ability == null or data.ability.id != "death_spawn_pack":
		push_error("spawn: goblin ability not mounted")
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
				"move_speed": 0.0,
				"attack_windup": 0.0,
				"attack_interval": 0.2,
				"attack_reach": 2.0,
				"sight_range": 10.0,
			},
		),
		Vector2(9.5, 20.0),
	)
	# 保留一个远处木桩，避免杀光后立刻结束战斗
	sim.add_unit(_dummy(UnitInstance.Team.PLAYER, 100000, {"move_speed": 0.0, "sight_range": 0.0}), Vector2(2.5, 28.5))
	var guard := 0
	while light.is_alive() and guard < 300:
		sim.advance_fixed_step()
		guard += 1
	if light.is_alive():
		push_error("spawn: light infantry should have died (killer atk=%d)" % killer.unit.get_effective_attack())
		return false
	var tokens := 0
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt.unit.id == "token_ember" and rt.is_alive():
			tokens += 1
	if tokens < 1:
		push_error("spawn: expected token_ember on field, got %d (units=%d)" % [tokens, sim.get_units().size()])
		return false
	return true


static func _test_death_aoe_deal_damage() -> bool:
	var data := _load_unit("res://resources/units/realtime/spear_goblin.tres")
	if data == null or data.ability == null or data.ability.id != "death_aoe_mid":
		push_error("aoe: spear_goblin ability not mounted")
		return false
	var sim := _new_sim()
	sim.configure(ARENA, 5)
	var spear := sim.add_unit(_make_from_data(data, UnitInstance.Team.PLAYER), Vector2(9.5, 20.5))
	# 远处唯一敌方，死亡 AOE 的 RANDOM_ENEMY 必打到它
	var enemy := sim.add_unit(
		_dummy(UnitInstance.Team.ENEMY, 200, {"move_speed": 0.0, "sight_range": 0.0, "attack_reach": 0.0}),
		Vector2(15.5, 4.5),
	)
	sim.begin_combat()
	var enemy_hp_before := enemy.unit.current_hp
	# 经 realtime 扣血入口杀投矛兵，触发 ON_DEATH → EffectResolver DEAL_DAMAGE
	var killed: bool = sim._pipeline.apply_damage(null, spear, 999)
	if not killed:
		push_error("aoe: apply_damage should kill spear")
		return false
	sim._drain_effects()
	if spear.unit.is_alive():
		push_error("aoe: spear should be dead")
		return false
	if enemy.unit.current_hp >= enemy_hp_before:
		push_error(
			"aoe: enemy hp unchanged (%d); expected DEAL_DAMAGE from death_aoe_mid"
			% enemy.unit.current_hp
		)
		return false
	var dealt := enemy_hp_before - enemy.unit.current_hp
	## death_aoe_mid：死亡对随机敌人造成 3 伤害
	if dealt < 3:
		push_error("aoe: dealt %d, expected >=3" % dealt)
		return false
	return true
