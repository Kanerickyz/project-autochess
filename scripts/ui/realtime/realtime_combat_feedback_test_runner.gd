extends SceneTree
## Headless：实时主路径技能因果反馈（COMBAT_FEEDBACK L2）。
## 断言 arena 收到 ON_EFFECT_RESOLVED 飘字；普攻伤害事件不产生反馈。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
const RIDER_PATH := "res://resources/units/realtime/rider.tres"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_mapper_and_arena_direct()
	await _test_effect_resolved_feedback_on_arena()
	await _test_rider_combat_start_feedback()
	await _test_basic_attack_does_not_float()
	await _test_timestop_queue_blocks_sim()
	if _failures == 0:
		print("RealtimeCombatFeedbackTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("RealtimeCombatFeedbackTest: FAIL %s" % label)


func _make_battle(seed: int) -> RealtimeBattleController:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	deck.reset_from_config()
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	var level := load(LEVEL_PATH) as LevelData
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = seed
	root.add_child(battle)
	battle.setup(deck, economy, level)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	return battle


func _seat_first_hand(battle: RealtimeBattleController) -> bool:
	var hand := battle.get_hand()
	if hand.is_empty():
		return false
	var err := battle.try_assign_to_slot(hand[0].entry_id, battle.get_slot_board().get_cell(0))
	return err.is_empty()


func _test_mapper_and_arena_direct() -> void:
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.MODIFY_STAT
	action.stat_name = &"attack"
	action.value = 50
	var unit := UnitInstance.from_unit_data(
		load(RIDER_PATH) as UnitData, Vector2i(2, 10), UnitInstance.Team.PLAYER
	)
	var payload := CombatEventPayload.new()
	payload.effect_owner = unit
	payload.source = unit
	payload.target = unit
	payload.effect_action = action
	payload.effect_spec = (load(RIDER_PATH) as UnitData).ability.effect_specs[0]
	payload.effect_entries = [{"action": action, "target": unit}]

	var pops := RealtimeEffectFeedback.build_popups(payload)
	_expect(pops.size() == 1, "mapper: one MODIFY_STAT popup")
	if pops.size() >= 1:
		_expect(pops[0]["kind"] == RealtimeEffectFeedback.KIND_STAT, "mapper: kind=stat")
		_expect(String(pops[0]["text"]).find("50") >= 0, "mapper: text contains 50")
		_expect(String(pops[0]["text"]).find("攻") >= 0, "mapper: text contains 攻")

	var spawn_action := EffectAction.new()
	spawn_action.action_type = EffectAction.Type.SPAWN_UNIT
	spawn_action.spawn_count = 3
	var spawn_payload := CombatEventPayload.new()
	spawn_payload.effect_owner = unit
	spawn_payload.source = unit
	spawn_payload.target = unit
	spawn_payload.effect_action = spawn_action
	spawn_payload.effect_entries = [{"action": spawn_action, "target": unit}]
	var spawn_pops := RealtimeEffectFeedback.build_popups(spawn_payload)
	_expect(spawn_pops.size() == 1, "mapper: SPAWN_UNIT yields label")
	if spawn_pops.size() >= 1:
		_expect(spawn_pops[0]["kind"] == RealtimeEffectFeedback.KIND_LABEL, "mapper: spawn kind=label")

	var arena := RealtimeArenaView.new()
	arena.board_size = Vector2i(9, 16)
	root.add_child(arena)
	arena.add_feedback_popup(
		RealtimeEffectFeedback.KIND_STAT,
		"+50攻",
		Vector2(2.5, 10.5),
		true,
		unit.instance_id,
		50,
		"%d|stat|attack" % unit.instance_id,
	)
	_expect(arena.get_feedback_count() == 1, "arena: one feedback after add")
	arena.add_feedback_popup(
		RealtimeEffectFeedback.KIND_STAT,
		"+12攻",
		Vector2(2.5, 10.5),
		true,
		unit.instance_id,
		12,
		"%d|stat|attack" % unit.instance_id,
	)
	_expect(arena.get_feedback_count() == 1, "arena: merge window keeps one entry")
	var merged := arena.get_feedback_entries()
	if merged.size() == 1:
		_expect(int(merged[0]["amount"]) == 62, "arena: merged amount 62")
		_expect(String(merged[0]["text"]).find("62") >= 0, "arena: merged text shows 62")
	arena.queue_free()


func _test_effect_resolved_feedback_on_arena() -> void:
	var battle := _make_battle(4242)
	await process_frame
	_expect(_seat_first_hand(battle), "inject: seat one unit")
	_expect(battle.try_start_combat(), "inject: start combat")
	var arena := battle.get_arena()
	var before := arena.get_feedback_count()
	var target: UnitInstance = null
	for item in battle.get_sim().get_units():
		var rt := item as RtUnit
		if rt.is_player():
			target = rt.unit
			break
	_expect(target != null, "inject: player unit on field")

	var action := EffectAction.new()
	action.action_type = EffectAction.Type.HEAL
	action.value = 18
	var payload := CombatEventPayload.new()
	payload.effect_owner = target
	payload.source = target
	payload.target = target
	payload.effect_action = action
	payload.effect_entries = [{"action": action, "target": target}]
	if battle._bus != null:
		battle._bus.emit_event(CombatEvents.ON_EFFECT_RESOLVED, payload)
	await process_frame
	_expect(arena.get_feedback_count() > before, "inject: ON_EFFECT_RESOLVED adds feedback")
	var saw_heal := false
	for fb in arena.get_feedback_entries():
		if fb["kind"] == RealtimeEffectFeedback.KIND_HEAL:
			saw_heal = true
			_expect(String(fb["text"]).find("18") >= 0, "inject: heal text shows 18")
			break
	_expect(saw_heal, "inject: heal kind present")

	battle.queue_free()
	await process_frame


func _test_rider_combat_start_feedback() -> void:
	## 多轮刷新直到手牌有 combat_start_charge，开战应飘 +攻。
	var battle := _make_battle(777)
	await process_frame
	var seated := false
	for _attempt in 8:
		for entry in battle.get_hand():
			if entry == null or entry.unit == null or entry.unit.ability == null:
				continue
			if entry.unit.ability.id != "combat_start_charge":
				continue
			var err := battle.try_assign_to_slot(entry.entry_id, battle.get_slot_board().get_cell(0))
			if err.is_empty():
				seated = true
				break
		if seated:
			break
		if not battle.try_refresh_hand():
			break
	if not seated:
		## 夹具：从牌库条目直接入座（DeckState 公开 get_entries）。
		for entry in battle._deck_state.get_entries():
			if entry == null or entry.unit == null or entry.unit.ability == null:
				continue
			if entry.unit.ability.id != "combat_start_charge":
				continue
			var slots := battle.get_slot_board()
			var ok := slots.try_assign(0, entry)
			_expect(ok, "rider: slot assign charge unit via deck fixture")
			seated = ok
			battle._sync_slot_visuals()
			battle._refresh_hud()
			break
	_expect(seated, "rider: combat_start_charge unit seated")
	if not seated:
		battle.queue_free()
		await process_frame
		return

	var arena := battle.get_arena()
	var before := arena.get_feedback_count()
	_expect(battle.try_start_combat(), "rider: start combat")
	await process_frame
	_expect(arena.get_feedback_count() > before, "rider: charge effect yields feedback")
	var has_stat := false
	for fb in arena.get_feedback_entries():
		if fb["kind"] == RealtimeEffectFeedback.KIND_STAT:
			has_stat = true
			_expect(String(fb["text"]).find("攻") >= 0, "rider: feedback text is +攻 style")
			break
	_expect(has_stat, "rider: at least one stat feedback")

	battle.queue_free()
	await process_frame


func _test_basic_attack_does_not_float() -> void:
	var battle := _make_battle(42)
	await process_frame
	_expect(_seat_first_hand(battle), "atk: seat one unit")
	_expect(battle.try_start_combat(), "atk: start combat")
	var arena := battle.get_arena()
	## 清掉开战技能可能留下的反馈，再测纯普攻事件。
	arena.clear_fx()
	var before := arena.get_feedback_count()
	var target: UnitInstance = null
	for item in battle.get_sim().get_units():
		var rt := item as RtUnit
		if rt.is_player():
			target = rt.unit
			break
	_expect(target != null, "atk: have player unit")
	if target != null and battle._bus != null:
		var dmg := CombatEventPayload.new()
		dmg.source = target
		dmg.target = target
		dmg.amount = 7
		battle._bus.emit_event(CombatEvents.ON_DAMAGE_TAKEN, dmg)
		battle._bus.emit_event(CombatEvents.ON_ATTACK_HIT, dmg)
	await process_frame
	_expect(arena.get_feedback_count() == before, "atk: basic-attack events do not add float text")
	_expect(not battle.is_timestop_blocking(), "atk: basic-attack does not enter timestop queue")

	battle.queue_free()
	await process_frame


func _test_timestop_queue_blocks_sim() -> void:
	var battle := _make_battle(99)
	await process_frame
	_expect(_seat_first_hand(battle), "timestop: seat one unit")
	_expect(battle.try_start_combat(), "timestop: start combat")
	var sim := battle.get_sim()
	var arena := battle.get_arena()
	arena.clear_fx()
	## 清空开战可能入队的播报（锁阵阶段不入队；此处仅防残留）。
	battle._timestop_queue.clear()
	sim.release_presentation()
	var steps_before := sim.fixed_step_count
	var target: UnitInstance = null
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt.is_player():
			target = rt.unit
			break
	_expect(target != null, "timestop: player unit")
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.HEAL
	action.value = 5
	var payload := CombatEventPayload.new()
	payload.effect_owner = target
	payload.source = target
	payload.target = target
	payload.effect_action = action
	payload.effect_entries = [{"action": action, "target": target}]
	battle._bus.emit_event(CombatEvents.ON_EFFECT_RESOLVED, payload)
	_expect(battle.is_timestop_blocking(), "timestop: queue blocks after effect")
	_expect(arena.get_feedback_count() > 0, "timestop: feedback shown for active item")
	## 推进若干帧：时停中 fixed_step 不应增加。
	for _i in 3:
		await process_frame
	_expect(sim.fixed_step_count == steps_before, "timestop: sim steps frozen while queue active")
	## 加速耗尽队列（0.4s / scale）；time_scale=8 → 墙钟约 0.05s+
	battle.time_scale = 8.0
	var guard := 0
	while battle.is_timestop_blocking() and guard < 60:
		await process_frame
		guard += 1
	_expect(not battle.is_timestop_blocking(), "timestop: queue drains")
	_expect(not sim.presentation_hold, "timestop: presentation hold released")

	battle.queue_free()
	await process_frame
