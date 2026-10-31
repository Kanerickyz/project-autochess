class_name CombatStatusTest
extends RefCounted

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_check("stack_cap", _test_stack_cap())
	_check("weak_before_armor", _test_weak_before_armor())
	_check("berserk_attack_only", _test_berserk_attack_only())
	_check("poison_tick_lethal", _test_poison_tick_lethal())
	_check("apply_status_via_resolver", _test_apply_via_resolver())
	_check("apply_relic_bone_via_resolver", _test_apply_relic_bone_via_resolver())
	_check("relic_bone_death_spawn", _test_relic_bone_death_spawn())
	_check("relic_bone_zero_stacks_no_spawn", _test_relic_bone_zero_stacks_no_spawn())
	_check("relic_bone_token_no_chain", _test_relic_bone_token_no_chain())
	_check("weak_skip_dead_on_deal_damage", _test_weak_skip_dead_on_deal_damage())
	_check("status_attachments_ui", _test_status_attachments())
	if _failures == 0:
		print("CombatStatusTest: all tests passed")
	else:
		push_error("CombatStatusTest: %d failure(s)" % _failures)
	return _failures == 0


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("CombatStatusTest FAIL: %s" % name)


static func _test_stack_cap() -> bool:
	var stack := CombatStatusStack.new()
	stack.add_stacks(CombatStatusStack.ID_POISON, 20)
	return stack.get_stacks(CombatStatusStack.ID_POISON) == CombatStatusStack.MAX_STACKS


static func _test_weak_before_armor() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var target := UnitInstance.new("t", Vector2i(0, 0), UnitInstance.Team.ENEMY)
	target.stats = UnitStats.new()
	target.stats.max_hp = 10
	target.current_hp = 10
	target.armor_block = 5
	target.combat_statuses.add_stacks(CombatStatusStack.ID_WEAK, 2)
	grid.place(target, Vector2i(0, 0))
	pipeline.apply_damage(null, target, 3, false)
	## 3 + 2 虚弱 = 5，全额护甲抵挡，不扣血。
	return target.current_hp == 10 and target.get_armor_block() == 0


