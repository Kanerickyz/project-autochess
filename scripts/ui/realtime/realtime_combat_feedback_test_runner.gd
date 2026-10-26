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
	await _test_rider_enemy_death_feedback()
	await _test_basic_attack_does_not_float()
	await _test_timestop_queue_blocks_sim()
	await _test_tape_next_skips_stuck_timestop()
	await _test_awaiting_resolve_recovers_next_frame()
	await _test_tape_next_unsticks_ally_death_spawn_lifecycle()
	if _failures == 0:
		print("RealtimeCombatFeedbackTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("RealtimeCombatFeedbackTest: FAIL %s" % label)


func _seed_test_deck(deck: DeckState) -> void:
	## 开局空队后勿依赖 starter tres 自带单位。
	deck.reset_from_config()
	if deck.size() > 0:
		return
	for path in [
		"res://resources/units/realtime/knight.tres",
		"res://resources/units/realtime/archer.tres",
		"res://resources/units/realtime/barbarian.tres",
		"res://resources/units/realtime/rider.tres",
	]:
		var unit := load(path) as UnitData
		if unit != null:
			deck.add_entry(unit)


func _make_battle(seed: int) -> RealtimeBattleController:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	_seed_test_deck(deck)
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
	var slots := battle.get_slot_board()
	## 准备主路径可能已持久占位自动入座。
	if slots.occupied_count() > 0:
		return true
	var hand := battle.get_hand()
	if hand.is_empty():
		return false
	var err := battle.try_assign_to_slot(hand[0].entry_id, slots.get_cell(0))
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

	var gold_action := EffectAction.new()
	gold_action.action_type = EffectAction.Type.GRANT_GOLD
	gold_action.value = 2
	var gold_payload := CombatEventPayload.new()
	gold_payload.effect_owner = unit
	gold_payload.source = unit
	gold_payload.target = unit
	gold_payload.effect_action = gold_action
	gold_payload.effect_entries = [{"action": gold_action, "target": unit}]
	var gold_pops := RealtimeEffectFeedback.build_popups(gold_payload)
	_expect(gold_pops.size() == 1, "mapper: GRANT_GOLD yields popup")
	if gold_pops.size() >= 1:
		_expect(gold_pops[0]["kind"] == RealtimeEffectFeedback.KIND_GOLD, "mapper: kind=gold")
		_expect(int(gold_pops[0]["amount"]) == 2, "mapper: gold amount 2")
		_expect(String(gold_pops[0]["text"]).find("金") >= 0, "mapper: gold text has 金")

	var arena := RealtimeArenaView.new()
	arena.board_size = Vector2i(5, 8)
	arena.size = Vector2(393, 700)
	root.add_child(arena)
	arena.spawn_gold_coin_burst(Vector2(2.5, 10.5), 2)
	_expect(arena.get_gold_coin_fx_count() == 2, "arena: gold burst spawns 2 coins")
	var expected_coin := arena._typical_paper_height_px(arena.get_cell_px()) * RealtimeArenaView.GOLD_COIN_PAPER_SCALE
	var first_coin := arena._gold_coin_layer.get_child(0) as TextureRect if arena._gold_coin_layer != null else null
	_expect(first_coin != null, "arena: gold coin node is TextureRect")
	if first_coin != null:
		_expect(
			is_equal_approx(first_coin.size.x, expected_coin)
			and is_equal_approx(first_coin.size.y, expected_coin),
			"arena: gold coin size is 1/4 character paper height",
		)
		_expect(is_zero_approx(first_coin.rotation), "arena: gold coin starts without rotation")
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


func _test_rider_enemy_death_feedback() -> void:
	## 狼骑兵入座开战；击杀一名敌人后应飘 +攻（敌亡叠层）。
	var battle := _make_battle(777)
	await process_frame
	var seated := false
	for _attempt in 8:
		for entry in battle.get_hand():
			if entry == null or entry.unit == null or entry.unit.id != "rider":
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
		for entry in battle._deck_state.get_entries():
			if entry == null or entry.unit == null or entry.unit.id != "rider":
				continue
			var slots := battle.get_slot_board()
			var ok := slots.try_assign(0, entry)
			_expect(ok, "rider: slot assign via deck fixture")
			seated = ok
			battle._sync_slot_visuals()
			battle._refresh_hud()
			break
	_expect(seated, "rider: rider unit seated")
	if not seated:
		battle.queue_free()
		await process_frame
		return

	_expect(battle.try_start_combat(), "rider: start combat")
	await process_frame
	var arena := battle.get_arena()
	var sim := battle.get_sim()
	arena.clear_fx()
	battle._timestop_queue.clear()
	if sim.get_effect_resolver() != null:
		sim.get_effect_resolver().clear_pending()
	sim.release_presentation()
	var before := arena.get_feedback_count()
	var enemy_rt: RtUnit = null
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt != null and not rt.is_player() and rt.is_alive():
			enemy_rt = rt
			break
	_expect(enemy_rt != null, "rider: have enemy to kill")
	if enemy_rt != null:
		## defer 时停：入队后须播完介绍/结果拍才有 ON_EFFECT_RESOLVED 反馈。
		sim._pipeline.apply_damage(null, enemy_rt, 999)
	battle.time_scale = 8.0
	var guard := 0
	while (battle.is_timestop_blocking() or sim.has_pending_effects()) and guard < 120:
		await process_frame
		guard += 1
	_expect(arena.get_feedback_count() > before, "rider: enemy-death effect yields feedback")
	var has_stat := false
	for fb in arena.get_feedback_entries():
		if fb["kind"] == RealtimeEffectFeedback.KIND_STAT:
			has_stat = true
			_expect(String(fb["text"]).find("攻") >= 0 or String(fb["text"]).find("血") >= 0, "rider: feedback text is +攻/血 style")
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
	## 受伤钩子可能入队技能；本断言只关心普攻事件本身不产生飘字/结果拍。
	var atk_sim := battle.get_sim()
	if atk_sim != null and atk_sim.get_effect_resolver() != null:
		atk_sim.get_effect_resolver().clear_pending()
	battle._timestop_queue.clear()
	if atk_sim != null:
		atk_sim.release_presentation()
	await process_frame
	_expect(arena.get_feedback_count() == before, "atk: basic-attack events do not add float text")
	_expect(not battle.is_timestop_blocking(), "atk: basic-attack does not enter timestop queue")

	battle.queue_free()
	await process_frame


func _test_timestop_queue_blocks_sim() -> void:
	## 先卡再结算：待结算批次入队后先阻塞并展示，卡拍结束才写入真值。
	var battle := _make_battle(99)
	await process_frame
	_expect(_seat_first_hand(battle), "timestop: seat one unit")
	_expect(battle.try_start_combat(), "timestop: start combat")
	var sim := battle.get_sim()
	var arena := battle.get_arena()
	arena.clear_fx()
	battle._timestop_queue.clear()
	var resolver := sim.get_effect_resolver()
	if resolver != null:
		resolver.clear_pending()
	sim.release_presentation()
	var steps_before := sim.fixed_step_count
	var target: UnitInstance = null
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt.is_player():
			target = rt.unit
			break
	_expect(target != null, "timestop: player unit")
	if target == null:
		battle.queue_free()
		await process_frame
		return

	## 故意压血，便于断言治疗在卡拍之后才结算。
	target.current_hp = maxi(1, target.get_effective_max_hp() - 10)
	var hp_before := target.current_hp
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.HEAL
	action.value = 5
	var step := QueuedEffectStep.new()
	step.action = action
	step.target = target
	step.owner = target
	var batch := QueuedEffectBatch.new()
	batch.owner = target
	batch.payload = CombatEventPayload.new()
	batch.entries.append(step)
	_expect(resolver != null, "timestop: effect resolver")
	resolver._pending_batches.append(batch)
	_expect(sim.has_pending_effects(), "timestop: pending before card")

	await process_frame
	_expect(battle.is_timestop_blocking(), "timestop: card phase blocks after pending")
	_expect(sim.has_pending_effects(), "timestop: not resolved during card")
	_expect(target.current_hp == hp_before, "timestop: hp unchanged during card")
	for _i in 3:
		await process_frame
	_expect(sim.fixed_step_count == steps_before, "timestop: sim steps frozen while queue active")

	## 加速耗尽卡拍+结果拍（约 1.0+0.4 / scale）
	battle.time_scale = 8.0
	var guard := 0
	while (battle.is_timestop_blocking() or sim.has_pending_effects()) and guard < 120:
		await process_frame
		guard += 1
	_expect(not battle.is_timestop_blocking(), "timestop: queue drains")
	_expect(not sim.has_pending_effects(), "timestop: effects resolved after card")
	var timestop_heal_cap := mini(hp_before + 5, target.get_effective_max_hp())
	_expect(target.current_hp == timestop_heal_cap, "timestop: heal applied after card")
	_expect(arena.get_feedback_count() > 0, "timestop: result feedback after resolve")
	_expect(not sim.presentation_hold, "timestop: presentation hold released")

	battle.queue_free()
	await process_frame


func _test_tape_next_skips_stuck_timestop() -> void:
	## 「下一动」须能跳过技能介绍拍；否则时停阻塞时 _tape_step_once 永远无法步进（战斗假死）。
	var battle := _make_battle(101)
	await process_frame
	_expect(_seat_first_hand(battle), "tape-skip: seat one unit")
	_expect(battle.try_start_combat(), "tape-skip: start combat")
	var sim := battle.get_sim()
	battle._timestop_queue.clear()
	var resolver := sim.get_effect_resolver()
	if resolver != null:
		resolver.clear_pending()
	sim.release_presentation()

	var target: UnitInstance = null
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt.is_player():
			target = rt.unit
			break
	_expect(target != null, "tape-skip: player unit")
	if target == null:
		battle.queue_free()
		await process_frame
		return

	target.current_hp = maxi(1, target.get_effective_max_hp() - 10)
	var hp_before := target.current_hp
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.HEAL
	action.value = 3
	var step := QueuedEffectStep.new()
	step.action = action
	step.target = target
	step.owner = target
	var batch := QueuedEffectBatch.new()
	batch.owner = target
	batch.payload = CombatEventPayload.new()
	batch.entries.append(step)
	resolver._pending_batches.append(batch)

	await process_frame
	_expect(battle.is_timestop_blocking(), "tape-skip: card blocks")
	_expect(sim.has_pending_effects(), "tape-skip: still pending during card")
	_expect(target.current_hp == hp_before, "tape-skip: not healed during card")

	## 同步强制收拍；随后关掉 step_once，避免本帧把整场打完干扰血量断言。
	battle._on_tape_next_pressed()
	_expect(not sim.has_pending_effects(), "tape-skip: next resolves pending")
	var heal_cap := mini(hp_before + 3, target.get_effective_max_hp())
	_expect(target.current_hp == heal_cap, "tape-skip: heal applied after next")
	battle._tape_step_once = false
	battle._tape_paused = true
	await process_frame
	_expect(not battle.is_timestop_blocking(), "tape-skip: timestop cleared after next")
	_expect(not sim.presentation_hold, "tape-skip: hold released")

	battle.queue_free()
	await process_frame


func _test_awaiting_resolve_recovers_next_frame() -> void:
	## 若卡拍结束停在 AWAITING_RESOLVE 未 begin_result，下一帧须强制结算，不能永久挡模拟。
	var battle := _make_battle(102)
	await process_frame
	_expect(_seat_first_hand(battle), "await-recover: seat")
	_expect(battle.try_start_combat(), "await-recover: start")
	var sim := battle.get_sim()
	battle._timestop_queue.clear()
	var resolver := sim.get_effect_resolver()
	if resolver != null:
		resolver.clear_pending()
	sim.release_presentation()

	var target: UnitInstance = null
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt.is_player():
			target = rt.unit
			break
	_expect(target != null, "await-recover: player")
	if target == null:
		battle.queue_free()
		await process_frame
		return

	target.current_hp = maxi(1, target.get_effective_max_hp() - 8)
	var hp_before := target.current_hp
	var action := EffectAction.new()
	action.action_type = EffectAction.Type.HEAL
	action.value = 2
	var step := QueuedEffectStep.new()
	step.action = action
	step.target = target
	step.owner = target
	var batch := QueuedEffectBatch.new()
	batch.owner = target
	batch.payload = CombatEventPayload.new()
	batch.entries.append(step)
	resolver._pending_batches.append(batch)
	## 直接进入 AWAITING_RESOLVE（模拟 card_done 回调中断）。
	battle._timestop_queue.begin_card(target, null, 1.0)
	battle._timestop_queue._phase = RealtimeTimestopQueue.Phase.AWAITING_RESOLVE
	battle._timestop_queue._remaining = 0.0
	sim.hold_for_presentation()

	await process_frame
	_expect(not sim.has_pending_effects(), "await-recover: pending resolved")
	_expect(target.current_hp == hp_before + 2, "await-recover: heal applied")
	_expect(
		battle._timestop_queue.get_phase() != RealtimeTimestopQueue.Phase.AWAITING_RESOLVE,
		"await-recover: left AWAITING_RESOLVE"
	)

	var guard := 0
	while battle.is_timestop_blocking() and guard < 60:
		await process_frame
		guard += 1
	_expect(not battle.is_timestop_blocking(), "await-recover: queue drains")
	_expect(not sim.presentation_hold, "await-recover: hold released")

	battle.queue_free()
	await process_frame


func _test_tape_next_unsticks_ally_death_spawn_lifecycle() -> void:
	## 生命周期：友亡入队「义士应召」→ 粘在 AWAITING → 点下一动须拆门闩并让模拟继续走步。
	var battle := _make_battle(103)
	await process_frame
	_expect(_seat_first_hand(battle), "lifecycle: seat")
	_expect(battle.try_start_combat(), "lifecycle: start")
	var sim := battle.get_sim()
	battle._timestop_queue.clear()
	var resolver := sim.get_effect_resolver()
	if resolver != null:
		resolver.clear_pending()
	sim.release_presentation()

	var soul_data := load("res://resources/units/realtime/soulcaller.tres") as UnitData
	_expect(soul_data != null and soul_data.ability != null, "lifecycle: soulcaller data")
	if soul_data == null:
		battle.queue_free()
		await process_frame
		return
	var caller := UnitInstance.from_unit_data(soul_data, Vector2i(2, 6), UnitInstance.Team.PLAYER)
	sim.add_unit(caller, Vector2(2.5, 6.5))
	var fodder := UnitInstance.from_unit_data(
		load("res://resources/units/realtime/knight.tres") as UnitData,
		Vector2i(1, 6),
		UnitInstance.Team.PLAYER,
	)
	var fodder_rt := sim.add_unit(fodder, Vector2(1.5, 6.5))
	_expect(fodder_rt != null, "lifecycle: fodder on field")

	## 击杀友方角色 → OnFriendDeath 入队义士应召（defer 不立刻结算）。
	sim._pipeline.apply_damage(null, fodder_rt, 999)
	_expect(sim.has_pending_effects() or battle.is_timestop_blocking(), "lifecycle: death queued or presenting")

	## 等到介绍卡，再人工粘住 AWAITING（复现 card_done 中断）。
	battle.time_scale = 8.0
	var wait_card := 0
	while not battle.is_timestop_blocking() and wait_card < 30:
		await process_frame
		wait_card += 1
	if battle.is_timestop_blocking():
		battle._timestop_queue._phase = RealtimeTimestopQueue.Phase.AWAITING_RESOLVE
		battle._timestop_queue._remaining = 0.0
		sim.hold_for_presentation()

	var steps_before := sim.fixed_step_count
	## 点「下一动」：须拆掉时停/待结算，并在随后帧推进固定步。
	battle._on_tape_next_pressed()
	_expect(not battle.is_timestop_blocking(), "lifecycle: next clears timestop")
	_expect(not sim.has_pending_effects(), "lifecycle: next drains pending")
	_expect(not sim.presentation_hold, "lifecycle: next releases hold")

	var advanced := false
	var guard := 0
	while guard < 90 and not sim.is_finished():
		await process_frame
		if sim.fixed_step_count > steps_before:
			advanced = true
			break
		guard += 1
	_expect(advanced or sim.is_finished(), "lifecycle: sim advances after next")

	battle.queue_free()
	await process_frame
