class_name RunGameController
extends Node

const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const DEFAULT_RUN_MAP := preload("res://resources/runs/act1_map.tres")
const DEFAULT_DECK_CONFIG := preload("res://resources/deck/realtime_starter_deck.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")
const DEFAULT_RECRUIT_CONFIG := preload("res://resources/recruit/default_recruit_config.tres")
## 无尽招募品阶软顶：避免进度比卡死，但实际层号可超过。
const ENDLESS_RECRUIT_SOFT_FLOOR_COUNT := 30

@export var map_config_override: RunMapConfig

@onready var _battle_root: Control = %BattleRoot
@onready var _map_screen: MapScreen = %MapScreen
@onready var _placeholder_screen: PlaceholderNodeScreen = %PlaceholderNodeScreen
@onready var _run_end_overlay: RunEndOverlay = %RunEndOverlay
@onready var _run_stats_overlay: RunStatsOverlay = %RunStatsOverlay

var run_controller: RunController = RunController.new()
var deck_state: DeckState = DeckState.new()
var run_economy: RunEconomy = RunEconomy.new()
var recruit_config: RecruitConfig = DEFAULT_RECRUIT_CONFIG
var map_shop_config: MapShopConfig = MapShopConfig.load_or_default()
var _battle: RealtimeBattleController
var _recruit_session: RecruitSession = RecruitSession.new()
var _map_shop_service: MapShopService = MapShopService.new()
var _rng := RandomNumberGenerator.new()
var _recruit_busy: bool = false
var _victory_boost_busy: bool = false
var _enchant_busy: bool = false
var _map_shop_busy: bool = false
## 时机 A：点开始后、见地图前先开局招募；期间抑制 MAP→_show_map。
var _opening_recruit_pending: bool = false
var _suppress_map_show: bool = false
var _run_stat_ledger: RunStatLedger = RunStatLedger.new()
var _pending_end_victory: bool = false
var _pending_end_snapshot: RunStatsSnapshot
var _pending_map_hint: String = ""


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
	_battle.final_trial_floors_recorded.connect(_on_final_trial_floors_recorded)
	_battle.victory_boost_finished.connect(_on_victory_boost_finished)
	_battle.recruit_finished.connect(_on_recruit_finished)
	_battle.enchant_finished.connect(_on_enchant_finished)
	_battle.map_shop_finished.connect(_on_map_shop_finished)

	var map_cfg: RunMapConfig = map_config_override if map_config_override != null else DEFAULT_RUN_MAP
	run_controller.configure(map_cfg, _rng.randi())
	run_controller.phase_changed.connect(_on_run_phase_changed)
	run_controller.map_updated.connect(_on_map_updated)

	_map_screen.node_selected.connect(_on_map_node_selected)
	_placeholder_screen.continue_pressed.connect(_on_placeholder_continue)
	_run_end_overlay.action_pressed.connect(_on_run_end_action)
	_run_stats_overlay.continue_pressed.connect(_on_run_stats_continue)

	await _start_new_run()


func _is_endless() -> bool:
	return run_controller != null and run_controller.is_endless()


func _start_new_run() -> void:
	_run_stat_ledger.reset()
	deck_state.set_run_stat_ledger(_run_stat_ledger)
	_pending_end_victory = false
	_pending_end_snapshot = null
	deck_state.reset_from_config()
	run_economy.reset()
	_recruit_session.clear_persisted_locks()
	_recruit_session.clear_party_bark_flags()
	_recruit_session.clear_taken_copies()
	_battle.reset_final_trial_state()
	_battle.setup(deck_state, run_economy, run_controller.get_board_defaults())
	if run_controller.map_config != null:
		_battle.set_map_floor_count(_recruit_map_floor_count())
		_battle.set_forward_tier_unlock(_is_endless())
		if run_controller.map_config.spawn_budget_override != null:
			_battle.set_spawn_budget_config(run_controller.map_config.spawn_budget_override)
		else:
			_battle.set_spawn_budget_config(null)
	_battle.reset_tier_unlock_announcements()
	_hide_encounter_ui()
	_suppress_map_show = true
	_opening_recruit_pending = true
	run_controller.start_run()
	run_controller.run_state.mark_run_started()
	## 见地图之前先开局招募；完成且队伍 ≥1 后由 _on_recruit_finished → _show_map。
	await _open_opening_recruit()


