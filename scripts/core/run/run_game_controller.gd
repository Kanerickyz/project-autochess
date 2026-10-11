class_name RunGameController
extends Node

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const DEFAULT_RUN_MAP := preload("res://resources/runs/act1_map.tres")

@onready var _board_root: Node2D = $BoardRoot
@onready var _map_screen: MapScreen = %MapScreen
@onready var _rest_screen: RestScreen = %RestScreen
@onready var _event_screen: EventScreen = %EventScreen
@onready var _treasure_screen: TreasureScreen = %TreasureScreen
@onready var _sacrifice_screen: SacrificeScreen = %SacrificeScreen
@onready var _run_end_overlay: RunEndOverlay = %RunEndOverlay

var run_controller: RunController = RunController.new()
var _board: BoardController
var _rng := RandomNumberGenerator.new()
var _current_treasure_offers: Array[BuffCardData] = []


func _ready() -> void:
	_rng.randomize()
	var main_instance := MAIN_SCENE.instantiate() as BoardController
	if main_instance == null:
		push_error("RunGameController: main scene is not BoardController")
		return
	main_instance.run_mode_enabled = true
	_board_root.add_child(main_instance)
	_board = main_instance
	_board.encounter_completed.connect(_on_encounter_completed)
	_board.shop_visit_completed.connect(_on_shop_visit_completed)

	run_controller.configure(DEFAULT_RUN_MAP, _rng.randi())
	run_controller.phase_changed.connect(_on_run_phase_changed)
	run_controller.map_updated.connect(_on_map_updated)

	_map_screen.node_selected.connect(_on_map_node_selected)
	_rest_screen.rest_choice_selected.connect(_on_rest_choice_selected)
	_event_screen.choice_selected.connect(_on_event_choice_selected)
	_treasure_screen.treasure_selected.connect(_on_treasure_selected)
	_sacrifice_screen.skipped.connect(_on_sacrifice_skipped)
	_sacrifice_screen.sacrifice_completed.connect(_on_sacrifice_completed)
	_run_end_overlay.action_pressed.connect(_on_run_end_action)

	_hide_encounter_ui()
	run_controller.start_run()
	_board.initialize_for_run(run_controller)
	_show_map()


func _show_map() -> void:
	_hide_encounter_ui()
	_map_screen.show_map(run_controller)
	_board.set_run_visible(false)


func _hide_encounter_ui() -> void:
	_map_screen.hide_map()
	_rest_screen.hide_rest()
	_event_screen.hide_event()
	_treasure_screen.hide_treasure()
	_sacrifice_screen.hide_sacrifice()
	if run_controller.phase != RunController.RunPhase.RUN_COMPLETE \
			and run_controller.phase != RunController.RunPhase.RUN_DEFEAT:
		_run_end_overlay.hide_overlay()


func _on_map_node_selected(node_id: int) -> void:
	var node := run_controller.enter_node(node_id)
	if node == null:
		return
	_map_screen.hide_map()
	var node_type := run_controller.get_pending_node_type()
	match node_type:
		MapNodeType.Type.START:
			run_controller.complete_encounter()
			return
		MapNodeType.Type.COMBAT, MapNodeType.Type.ELITE, MapNodeType.Type.BOSS:
			var encounter := node.get_encounter()
			if encounter == null:
				push_warning("RunGameController: combat node missing encounter")
				run_controller.complete_encounter()
				return
			_board.start_run_encounter(encounter, run_controller.get_encounter_tier_index())
		MapNodeType.Type.SHOP:
			run_controller.register_shop_visit()
			_board.start_map_shop(run_controller.get_shop_wave())
		MapNodeType.Type.REST:
			_rest_screen.show_rest()
		MapNodeType.Type.EVENT:
			var event_data := node.get_event_data()
			if event_data == null and run_controller.map_config != null:
				var pool := run_controller.map_config.event_pool
				if not pool.is_empty():
					event_data = pool[_rng.randi_range(0, pool.size() - 1)]
			_event_screen.show_event(event_data)
		MapNodeType.Type.TREASURE:
			_current_treasure_offers = _roll_treasure_offers()
			_treasure_screen.show_treasure(_current_treasure_offers)
		MapNodeType.Type.SACRIFICE:
			_sacrifice_screen.show_sacrifice(
				_board.deck_state.get_entries(),
				_board.deck_state.get_level_config(),
			)
		MapNodeType.Type.MYSTERY:
			push_warning("RunGameController: unresolved mystery node")
			run_controller.complete_encounter()


