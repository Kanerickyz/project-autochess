extends SceneTree

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATH := "res://resources/encounters/realtime/rt_combat_01.tres"
## 仅测开战自 Buff；咒刃/盾祷改为周围其他友方，由 realtime_ability_effect_test 覆盖。
const UNITS := [
	["iron_heart", "res://resources/units/realtime/iron_heart.tres", 12, "max_hp"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for row in UNITS:
		if not await _test_unit(String(row[0]), String(row[1]), int(row[2]), String(row[3])):
			quit(1)
	print("combat_start_controller_test: OK")
	quit(0)


func _test_unit(unit_id: String, path: String, delta: int, stat: String) -> bool:
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	deck.reset_from_config()
	var data := load(path) as UnitData
	var entry := deck.add_entry(data)
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.rng_seed = 9001
	root.add_child(battle)
	await process_frame
	battle.setup(deck, economy, load(LEVEL_PATH) as LevelData)
	battle.start_encounter(load(ENCOUNTER_PATH) as EncounterData, 0)
	var slots := battle.get_slot_board()
	for i in slots.slot_count:
		slots.try_recall(i)
		if entry != null:
			deck.clear_seat(entry.entry_id)
	slots.try_assign(0, entry)
	battle._sync_slot_visuals()
	var base := data.stats.max_hp if stat == "max_hp" else data.stats.attack
	battle.try_start_combat()
	await process_frame
	var sim := battle.get_sim()
	if sim == null:
		push_error("%s: sim missing" % unit_id)
		battle.queue_free()
		return false
	if not sim.has_pending_effects():
		push_error("%s: expected pending combat-start batch with defer" % unit_id)
		battle.queue_free()
		return false
	sim.flush_combat_start_lock()
	for item in sim.get_units():
		var rt := item as RtUnit
		if rt.unit != null and rt.unit.unit_data != null and rt.unit.unit_data.id == unit_id:
			var got := (
				rt.unit.get_effective_max_hp()
				if stat == "max_hp"
				else rt.unit.get_effective_attack()
			)
			if got != base + delta:
				push_error("%s: %s %d expected %d" % [unit_id, stat, got, base + delta])
				battle.queue_free()
				return false
			battle.queue_free()
			return true
	push_error("%s: unit missing on field" % unit_id)
	battle.queue_free()
	return false
