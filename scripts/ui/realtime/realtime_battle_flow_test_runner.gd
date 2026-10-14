extends SceneTree
## Headless：准备入槽 / 刷新 / 开战观战 / 结算（对齐 Features/PLAYER.md）。

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
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 4242
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, load(LEVEL_PATH) as LevelData)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)

	_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "controller: start_encounter enters PREPARE")
	_expect(battle.get_board_size() == Vector2i(18, 32), "controller: board is 18x32")
	_expect(battle.get_command_current() == 0.0, "controller: command resource disabled")
	var hand := battle.get_hand()
	_expect(hand.size() == deck.get_hand_width(), "controller: hand size equals hand_width")
	_expect(deck.get_hand_width() > battle.get_slot_board().slot_count, "controller: hand_width > slot_count")
	_expect(battle.get_sim() == null, "controller: sim not started in PREPARE")
	_expect(not battle.get_pending_enemy_positions().is_empty(), "controller: enemy previews available in prepare")
	_expect(not battle.try_start_combat(), "controller: cannot start with empty slots")

	var slots := battle.get_slot_board()
	var first_id := hand[0].entry_id
	var slot0 := slots.get_cell(0)
	_expect(battle.try_assign_to_slot(first_id, slot0).is_empty(), "controller: assign hand to empty slot")
	_expect(slots.get_entry(0) != null and slots.get_entry(0).entry_id == first_id, "controller: slot occupied")
	_expect(not battle._card_flow.is_in_hand(first_id), "controller: slotted card left hand")
	_expect(battle.get_hand().size() == hand.size() - 1, "controller: no auto-draw on slot assign")

	_expect(battle.try_recall_slot(0), "controller: recall from slot to hand")
	_expect(slots.is_empty(0), "controller: slot empty after recall")
	_expect(battle._card_flow.is_in_hand(first_id), "controller: recalled card back in hand")

	# 刷新：入槽保留，未入槽重抽
	hand = battle.get_hand()
	var keep_id := hand[0].entry_id
	_expect(battle.try_assign_to_slot(keep_id, slot0).is_empty(), "controller: re-assign for refresh test")
	var before_refresh_ids: Array[int] = []
	for entry in battle.get_hand():
		before_refresh_ids.append(entry.entry_id)
	_expect(battle.get_refresh_remaining() == 3, "controller: refresh starts at 3")
	_expect(battle.try_refresh_hand(), "controller: refresh succeeds")
	_expect(battle.get_refresh_remaining() == 2, "controller: refresh decremented")
	_expect(slots.get_entry(0) != null and slots.get_entry(0).entry_id == keep_id, "controller: slotted card kept after refresh")
	_expect(not battle._card_flow.is_in_hand(keep_id), "controller: slotted card not returned to hand by refresh")
	## 入槽牌不在牌流中；刷新后手牌仍抽满到 hand_width。
	_expect(battle.get_hand().size() == deck.get_hand_width(), "controller: hand refilled to width after refresh")

	# 开战
	_expect(battle.try_start_combat(), "controller: start combat with >=1 slotted")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.COMBAT, "controller: phase COMBAT after start")
	var sim := battle.get_sim()
	_expect(sim != null and sim.has_started(), "controller: sim started on combat start")
	_expect(sim.count_alive(UnitInstance.Team.ENEMY) > 0, "controller: enemies spawned on combat start")
	_expect(sim.count_alive(UnitInstance.Team.PLAYER) >= 1, "controller: allies spawned from slots")
	_expect(battle.get_hand().is_empty(), "controller: unslotted hand returned / cleared on combat")
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

	# 刷新上限 + 手牌全入槽后不可刷新
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	_expect(battle.get_phase() == RealtimeBattleController.Phase.PREPARE, "controller: second encounter PREPARE")
	for i in 3:
		_expect(battle.try_refresh_hand(), "controller: refresh %d ok" % (i + 1))
	_expect(not battle.try_refresh_hand(), "controller: refresh blocked at limit")

	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 1)
	var hand3 := battle.get_hand()
	var slots3 := battle.get_slot_board()
	# 把当前手牌尽量入槽；再用刷新把剩余手牌刷光不现实，改为：只留入槽、清空手牌测 can_refresh
	for i in mini(hand3.size(), slots3.slot_count):
		battle.try_assign_to_slot(hand3[i].entry_id, slots3.get_cell(i))
	# 手牌仍可能有剩余（width>slots）；强制清空手牌到抽牌堆再断言
	battle._card_flow.return_hand_to_draw(battle._encounter_rng)
	battle._rebuild_cards()
	_expect(battle.get_hand().is_empty(), "controller: hand empty for refresh-empty check")
	_expect(not battle.try_refresh_hand(), "controller: refresh blocked when hand empty")

	battle.queue_free()
	await process_frame
