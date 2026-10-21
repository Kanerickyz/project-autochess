class_name RunGameController
extends Node

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const DEFAULT_RUN_MAP := preload("res://resources/runs/act1_map.tres")
const DEFAULT_DECK_CONFIG := preload("res://resources/deck/realtime_starter_deck.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")
const DEFAULT_RECRUIT_CONFIG := preload("res://resources/recruit/default_recruit_config.tres")

@onready var _battle_root: Control = %BattleRoot
@onready var _map_screen: MapScreen = %MapScreen
@onready var _placeholder_screen: PlaceholderNodeScreen = %PlaceholderNodeScreen
@onready var _run_end_overlay: RunEndOverlay = %RunEndOverlay
@onready var _run_stats_overlay: RunStatsOverlay = %RunStatsOverlay

var run_controller: RunController = RunController.new()
var deck_state: DeckState = DeckState.new()
var run_economy: RunEconomy = RunEconomy.new()
var recruit_config: RecruitConfig = DEFAULT_RECRUIT_CONFIG
var _battle: RealtimeBattleController
var _recruit_session: RecruitSession = RecruitSession.new()
var _rng := RandomNumberGenerator.new()
var _recruit_busy: bool = false
var _enchant_busy: bool = false
## 时机 A：点开始后、见地图前先开局招募；期间抑制 MAP→_show_map。
var _opening_recruit_pending: bool = false
var _suppress_map_show: bool = false
var _run_stat_ledger: RunStatLedger = RunStatLedger.new()
var _pending_end_victory: bool = false


func _ready() -> void:
	_rng.randomize()
	deck_state.configure(DEFAULT_DECK_CONFIG)
	run_economy.configure(DEFAULT_ECONOMY)

	_battle = BATTLE_SCENE.instantiate() as RealtimeBattleController
	if _battle == null:
		push_error("RunGameController: battle scene is not RealtimeBattleController")
		return
	_battle_root.add_child(_battle)
	if recruit_config != null:
		_battle.half_exit_seconds = recruit_config.half_exit_seconds
		_battle.recruit_enter_seconds = recruit_config.panel_enter_seconds
	_battle.set_run_stat_ledger(_run_stat_ledger)
	_battle.encounter_completed.connect(_on_encounter_completed)
	_battle.combat_resolved.connect(_on_combat_resolved)
	_battle.recruit_finished.connect(_on_recruit_finished)
	_battle.enchant_finished.connect(_on_enchant_finished)

	run_controller.configure(DEFAULT_RUN_MAP, _rng.randi())
	run_controller.phase_changed.connect(_on_run_phase_changed)
	run_controller.map_updated.connect(_on_map_updated)

	_map_screen.node_selected.connect(_on_map_node_selected)
	_placeholder_screen.continue_pressed.connect(_on_placeholder_continue)
	_run_end_overlay.action_pressed.connect(_on_run_end_action)
	_run_stats_overlay.continue_pressed.connect(_on_run_stats_continue)

	await _start_new_run()


func _start_new_run() -> void:
	_run_stat_ledger.reset()
	_pending_end_victory = false
	deck_state.reset_from_config()
	run_economy.reset()
	_recruit_session.clear_persisted_locks()
	_battle.setup(deck_state, run_economy, run_controller.get_board_defaults())
	_hide_encounter_ui()
	_suppress_map_show = true
	_opening_recruit_pending = true
	run_controller.start_run()
	## 见地图之前先开局招募；完成且队伍 ≥1 后由 _on_recruit_finished → _show_map。
	await _open_opening_recruit()


func _show_map() -> void:
	if _suppress_map_show:
		return
	_hide_encounter_ui()
	## 地图与关卡共用竞技场背景：战斗层保留在下方作世界底图，地图半透明罩上。
	_battle_root.visible = true
	if _battle != null:
		_battle.exit_recruit()
		_battle.set_world_backdrop_mode(true)
	_map_screen.show_map(run_controller)


func _hide_encounter_ui() -> void:
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	if run_controller.phase != RunController.RunPhase.RUN_COMPLETE \
			and run_controller.phase != RunController.RunPhase.RUN_DEFEAT:
		_run_end_overlay.hide_overlay()
		_run_stats_overlay.hide_overlay()


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
		if _battle != null:
			_battle.set_world_backdrop_mode(false)
		var floor_index := node.get_floor()
		_battle.start_encounter(
			encounter,
			run_controller.get_encounter_tier_index(),
			floor_index,
			int(node_type),
		)
		return
	if node_type == MapNodeType.Type.SHOP:
		run_controller.register_shop_visit()
	if node_type == MapNodeType.Type.ENCHANT:
		await _open_enchant()
		return
	## 非战斗节点仍留世界底图，占位 UI 叠在上面。
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(true)
	_placeholder_screen.show_placeholder(node_type)


func _on_placeholder_continue() -> void:
	_placeholder_screen.hide_placeholder()
	run_controller.complete_encounter()


