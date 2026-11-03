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
## 十五天日程（主爬塔）；无尽仍走地图。
var _day_schedule: DayRunSchedule = DayRunSchedule.new()
var _day_overlay: DayPickOverlay
var _day_shop_service: MapShopService = MapShopService.new()
var _day_encounter: EncounterData
var _art_catalog: UnitArtCatalog = UnitArtCatalog.load_default()


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
	_ensure_day_overlay()

	await _start_new_run()


func _uses_day_loop() -> bool:
	return not _is_endless()


## 弹层挂在 UI 层、结局层之下：结局 / 统计始终盖在日程弹层上。
func _ensure_day_overlay() -> void:
	if _day_overlay != null:
		return
	_day_overlay = DayPickOverlay.new()
	_day_overlay.name = "DayPickOverlay"
	var ui_layer := _run_end_overlay.get_parent()
	ui_layer.add_child(_day_overlay)
	ui_layer.move_child(_day_overlay, _run_end_overlay.get_index())
	_run_end_overlay.day_loop = _uses_day_loop()


func _is_endless() -> bool:
	return run_controller != null and run_controller.is_endless()


func _start_new_run() -> void:
	_run_stat_ledger.reset()
	deck_state.set_run_stat_ledger(_run_stat_ledger)
	deck_state.set_run_state(run_controller.run_state)
	_pending_end_victory = false
	_pending_end_snapshot = null
	deck_state.reset_from_config()
	deck_state.ensure_commander()
	run_economy.reset()
	_recruit_session.clear_persisted_locks()
	_recruit_session.clear_party_bark_flags()
	_recruit_session.clear_taken_copies()
	_battle.reset_final_trial_state()
	_battle.setup(deck_state, run_economy, run_controller.get_board_defaults())
	_battle.set_run_state(run_controller.run_state)
	if run_controller.map_config != null:
		_battle.set_map_floor_count(_recruit_map_floor_count())
		_battle.set_forward_tier_unlock(_is_endless())
		## 无尽走阶梯同质白板刷敌，不依赖 spawn_budget 加压。
		if _is_endless():
			_battle.set_endless_ladder_spawn(true)
			_battle.set_spawn_budget_config(null)
		else:
			_battle.set_endless_ladder_spawn(false)
			if run_controller.map_config.spawn_budget_override != null:
				_battle.set_spawn_budget_config(run_controller.map_config.spawn_budget_override)
			else:
				_battle.set_spawn_budget_config(null)
	_battle.reset_tier_unlock_announcements()
	_battle.final_trial_enabled = not _uses_day_loop()
	_hide_encounter_ui()
	_suppress_map_show = true
	if _uses_day_loop():
		_opening_recruit_pending = false
		_battle.set_map_floor_count(DayRunSchedule.DAY_COUNT)
		run_controller.start_day_run()
		run_controller.run_state.mark_run_started()
		await _day_begin_run()
		return
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
	if _uses_day_loop():
		_placeholder_screen.hide_placeholder()
		_day_advance()
		return
	_grant_pending_node_floor_gold()
	_placeholder_screen.hide_placeholder()
	run_controller.complete_encounter()


func _on_final_trial_floors_recorded(floors: int) -> void:
	if run_controller != null and run_controller.run_state != null:
		run_controller.run_state.final_trial_floors_cleared = maxi(0, floors)


func _on_encounter_completed(won: bool) -> void:
	if _uses_day_loop():
		_day_on_encounter_completed(won)
		return
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


# --- 十五天日程 -----------------------------------------------------------------


func _day_begin_run() -> void:
	_day_schedule.reset()
	_battle_root.visible = true
	if _battle != null:
		_battle.set_encounter_label_override("")
		_battle.set_world_backdrop_mode(true)
	await _day_pick_commander()
	await _day_show_day_start_banner()
	_day_run_current_step()


func _day_is_run_over() -> bool:
	return (
		run_controller.phase == RunController.RunPhase.RUN_DEFEAT
		or run_controller.phase == RunController.RunPhase.RUN_COMPLETE
	)


