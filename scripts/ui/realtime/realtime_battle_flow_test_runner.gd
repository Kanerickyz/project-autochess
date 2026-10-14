extends SceneTree
## Headless：准备入座 / 刷新 / 开战观战 / 结算（对齐 Features/PLAYER.md）。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_battle_controller_rules()
	if _failures == 0:
		print("RealtimeBattleFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("RealtimeBattleFlowTest: FAIL %s" % label)


func _test_battle_controller_rules() -> void:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	deck.reset_from_config()
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	var level := load(LEVEL_PATH) as LevelData
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 4242
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, level)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)

	_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "controller: start_encounter enters PREPARE")
	_expect(battle.get_board_size() == Vector2i(9, 16), "controller: board is 9x16")
	_expect(battle.get_command_current() == 0.0, "controller: command resource disabled")
	var hand := battle.get_hand()
	_expect(hand.size() == deck.get_hand_width(), "controller: hand size equals hand_width")
	_expect(deck.get_hand_width() == EncounterCardFlow.DEFAULT_HAND_WIDTH or deck.get_hand_width() == 4, "controller: hand_width default 4")
	var slots := battle.get_slot_board()
	_expect(slots.seat_rows == 2 and slots.seat_cols == 5, "controller: ally seats 2x5")
	_expect(slots.slot_count == 10, "controller: ally seat total 10")
	var enemy_slots := battle.get_enemy_slot_board()
	_expect(enemy_slots.seat_rows == 2 and enemy_slots.seat_cols == 5, "controller: enemy seats 2x5")
	_expect(enemy_slots.is_enemy_side, "controller: enemy seat board flagged")
	var deploy_cap := battle.get_deploy_cap()
	_expect(deploy_cap == deck.get_deploy_cap(), "controller: deploy_cap from deck")
	_expect(deploy_cap == battle.get_max_board_units(), "controller: get_max_board_units == deploy_cap")
	_expect(deploy_cap < slots.slot_count, "controller: deploy_cap < seat total (empty seats normal)")
	_expect(battle.get_sim() == null, "controller: sim not started in PREPARE")
	_expect(not battle.get_pending_enemy_positions().is_empty(), "controller: enemy previews available in prepare")
	## 敌人落在敌方座位格心上
	var enemy_cell_set: Dictionary = {}
	for i in enemy_slots.slot_count:
		enemy_cell_set[enemy_slots.get_cell(i)] = true
	var enemies_on_seats := true
	for pos in battle.get_pending_enemy_positions():
		var cell := Vector2i(floori(pos.x), floori(pos.y))
		if not enemy_cell_set.has(cell):
			enemies_on_seats = false
			break
	_expect(enemies_on_seats, "controller: enemy spawns land on enemy seats")
	_expect(not battle.try_start_combat(), "controller: cannot start with empty seats")

	## 前排更近中线、后排更靠己方底
	var mid := BoardHalf.midline_row(battle.get_board_size().y)
	_expect(slots.get_cell(0).y < slots.get_cell(5).y, "controller: ally front row nearer mid than back")
	_expect(slots.get_cell(0).y >= mid, "controller: ally seats on player half")
	_expect(enemy_slots.get_cell(0).y > enemy_slots.get_cell(5).y, "controller: enemy front row nearer mid than back")
	_expect(enemy_slots.get_cell(0).y < mid, "controller: enemy seats on enemy half")

	var first_id := hand[0].entry_id
	var slot0 := slots.get_cell(0)
	_expect(battle.try_assign_to_slot(first_id, slot0).is_empty(), "controller: assign hand to empty seat")
	_expect(slots.get_entry(0) != null and slots.get_entry(0).entry_id == first_id, "controller: seat occupied")
	_expect(not battle._card_flow.is_in_hand(first_id), "controller: seated card left hand")
	_expect(battle.get_hand().size() == hand.size() - 1, "controller: no auto-draw on seat assign")

	_expect(battle.try_recall_slot(0), "controller: recall from seat to hand")
	_expect(slots.is_empty(0), "controller: seat empty after recall")
	_expect(battle._card_flow.is_in_hand(first_id), "controller: recalled card back in hand")

	# 刷新：入座保留，未入座重抽
	hand = battle.get_hand()
	var keep_id := hand[0].entry_id
	_expect(battle.try_assign_to_slot(keep_id, slot0).is_empty(), "controller: re-assign for refresh test")
	_expect(battle.get_refresh_remaining() == 3, "controller: refresh starts at 3")
	_expect(battle.try_refresh_hand(), "controller: refresh succeeds")
	_expect(battle.get_refresh_remaining() == 2, "controller: refresh decremented")
	_expect(slots.get_entry(0) != null and slots.get_entry(0).entry_id == keep_id, "controller: seated card kept after refresh")
	_expect(not battle._card_flow.is_in_hand(keep_id), "controller: seated card not returned to hand by refresh")
	## 入座牌不在牌流中；刷新后手牌仍抽满到 hand_width。
	_expect(battle.get_hand().size() == deck.get_hand_width(), "controller: hand refilled to width after refresh")

	# 开战
	_expect(battle.try_start_combat(), "controller: start combat with >=1 seated")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.COMBAT, "controller: phase COMBAT after start")
	var sim := battle.get_sim()
	_expect(sim != null and sim.has_started(), "controller: sim started on combat start")
	_expect(sim.count_alive(UnitInstance.Team.ENEMY) > 0, "controller: enemies spawned on combat start")
	_expect(sim.count_alive(UnitInstance.Team.PLAYER) >= 1, "controller: allies spawned from seats")
	_expect(battle.get_hand().is_empty(), "controller: unseated hand returned / cleared on combat")
	_expect(not battle.try_deploy(keep_id, Vector2i(3, battle.get_board_size().y - 3)).is_empty(), "controller: deploy rejected in COMBAT")
	_expect(not battle.try_refresh_hand(), "controller: refresh rejected in COMBAT")
	_expect(not battle.try_assign_to_slot(keep_id, slot0).is_empty(), "controller: assign rejected in COMBAT")

	var gold_before := economy.gold
	for rt in sim.get_units():
		if not rt.is_player():
			rt.unit.current_hp = 0
	sim.advance_fixed_step()
	_expect(battle.get_phase() == RealtimeBattleController.Phase.RESULT, "controller: RESULT after enemies wiped")
	_expect(sim.did_player_win(), "controller: player won")
	_expect(economy.gold > gold_before, "controller: wave gold granted on win")

	var completed: Array = []
	battle.encounter_completed.connect(func(won: bool) -> void: completed.append(won))
	battle.continue_after_result()
	_expect(completed == [true], "controller: encounter_completed(true) emitted on continue")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "controller: IDLE after continue")
	_expect(battle.get_sim() == null, "controller: sim released after continue")
	await process_frame
	_expect(battle.find_child("RealtimeCombatEventBus", false, false) == null, "controller: bus freed after continue")

	# 刷新上限 + 手牌全入座后不可刷新
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "controller: second encounter PREPARE")
	for i in 3:
		_expect(battle.try_refresh_hand(), "controller: refresh %d ok" % (i + 1))
	_expect(not battle.try_refresh_hand(), "controller: refresh blocked at limit")

	# 上场人数上限：占满 deploy_cap 后不能再入座（空座仍在）
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 1)
	var slots_cap := battle.get_slot_board()
	var cap := battle.get_deploy_cap()
	## 先入座 cap-1，刷新补手牌，再入第 cap 人，保证仍有手牌可测硬顶。
	var assigned := 0
	var hand_cap := battle.get_hand()
	for i in mini(hand_cap.size(), maxi(0, cap - 1)):
		if battle.try_assign_to_slot(hand_cap[i].entry_id, slots_cap.get_cell(i)).is_empty():
			assigned += 1
	_expect(assigned == maxi(0, cap - 1), "controller: seated to cap-1")
	_expect(battle.try_refresh_hand(), "controller: refresh while under cap for overflow hand")
	hand_cap = battle.get_hand()
	_expect(not hand_cap.is_empty(), "controller: hand after mid refresh")
	_expect(battle.try_assign_to_slot(hand_cap[0].entry_id, slots_cap.get_cell(assigned)).is_empty(), "controller: seat final unit to deploy_cap")
	assigned += 1
	_expect(assigned == cap, "controller: filled to deploy_cap")
	_expect(slots_cap.occupied_count() == cap, "controller: occupied equals deploy_cap")
	_expect(not slots_cap.is_full(), "controller: seats not full when at deploy_cap")
	_expect(not slots_cap.can_assign_more(cap), "controller: can_assign_more false at cap")
	_expect(not battle.get_hand().is_empty(), "controller: hand has overflow candidate")
	var overflow_id := battle.get_hand()[0].entry_id
	var overflow_cell := slots_cap.get_cell(cap) ## 下一空座
	var overflow_msg := battle.try_assign_to_slot(overflow_id, overflow_cell)
	_expect(not overflow_msg.is_empty(), "controller: assign blocked at deploy_cap")
	_expect(overflow_msg.find("上限") >= 0, "controller: deploy_cap block message")
	_expect(slots_cap.occupied_count() == cap, "controller: occupied unchanged after blocked assign")

	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 2)
	var hand3 := battle.get_hand()
	var slots3 := battle.get_slot_board()
	var cap3 := battle.get_deploy_cap()
	for i in mini(hand3.size(), cap3):
		battle.try_assign_to_slot(hand3[i].entry_id, slots3.get_cell(i))
	# 手牌仍可能有剩余；强制清空手牌到抽牌堆再断言
	battle._card_flow.return_hand_to_draw(battle._encounter_rng)
	battle._rebuild_cards()
	_expect(battle.get_hand().is_empty(), "controller: hand empty for refresh-empty check")
	_expect(not battle.try_refresh_hand(), "controller: refresh blocked when hand empty")

	battle.queue_free()
	await process_frame