func _show_map() -> void:
	if _suppress_map_show:
		return
	_hide_encounter_ui()
	## 地图与关卡共用竞技场背景：战斗层保留在下方作世界底图，地图半透明罩上。
	_battle_root.visible = true
	if _battle != null:
		_battle.exit_victory_boost(false)
		_battle.exit_recruit()
		_battle.exit_map_shop()
		_battle.exit_enchant()
		_battle.set_world_backdrop_mode(true)
	var hint := _pending_map_hint
	_pending_map_hint = ""
	_map_screen.show_map(run_controller, hint)


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
			## 无尽软顶随当前战斗层放开，避免品阶/抽阵仍按开局 30 卡死观感。
			if _is_endless():
				_battle.set_map_floor_count(maxi(ENDLESS_RECRUIT_SOFT_FLOOR_COUNT, node.get_floor()))
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
		await _open_map_shop()
		return
	if node_type == MapNodeType.Type.ENCHANT:
		await _open_enchant()
		return
	## 非战斗节点仍留世界底图，占位 UI 叠在上面。
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(true)
	_placeholder_screen.show_placeholder(node_type)


func _on_placeholder_continue() -> void:
	_grant_pending_node_floor_gold()
	_placeholder_screen.hide_placeholder()
	run_controller.complete_encounter()


func _on_final_trial_floors_recorded(floors: int) -> void:
	if run_controller != null and run_controller.run_state != null:
		run_controller.run_state.final_trial_floors_cleared = maxi(0, floors)


func _on_encounter_completed(won: bool) -> void:
	if not won:
		var snap := _build_stats_snapshot(false)
		_battle_root.visible = false
		if _battle != null:
			_battle.exit_victory_boost(false)
			_battle.exit_recruit()
		run_controller.fail_run()
		_present_run_end_result(snap)
		return

	var node := run_controller.get_pending_node()
	var encounter := node.get_encounter() if node != null else null
	if encounter != null and encounter.bonus_gold > 0:
		run_economy.grant(encounter.bonus_gold)

	var node_type := run_controller.get_pending_node_type()
	## Boss / 不应招募：与招募同条件，也不进免费强化。
	if not _recruit_session.should_offer_recruit(node_type, true):
		_battle_root.visible = false
		if _battle != null:
			_battle.exit_victory_boost(false)
			_battle.exit_recruit()
		run_controller.complete_encounter()
		return

	## 普/精胜：免费强化（可跳过）→ 招募。开局招募不走本路径。
	await _open_victory_boost()
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
	## 开局：第 1 层尺 → 仅 T1。
	_recruit_session.forward_tier_unlock = _is_endless()
	_recruit_session.begin(0.0, 1, _recruit_map_floor_count())
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_recruit(_recruit_session, enter_s)


## 胜后免费强化：在招募进门快照之前落盘；空队自动跳过。
func _open_victory_boost() -> void:
	if _victory_boost_busy:
		return
	if deck_state == null or deck_state.size() <= 0:
		return
	_victory_boost_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()

	var session := VictoryBoostSession.new()
	session.configure(
		deck_state,
		_recruit_map_floor(),
		_recruit_map_floor_count(),
		_is_endless(),
	)
	session.begin()
	if not session.has_boostable_roster():
		_victory_boost_busy = false
		return
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_victory_boost(session, enter_s)
	## 等玩家确认/跳过；信号由 battle 发出后 _on_victory_boost_finished 清 busy。
	if _victory_boost_busy:
		await _battle.victory_boost_finished


func _on_victory_boost_finished(_applied: bool) -> void:
	_victory_boost_busy = false


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


## 事件 / 商店离开：与战斗胜场同公式（第 n 层 → n+3 金）。
func _grant_pending_node_floor_gold() -> int:
	if run_controller == null or run_economy == null:
		return 0
	var node_type := run_controller.get_pending_node_type()
	if not MapNodeType.grants_node_completion_gold(node_type):
		return 0
	var node := run_controller.get_pending_node()
	if node == null:
		return 0
	var amount := run_economy.grant_floor_gold(node.get_floor())
	if amount > 0:
		_pending_map_hint = "节点完成  +%d 金" % amount
	return amount


## 地图商店：Arena 主路径（上队伍 / 下货架），与招募同屏半场；结束回地图。
func _open_map_shop() -> void:
	if _map_shop_busy:
		return
	_map_shop_busy = true
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(false)
	_map_screen.hide_map()
	_placeholder_screen.hide_placeholder()
	var shop_rng := RandomNumberGenerator.new()
	shop_rng.seed = _rng.randi()
	var config := map_shop_config if map_shop_config != null else MapShopConfig.load_or_default()
	_map_shop_service.configure(config, run_economy, deck_state, shop_rng)
	_map_shop_service.open_shop()
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_map_shop(_map_shop_service, enter_s)


func _on_map_shop_finished() -> void:
	_grant_pending_node_floor_gold()
	_map_shop_service.close_shop()
	_map_shop_busy = false
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
	_recruit_session.forward_tier_unlock = _is_endless()
	_recruit_session.begin(
		_recruit_progress_ratio(),
		_recruit_map_floor(),
		_recruit_map_floor_count(),
	)
	var enter_s := recruit_config.panel_enter_seconds if recruit_config != null else 0.45
	await _battle.enter_recruit(_recruit_session, enter_s)