func _roll_treasure_offers() -> Array[BuffCardData]:
	var pool: Array[BuffCardData] = []
	if run_controller.map_config != null:
		pool = run_controller.map_config.treasure_buff_pool
	if pool.is_empty():
		return []
	var offers: Array[BuffCardData] = []
	var copy := pool.duplicate()
	copy.shuffle()
	for i in mini(3, copy.size()):
		offers.append(copy[i])
	return offers


func _on_encounter_completed(won: bool) -> void:
	if not won:
		run_controller.fail_run()
		_board.initialize_for_run(run_controller)
		return
	var node := run_controller.get_pending_node()
	var encounter := node.get_encounter() if node != null else null
	if encounter != null and encounter.bonus_gold > 0:
		_board.grant_bonus_gold(encounter.bonus_gold)
	run_controller.complete_encounter()


func _on_shop_visit_completed() -> void:
	run_controller.complete_encounter()


func _on_rest_choice_selected(choice: StringName) -> void:
	if choice == &"heal":
		_board.heal_all_player_units()
	elif choice == &"remove":
		var entries := _board.deck_state.get_entries()
		if not entries.is_empty():
			var pick: DeckEntry = entries[_rng.randi_range(0, entries.size() - 1)]
			_board.deck_state.remove_entry(pick.entry_id)
			_board.run_economy.grant(5)
	_rest_screen.hide_rest()
	run_controller.complete_encounter()


func _on_event_choice_selected(index: int) -> void:
	var node := run_controller.get_pending_node()
	var event_data := node.get_event_data() if node != null else null
	if node == null or event_data == null:
		_event_screen.hide_event()
		run_controller.complete_encounter()
		return
	if index < 0 or index >= event_data.choices.size():
		return
	var choice := event_data.choices[index]
	if choice.effect_type == EventChoice.EffectType.HEAL_ALL_UNITS:
		_board.heal_all_player_units()
	var pool: Array[BuffCardData] = []
	if run_controller.map_config != null:
		pool = run_controller.map_config.treasure_buff_pool
	EventEffectResolver.apply_choice(
		choice,
		_board.deck_state,
		_board.run_economy,
		pool,
		_rng,
	)
	_event_screen.hide_event()
	run_controller.complete_encounter()


func _on_treasure_selected(buff_index: int) -> void:
	if buff_index >= 0 and buff_index < _current_treasure_offers.size():
		var buff := _current_treasure_offers[buff_index]
		var entries := _board.deck_state.get_entries()
		if buff != null and not entries.is_empty():
			var entry: DeckEntry = entries[_rng.randi_range(0, entries.size() - 1)]
			_board.deck_state.attach_buff(entry.entry_id, buff)
	_current_treasure_offers.clear()
	_treasure_screen.hide_treasure()
	run_controller.complete_encounter()


func _on_sacrifice_skipped() -> void:
	_sacrifice_screen.hide_sacrifice()
	run_controller.complete_encounter()


func _on_sacrifice_completed(donor_id: int, recipient_id: int) -> void:
	_board.deck_state.sacrifice_transfer_ability(donor_id, recipient_id)
	_sacrifice_screen.hide_sacrifice()
	run_controller.complete_encounter()


func _on_run_phase_changed(new_phase: RunController.RunPhase) -> void:
	match new_phase:
		RunController.RunPhase.MAP:
			_show_map()
		RunController.RunPhase.RUN_COMPLETE:
			_board.set_run_visible(false)
			_map_screen.hide_map()
			_run_end_overlay.show_victory()
		RunController.RunPhase.RUN_DEFEAT:
			_board.set_run_visible(false)
			_map_screen.hide_map()
			_run_end_overlay.show_defeat()


func _on_map_updated() -> void:
	if run_controller.phase == RunController.RunPhase.MAP:
		_map_screen.refresh_map(run_controller)


func _on_run_end_action(action: StringName) -> void:
	_run_end_overlay.hide_overlay()
	if action == &"menu":
		get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
		return
	run_controller.restart_run()
	_board.initialize_for_run(run_controller)
	_show_map()
