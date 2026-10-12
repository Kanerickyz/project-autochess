class_name RunGameController
extends Node

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const DEFAULT_RUN_MAP := preload("res://resources/runs/act1_map.tres")
const DEFAULT_DECK_CONFIG := preload("res://resources/deck/realtime_starter_deck.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")

@onready var _battle_root: Control = %BattleRoot
@onready var _map_screen: MapScreen = %MapScreen
@onready var _placeholder_screen: PlaceholderNodeScreen = %PlaceholderNodeScreen
@onready var _run_end_overlay: RunEndOverlay = %RunEndOverlay

var run_controller: RunController = RunController.new()
var deck_state: DeckState = DeckState.new()
var run_economy: RunEconomy = RunEconomy.new()
var _battle: RealtimeBattleController
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	deck_state.configure(DEFAULT_DECK_CONFIG)
	run_economy.configure(DEFAULT_ECONOMY)

	_battle = BATTLE_SCENE.instantiate() as RealtimeBattleController
	if _battle == null:
		push_error("RunGameController: battle scene is not RealtimeBattleController")
		return
	_battle_root.add_child(_battle)
	_battle.encounter_completed.connect(_on_encounter_completed)

	run_controller.configure(DEFAULT_RUN_MAP, _rng.randi())
	run_controller.phase_changed.connect(_on_run_phase_changed)
	run_controller.map_updated.connect(_on_map_updated)

	_map_screen.node_selected.connect(_on_map_node_selected)
	_placeholder_screen.continue_pressed.connect(_on_placeholder_continue)
	_run_end_overlay.action_pressed.connect(_on_run_end_action)

	_start_new_run()


func _start_new_run() -> void:
	deck_state.reset_from_config()
	run_economy.reset()
	_battle.setup(deck_state, run_economy, run_controller.get_board_defaults())
	_hide_encounter_ui()
	run_controller.start_run()
	_show_map()


func _show_map() -> void:
	_hide_encounter_ui()
	_battle_root.visible = false
	_map_screen.show_map(run_controller)


func _hide_encounter_ui() -> void:
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	if run_controller.phase != RunController.RunPhase.RUN_COMPLETE \
			and run_controller.phase != RunController.RunPhase.RUN_DEFEAT:
		_run_end_overlay.hide_overlay()


func _on_map_node_selected(node_id: int) -> void:
	var node := run_controller.enter_node(node_id)
	if node == null:
		return
	_map_screen.hide_map()
	var node_type := run_controller.get_pending_node_type()
	if node_type == MapNodeType.Type.START:
		run_controller.complete_encounter()
		return
	if MapNodeType.is_combat(node_type):
		var encounter := node.get_encounter()
		if encounter == null:
			push_warning("RunGameController: combat node missing encounter")
			run_controller.complete_encounter()
			return
		_battle_root.visible = true
		_battle.start_encounter(encounter, run_controller.get_encounter_tier_index())
		return
	if node_type == MapNodeType.Type.SHOP:
		run_controller.register_shop_visit()
	_placeholder_screen.show_placeholder(node_type)


func _on_placeholder_continue() -> void:
	_placeholder_screen.hide_placeholder()
	run_controller.complete_encounter()


func _on_encounter_completed(won: bool) -> void:
	_battle_root.visible = false
	if not won:
		run_controller.fail_run()
		return
	var node := run_controller.get_pending_node()
	var encounter := node.get_encounter() if node != null else null
	if encounter != null and encounter.bonus_gold > 0:
		run_economy.grant(encounter.bonus_gold)
	run_controller.complete_encounter()


func _on_run_phase_changed(new_phase: RunController.RunPhase) -> void:
	match new_phase:
		RunController.RunPhase.MAP:
			_show_map()
		RunController.RunPhase.RUN_COMPLETE:
			_battle_root.visible = false
			_map_screen.hide_map()
			_run_end_overlay.show_victory()
		RunController.RunPhase.RUN_DEFEAT:
			_battle_root.visible = false
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
	_start_new_run()