func _recruit_progress_ratio() -> float:
	var floors := _recruit_map_floor_count()
	var depth := run_controller.run_state.completed_encounter_count
	return clampf(float(depth) / float(floors), 0.0, 1.0)


## 胜后招募品阶：用本场遭遇地图层（T2 自第 4 层；T3 自倒数 6 层 / 无尽单向）。
func _recruit_map_floor() -> int:
	if _battle != null:
		return maxi(1, _battle.get_floor_index())
	return 1


func _recruit_map_floor_count() -> int:
	## 无尽：软顶 max(30, currentF)，品阶靠 forward_tier_unlock 随 F 放开。
	if _is_endless():
		var current_f := _recruit_map_floor()
		return maxi(ENDLESS_RECRUIT_SOFT_FLOOR_COUNT, current_f)
	if run_controller != null and run_controller.map_config != null:
		return maxi(1, run_controller.map_config.floor_count)
	if _battle != null:
		return maxi(1, _battle.get_map_floor_count())
	return TierUnlock.DEFAULT_FLOOR_COUNT


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
				_battle.exit_victory_boost(false)
				_battle.exit_recruit()
			_present_run_end_result(_build_stats_snapshot(true))
		RunController.RunPhase.RUN_DEFEAT:
			_battle_root.visible = false
			_map_screen.hide_map()
			if _battle != null:
				_battle.exit_victory_boost(false)
				_battle.exit_recruit()


func _on_map_updated() -> void:
	if run_controller.phase == RunController.RunPhase.MAP and not _suppress_map_show:
		_map_screen.refresh_map(run_controller)


## 结局宣告「继续」→ 远征统计；统计「继续」→ 再来一局/回主菜单。
func _on_run_stats_continue() -> void:
	_run_stats_overlay.hide_overlay()
	var reached := 0
	var endless := false
	if _pending_end_snapshot != null:
		reached = _pending_end_snapshot.reached_floor
		endless = _pending_end_snapshot.endless_mode
	_run_end_overlay.show_choices(_pending_end_victory, reached, endless)


func _present_run_end_result(snapshot: RunStatsSnapshot) -> void:
	_pending_end_snapshot = snapshot
	_pending_end_victory = snapshot != null and snapshot.victory
	_run_stats_overlay.hide_overlay()
	var reached := snapshot.reached_floor if snapshot != null else 0
	var endless := snapshot.endless_mode if snapshot != null else false
	_run_end_overlay.show_result_intro(_pending_end_victory, reached, endless)


func _present_run_end_stats(snapshot: RunStatsSnapshot) -> void:
	_run_end_overlay.hide_overlay()
	if snapshot != null:
		RunMatchHistoryStore.append_snapshot(snapshot)
	_run_stats_overlay.show_snapshot(snapshot)


func _build_stats_snapshot(victory: bool) -> RunStatsSnapshot:
	var snap := RunStatsSnapshot.new()
	snap.victory = victory
	var rs := run_controller.run_state
	snap.encounters_won = rs.completed_encounter_count
	snap.shop_visits = rs.shop_visit_count
	snap.combat_seconds = rs.get_run_elapsed_real_seconds()
	snap.gold = run_economy.gold
	snap.endless_mode = _is_endless()
	snap.final_trial_floors_cleared = rs.final_trial_floors_cleared
	## 败局：优先用正打着的战斗层；否则用已胜场+1；通关不记层深成绩。
	if not victory:
		var pending := run_controller.get_pending_node()
		if pending != null and MapNodeType.is_combat(pending.get_effective_type()):
			snap.reached_floor = maxi(1, pending.get_floor())
		elif _battle != null and _battle.get_floor_index() > 0:
			snap.reached_floor = _battle.get_floor_index()
		else:
			snap.reached_floor = maxi(1, rs.completed_encounter_count + 1)
	else:
		snap.reached_floor = 0
	snap.roster.assign(deck_state.get_entries())
	## 拷贝账本：历程数字已是值拷贝；战斗合计也须与活账本脱钩（再开局 reset 不影响已展示快照）。
	snap.ledger = (
		_run_stat_ledger.duplicate_ledger()
		if _run_stat_ledger != null
		else RunStatLedger.new()
	)
	snap.highest_attack_entries = RunStatsSnapshot.pick_highest_attack(snap.roster)
	snap.highest_max_hp_entries = RunStatsSnapshot.pick_highest_max_hp(snap.roster)
	snap.highest_combat_atk_hp_entries.assign(snap.ledger.peak_combat_entries)
	return snap


func _on_run_end_action(action: StringName) -> void:
	if action == &"continue":
		_run_end_overlay.hide_overlay()
		_present_run_end_stats(_pending_end_snapshot)
		return
	_run_end_overlay.hide_overlay()
	_run_stats_overlay.hide_overlay()
	_pending_end_snapshot = null
	if action == &"menu":
		await SceneTransition.change_scene_to_file("res://scenes/main/main_menu.tscn")
		return
	_start_new_run()