func _day_sync_progress() -> void:
	if _day_overlay == null:
		return
	_day_overlay.set_day_progress(
		_day_schedule.get_day(),
		_day_schedule.get_day_count(),
		_day_schedule.get_step_labels(),
		_day_schedule.get_step_index(),
	)


func _day_run_current_step() -> void:
	if _day_is_run_over():
		return
	_day_sync_progress()
	match _day_schedule.get_step():
		DayRunSchedule.Step.RECRUIT:
			await _day_recruit()
			_day_advance()
		DayRunSchedule.Step.COMBAT:
			await _day_start_combat()
		DayRunSchedule.Step.SHOP:
			await _day_shop()
			_day_advance()
		DayRunSchedule.Step.EVENT:
			_day_event()


## 推进一步；跨天播「第 N 天结束」与新一天横幅。用 call_deferred 断开协程链。
func _day_advance() -> void:
	if _day_is_run_over():
		return
	var finished_day := _day_schedule.get_day()
	var new_day := _day_schedule.advance()
	if new_day:
		if _day_overlay != null:
			await _day_overlay.show_banner("第 %d 天结束" % finished_day, "队伍休整，明日再战")
		await _day_show_day_start_banner()
	call_deferred("_day_run_current_step")


func _day_show_day_start_banner() -> void:
	if _day_overlay == null:
		return
	var day := _day_schedule.get_day()
	var sub := " → ".join(_day_schedule.get_step_labels())
	if day >= _day_schedule.get_day_count():
		sub = "最后一天 · 末场迎战 Boss"
	await _day_overlay.show_banner("第 %d 天" % day, sub)


func _day_unit_texture(unit_id: String) -> Texture2D:
	return _art_catalog.get_texture(unit_id, true) if _art_catalog != null else null


## 目前只有一位指挥官：仍走一次选择，确认带队后再进招募。
func _day_pick_commander() -> void:
	var cmd := deck_state.get_commander_entry()
	if cmd == null or _day_overlay == null:
		return
	var option := {
		"title": cmd.get_display_name(),
		"texture": _day_unit_texture(cmd.get_unit_id()),
		"attack": DeckUpgradeService.get_display_attack(cmd),
		"hp": DeckUpgradeService.get_display_max_hp(cmd),
		"tag": "装备槽 %d" % cmd.get_equipment_slot_count(),
		"desc": "阵亡即整局失败",
		"detail": "指挥官常驻上场，不占上场席位上限、不可出售、不可进备战。\n生命跨战斗继承。\n装备槽 %d 格（不受职业槽位表限制）。" % cmd.get_equipment_slot_count(),
	}
	await _day_overlay.present({
		"title": "选择指挥官",
		"subtitle": "本局带领队伍撑过十五天的指挥官",
		"hint": "短按选择 · 长按查看详情",
		"options": [option],
	})
	while true:
		var r: Dictionary = await _day_overlay.resolved
		if r.get("kind") == &"option":
			break
	await _day_overlay.play_choice_feedback(0)
	await _day_overlay.close()


func _day_unit_option(unit: UnitData) -> Dictionary:
	if unit == null:
		return {"title": "—", "disabled": true, "disabled_reason": "空"}
	var tag_parts := PackedStringArray(["T%d" % unit.tier, UnitData.combat_profession_label(unit.combat_profession)])
	if unit.theme_bond != UnitData.ThemeBond.NONE:
		tag_parts.append(UnitData.theme_bond_label(unit.theme_bond))
	var rules := UnitData.combat_profession_rules_text(unit.combat_profession)
	return {
		"title": UnitInfoText.get_display_name_from_unit_data(unit),
		"texture": _day_unit_texture(unit.id),
		"attack": unit.stats.attack if unit.stats != null else 0,
		"hp": unit.stats.max_hp if unit.stats != null else 0,
		"tag": " · ".join(tag_parts),
		"desc": "装备槽 %d" % UnitData.equipment_slots_for_profession(unit.combat_profession),
		"detail": UnitInfoText.get_skills_block_from_unit_data(unit, 1, false) if not rules.is_empty() else "",
	}


