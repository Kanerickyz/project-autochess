extends SceneTree
## GUI：上半场 StageChoice 卡片截图 → /opt/cursor/artifacts/

const OUT_PATH := "/opt/cursor/artifacts/stage_choice_cards_demo.png"
const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const DEFAULT_DECK := preload("res://resources/deck/realtime_starter_deck.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")


func _initialize() -> void:
	await process_frame
	var root := Window.new()
	root.title = "StageChoice demo"
	root.size = Vector2i(720, 1280)
	root.mode = Window.MODE_WINDOWED
	get_root().add_child(root)
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	root.add_child(battle)
	await process_frame
	var deck := DeckState.new()
	deck.configure(DEFAULT_DECK)
	deck.reset_from_config()
	var eco := RunEconomy.new()
	eco.configure(DEFAULT_ECONOMY)
	eco.reset()
	var level := LevelData.new()
	battle.setup(deck, eco, level)
	await process_frame
	## 放几个已入座单位，确认下半场 AllyBoard 仍可见。
	var entries := deck.get_entries()
	for i in mini(3, entries.size()):
		var e: DeckEntry = entries[i]
		if e != null and e.seat_index < 0:
			deck.assign_seat(e.entry_id, i)
	var cards: Array = [
		{"id": &"shop", "label": "商店", "summary": "消耗品 / 装备"},
		{"id": &"event", "label": "事件", "summary": "远征圣物等"},
	]
	battle.enter_stage_choice("战后选择", cards, 0.0)
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var err := img.save_png(OUT_PATH)
	if err != OK:
		push_error("StageChoiceGuiDemo: save failed %s" % err)
		quit(1)
		return
	print("StageChoiceGuiDemo: wrote %s" % OUT_PATH)
	quit(0)
