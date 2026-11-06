extends SceneTree
## Headless：StageChoice 下半场可检视队伍、上半场卡可检视详情。

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const DEFAULT_DECK := preload("res://resources/deck/realtime_starter_deck.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")
const UNIT_A := preload("res://resources/units/ant.tres")
const UNIT_B := preload("res://resources/units/beaver.tres")


func _initialize() -> void:
	var ok := true
	var battle := BATTLE_SCENE.instantiate() as RealtimeBattleController
	root.add_child(battle)
	await process_frame
	var deck := DeckState.new()
	deck.configure(DEFAULT_DECK)
	deck.reset_from_config()
	var eco := RunEconomy.new()
	eco.configure(DEFAULT_ECONOMY)
	eco.reset()
	battle.setup(deck, eco, LevelData.new())
	await process_frame
	## 开局牌库可为空：手动放入两名已入座成员以测友方半场检视。
	deck.add_entry(UNIT_A as UnitData, 0, 0)
	deck.add_entry(UNIT_B as UnitData, 0, 1)
	var cards: Array = [
		{
			"id": &"event",
			"label": "事件",
			"summary": "短摘要",
			"detail": "完整事件说明：长按应看到这段全文。",
			"kind_label": "去向",
		},
		{
			"id": &"shop",
			"label": "商店",
			"summary": "货架",
			"detail": "完整商店说明。",
			"kind_label": "去向",
		},
	]
	battle.enter_stage_choice("战后选择", cards, 0.0)
	await process_frame
	var arena: RealtimeArenaView = battle.get_node_or_null("%ArenaView") as RealtimeArenaView
	if arena == null:
		arena = _find_arena(battle)
	if arena == null:
		push_error("StageChoiceInputTest: arena missing")
		quit(1)
		return
	## 强制布局，避免 board_rect 为零导致半场判断失真。
	battle.size = Vector2(720, 1280)
	arena.size = Vector2(720, 900)
	arena.custom_minimum_size = Vector2(720, 900)
	await process_frame
	ok = _expect(arena.stage_choice_active, "stage_choice_active") and ok
	ok = _expect(arena.recruit_team_slots != null, "team slots bound") and ok
	var occupied := 0
	if arena.recruit_team_slots != null:
		for si in arena.recruit_team_slots.slot_count:
			if arena.recruit_team_slots.get_entry(si) != null:
				occupied += 1
	ok = _expect(occupied >= 2, "team slots occupied") and ok
	var card_info := arena._info_from_stage_choice_index(0, Vector2.ZERO)
	ok = _expect(not card_info.is_empty(), "card info non-empty") and ok
	ok = _expect(
		String(card_info.get("skills", "")).contains("完整事件说明"),
		"card detail uses full text",
	) and ok
	var inspectables: Array = arena._collect_inspectables()
	var has_team := false
	var has_card := false
	for info in inspectables:
		if not (info is Dictionary):
			continue
		var key := String((info as Dictionary).get("inspect_key", ""))
		if key.begins_with("entry:"):
			has_team = true
		if key.begins_with("stage_choice:"):
			has_card = true
	ok = _expect(has_team, "inspectables include ally team") and ok
	ok = _expect(has_card, "inspectables include stage cards") and ok
	## 下半场中心应判为友方。
	var board := arena.get_board_rect()
	ok = _expect(board.size.x > 1.0 and board.size.y > 1.0, "board rect sized") and ok
	var ally_pos := board.position + Vector2(board.size.x * 0.5, board.size.y * 0.75)
	ok = _expect(arena._is_pointer_on_ally_half(ally_pos), "ally half hit") and ok
	var enemy_pos := board.position + Vector2(board.size.x * 0.5, board.size.y * 0.2)
	ok = _expect(not arena._is_pointer_on_ally_half(enemy_pos), "enemy half not ally") and ok
	var ally_press := InputEventMouseButton.new()
	ally_press.button_index = MOUSE_BUTTON_LEFT
	ally_press.pressed = true
	ally_press.position = ally_pos
	ok = _expect(
		arena._should_route_stage_choice_to_ally(ally_press),
		"ally press routes to team",
	) and ok
	var enemy_press := InputEventMouseButton.new()
	enemy_press.button_index = MOUSE_BUTTON_LEFT
	enemy_press.pressed = true
	enemy_press.position = enemy_pos
	ok = _expect(
		not arena._should_route_stage_choice_to_ally(enemy_press),
		"enemy press stays on cards",
	) and ok
	if ok:
		print("StageChoiceInputTest: PASS")
		quit(0)
	else:
		push_error("StageChoiceInputTest: FAIL")
		quit(1)


func _find_arena(n: Node) -> RealtimeArenaView:
	if n is RealtimeArenaView:
		return n as RealtimeArenaView
	for c in n.get_children():
		var found := _find_arena(c)
		if found != null:
			return found
	return null


func _expect(cond: bool, label: String) -> bool:
	if cond:
		print("StageChoiceInputTest: %s OK" % label)
		return true
	push_error("StageChoiceInputTest: %s failed" % label)
	return false