func _day_entry_option(entry: DeckEntry) -> Dictionary:
	var place := "指挥官" if entry.is_commander() else ("备战" if entry.seat_index < 0 else "已入座")
	return {
		"title": entry.get_display_name(),
		"texture": _day_unit_texture(entry.get_unit_id()),
		"attack": DeckUpgradeService.get_display_attack(entry),
		"hp": DeckUpgradeService.get_display_max_hp(entry),
		"tag": place,
		"detail": UnitInfoText.get_skills_block_from_entry(entry, false),
	}


## 招募：每次三选一（免费）；第 1 天连拿 6 次不可跳过，之后每天 1 次可跳过。
func _day_recruit() -> void:
	if _day_overlay == null:
		return
	_battle_root.visible = true
	if _battle != null:
		_battle.set_world_backdrop_mode(true)
	var picks := _day_schedule.get_recruit_pick_count()
	var cfg: RecruitConfig = (
		recruit_config.duplicate() as RecruitConfig if recruit_config != null else RecruitConfig.new()
	)
	cfg.candidate_count = DayRunSchedule.PICK_OPTION_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.randi()
	_recruit_session.configure(cfg, deck_state, run_economy, rng)
	_recruit_session.require_nonempty_roster = false
	_recruit_session.forward_tier_unlock = false
	var day := _day_schedule.get_day()
	var actions: Array = []
	if _day_schedule.can_skip_recruit():
		actions.append({"id": &"skip", "text": "今天不招"})
	for i in picks:
		_recruit_session.begin(
			float(day - 1) / float(maxi(1, _day_schedule.get_day_count() - 1)),
			day,
			_day_schedule.get_day_count(),
		)
		var options: Array = []
		var cands := _recruit_session.get_candidates()
		for ci in cands.size():
			var opt := _day_unit_option(cands[ci])
			if cands[ci] != null and _recruit_session.needs_replace_for_candidate(ci):
				opt["disabled"] = true
				opt["disabled_reason"] = "队伍已满"
			options.append(opt)
		await _day_overlay.present({
			"title": "招募",
			"subtitle": "第 %d 天 · 第 %d/%d 次 · 三选一（免费）" % [day, i + 1, picks],
			"hint": "短按招入 · 长按查看职业与说明 · 入座满 5 人后进备战",
			"options": options,
			"actions": actions,
		})
		var skipped := false
		while true:
			var r: Dictionary = await _day_overlay.resolved
			if r.get("kind") == &"action" and r.get("action") == &"skip":
				skipped = true
				break
			var idx := int(r.get("index", -1))
			var res := _recruit_session.try_recruit(idx, -1, -1, true)
			if bool(res.get("ok", false)):
				await _day_overlay.play_choice_feedback(idx)
				break
			_day_overlay.reject(idx, _day_recruit_fail_text(String(res.get("reason", ""))))
		if skipped:
			break
	_recruit_session.finish()
	await _day_overlay.close()


static func _day_recruit_fail_text(reason: String) -> String:
	match reason:
		"roster_full", "seat_cap_full":
			return "队伍与备战都已满"
		"no_candidate":
			return "该位置没有候选人"
	return "无法招入"


func _day_start_combat() -> void:
	var boss := _day_schedule.is_boss_battle()
	var map_cfg := run_controller.map_config
	var encounter: EncounterData = null
	if map_cfg != null:
		if boss:
			encounter = map_cfg.boss_encounter
		elif not map_cfg.combat_pool.is_empty():
			encounter = map_cfg.combat_pool[_rng.randi_range(0, map_cfg.combat_pool.size() - 1)]
	if encounter == null:
		push_warning("RunGameController: day combat missing encounter; skip")
		_day_advance()
		return
	if boss and _day_overlay != null:
		await _day_overlay.show_banner("最终战", "击败 Boss 即通关")
	var day := _day_schedule.get_day()
	_day_encounter = encounter
	_battle_root.visible = true
	_battle.set_world_backdrop_mode(false)
	_battle.set_encounter_label_override(
		"第 %d 天 · %s" % [day, "Boss 战" if boss else "第 %d 战" % _day_schedule.get_battle_index()]
	)
	_battle.start_encounter(
		encounter,
		run_controller.get_encounter_tier_index(),
		day,
		int(MapNodeType.Type.BOSS if boss else MapNodeType.Type.COMBAT),
	)
	if deck_state.get_equipment_stash_count() > 0:
		_battle.flash_hint("装备暂存里有新装备：短点角色挂装")