static func _test_berserk_attack_only() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var atk := UnitInstance.new("a", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	var def := UnitInstance.new("d", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	atk.stats = UnitStats.new()
	def.stats = UnitStats.new()
	def.stats.max_hp = 20
	def.current_hp = 20
	atk.combat_statuses.add_stacks(CombatStatusStack.ID_BERSERK, 3)
	grid.place(atk, Vector2i(0, 0))
	grid.place(def, Vector2i(1, 0))
	pipeline.apply_damage(atk, def, 2, false)
	if def.current_hp != 18:
		return false
	def.current_hp = 20
	pipeline.apply_damage(atk, def, 2, true)
	return def.current_hp == 15


static func _test_poison_tick_lethal() -> bool:
	var sim := RealtimeCombatSim.new()
	sim.configure(Vector2i(18, 32), 99)
	var unit := UnitInstance.new("p", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.stats = UnitStats.new()
	unit.stats.max_hp = 2
	unit.current_hp = 2
	unit.combat_statuses.add_stacks(CombatStatusStack.ID_POISON, 2)
	var rt := sim.add_unit(unit, Vector2(2.5, 6.5))
	if rt == null:
		return false
	var still_alive := sim._apply_poison_tick_before_round_start(rt)
	sim.dispose()
	return not still_alive and not unit.is_alive()


static func _test_weak_skip_dead_on_deal_damage() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var archer_data := load("res://resources/units/realtime/archer.tres") as UnitData
	if archer_data == null or archer_data.ability == null:
		return false
	var archer := UnitInstance.from_unit_data(archer_data, Vector2i(0, 0), UnitInstance.Team.PLAYER)
	var enemy := UnitInstance.new("e", Vector2i(1, 0), UnitInstance.Team.ENEMY)
	enemy.stats = UnitStats.new()
	enemy.stats.max_hp = 1
	enemy.current_hp = 0
	grid.place(archer, Vector2i(0, 0))
	grid.place(enemy, Vector2i(1, 0))
	var payload := CombatEventPayload.new()
	payload.source = archer
	payload.target = enemy
	payload.amount = 3
	resolver.on_event(CombatEvents.ON_DEAL_DAMAGE, payload)
	if resolver.has_pending_steps():
		return false
	resolver.clear_pending()
	enemy.current_hp = 1
	resolver.on_event(CombatEvents.ON_DEAL_DAMAGE, payload)
	return resolver.has_pending_steps()


static func _test_apply_via_resolver() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var target := UnitInstance.new("t", Vector2i(0, 0), UnitInstance.Team.ENEMY)
	target.stats = UnitStats.new()
	target.stats.max_hp = 10
	target.current_hp = 10
	grid.place(target, Vector2i(0, 0))
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
	action.stat_name = CombatStatusStack.ID_BERSERK
	action.value = 2
	var spec := EffectSpec.new()
	resolver._execute_action(action, target, CombatEventPayload.new(), 0, target, spec)
	return target.combat_statuses.get_stacks(CombatStatusStack.ID_BERSERK) == 2


static func _test_apply_relic_bone_via_resolver() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var target := UnitInstance.new("t", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	target.stats = UnitStats.new()
	target.stats.max_hp = 10
	target.current_hp = 10
	grid.place(target, Vector2i(0, 0))
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.APPLY_COMBAT_STATUS
	action.stat_name = CombatStatusStack.ID_RELIC_BONE
	action.value = 1
	var spec := EffectSpec.new()
	resolver._execute_action(action, target, CombatEventPayload.new(), 0, target, spec)
	if target.combat_statuses.get_stacks(CombatStatusStack.ID_RELIC_BONE) != 1:
		return false
	if CombatStatusStack.get_display_name(CombatStatusStack.ID_RELIC_BONE) != "遗骨":
		return false
	return CombatStatusStack.get_rule_summary(CombatStatusStack.ID_RELIC_BONE).contains("层数×2")


static func _find_relic_token(grid: BoardGrid) -> UnitInstance:
	for item in grid.get_alive_units():
		var unit := item as UnitInstance
		if unit != null and unit.id == "token_relic_skeleton":
			return unit
	return null


static func _test_relic_bone_death_spawn() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var dead := UnitInstance.new("dead", Vector2i(2, 2), UnitInstance.Team.PLAYER)
	dead.stats = UnitStats.new()
	dead.stats.max_hp = 1
	dead.stats.attack = 1
	dead.current_hp = 0
	dead.combat_statuses.add_stacks(CombatStatusStack.ID_RELIC_BONE, 3)
	grid.place(dead, Vector2i(2, 2))
	var payload := CombatEventPayload.new()
	payload.target = dead
	resolver.on_event(CombatEvents.ON_DEATH, payload)
	var token := _find_relic_token(grid)
	if token == null:
		return false
	if not token.is_combat_summon:
		return false
	if token.stats == null or token.stats.attack != 6 or token.stats.max_hp != 6:
		return false
	if token.current_hp != 6:
		return false
	return token.combat_statuses.get_stacks(CombatStatusStack.ID_RELIC_BONE) == 0


static func _test_relic_bone_zero_stacks_no_spawn() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var dead := UnitInstance.new("dead0", Vector2i(1, 1), UnitInstance.Team.PLAYER)
	dead.stats = UnitStats.new()
	dead.stats.max_hp = 1
	dead.current_hp = 0
	grid.place(dead, Vector2i(1, 1))
	var payload := CombatEventPayload.new()
	payload.target = dead
	resolver.on_event(CombatEvents.ON_DEATH, payload)
	return _find_relic_token(grid) == null


static func _test_relic_bone_token_no_chain() -> bool:
	var grid := BoardGrid.new()
	grid.configure(Vector2i(8, 8))
	var bus := CombatEventBus.new()
	var pipeline := DamagePipeline.new(bus, grid)
	var resolver := EffectResolver.new(grid, bus, pipeline)
	var dead := UnitInstance.new("dead_chain", Vector2i(3, 3), UnitInstance.Team.ENEMY)
	dead.stats = UnitStats.new()
	dead.stats.max_hp = 1
	dead.current_hp = 0
	dead.combat_statuses.add_stacks(CombatStatusStack.ID_RELIC_BONE, 2)
	grid.place(dead, Vector2i(3, 3))
	var payload := CombatEventPayload.new()
	payload.target = dead
	resolver.on_event(CombatEvents.ON_DEATH, payload)
	var token := _find_relic_token(grid)
	if token == null:
		return false
	## 骷髅再死：无遗骨 → 不再生成。
	token.current_hp = 0
	var payload2 := CombatEventPayload.new()
	payload2.target = token
	resolver.on_event(CombatEvents.ON_DEATH, payload2)
	var count := 0
	for item in grid.get_alive_units():
		var unit := item as UnitInstance
		if unit != null and unit.id == "token_relic_skeleton" and unit.is_alive():
			count += 1
	## 原 token 已死；不应出现第二只。
	return count == 0


static func _test_status_attachments() -> bool:
	var unit := UnitInstance.new("u", Vector2i(0, 0), UnitInstance.Team.PLAYER)
	unit.combat_statuses.add_stacks(CombatStatusStack.ID_WEAK, 2)
	var attachments := UnitInfoText.collect_combat_status_attachments(unit, false)
	if attachments.size() != 1:
		return false
	var info: Dictionary = attachments[0]
	return (
		String(info.get("name", "")) == "虚弱"
		and String(info.get("attachment_kind", "")) == String(UnitInfoText.INFO_ATTACHMENT_KIND_STATUS)
	)
