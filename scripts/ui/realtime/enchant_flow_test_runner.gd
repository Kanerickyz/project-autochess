extends SceneTree

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const HURT := preload("res://resources/abilities/hurt_gain_atk_small.tres")
const CRIT := preload("res://resources/abilities/crit_extra_damage_mid.tres")

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_enchant_fuse_flow()
	if _failures == 0:
		print("EnchantFlowTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		push_error("EnchantFlowTest: FAIL %s" % label)


func _test_enchant_fuse_flow() -> void:
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
	u1.id = "mat_a"
	u1.display_name = "原料A"
	u1.stats = UnitStats.new()
	u1.stats.attack = 4
	u1.stats.max_hp = 6
	u1.ability = HURT
	var u2 := UnitData.new()
	u2.id = "mat_b"
	u2.display_name = "原料B"
	u2.stats = UnitStats.new()
	u2.stats.attack = 8
	u2.stats.max_hp = 4
	u2.ability = CRIT
	var e1 := deck.add_entry(u1)
	var e2 := deck.add_entry(u2)
	_expect(e1 != null and e2 != null, "materials added")

	var economy := RunEconomy.new()
	var level := load("res://resources/levels/board_act1.tres") as LevelData
	battle.setup(deck, economy, level)

	var finished: Array = []
	battle.enchant_finished.connect(func(did: bool) -> void: finished.append(did))

	await battle.enter_enchant(0.0)
	_expect(battle.get_phase() == RealtimeBattleController.Phase.ENCHANT, "phase ENCHANT")

	var session := battle.get_enchant_session()
	_expect(session != null, "session exists")
	session.set_slot(&"a", e1.entry_id)
	session.set_slot(&"b", e2.entry_id)
	var fuse := session.try_fuse()
	_expect(fuse.get("ok", false), "fuse ok")
	_expect(deck.size() == 1, "one member")
	_expect(deck.get_entries()[0].is_fused_enchant(), "fused product")

	session.finish_after_fuse()
	await _process_n_frames(2)
	_expect(finished == [true], "enchant_finished true")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "back idle")

	battle.queue_free()
	await process_frame


func _process_n_frames(n: int) -> void:
	for _i in n:
		await process_frame