func _day_on_encounter_completed(won: bool) -> void:
	if not won:
		var snap := _build_stats_snapshot(false)
		_battle_root.visible = false
		run_controller.fail_day_run(_day_schedule.get_day())
		_present_run_end_result(snap)
		return
	var encounter := _day_encounter
	_day_encounter = null
	if encounter != null and encounter.bonus_gold > 0:
		run_economy.grant(encounter.bonus_gold)
	run_controller.register_day_combat_win()
	if _day_schedule.is_boss_battle():
		_battle_root.visible = false
		run_controller.complete_day_run()
		return
	_battle.set_world_backdrop_mode(true)
	_day_advance()


## 商店：先选店（军械 / 远程 / 魔法 / 消耗品）→ 随机货架；装备买入暂存，消耗品选人使用。
func _day_shop() -> void:
	if _day_overlay == null:
		return
	run_controller.register_shop_visit()
	_battle_root.visible = true
	_battle.set_world_backdrop_mode(true)
	var day := _day_schedule.get_day()
	var type_options: Array = []
	for cat in DayShopCatalog.CATEGORIES:
		var icon_path := DayShopCatalog.icon_path(cat)
		type_options.append({
			"title": DayShopCatalog.label(cat),
			"texture": load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null,
			"desc": DayShopCatalog.blurb(cat),
			"detail": DayShopCatalog.blurb(cat) + "\n选中后随机出货；货品内容后续设计。",
		})
	await _day_overlay.present({
		"title": "商店",
		"subtitle": "第 %d 天 · 选择今天要逛的商店" % day,
		"hint": "短按进店 · 长按查看说明",
		"options": type_options,
		"actions": [{"id": &"leave", "text": "不逛了"}],
		"gold": run_economy.gold,
	})
	var r: Dictionary = await _day_overlay.resolved
	if r.get("kind") == &"action":
		await _day_overlay.close()
		return
	var cat_index := clampi(int(r.get("index", 0)), 0, DayShopCatalog.CATEGORIES.size() - 1)
	var category: DayShopCatalog.Category = DayShopCatalog.CATEGORIES[cat_index]
	await _day_overlay.play_choice_feedback(cat_index)

	var shop_rng := RandomNumberGenerator.new()
	shop_rng.seed = _rng.randi()
	var config := map_shop_config if map_shop_config != null else MapShopConfig.load_or_default()
	var offers := DayShopCatalog.roll_offers(category, config, shop_rng)
	var is_consumable := category == DayShopCatalog.Category.CONSUMABLE
	_day_shop_service.configure(config, run_economy, deck_state, shop_rng)
	if is_consumable:
		_day_shop_service.open_with_offers(offers, [])
	else:
		_day_shop_service.open_with_offers([], offers)
	var sold: Array[bool] = []
	for _i in offers.size():
		sold.append(false)
	while true:
		await _day_overlay.present(_day_shelf_cfg(category, offers, sold))
		var pick: Dictionary = await _day_overlay.resolved
		if pick.get("kind") == &"action":
			break
		var idx := int(pick.get("index", -1))
		if idx < 0 or idx >= offers.size():
			continue
		if is_consumable:
			var bought := await _day_buy_consumable(idx, offers[idx] as MapShopConsumableData)
			if bought:
				sold[idx] = true
			continue
		## 装备：同一货架内连续购买，不重排卡片。
		var res := _day_shop_service.try_buy_equipment_to_stash(idx)
		while true:
			if int(res.get("result", 0)) == MapShopService.BuyResult.OK:
				sold[idx] = true
				_day_overlay.mark_sold(idx, "已入暂存")
				_day_overlay.set_gold(run_economy.gold)
				_day_overlay.flash_hint("已放入装备暂存（%d/%d）" % [
					deck_state.get_equipment_stash_count(), deck_state.get_equipment_stash_capacity()
				])
			else:
				_day_overlay.reject(idx, _day_shop_fail_text(String(res.get("reason", ""))))
			var nxt: Dictionary = await _day_overlay.resolved
			if nxt.get("kind") == &"action":
				break
			idx = int(nxt.get("index", -1))
			if idx < 0 or idx >= offers.size():
				continue
			res = _day_shop_service.try_buy_equipment_to_stash(idx)
		break
	_day_shop_service.close_shop()
	await _day_overlay.close()


