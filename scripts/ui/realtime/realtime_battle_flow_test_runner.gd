extends SceneTree
## Headless：持久占位准备 / 换座 / 开战观战 / 结算（对齐 Features/PLAYER.md 无手牌主路径）。

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


func _seed_test_deck(deck: DeckState) -> void:
	## 开局空队后 starter tres 可能为空；战斗规则测试自行注入牌库。
	deck.reset_from_config()
	if deck.size() > 0:
		return
	var paths := [
		"res://resources/units/realtime/knight.tres",
		"res://resources/units/realtime/archer.tres",
		"res://resources/units/realtime/barbarian.tres",
		"res://resources/units/realtime/goblin.tres",
		"res://resources/units/realtime/musketeer.tres",
		"res://resources/units/realtime/valkyrie.tres",
	]
	for path in paths:
		var unit := load(path) as UnitData
		if unit != null:
			deck.add_entry(unit)


func _test_battle_controller_rules() -> void:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	_seed_test_deck(deck)
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	var level := load(LEVEL_PATH) as LevelData
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 4242
	## Headless：跳过胜后半场退出演出，直接验证 continue 语义。
	battle.half_exit_seconds = 0.0
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, level)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)

	_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "controller: start_encounter enters PREPARE")
	_expect(battle.get_board_size() == Vector2i(5, 8), "controller: board is 5x8")
	_expect(battle.get_command_current() == 0.0, "controller: command resource disabled")
	## 本版准备无手牌抽选：清牌区后按 DeckState 持久占位入座。
	_expect(battle.get_hand().is_empty(), "controller: prepare hand empty (no encounter draw)")
	var slots := battle.get_slot_board()
	_expect(slots.seat_rows == 4 and slots.seat_cols == 5, "controller: ally seats 4x5")
	_expect(slots.slot_count == 20, "controller: ally seat total 20")
	var enemy_slots := battle.get_enemy_slot_board()
	_expect(enemy_slots.seat_rows == 4 and enemy_slots.seat_cols == 5, "controller: enemy seats 4x5")
	_expect(enemy_slots.is_enemy_side, "controller: enemy seat board flagged")
	var deploy_cap := battle.get_deploy_cap()
	_expect(deploy_cap == mini(deck.get_max_size(), deck.get_slot_count()), "controller: deploy_cap from max_size ∩ seats")
	_expect(deploy_cap == battle.get_max_board_units(), "controller: get_max_board_units == deploy_cap")
	_expect(deploy_cap < slots.slot_count, "controller: deploy_cap < seat total (empty seats normal)")
	_expect(slots.occupied_count() >= 1, "controller: persistent seats auto-filled from deck")
	_expect(slots.occupied_count() <= deploy_cap, "controller: occupied within deploy_cap")
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

	## 前排更近中线、后排更靠己方底（4×5 铺满：末行索引 15）
	var mid := BoardHalf.midline_row(battle.get_board_size().y)
	_expect(slots.get_cell(0).y < slots.get_cell(15).y, "controller: ally front row nearer mid than back")
	_expect(slots.get_cell(0).y >= mid, "controller: ally seats on player half")
	_expect(enemy_slots.get_cell(0).y > enemy_slots.get_cell(15).y, "controller: enemy front row nearer mid than back")
	_expect(enemy_slots.get_cell(0).y < mid, "controller: enemy seats on enemy half")
	## 5×8 / 4×5 / 无间距：列 x=0..4；我半场 y=4..7；敌半场 y=3..0（前排近中线）。
	_expect(slots.get_cell(0) == Vector2i(0, 4), "controller: ally front-left fills half")
	_expect(slots.get_cell(1) == Vector2i(1, 4), "controller: ally adjacent columns")
	_expect(slots.get_cell(5) == Vector2i(0, 5), "controller: ally next row no gap")
	_expect(enemy_slots.get_cell(0) == Vector2i(0, 3), "controller: enemy front-left near mid")
	_expect(enemy_slots.get_cell(15) == Vector2i(0, 0), "controller: enemy back-left at top")

	## 清空全部座位后不可开战；再入一座可开战（绕过手牌宽度，直接清槽）。
	var first_cleared: DeckEntry = null
	for i in range(slots.slot_count - 1, -1, -1):
		var e := slots.try_recall(i)
		if e == null:
			continue
		deck.clear_seat(e.entry_id)
		if first_cleared == null:
			first_cleared = e
	_expect(slots.occupied_count() == 0, "controller: all seats cleared")
	_expect(not battle.try_start_combat(), "controller: cannot start with empty seats")
	_expect(first_cleared != null, "controller: had seated units before clear")
	if first_cleared != null:
		_expect(battle._card_flow.try_return_to_hand(first_cleared), "controller: park one unit in hand")
		var slot0 := slots.get_cell(0)
		_expect(battle.try_assign_to_slot(first_cleared.entry_id, slot0).is_empty(), "controller: re-seat from hand")
		_expect(slots.get_entry(0) != null and slots.get_entry(0).entry_id == first_cleared.entry_id, "controller: seat occupied after re-seat")
		_expect(slots.get_seat_assign_seq(0) > 0, "controller: seat assign seq recorded")

	## 准备刷新手牌已取消
	_expect(not battle.try_refresh_hand(), "controller: refresh disabled in prepare")

	# 开战
	_expect(battle.try_start_combat(), "controller: start combat with >=1 seated")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.COMBAT, "controller: phase COMBAT after start")
	var sim := battle.get_sim()
	_expect(sim != null and sim.has_started(), "controller: sim started on combat start")
	_expect(sim.count_alive(UnitInstance.Team.ENEMY) > 0, "controller: enemies spawned on combat start")
	_expect(sim.count_alive(UnitInstance.Team.PLAYER) >= 1, "controller: allies spawned from seats")
	_expect(battle.get_hand().is_empty(), "controller: unseated hand returned / cleared on combat")
	## 敌方生成序：座位索引升序（配置书写序 → 顺序占座，无 shuffle）
	var enemy_seats: Array[int] = []
	for spawn in battle._enemy_spawns:
		enemy_seats.append(int(spawn.get("seat_index", -1)))
	var seats_sorted := enemy_seats.duplicate()
	seats_sorted.sort()
	_expect(enemy_seats == seats_sorted, "controller: enemy spawn seats follow index order (no shuffle)")
	_expect(not battle.try_deploy(0, Vector2i(3, battle.get_board_size().y - 3)).is_empty(), "controller: deploy rejected in COMBAT")
	_expect(not battle.try_refresh_hand(), "controller: refresh rejected in COMBAT")
	_expect(not battle.try_assign_to_slot(0, slots.get_cell(0)).is_empty(), "controller: assign rejected in COMBAT")

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

	# 再次进入：持久占位仍自动入座；刷新仍禁用
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "controller: second encounter PREPARE")
	_expect(battle.get_slot_board().occupied_count() >= 1, "controller: second prepare auto-seated")
	_expect(not battle.try_refresh_hand(), "controller: refresh still disabled")

	## 上场人数上限：持久入座不超过 deploy_cap；空座仍多
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 1)
	var slots_cap := battle.get_slot_board()
	var cap := battle.get_deploy_cap()
	_expect(slots_cap.occupied_count() <= cap, "controller: occupied <= deploy_cap after load")
	_expect(not slots_cap.is_full(), "controller: seats not full when at/under deploy_cap")
	_expect(slots_cap.can_assign_more(cap) == (slots_cap.occupied_count() < cap), "controller: can_assign_more matches occupancy")

	## 换座
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	var slots_ord := battle.get_slot_board()
	while slots_ord.occupied_count() < 2 and not battle.get_hand().is_empty():
		var hand_e := battle.get_hand()[0]
		var empty_i := -1
		for i in slots_ord.slot_count:
			if slots_ord.is_empty(i):
				empty_i = i
				break
		if empty_i < 0:
			break
		battle.try_assign_to_slot(hand_e.entry_id, slots_ord.get_cell(empty_i))
	_expect(slots_ord.occupied_count() >= 2, "seat-order: need >=2 seated")
	if slots_ord.occupied_count() >= 2:
		var occ := slots_ord.get_occupied_indices_by_seat_order()
		var from_i: int = occ[0]
		var to_i: int = occ[1]
		var id_a := slots_ord.get_entry(from_i).entry_id
		var id_b := slots_ord.get_entry(to_i).entry_id
		_expect(battle.try_swap_prepare_seats(from_i, to_i), "seat-order: swap A and B")
		_expect(slots_ord.get_entry(to_i) != null and slots_ord.get_entry(to_i).entry_id == id_a, "seat-order: A moved to B seat")
		_expect(slots_ord.get_entry(from_i) != null and slots_ord.get_entry(from_i).entry_id == id_b, "seat-order: B moved to A seat")
		_expect(battle.try_start_combat(), "seat-order: start combat")
		var sim_ord := battle.get_sim()
		_expect(sim_ord != null and sim_ord.has_started(), "seat-order: sim started")
		_expect(battle.get_hand().is_empty(), "seat-order: hand cleared after lock spawn")

	battle.queue_free()
	await process_frame