func _on_combat_resolved(_won: bool) -> void:
	if _battle != null:
		run_controller.run_state.add_combat_time(_battle.get_last_encounter_elapsed_seconds())


func _on_encounter_completed(won: bool) -> void:
	if not won:
		var snap := _build_stats_snapshot(false)
		_battle_root.visible = false
		if _battle != null:
			_battle.exit_recruit()
		run_controller.fail_run()
		_present_run_end_stats(snap)
		return

	var node := run_controller.get_pending_node()
	var encounter := node.get_encounter() if node != null else null
	if encounter != null and encounter.bonus_gold > 0:
		run_economy.grant(encounter.bonus_gold)

	var node_type := run_controller.get_pending_node_type()
	if not _recruit_session.should_offer_recruit(node_type, true):
		_battle_root.visible = false
		if _battle != null:
			_battle.exit_recruit()
		run_controller.complete_encounter()
		return

	await _open_recruit()


## 开局招募：与胜后同一套 Arena enter_recruit；进度 0；须队伍 ≥1 才能完成。
func _open_opening_recruit() -> void:
	if _recruit_busy:
		return
	_recruit_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()

	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.randi()
	_recruit_session.configure(recruit_config, deck_state, run_economy, rng)
	_recruit_session.require_nonempty_roster = true
	_recruit_session.begin(0.0)
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_recruit(_recruit_session, enter_s)


## 胜后留在 BattleRoot：半场退场后同屏滑入队伍/候选人（Arena 主路径，非暗色卡片面板）。
func _open_enchant() -> void:
	if _enchant_busy:
		return
	_enchant_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_enchant(enter_s)


func _on_enchant_finished(_did_fuse: bool) -> void:
	_enchant_busy = false
	run_controller.complete_encounter()


func _open_recruit() -> void:
	if _recruit_busy:
		return
	_recruit_busy = true
	_opening_recruit_pending = false
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()

	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.randi()
	_recruit_session.configure(recruit_config, deck_state, run_economy, rng)
	_recruit_session.require_nonempty_roster = false
	_recruit_session.begin(_recruit_progress_ratio())
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_recruit(_recruit_session, enter_s)


func _recruit_progress_ratio() -> float:
	var floors := 12
	if run_controller.map_config != null:
		floors = maxi(1, run_controller.map_config.floor_count)
	var depth := run_controller.run_state.completed_encounter_count
	return clampf(float(depth) / float(floors), 0.0, 1.0)


func _on_recruit_finished(_kept: bool) -> void:
	_recruit_busy = false
	if _opening_recruit_pending:
		_opening_recruit_pending = false
		_suppress_map_show = false
		_show_map()
		return
	_battle_root.visible = false
	run_controller.complete_encounter()


func _on_run_phase_changed(new_phase: RunController.RunPhase) -> void:
	match new_phase:
		RunController.RunPhase.MAP:
			_show_map()
		RunController.RunPhase.RUN_COMPLETE:
			_battle_root.visible = false
			_map_screen.hide_map()
			if _battle != null:
				_battle.exit_recruit()
			_present_run_end_stats(_build_stats_snapshot(true))
		RunController.RunPhase.RUN_DEFEAT:
			_battle_root.visible = false
			_map_screen.hide_map()
			if _battle != null:
				_battle.exit_recruit()


func _on_map_updated() -> void:
	if run_controller.phase == RunController.RunPhase.MAP and not _suppress_map_show:
		_map_screen.refresh_map(run_controller)


func _on_run_stats_continue() -> void:
	_run_stats_overlay.hide_overlay()
	if _pending_end_victory:
		_run_end_overlay.show_victory()
	else:
		_run_end_overlay.show_defeat()


func _present_run_end_stats(snapshot: RunStatsSnapshot) -> void:
	_pending_end_victory = snapshot != null and snapshot.victory
	_run_end_overlay.hide_overlay()
	_run_stats_overlay.show_snapshot(snapshot)


func _build_stats_snapshot(victory: bool) -> RunStatsSnapshot:
	var snap := RunStatsSnapshot.new()
	snap.victory = victory
	var rs := run_controller.run_state
	snap.encounters_won = rs.completed_encounter_count
	snap.shop_visits = rs.shop_visit_count
	snap.combat_seconds = rs.total_combat_seconds
	snap.gold = run_economy.gold
	snap.roster.assign(deck_state.get_entries())
	snap.ledger = _run_stat_ledger
	snap.highest_attack_entries = RunStatsSnapshot.pick_highest_attack(snap.roster)
	snap.highest_max_hp_entries = RunStatsSnapshot.pick_highest_max_hp(snap.roster)
	return snap


func _on_run_end_action(action: StringName) -> void:
	_run_end_overlay.hide_overlay()
	_run_stats_overlay.hide_overlay()
	if action == &"menu":
		get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
		return
	_start_new_run()