func _day_shelf_cfg(category: DayShopCatalog.Category, offers: Array, sold: Array[bool]) -> Dictionary:
	var options: Array = []
	for i in offers.size():
		var opt := _day_offer_option(offers[i])
		if i < sold.size() and sold[i]:
			opt["sold"] = true
			opt["status_text"] = "已购入"
		options.append(opt)
	var is_consumable := category == DayShopCatalog.Category.CONSUMABLE
	return {
		"title": DayShopCatalog.label(category),
		"subtitle": (
			"短按购买后选择使用对象"
			if is_consumable
			else "买入的装备进入装备暂存；下一场准备时短点角色挂装"
		),
		"hint": "短按购买 · 长按查看详情",
		"options": options,
		"actions": [{"id": &"done", "text": "完成购买"}],
		"gold": run_economy.gold,
	}


func _day_offer_option(item: Variant) -> Dictionary:
	if item is EquipmentData:
		var eq := item as EquipmentData
		return {
			"title": eq.get_display_name(),
			"texture": eq.get_icon(),
			"cost": maxi(0, eq.cost),
			"tag": eq.get_kind_label(),
			"desc": eq.get_summary(),
			"detail": UnitInfoText.format_equipment(eq, false),
		}
	if item is MapShopConsumableData:
		var c := item as MapShopConsumableData
		return {
			"title": c.get_display_name(),
			"texture": c.get_icon(),
			"cost": maxi(0, c.cost),
			"tag": "消耗品",
			"desc": c.get_effect_summary(),
			"detail": c.get_effect_summary(),
		}
	return {"title": "—", "disabled": true, "disabled_reason": "空"}


## 消耗品：主题药水直接作用全队同主题；单体魔药弹出选人（同一套卡片）。
func _day_buy_consumable(slot: int, item: MapShopConsumableData) -> bool:
	if item == null:
		return false
	if not run_economy.can_afford(maxi(0, item.cost)):
		_day_overlay.reject(slot, _day_shop_fail_text("cant_afford"))
		await get_tree().create_timer(0.5).timeout
		return false
	var target_id := -1
	if item.is_theme_potion():
		var cmd := deck_state.get_commander_entry()
		target_id = cmd.entry_id if cmd != null else -1
	else:
		var entries := deck_state.get_entries()
		var options: Array = []
		for e in entries:
			options.append(_day_entry_option(e))
		await _day_overlay.present({
			"title": "使用 %s" % item.get_display_name(),
			"subtitle": item.get_effect_summary(),
			"hint": "短按选择使用对象",
			"options": options,
			"actions": [{"id": &"cancel", "text": "取消"}],
			"gold": run_economy.gold,
		})
		var r: Dictionary = await _day_overlay.resolved
		if r.get("kind") == &"action":
			return false
		var ti := int(r.get("index", -1))
		if ti < 0 or ti >= entries.size():
			return false
		target_id = entries[ti].entry_id
		await _day_overlay.play_choice_feedback(ti)
	var res := _day_shop_service.try_buy_consumable_on_entry(slot, target_id)
	if int(res.get("result", 0)) != MapShopService.BuyResult.OK:
		_day_overlay.flash_hint(_day_shop_fail_text(String(res.get("reason", ""))), true)
		return false
	_day_overlay.set_gold(run_economy.gold)
	return true


static func _day_shop_fail_text(reason: String) -> String:
	match reason:
		"cant_afford":
			return "金币不足"
		"stash_full":
			return "装备暂存已满"
		"empty_slot":
			return "已购入"
	return "无法购买"


func _day_event() -> void:
	_battle_root.visible = true
	_battle.set_world_backdrop_mode(true)
	_placeholder_screen.show_placeholder(
		MapNodeType.Type.EVENT,
		"（占位）事件内容尚未实装，点击继续进入今天的最后一场战斗。",
	)
