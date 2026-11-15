extends SceneTree

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const HURT := preload("res://resources/abilities/hurt_gain_atk_small.tres")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_enchant_trait_flow()
	await _test_enchant_sandbox_skip_no_map_signal()
	await _test_enchant_sandbox_trait_hud()
	await _test_enchant_team_seat_swap()
	await _test_enchant_scroll_vs_drag_gesture()
	if _failures == 0:
		print("EnchantFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		push_error("EnchantFlowTest: FAIL %s" % label)


func _test_enchant_trait_flow() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 10
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	var u1 := UnitData.new()
	u1.id = "hero_a"
	u1.stats = UnitStats.new()
	u1.ability = HURT
	var e1 := deck.add_entry(u1)
	deck.assign_seat(e1.entry_id, 0)
	_expect(e1 != null, "member added")

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)

	var finished: Array = []
	battle.enchant_finished.connect(func(did: bool) -> void: finished.append(did))

	await battle.enter_enchant(0.0)
	_expect(battle.get_phase() == RealtimeBattleController.Phase.ENCHANT, "phase ENCHANT")

	var session := battle.get_enchant_session()
	_expect(session != null, "session exists")
	_expect(session.trait_offers.size() == EnchantTraitCatalog.OFFER_COUNT, "three offers")
	_expect(session.select_trait(0), "pick trait")
	_expect(session.select_entry(e1.entry_id), "pick member")
	_expect(session.try_confirm().get("ok", false), "confirm ok")
	_expect(e1.has_enchant_trait(), "trait on deck entry")

	session.finish_after_confirm()
	await _process_n_frames(2)
	_expect(finished == [true], "enchant_finished true")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "back idle")

	battle.queue_free()
	await process_frame


func _process_n_frames(n: int) -> void:
	for _i in n:
		await process_frame


func _test_enchant_sandbox_trait_hud() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 4
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	for id in ["ra", "rb"]:
		var u := UnitData.new()
		u.id = id
		u.stats = UnitStats.new()
		u.ability = HURT
		var e := deck.add_entry(u)
		deck.assign_seat(e.entry_id, 0 if id == "ra" else 1)

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)
	await battle.enter_enchant(0.0, true)
	_expect(battle.is_enchant_sandbox_mode(), "sandbox flag")

	var session := battle.get_enchant_session()
	_expect(session.trait_offers.size() >= 1, "offers in sandbox")

	var dock := battle.get_dock()
	var hud := dock.find_child("EnchantHud", true, false) as Control if dock != null else null
	_expect(hud != null and hud.visible, "enchant hud present")
	var confirm_btn: Button = null
	if hud != null:
		for child in hud.get_children():
			if child is HBoxContainer:
				for btn in child.get_children():
					if btn is Button and (btn as Button).text == "确认附魔":
						confirm_btn = btn as Button
						break
	_expect(confirm_btn != null, "confirm button")

	battle.queue_free()
	await process_frame


func _test_enchant_sandbox_skip_no_map_signal() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 4
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	var u := UnitData.new()
	u.id = "solo"
	u.stats = UnitStats.new()
	u.ability = HURT
	deck.add_entry(u)

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)

	var finished: Array = []
	battle.enchant_finished.connect(func(did: bool) -> void: finished.append(did))

	await battle.enter_enchant(0.0, true)
	_expect(battle.is_enchant_sandbox_mode(), "sandbox flag")
	var session := battle.get_enchant_session()
	session.skip()
	await _process_n_frames(2)
	_expect(finished.is_empty(), "sandbox skip does not emit enchant_finished")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "idle after skip")

	battle.queue_free()
	await process_frame


func _test_enchant_team_seat_swap() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 5
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	for i in 3:
		var u := UnitData.new()
		u.id = "swap_%d" % i
		u.stats = UnitStats.new()
		u.stats.attack = 2 + i
		u.stats.max_hp = 4
		u.ability = HURT
		var e := deck.add_entry(u)
		deck.assign_seat(e.entry_id, i)
	_expect(deck.size() == 3, "three members")

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)
	await battle.enter_enchant(0.0)

	var session := battle.get_enchant_session()
	_expect(session.is_active, "session active")
	var entries := deck.get_entries()
	var id0 := entries[0].entry_id
	var id2 := entries[2].entry_id
	_expect(deck.swap_seats(id0, 2), "swap via deck")

	battle.queue_free()
	await process_frame


func _test_enchant_scroll_vs_drag_gesture() -> void:
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	await process_frame

	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 20
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	for i in 12:
		var u := UnitData.new()
		u.id = "scroll_%d" % i
		u.stats = UnitStats.new()
		u.ability = HURT
		deck.add_entry(u)

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)
	await battle.enter_enchant(0.0, true)

	var arena := battle.get_arena()
	_expect(arena != null and arena.enchant_team_scroll_enabled, "scroll enabled expanded")

	battle.queue_free()
	await process_frame