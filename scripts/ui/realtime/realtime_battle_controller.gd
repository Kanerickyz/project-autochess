class_name RealtimeBattleController
extends Control
## 竖屏实时战斗关卡：准备抽选入角色槽 → 开战纯观战（见 Features/PLAYER.md / COMBAT.md）。
## 逻辑由 RealtimeCombatSim 固定步推进；本节点只做流程、输入与 HUD。

signal encounter_completed(won: bool)
signal phase_changed(phase: Phase)
## 战斗刚分出胜负（结算遮罩出现时）；encounter_completed 在玩家点“继续”后才发出
signal combat_resolved(won: bool)
## 最终试炼结束：已通过层数（失败时 = 本场胜利波数）。
signal final_trial_floors_recorded(floors: int)
## 招募阶段结束（完成/跳过）；由 Run 接线回地图。
signal recruit_finished(kept_changes: bool)
signal enchant_finished(did_fuse: bool)
## 地图商店离开回地图。
signal map_shop_finished

enum Phase { IDLE, PREPARE, COMBAT, RESULT, RECRUIT, ENCHANT, MAP_SHOP }

const HINT_SECONDS := 2.0
const NO_CELL := Vector2i(-1, -1)
const DEFAULT_BOARD_SIZE := Vector2i(5, 8)
const TIER_UNLOCK_TOAST_SCENE := preload("res://scenes/ui/tier_unlock_toast.tscn")
## 0 = 每场随机；非 0 = 固定种子（抽牌、敌人组成与落点、模拟）
@export var rng_seed: int = 0
## 战斗推进倍速（仅表现层；不影响结果）
@export_range(0.25, 8.0, 0.25) var time_scale: float = 1.0
## 胜后半场退出动画秒数；≤0 跳过（测试可用）。
@export_range(0.0, 2.0, 0.05) var half_exit_seconds: float = 0.5
## 招募半场滑入秒数；≤0 瞬切。
@export_range(0.0, 2.0, 0.05) var recruit_enter_seconds: float = 0.45

var last_seed: int = 0

var _deck_state: DeckState
var _economy: RunEconomy
var _level: LevelData
var _encounter: EncounterData
var _tier_index: int = 0
## 层预算抽阵上下文（Run 传入；测试可省略并按 encounter 旗标推断）。
var _floor_index: int = 0
## 地图普通层数（Boss 层 = floor_count+1）；品阶解锁用。敌方 2★ 只数跟玩家二星人数。
var _map_floor_count: int = 15
## 无尽：品阶随 F 单向解锁（不用倒数层）。
var _forward_tier_unlock: bool = false
var _node_type: MapNodeType.Type = MapNodeType.Type.COMBAT


func get_floor_index() -> int:
	return _floor_index


func get_map_floor_count() -> int:
	return _map_floor_count


func set_map_floor_count(count: int) -> void:
	_map_floor_count = maxi(1, count)


func set_forward_tier_unlock(enabled: bool) -> void:
	_forward_tier_unlock = enabled


func get_forward_tier_unlock() -> bool:
	return _forward_tier_unlock


func reset_final_trial_state() -> void:
	_final_trial_active = false
	_final_trial_wave_index = 0
	_final_trial_floors_cleared = 0
	_boss_final_trial_offer = false
	_update_result_action_buttons()


func get_final_trial_floors_cleared() -> int:
	return _final_trial_floors_cleared


var _spawn_budget_config: SpawnBudgetConfig = null
var _board_size: Vector2i = DEFAULT_BOARD_SIZE
var _phase: Phase = Phase.IDLE
var _card_flow: EncounterCardFlow = EncounterCardFlow.new()
var _slots: PrepareSlotBoard = PrepareSlotBoard.new()
## 敌方座位几何（镜像 4×5）；准备预览 / 开战落点用，不存 DeckEntry。
var _enemy_slots: PrepareSlotBoard = PrepareSlotBoard.new()
var _deploy_cap: int = DeckConfig.DEFAULT_DEPLOY_CAP
var _cards: Array[RealtimeHandCard] = []
var _selected_entry_id: int = -1
var _sim: RealtimeCombatSim
var _bus: CombatEventBus
var _won: bool = false
var _last_encounter_elapsed_seconds: float = 0.0
var _floor_gold: int = 0
var _hint_text: String = ""
var _hint_remaining: float = 0.0
## 本 Run 已提示过的最高解锁品阶；部署阶段新档出现时播 toast。
var _announced_max_tier: int = 1
var _tier_toast_wrap: CenterContainer
var _tier_toast: TierUnlockToast
var _enemy_spawns: Array = []
var _encounter_rng: RandomNumberGenerator
## 开战锁阵阶段：部署/开战技能只播动画·UI，不走行动内播报队列。
var _lock_phase_active: bool = false
var _timestop_queue: RealtimeTimestopQueue = RealtimeTimestopQueue.new()
var _combo_tracker: CombatComboTracker = CombatComboTracker.new()
var _combo_hud: ComboCounterHud
## 正在执行「先卡再结算」的第二拍；ON_EFFECT_RESOLVED 只捕获 payload，不再入队。
var _resolving_presented_skill: bool = false
var _last_resolved_payload: CombatEventPayload = null
## 胜后半场退出后保留 slide，供招募同屏滑入（不重置边框/草地）。
var _preserve_half_slide_for_recruit: bool = false
var _run_stat_ledger: RunStatLedger
var _stat_collector: RunCombatStatCollector = RunCombatStatCollector.new()
var _recruit_session: RecruitSession
var _recruit_team_slots: PrepareSlotBoard = PrepareSlotBoard.new()
var _recruit_hud: Control
var _recruit_title: Label
var _recruit_hint: Label
var _recruit_gold: Label
var _recruit_seat: Label
var _recruit_refresh_btn: Button
var _recruit_reset_btn: Button
var _recruit_skip_btn: Button
var _recruit_finish_btn: Button
var _recruit_selected_candidate: int = -1
var _recruit_selected_replace_id: int = -1
var _recruit_animating: bool = false
## 待播三合一演出（DeckState.triple_merged 入队，招募 sync 后播放）。
var _pending_merge_fx: Array = []
## 招募半场道具行（生命/力量药水、旗帜）；不挂准备阶段。
var _recruit_shop: RecruitShopService = RecruitShopService.new()
var _recruit_shop_config: RecruitShopConfig = null
var _recruit_pending_item_slot: int = -1
var _enchant_session: EnchantSession = EnchantSession.new()
var _enchant_ui: EnchantBattleExtension = EnchantBattleExtension.new()
var _enchant_slots: PrepareSlotBoard = PrepareSlotBoard.new()
var _enchant_sandbox_mode: bool = false
var _map_shop_service: MapShopService
var _map_shop_ui: MapShopBattleExtension = MapShopBattleExtension.new()
## 主菜单战斗沙盒：无地图/商店/招募/层金；胜负不写远征统计。
var _combat_sandbox_mode: bool = false
## 沙盒粘贴的敌方覆盖（非空则跳过预算抽阵）；元素为 Dictionary unit_id/seat/level。
var _sandbox_enemy_override: Array = []
## 观战录音机：动与动之间冻结；下一动只放一动；上一动真倒带。
var _tape_paused: bool = false
var _tape_step_once: bool = false
var _tape_pause_requested: bool = false
var _tape_boundary_pending: bool = false
var _tape_completed_turns: int = 0
var _tape_rewinding: bool = false
var _tape_stats_disabled: bool = false
## 时停/出击演出卡住时的墙钟看门狗（秒）；超时强制收拍，避免 Web 端假死。
const PRESENTATION_STUCK_SECONDS := 3.5
var _presentation_block_elapsed: float = 0.0
## Boss 胜后可选最终试炼；进行中阵容锁定、连续波次。
var _final_trial_active: bool = false
var _final_trial_wave_index: int = 0
var _final_trial_floors_cleared: int = 0
var _boss_final_trial_offer: bool = false

@onready var _encounter_label: Label = %EncounterLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _pop_label: Label = %PopLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _arena: RealtimeArenaView = %ArenaView
@onready var _hand_row: HBoxContainer = %HandRow
@onready var _start_button: Button = %StartButton
@onready var _result_overlay: Control = %ResultOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _result_detail: Label = %ResultDetail
@onready var _continue_button: Button = %ContinueButton
@onready var _final_trial_button: Button = %FinalTrialButton
@onready var _dock: Control = $Layout/Dock
@onready var _hud: Control = $Layout/Hud
@onready var _solid_bg: CanvasItem = $Background

## 地图罩在关卡世界上：藏 HUD/底栏，只留竞技场底图，避免黑屏跳转。
var _world_backdrop_mode: bool = false

## 旧 Dock 备战按钮行（已弃用主表现；恒隐藏，备战改画在 Arena 半场下方）。
var _bench_row: HBoxContainer
var _bench_buttons: Array[Button] = []
## Arena 备战格板（虚拟一行，与 DeckState 备战条目同步）。
var _bench_slots := PrepareSlotBoard.new()

var _refresh_button: Button
## 观战倍速档位；由录音机中键与暂停合成循环：1×→2×→3×→暂停→1×。
const _SPEED_STEPS: Array[float] = [1.0, 2.0, 3.0]
## 准备阶段：复制/粘贴/开战横排（开战更宽）。
var _prepare_action_row: HBoxContainer
## 准备阶段：复制本场布局（正式 + 沙盒）。
var _copy_layout_button: Button
## 沙盒准备：粘贴布局。
var _paste_layout_button: Button
## 沙盒粘贴布局：自定义叠层（非 AcceptDialog，避免移动端底部按钮被裁切）。
var _paste_dialog: Control
var _paste_edit: TextEdit
var _paste_apply_button: Button
var _paste_cancel_button: Button
## 观战录音机三键（中键＝倍速/暂停合一）。
var _tape_row: HBoxContainer
var _tape_prev_button: Button
var _tape_play_speed_button: Button
var _tape_next_button: Button
const DEFAULT_SANDBOX_ENEMY_ID := "enemy_skeleton"
const DEFAULT_SANDBOX_ENCOUNTER := "res://resources/encounters/realtime/rt_combat_01.tres"
const FINAL_TRIAL_DEV_UNIT := preload("res://resources/units/enemies/enemy_final_trial_dev.tres")
## 准备横排：开战相对复制/粘贴的宽度比。
const _PREPARE_START_STRETCH := 2.0
const _PREPARE_SECONDARY_STRETCH := 1.0


func _ready() -> void:
	_arena.board_pressed.connect(_on_board_pressed)
	_arena.card_dropped.connect(_on_card_dropped)
	_arena.recruit_drop.connect(_on_recruit_drop)
	_arena.recruit_drop_rejected.connect(_on_recruit_drop_rejected)
	_arena.recruit_candidate_pressed.connect(_on_recruit_candidate_pressed)
	_arena.recruit_team_pressed.connect(_on_recruit_team_pressed)
	_arena.recruit_sell.connect(_on_recruit_sell)
	_arena.recruit_candidate_lock.connect(_on_recruit_candidate_lock)
	_arena.recruit_team_seat_drop.connect(_on_recruit_team_seat_drop)
	_arena.recruit_team_bench_drop.connect(_on_recruit_team_bench_drop)
	_arena.recruit_empty_seat_pressed.connect(_on_recruit_empty_seat_pressed)
	_arena.recruit_item_pressed.connect(_on_recruit_item_pressed)
	_arena.recruit_item_drop.connect(_on_recruit_item_drop)
	_arena.enchant_forge_drop.connect(_on_enchant_forge_drop)
	_arena.enchant_team_seat_drop.connect(_on_enchant_team_seat_drop)
	_arena.map_shop_offer_drop.connect(_on_map_shop_offer_drop)
	_arena.map_shop_team_seat_drop.connect(_on_map_shop_team_seat_drop)
	_arena.prepare_team_seat_drop.connect(_on_prepare_team_seat_drop)
	_arena.prepare_team_bench_drop.connect(_on_prepare_team_bench_drop)
	_arena.bench_pressed.connect(_on_bench_pressed)
	_arena.bench_empty_pressed.connect(_on_bench_empty_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	if _final_trial_button != null:
		_final_trial_button.pressed.connect(_on_final_trial_pressed)
		_final_trial_button.visible = false
	_ensure_refresh_button()
	_ensure_prepare_action_row()
	_ensure_layout_clipboard_buttons()
	_ensure_tape_controls()
	_ensure_recruit_hud()
	_ensure_bench_row()
	_ensure_tier_unlock_toast()
	_ensure_combo_hud()
	_enchant_ui.setup(self)
	_enchant_session.session_finished.connect(_on_enchant_session_finished)
	_map_shop_ui.setup(self)
	_result_overlay.visible = false
	if _start_button != null:
		_start_button.visible = false
	if _prepare_action_row != null:
		_prepare_action_row.visible = false
	_refresh_hud()


func _exit_tree() -> void:
	_teardown_sim()
	_disconnect_economy()


func _process(delta: float) -> void:
	if _hint_remaining > 0.0:
		_hint_remaining -= delta
		if _hint_remaining <= 0.0:
			_hint_text = ""
	if _arena != null:
		## 观战加速：缩短单动格步/出手与反馈寿命；不改行动序与已结算数值。
		_arena.presentation_time_scale = time_scale
	if _phase == Phase.COMBAT and _sim != null:
		## 行动内播报：先卡再结算插入待执行队列；与行动队列串行（COMBAT_FEEDBACK §5.2）。
		_tick_combat_presentation(delta)
		if _arena != null:
			_arena.queue_redraw()
	_refresh_hud()
	_refresh_cards()


# --- 公开接口 ---


func set_run_stat_ledger(ledger: RunStatLedger) -> void:
	_run_stat_ledger = ledger
	_stat_collector.configure(ledger)


func set_combat_sandbox_mode(enabled: bool) -> void:
	_combat_sandbox_mode = enabled
	if enabled:
		_run_stat_ledger = null
		_stat_collector.configure(null)


func is_combat_sandbox_mode() -> bool:
	return _combat_sandbox_mode


func setup(deck_state: DeckState, economy: RunEconomy, level: LevelData) -> void:
	_disconnect_economy()
	_disconnect_deck_merge()
	_deck_state = deck_state
	_economy = economy
	_level = level
	_connect_deck_merge()
	if _economy != null:
		_economy.gold_changed.connect(_on_gold_changed)
	_refresh_hud()


func _connect_deck_merge() -> void:
	if _deck_state == null:
		return
	if not _deck_state.triple_merged.is_connected(_on_deck_triple_merged):
		_deck_state.triple_merged.connect(_on_deck_triple_merged)


func _disconnect_deck_merge() -> void:
	if _deck_state == null:
		return
	if _deck_state.triple_merged.is_connected(_on_deck_triple_merged):
		_deck_state.triple_merged.disconnect(_on_deck_triple_merged)


func _on_deck_triple_merged(product: DeckEntry, consumed_seats: Array) -> void:
	if product == null:
		return
	_pending_merge_fx.append({
		"seat": product.seat_index,
		"seats": consumed_seats.duplicate(),
		"unit_id": product.get_unit_id(),
		"level": product.level,
	})


## Run 地图阶段：保留竞技场背景作世界底图，隐藏战斗 HUD。
func set_world_backdrop_mode(enabled: bool) -> void:
	_world_backdrop_mode = enabled
	if _solid_bg != null:
		## 地图自带同款背景；关掉纯色底以免发灰。
		_solid_bg.visible = not enabled
	if _hud != null:
		_hud.visible = not enabled
	if _dock != null:
		_dock.visible = not enabled
	if _result_overlay != null and enabled:
		_result_overlay.visible = false
	if _arena != null:
		_arena.modulate = Color(1, 1, 1, 0.42) if enabled else Color.WHITE
		_arena.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
		)
	if enabled:
		_teardown_sim()
		if _arena != null:
			_arena.clear_fx()
			_arena.queue_redraw()


## 注入层预算配置（测试用）；null 时按 SpawnBudgetConfig.load_or_default()。
func set_spawn_budget_config(config: SpawnBudgetConfig) -> void:
	_spawn_budget_config = config


## 进入遭遇：按持久占位载入友方座位 → PREPARE（可换座写回）；无准备刷新手牌。
## floor_index / node_type 供层预算抽阵；node_type < 0 时按 encounter.is_boss/is_elite 推断。
func start_encounter(
	encounter: EncounterData,
	tier_index: int,
	floor_index: int = 0,
	node_type: int = -1,
) -> void:
	if _deck_state == null or _level == null:
		push_error("RealtimeBattleController.start_encounter: call setup() first")
		return
	if encounter == null or encounter.wave == null:
		push_error("RealtimeBattleController.start_encounter: encounter or encounter.wave is null")
		return
	_teardown_sim()
	_encounter = encounter
	_tier_index = tier_index
	_floor_index = maxi(0, floor_index)
	_node_type = _resolve_node_type(encounter, node_type)
	_won = false
	_floor_gold = 0
	_selected_entry_id = -1
	_lock_phase_active = false
	_result_overlay.visible = false
	_board_size = encounter.get_board_size(_level.get_board_size())

	last_seed = rng_seed if rng_seed != 0 else randi()
	_encounter_rng = RandomNumberGenerator.new()
	_encounter_rng.seed = last_seed
	print(
		"RealtimeBattle: encounter=%s tier=%d floor=%d node=%s seed=%d board=%s"
		% [encounter.id, tier_index, _floor_index, MapNodeType.display_name(_node_type), last_seed, _board_size]
	)

	var config := _deck_state.get_config()
	_card_flow.configure_from_deck_config(config)
	## 本版准备无手牌抽选：清牌区后按 DeckState 持久占位入座。
	_card_flow.clear()
	var seat_rows := config.get_seat_rows() if config != null else DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := config.get_seat_cols() if config != null else DeckConfig.DEFAULT_SEAT_COLS
	## 全体上场：准备可入座人数 = 队伍席位上限（max_size ∩ 座位网格）。
	var deck_cap := _deck_state.get_max_size()
	var seat_grid := _deck_state.get_slot_count()
	if deck_cap > 0 and seat_grid > 0:
		_deploy_cap = mini(deck_cap, seat_grid)
	elif deck_cap > 0:
		_deploy_cap = deck_cap
	elif seat_grid > 0:
		_deploy_cap = seat_grid
	else:
		_deploy_cap = config.get_deploy_cap() if config != null else DeckConfig.DEFAULT_DEPLOY_CAP
	_slots.configure_grid(seat_rows, seat_cols, _board_size, false)
	_enemy_slots.configure_grid(seat_rows, seat_cols, _board_size, true)
	if _sandbox_enemy_override.is_empty():
		_enemy_spawns = _roll_enemy_spawns(_encounter_rng)
	else:
		_enemy_spawns = _build_enemy_spawns_from_override(_sandbox_enemy_override)
	_load_persistent_seats_into_prepare()
	_reset_tape_state()

	_arena.board_size = _board_size
	_arena.sim = null
	_arena.clear_fx()
	_arena.clear_recruit_mode()
	_arena.clear_map_shop_mode()
	_arena.clear_enchant_mode()
	_arena.reset_half_slide()
	_arena.prepare_slots = _slots
	_arena.enemy_slots = _enemy_slots
	_arena.enemy_previews = _build_enemy_previews(_enemy_spawns)
	_arena.placement_active = false
	_preserve_half_slide_for_recruit = false
	_hide_recruit_hud()
	_map_shop_ui.hide_hud()
	_enchant_ui.hide_hud()
	_restore_combat_chrome_after_recruit()
	_rebuild_cards()
	_set_phase(Phase.PREPARE)
	_maybe_show_tier_unlock_toast()


func get_phase() -> Phase:
	return _phase


func get_sim() -> RealtimeCombatSim:
	return _sim


func get_last_encounter_elapsed_seconds() -> float:
	return _last_encounter_elapsed_seconds


func get_arena() -> RealtimeArenaView:
	return _arena


func get_board_size() -> Vector2i:
	return _board_size


func get_dock() -> Control:
	return _dock


func flash_hint(text: String) -> void:
	_show_hint(text)


func get_hand() -> Array[DeckEntry]:
	return _card_flow.get_hand()


func get_bench_slot_board() -> PrepareSlotBoard:
	return _bench_slots


func get_slot_board() -> PrepareSlotBoard:
	return _slots


func get_enemy_slot_board() -> PrepareSlotBoard:
	return _enemy_slots


func get_refresh_remaining() -> int:
	return _card_flow.get_refresh_remaining()


## 号令已删除；保留 0 返回以免旧调用报错。
func get_command_current() -> float:
	return 0.0


func get_command_max() -> float:
	return 0.0


func get_pending_enemy_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for spawn in _enemy_spawns:
		positions.append(spawn["position"])
	return positions


func get_deploy_cap() -> int:
	return _deploy_cap


func get_timestop_queue_size() -> int:
	return _timestop_queue.size() if _timestop_queue != null else 0


func get_combo_tracker() -> CombatComboTracker:
	return _combo_tracker


func _ensure_combo_hud() -> void:
	if _combo_hud != null or _arena == null:
		return
	_combo_hud = ComboCounterHud.new()
	_combo_hud.name = "ComboCounterHud"
	_arena.add_child(_combo_hud)


func _reset_combo_display() -> void:
	_combo_tracker.reset()
	if _combo_hud != null:
		_combo_hud.set_combo_count(0)


func _refresh_combo_hud_from_tracker() -> void:
	if _combo_hud == null:
		return
	_combo_hud.set_combo_count(_combo_tracker.get_display_value())


func is_timestop_blocking() -> bool:
	return _timestop_queue != null and _timestop_queue.is_blocking()


func get_max_board_units() -> int:
	## 本场上场人数上限（deploy_cap）；空座可多于上限。
	return get_deploy_cap()


func get_player_unit_count() -> int:
	return _sim.count_alive(UnitInstance.Team.PLAYER) if _sim != null else 0


func is_entry_on_field(entry_id: int) -> bool:
	if _phase == Phase.PREPARE:
		return _slots.find_slot_by_entry(entry_id) >= 0
	return _sim != null and _sim.find_unit_by_deck_entry(entry_id) != null


## 准备：把手牌放入空角色座位（遗留；主路径已无手牌入座）。成功写回持久占位。
func try_assign_to_slot(entry_id: int, cell: Vector2i) -> String:
	if _phase != Phase.PREPARE:
		return "当前不可入座"
	if not _card_flow.is_in_hand(entry_id):
		return "该牌不在手牌中"
	if not _slots.can_assign_more(_deploy_cap):
		var msg := "已达上场人数上限" if not _slots.is_full() else "座位已满"
		_show_hint(msg)
		return msg
	if cell != NO_CELL and not BoardHalf.is_player_deploy_cell(cell, _board_size.y):
		_show_hint("请放到我半场角色座位")
		return "请放到我半场角色座位"
	var slot_index := _slots.find_slot_at_cell(cell)
	if slot_index < 0:
		slot_index = _slots.find_nearest_empty_slot(cell)
		if slot_index >= 0:
			var sc := _slots.get_cell(slot_index)
			if absi(sc.x - cell.x) + absi(sc.y - cell.y) > 4:
				_show_hint("请放到角色座位")
				return "请放到角色座位"
	if slot_index < 0:
		_show_hint("座位已满")
		return "座位已满"
	if not _slots.is_empty(slot_index):
		_show_hint("该座已有人")
		return "该座已有人"
	var entry := _card_flow.try_take_from_hand(entry_id)
	if entry == null:
		_show_hint("无法入座")
		return "无法入座"
	if not _slots.try_assign(slot_index, entry):
		_card_flow.try_return_to_hand(entry)
		_show_hint("无法入座")
		return "无法入座"
	if _deck_state != null:
		_deck_state.assign_seat(entry_id, slot_index)
	if _selected_entry_id == entry_id:
		_set_selected(-1)
	_sync_slot_visuals()
	_rebuild_cards()
	return ""


## 准备换座：将 from 座成员移到 to 座（空则移入，有人则互换）；写回 DeckState。
func try_swap_prepare_seats(from_slot: int, to_slot: int) -> bool:
	if _final_trial_active:
		return false
	if _phase != Phase.PREPARE or _deck_state == null:
		return false
	if from_slot < 0 or to_slot < 0 or from_slot == to_slot:
		return false
	var entry := _slots.get_entry(from_slot)
	if entry == null:
		return false
	if not _deck_state.swap_seats(entry.entry_id, to_slot):
		return false
	_load_persistent_seats_into_prepare()
	_set_selected(-1)
	_sync_slot_visuals()
	_rebuild_cards()
	return true


## 备战 → 空座位（准备/招募）。
func try_move_bench_to_seat(entry_id: int, target_seat: int) -> bool:
	if _final_trial_active:
		return false
	if _deck_state == null:
		return false
	if _phase != Phase.PREPARE and _phase != Phase.RECRUIT:
		return false
	var entry := _deck_state.get_entry(entry_id)
	if entry == null or entry.seat_index >= 0:
		return false
	if target_seat < 0 or target_seat >= _deck_state.get_slot_count():
		return false
	if not _deck_state.is_seat_free(target_seat):
		return false
	if not _deck_state.assign_seat(entry_id, target_seat):
		return false
	_set_selected(-1)
	if _phase == Phase.RECRUIT:
		_sync_recruit_arena()
		_refresh_recruit_hud()
	else:
		_load_persistent_seats_into_prepare()
		_sync_slot_visuals()
		_rebuild_cards()
		_refresh_hud()
	return true


## 点备战：有空上场席则自动落到首个空座；否则失败。
func try_auto_deploy_bench(entry_id: int) -> bool:
	if _deck_state == null:
		return false
	if not _is_bench_entry(entry_id):
		return false
	if not _deck_state.can_seat_more():
		return false
	var empty := _deck_state.find_first_empty_seat()
	if empty < 0:
		return false
	return try_move_bench_to_seat(entry_id, empty)


## 已入座 → 备战（准备/招募）；备战满失败。战斗观战不可用。
func try_move_seat_to_bench(entry_id: int) -> bool:
	if _final_trial_active:
		return false
	if _deck_state == null:
		return false
	if _phase != Phase.PREPARE and _phase != Phase.RECRUIT:
		return false
	var entry := _deck_state.get_entry(entry_id)
	if entry == null or entry.seat_index < 0:
		return false
	var ok := false
	if _phase == Phase.RECRUIT and _recruit_session != null:
		ok = _recruit_session.try_move_to_bench(entry_id)
	else:
		ok = _deck_state.try_move_seat_to_bench(entry_id)
	if not ok:
		return false
	_set_selected(-1)
	if _phase == Phase.RECRUIT:
		_sync_recruit_arena()
		_refresh_recruit_hud()
	else:
		_load_persistent_seats_into_prepare()
		_sync_slot_visuals()
		_rebuild_cards()
		_refresh_hud()
	_refresh_bench_row()
	return true


func _is_bench_entry(entry_id: int) -> bool:
	if _deck_state == null or entry_id < 0:
		return false
	var entry := _deck_state.get_entry(entry_id)
	return entry != null and entry.seat_index < 0


func _is_seated_entry(entry_id: int) -> bool:
	if _deck_state == null or entry_id < 0:
		return false
	var entry := _deck_state.get_entry(entry_id)
	return entry != null and entry.seat_index >= 0


func _is_pointer_over_bench_row() -> bool:
	## 主路径：Arena 备战格；兼容旧 Dock 行若仍可见。
	if _arena != null and _arena.bench_visible and _arena.is_pointer_over_bench():
		return true
	if _bench_row == null or not is_instance_valid(_bench_row) or not _bench_row.visible:
		return false
	return _bench_row.get_global_rect().has_point(_bench_row.get_global_mouse_position())


## 准备：拖角色落到目标座（空座移入 / 占座互换）。
func _on_prepare_team_seat_drop(entry_id: int, target_seat: int) -> void:
	if _final_trial_active:
		return
	if _phase != Phase.PREPARE or _deck_state == null:
		return
	if _is_bench_entry(entry_id):
		if try_move_bench_to_seat(entry_id, target_seat):
			return
		_show_hint("备战只能上到空座位")
		return
	var from_i := _slots.find_slot_by_entry(entry_id)
	if from_i < 0:
		return
	if not try_swap_prepare_seats(from_i, target_seat):
		_show_hint("无法换座")


## 准备：拖已入座角色松手落在备战格 → 入备战。
func _on_prepare_team_bench_drop(entry_id: int) -> void:
	if _final_trial_active:
		return
	if _phase != Phase.PREPARE or _deck_state == null:
		return
	if not _is_seated_entry(entry_id):
		return
	if try_move_seat_to_bench(entry_id):
		_show_hint("已移入备战")
		return
	_show_hint("备战已满")


## 点备战已占格：有空位则自动上阵；上场满则选中（可再拖/点空座）；招募药水可点备战结算。
func _on_bench_pressed(entry_id: int) -> void:
	if entry_id < 0:
		return
	if _phase == Phase.RECRUIT:
		if _recruit_animating:
			return
		if _recruit_pending_item_slot >= 0:
			_try_apply_recruit_potion(_recruit_pending_item_slot, entry_id)
			return
		## 已选入座 → 点备战下阵（与准备一致）。
		if _selected_entry_id >= 0 and _is_seated_entry(_selected_entry_id):
			if try_move_seat_to_bench(_selected_entry_id):
				if _recruit_hint != null:
					_recruit_hint.text = "已移入备战"
				return
			if _recruit_hint != null:
				_recruit_hint.text = "备战已满"
			return
		if try_auto_deploy_bench(entry_id):
			if _recruit_hint != null:
				_recruit_hint.text = "已上阵"
			return
		_set_selected(-1 if _selected_entry_id == entry_id else entry_id)
		_refresh_bench_row()
		if _recruit_hint != null:
			_recruit_hint.text = "上场已满：可拖到空座或先腾位"
		return
	if _phase != Phase.PREPARE:
		return
	## 已选入座 → 点备战格下阵。
	if _selected_entry_id >= 0 and _is_seated_entry(_selected_entry_id):
		if try_move_seat_to_bench(_selected_entry_id):
			_show_hint("已移入备战")
			return
		_show_hint("备战已满")
		return
	if try_auto_deploy_bench(entry_id):
		_show_hint("已上阵")
		return
	_set_selected(-1 if _selected_entry_id == entry_id else entry_id)
	_refresh_bench_row()
	_show_hint("上场已满：可拖到空座或先腾位")


## 点备战空格：接收已选入座角色下阵。
func _on_bench_empty_pressed(_slot_index: int) -> void:
	if _phase != Phase.PREPARE and _phase != Phase.RECRUIT:
		return
	if _phase == Phase.RECRUIT and _recruit_animating:
		return
	if _selected_entry_id < 0 or not _is_seated_entry(_selected_entry_id):
		return
	if try_move_seat_to_bench(_selected_entry_id):
		if _phase == Phase.PREPARE:
			_show_hint("已移入备战")
		elif _recruit_hint != null:
			_recruit_hint.text = "已移入备战"
		return
	if _phase == Phase.PREPARE:
		_show_hint("备战已满")
	elif _recruit_hint != null:
		_recruit_hint.text = "备战已满"


## 准备：从槽收回到手牌（遗留测试路径；主路径改为换座不收回）。
func try_recall_slot(slot_index: int) -> bool:
	if _phase != Phase.PREPARE:
		return false
	var entry := _slots.get_entry(slot_index)
	if entry == null:
		return false
	if _card_flow.get_hand().size() >= _card_flow.hand_width:
		_show_hint("手牌已满，无法收回")
		return false
	entry = _slots.try_recall(slot_index)
	if entry == null:
		return false
	if not _card_flow.try_return_to_hand(entry):
		_slots.try_assign(slot_index, entry)
		_show_hint("手牌已满，无法收回")
		return false
	if _deck_state != null:
		_deck_state.clear_seat(entry.entry_id)
	_sync_slot_visuals()
	_rebuild_cards()
	return true


## 点击格子换座目标（若点在座位上）。
func try_recall_at(tile_pos: Vector2) -> bool:
	if _phase != Phase.PREPARE:
		return false
	var cell := Vector2i(floori(tile_pos.x), floori(tile_pos.y))
	var slot_index := _slots.find_slot_at_cell(cell)
	if slot_index < 0:
		return false
	## 主路径：点座位选中 / 换座，不再收回手牌。
	if _selected_entry_id >= 0:
		var from_i := _slots.find_slot_by_entry(_selected_entry_id)
		if from_i >= 0:
			return try_swap_prepare_seats(from_i, slot_index)
	var seated := _slots.get_entry(slot_index)
	if seated != null:
		_set_selected(seated.entry_id)
		return true
	return false


## 准备刷新手牌已取消（PLAYER §5 / 本版无遭遇内抽牌）。
func try_refresh_hand() -> bool:
	_show_hint("准备阶段不可刷新手牌")
	return false


## 遗留战中出牌接口：开战后天禁用，恒失败。
func try_deploy(_entry_id: int, _cell: Vector2i) -> String:
	_show_hint("开战后不能出牌")
	return "开战后不能出牌"


## 至少 1 槽有人时可开战：生成友方、未入槽回抽、刷怪、进入 COMBAT。
func try_start_combat() -> bool:
	if _phase != Phase.PREPARE:
		return _phase == Phase.COMBAT and _sim != null
	if _slots.occupied_count() < 1:
		_show_hint("至少安排 1 名角色才能开战")
		return false
	if _combat_sandbox_mode and _enemy_spawns.is_empty():
		_show_hint("双方至少各 1 人方可开战")
		return false
	_begin_combat_from_prepare()
	return true


## 复制整局阵容（仅友方）；供远征统计 / 外部调用。
func copy_roster_to_clipboard() -> String:
	if _deck_state == null:
		return "无队伍可复制"
	var text := BattleLayoutClipboard.encode_roster(
		_deck_state.get_entries(),
		_deck_state.get_max_size(),
	)
	DisplayServer.clipboard_set(text)
	_show_hint("已复制阵容")
	return ""


## 复制本场布局（友+敌+遭遇+种子）；准备阶段可用。
func copy_layout_to_clipboard() -> String:
	if _deck_state == null:
		return "无布局可复制"
	var enemy_rows: Array = []
	for spawn in _enemy_spawns:
		var unit: UnitInstance = spawn.get("unit")
		var uid := ""
		if unit != null and unit.unit_data != null:
			uid = unit.unit_data.id
		if uid.is_empty():
			continue
		enemy_rows.append({
			"unit_id": uid,
			"seat": int(spawn.get("seat_index", -1)),
			"level": unit.level if unit != null else 1,
		})
	var enc := BattleLayoutClipboard.encounter_type_from_node(_node_type)
	var text := BattleLayoutClipboard.encode_layout(
		_deck_state.get_entries(),
		_deck_state.get_max_size(),
		enemy_rows,
		last_seed,
		enc,
	)
	DisplayServer.clipboard_set(text)
	_show_hint("已复制本场布局")
	return ""


## 粘贴布局：始终弹出文本框（预填系统剪贴板若有），避免 iOS/无剪贴板时点按无反馈。
func paste_layout_from_clipboard() -> String:
	var text := ""
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		text = str(DisplayServer.clipboard_get())
	_show_hint("请粘贴布局文本后点「应用」")
	_show_paste_layout_dialog(text)
	return ""


func apply_layout_clipboard_text(text: String, open_editor_on_fail: bool = true) -> String:
	var parsed := BattleLayoutClipboard.parse(text)
	if not parsed.ok or parsed.payload == null:
		var err := parsed.error if not parsed.error.is_empty() else "粘贴失败"
		_show_hint(err)
		## 格式无效时打开文本框改完再确认（对话框内确认失败不再嵌套弹窗）。
		if open_editor_on_fail:
			_show_paste_layout_dialog(text)
		return err
	return _apply_layout_payload(parsed.payload)


## 沙盒：进入默认弱遭遇准备（可先空队再粘贴）。
func enter_combat_sandbox(tier_index: int = 0) -> void:
	_combat_sandbox_mode = true
	_run_stat_ledger = null
	_stat_collector.configure(null)
	_sandbox_enemy_override.clear()
	var encounter := load(DEFAULT_SANDBOX_ENCOUNTER) as EncounterData
	if encounter == null:
		push_error("RealtimeBattleController.enter_combat_sandbox: missing default encounter")
		return
	start_encounter(encounter, tier_index, 0, MapNodeType.Type.COMBAT)
	## 默认弱敌：若队伍已有人则保留抽阵；空队时仍放一只弱敌便于粘贴后开战。
	if _enemy_spawns.is_empty():
		_sandbox_enemy_override = [{"unit_id": DEFAULT_SANDBOX_ENEMY_ID, "seat": 0, "level": 1}]
		_enemy_spawns = _build_enemy_spawns_from_override(_sandbox_enemy_override)
		if _arena != null:
			_arena.enemy_previews = _build_enemy_previews(_enemy_spawns)
	_refresh_hud()
	_refresh_cards()
	_sync_slot_visuals()


## 沙盒结算后重开本场准备（保留当前队伍与敌方覆盖）。
func restart_sandbox_prepare() -> void:
	if not _combat_sandbox_mode:
		return
	_teardown_sim()
	_result_overlay.visible = false
	_won = false
	_reset_tape_state()
	var encounter := _encounter
	if encounter == null:
		encounter = load(DEFAULT_SANDBOX_ENCOUNTER) as EncounterData
	var tier := _tier_index
	## 保留 _sandbox_enemy_override 与 deck；重进准备。
	start_encounter(encounter, tier, _floor_index, int(_node_type))


## 结算后“继续”：胜则先播半场退出，再释放本场并发出 encounter_completed。
## 无 await：半场演出用 Tween 回调，避免 headless 测试卡在空协程上。
## 胜场保留半场 slide，供随后 enter_recruit 同屏滑入（草地/边框不断）。
func continue_after_result() -> void:
	if _phase != Phase.RESULT:
		return
	if _boss_final_trial_offer:
		_boss_final_trial_offer = false
		_update_result_action_buttons()
		_complete_continue(true)
		return
	if _final_trial_active:
		if _won:
			_advance_final_trial_after_wave_win()
		else:
			_finish_final_trial_after_loss()
		return
	var won := _won
	_result_overlay.visible = false
	_preserve_half_slide_for_recruit = won
	if won and half_exit_seconds > 0.001 and _arena != null:
		_play_half_field_exit_then_continue(won, half_exit_seconds)
		return
	_complete_continue(won)


func _complete_continue(won: bool) -> void:
	if _combat_sandbox_mode:
		_teardown_sim()
		_result_overlay.visible = false
		_reset_tape_state()
		restart_sandbox_prepare()
		encounter_completed.emit(won)
		return
	_teardown_sim()
	_card_flow.clear()
	_slots.clear()
	_enemy_slots.clear()
	_enemy_spawns.clear()
	if _arena != null:
		_arena.sim = null
		_arena.enemy_previews = []
		_arena.prepare_slots = null
		_arena.enemy_slots = null
		_arena.placement_active = false
	if _preserve_half_slide_for_recruit and won:
		## 衔接到招募：不闪准备手牌/Dock；半场停在屏外，草地与外框仍在。
		_hide_combat_chrome_for_recruit()
		_set_phase(Phase.IDLE)
		## 顶栏提前切到招募语义，避免「等待 / 入座 0」闪一下。
		if _encounter_label != null:
			_encounter_label.text = "招募"
		if _phase_label != null:
			_phase_label.text = "招募"
			_phase_label.modulate = Color.WHITE
		if _pop_label != null:
			_pop_label.text = ""
		if _arena != null:
			var travel := _half_slide_travel()
			_arena.set_half_slide_offscreen(travel)
			_arena.queue_redraw()
	else:
		_rebuild_cards()
		_set_phase(Phase.IDLE)
		if _arena != null:
			_arena.reset_half_slide()
			_arena.clear_recruit_mode()
	encounter_completed.emit(won)


func _play_half_field_exit_then_continue(won: bool, seconds: float) -> void:
	## 退场开始即收起战斗 Dock，只留外框+草地+半场内容在变。
	_hide_combat_chrome_for_recruit()
	_arena.reset_half_slide()
	var travel := _half_slide_travel()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_arena, "enemy_half_slide_y", -travel, seconds)
	tween.tween_property(_arena, "ally_half_slide_y", travel, seconds)
	## 属性 Tween 时手动 redraw
	tween.tween_method(_redraw_arena_half_slide, 0.0, 1.0, seconds)
	tween.chain().tween_callback(_complete_continue.bind(won))


func _redraw_arena_half_slide(_t: float) -> void:
	if _arena != null:
		_arena.queue_redraw()


func _on_final_trial_pressed() -> void:
	if _phase != Phase.RESULT or not _boss_final_trial_offer:
		return
	_boss_final_trial_offer = false
	_update_result_action_buttons()
	_result_overlay.visible = false
	_begin_final_trial_from_boss()


func _begin_final_trial_from_boss() -> void:
	_final_trial_active = true
	_final_trial_wave_index = 0
	_final_trial_floors_cleared = 0
	_preserve_half_slide_for_recruit = false
	_teardown_sim()
	_reset_tape_state()
	_prepare_final_trial_wave()
	call_deferred("try_start_combat")


func _prepare_final_trial_wave() -> void:
	_enemy_spawns = _build_final_trial_enemy_spawns(_final_trial_wave_index)
	if _arena != null:
		_arena.sim = null
		_arena.enemy_previews = _build_enemy_previews(_enemy_spawns)
		_arena.prepare_slots = _slots
		_arena.enemy_slots = _enemy_slots
		_arena.placement_active = false
		_arena.bench_interactive = false
		_arena.bench_visible = false
		_arena.reset_half_slide()
	_load_persistent_seats_into_prepare()
	_set_phase(Phase.PREPARE)
	_refresh_hud()


func _build_final_trial_enemy_spawns(wave_index: int) -> Array:
	var spawns: Array = []
	if _enemy_slots == null or FINAL_TRIAL_DEV_UNIT == null:
		return spawns
	var stat := FinalTrialBalance.stat_for_wave(wave_index)
	var seat_fill := SeatLayout.iter_seats_center_out(
		_enemy_slots.seat_rows, _enemy_slots.seat_cols
	)
	var placed := 0
	for seat_i in seat_fill:
		if placed >= FinalTrialBalance.ENEMY_COUNT:
			break
		if seat_i < 0 or seat_i >= _enemy_slots.slot_count:
			continue
		var cell := _enemy_slots.get_cell(seat_i)
		var unit := UnitInstance.from_unit_data(
			FINAL_TRIAL_DEV_UNIT, cell, UnitInstance.Team.ENEMY
		)
		if unit == null or unit.stats == null:
			continue
		unit.stats.attack = stat
		unit.stats.max_hp = stat
		unit.current_hp = stat
		unit.level = 1
		spawns.append({
			"unit": unit,
			"position": _enemy_spawn_visual_position(unit, cell),
			"seat_index": seat_i,
		})
		placed += 1
	return spawns


func _advance_final_trial_after_wave_win() -> void:
	_final_trial_floors_cleared = _final_trial_wave_index + 1
	_final_trial_wave_index += 1
	_result_overlay.visible = false
	_teardown_sim()
	_reset_tape_state()
	_prepare_final_trial_wave()
	call_deferred("try_start_combat")


func _finish_final_trial_after_loss() -> void:
	_final_trial_floors_cleared = _final_trial_wave_index
	final_trial_floors_recorded.emit(_final_trial_floors_cleared)
	_final_trial_active = false
	_result_overlay.visible = false
	_complete_continue(true)


func _should_offer_final_trial_after_boss() -> bool:
	if _combat_sandbox_mode or _final_trial_active:
		return false
	if not _won or _encounter == null or not _encounter.is_boss:
		return false
	return _node_type == MapNodeType.Type.BOSS


func _update_result_action_buttons() -> void:
	if _final_trial_button == null or _continue_button == null:
		return
	_final_trial_button.visible = _boss_final_trial_offer
	if _boss_final_trial_offer:
		_continue_button.text = "继续"
		_final_trial_button.text = "最终试炼"
	elif _final_trial_active and _phase == Phase.RESULT:
		if _won:
			_continue_button.text = "下一层"
		else:
			_continue_button.text = "继续"
		_final_trial_button.visible = false
	elif _combat_sandbox_mode:
		_continue_button.text = "再来一局"
		_final_trial_button.visible = false
	else:
		_continue_button.text = "继续"
		_final_trial_button.visible = false


func _half_slide_travel() -> float:
	if _arena == null:
		return 220.0
	return maxf(_arena.size.y * 0.65, 220.0)


func _bench_slide_travel() -> float:
	if _arena == null:
		return 120.0
	var px := _arena.get_cell_px()
	return px * (RealtimeArenaView.BENCH_GAP_TILES + RealtimeArenaView.BENCH_ROW_TILES + 0.75) + 48.0


func _play_bench_exit_on_combat_start() -> void:
	if _arena == null or not _arena.bench_visible:
		return
	var travel := _bench_slide_travel()
	var seconds := recruit_enter_seconds
	if seconds <= 0.001:
		_arena.bench_slide_y = travel
		_arena.queue_redraw()
		return
	_arena.bench_slide_y = 0.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_arena, "bench_slide_y", travel, seconds)
	tween.tween_method(_redraw_arena_half_slide, 0.0, 1.0, seconds)


## 敌半场向上、友半场向下移出摄像范围（可读占位演出）；供外部 await。
func play_half_field_exit_animation(duration: float = -1.0) -> void:
	if _arena == null:
		return
	var seconds := half_exit_seconds if duration < 0.0 else duration
	if seconds <= 0.001:
		return
	_arena.reset_half_slide()
	var travel := _half_slide_travel()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_arena, "enemy_half_slide_y", -travel, seconds)
	tween.tween_property(_arena, "ally_half_slide_y", travel, seconds)
	tween.tween_method(_redraw_arena_half_slide, 0.0, 1.0, seconds)
	await tween.finished
	if _arena != null:
		_arena.enemy_half_slide_y = -travel
		_arena.ally_half_slide_y = travel
		_arena.queue_redraw()


## 胜后进入招募：同屏半场滑入队伍（上）与候选人（下）；规则走 RecruitSession。
## headless：enter_seconds≤0 时瞬间到位，不 await 长动画。
func enter_recruit(session: RecruitSession, enter_seconds: float = -1.0) -> void:
	if session == null:
		push_error("RealtimeBattleController.enter_recruit: session is null")
		return
	_recruit_session = session
	_recruit_selected_candidate = -1
	_recruit_selected_replace_id = -1
	_recruit_pending_item_slot = -1
	_preserve_half_slide_for_recruit = false
	var seconds := recruit_enter_seconds if enter_seconds < 0.0 else enter_seconds
	if session.config != null and enter_seconds < 0.0:
		seconds = session.config.panel_enter_seconds
	_set_phase(Phase.RECRUIT)
	_hide_combat_chrome_for_recruit()
	_show_recruit_hud()
	## 等一帧让 Dock 最小高度生效，Arena 与准备同尺后再算 slide / 画单位。
	await get_tree().process_frame
	_bind_recruit_session()
	_open_recruit_shop()
	## 若未播退出（half_exit=0），先瞬移到屏外再滑入，保持「进出一段」。
	## 先就位 slide，再 sync 单位：开场瞬间队伍/候选人已在半场上（屏外），滑入时可见生成。
	if _arena != null:
		var travel := _half_slide_travel()
		var already_out := absf(_arena.enemy_half_slide_y) > 1.0 or absf(_arena.ally_half_slide_y) > 1.0
		if not already_out:
			_arena.set_half_slide_offscreen(travel)
	_sync_recruit_arena()
	_refresh_recruit_hud()
	if _arena != null:
		_arena.queue_redraw()
	await _play_half_field_enter_animation(seconds)
	_recruit_animating = false
	_sync_recruit_arena()
	_refresh_recruit_hud()


## 地图附魔节点：上附魔台、下队伍；规则走 EnchantSession。
func enter_enchant(enter_seconds: float = -1.0, expanded_team: bool = false) -> void:
	if not is_node_ready():
		await ready
	if _deck_state == null:
		push_error("RealtimeBattleController.enter_enchant: deck missing")
		return
	_enchant_sandbox_mode = expanded_team
	_enchant_ui.set_expanded_team(expanded_team)
	_enchant_session.configure(_deck_state, _economy, _enchant_sandbox_mode)
	_enchant_session.begin()
	_enchant_ui.set_session(_enchant_session)
	var seconds := recruit_enter_seconds if enter_seconds < 0.0 else enter_seconds
	_set_phase(Phase.ENCHANT)
	_hide_combat_chrome_for_recruit()
	_enchant_ui.show_hud()
	await get_tree().process_frame
	if _arena != null:
		var travel := _half_slide_travel()
		_arena.set_half_slide_offscreen(travel)
	_enchant_ui.sync_arena(_arena, _deck_state, _enchant_slots)
	_enchant_ui.rebuild_team_slots(_enchant_slots, _deck_state)
	if _arena != null:
		_arena.queue_redraw()
	await _play_half_field_enter_animation(seconds)
	_enchant_ui.sync_arena(_arena, _deck_state, _enchant_slots)


func exit_enchant() -> void:
	_enchant_ui.hide_hud()
	_enchant_ui.clear_arena(_arena)
	_enchant_ui.clear_session()
	_enchant_slots.clear()
	_enchant_sandbox_mode = false
	_enchant_ui.set_expanded_team(false)
	if _arena != null:
		_arena.reset_half_slide()
	_restore_combat_chrome_after_recruit()
	if _phase == Phase.ENCHANT:
		_set_phase(Phase.IDLE)


func on_enchant_fused() -> void:
	on_enchant_forge_changed()


func on_enchant_forge_changed() -> void:
	_enchant_ui.rebuild_team_slots(_enchant_slots, _deck_state)
	_enchant_ui.sync_arena(_arena, _deck_state, _enchant_slots)


func get_enchant_session() -> EnchantSession:
	return _enchant_session


func _on_enchant_forge_drop(entry_id: int, slot: StringName) -> void:
	if _enchant_session == null or not _enchant_session.is_active:
		return
	if _enchant_session.fused_this_visit:
		return
	if not _enchant_session.set_slot(slot, entry_id):
		flash_hint("无法放入该格")
		return
	_sync_enchant_arena()


func _on_enchant_team_seat_drop(entry_id: int, target_seat: int) -> void:
	if _phase != Phase.ENCHANT or _deck_state == null:
		return
	if _enchant_session == null or not _enchant_session.is_active or _enchant_session.fused_this_visit:
		return
	var from_slot := _enchant_slots.find_slot_by_entry(entry_id)
	if from_slot < 0 or target_seat < 0 or from_slot == target_seat:
		return
	if _enchant_ui.is_expanded_team():
		if not _enchant_slots.try_swap_slots(from_slot, target_seat):
			flash_hint("无法换座")
			return
		_sync_enchant_expanded_seat_indices()
	else:
		if not _deck_state.swap_seats(entry_id, target_seat):
			flash_hint("无法换座")
			_enchant_ui.rebuild_team_slots(_enchant_slots, _deck_state)
			return
		_enchant_ui.rebuild_team_slots(_enchant_slots, _deck_state)
	_sync_enchant_arena()


func _sync_enchant_expanded_seat_indices() -> void:
	for i in _enchant_slots.slot_count:
		var entry := _enchant_slots.get_entry(i)
		if entry == null:
			continue
		entry.seat_index = i
		if i < _enchant_slots.seat_assign_seq.size():
			entry.seat_assign_seq = _enchant_slots.seat_assign_seq[i]


func _sync_enchant_arena() -> void:
	_enchant_ui.sync_arena(_arena, _deck_state, _enchant_slots)


func _on_enchant_session_finished(did_fuse: bool) -> void:
	var sandbox := _enchant_sandbox_mode
	exit_enchant()
	if sandbox:
		return
	enchant_finished.emit(did_fuse)


func is_enchant_sandbox_mode() -> bool:
	return _enchant_sandbox_mode


## 地图商店：上队伍、下货架；规则走 MapShopService。
func enter_map_shop(service: MapShopService, enter_seconds: float = -1.0) -> void:
	if not is_node_ready():
		await ready
	if service == null:
		push_error("RealtimeBattleController.enter_map_shop: service is null")
		return
	if _deck_state == null:
		push_error("RealtimeBattleController.enter_map_shop: deck missing")
		return
	_map_shop_service = service
	_map_shop_ui.set_service(service)
	var seconds := recruit_enter_seconds if enter_seconds < 0.0 else enter_seconds
	_set_phase(Phase.MAP_SHOP)
	_hide_combat_chrome_for_recruit()
	_map_shop_ui.show_hud()
	await get_tree().process_frame
	if _arena != null:
		var travel := _half_slide_travel()
		_arena.set_half_slide_offscreen(travel)
	_map_shop_ui.sync_arena(_arena, _deck_state, _board_size)
	if _arena != null:
		_arena.queue_redraw()
	_map_shop_ui.set_animating(true)
	await _play_half_field_enter_animation(seconds)
	_map_shop_ui.set_animating(false)
	_map_shop_ui.sync_arena(_arena, _deck_state, _board_size)
	_refresh_hud()


func exit_map_shop() -> void:
	_map_shop_ui.hide_hud()
	_map_shop_ui.clear_arena(_arena)
	_map_shop_ui.clear_service()
	_map_shop_ui.get_team_slots().clear()
	_map_shop_service = null
	_map_shop_ui.set_animating(false)
	if _arena != null:
		_arena.reset_half_slide()
	_restore_combat_chrome_after_recruit()
	if _phase == Phase.MAP_SHOP:
		_set_phase(Phase.IDLE)


func request_exit_map_shop() -> void:
	exit_map_shop()
	map_shop_finished.emit()


func on_map_shop_changed() -> void:
	if _phase != Phase.MAP_SHOP:
		return
	_map_shop_ui.sync_arena(_arena, _deck_state, _board_size)
	_refresh_hud()


func refresh_map_shop_chrome() -> void:
	if _phase != Phase.MAP_SHOP:
		return
	_refresh_hud()


func get_map_shop_service() -> MapShopService:
	return _map_shop_service


func _on_map_shop_offer_drop(kind: StringName, slot_index: int, entry_id: int) -> void:
	if _phase != Phase.MAP_SHOP or _map_shop_service == null or _map_shop_ui.is_animating():
		return
	var result: Dictionary
	if kind == &"equipment":
		result = _map_shop_service.try_buy_equipment_on_entry(slot_index, entry_id)
	else:
		result = _map_shop_service.try_buy_consumable_on_entry(slot_index, entry_id)
	if int(result.get("result", MapShopService.BuyResult.FAILED)) != MapShopService.BuyResult.OK:
		var reason := String(result.get("reason", ""))
		match reason:
			"cant_afford":
				_map_shop_ui.set_hint("金币不足")
			"no_target":
				_map_shop_ui.set_hint("无效目标")
			"empty_slot":
				_map_shop_ui.set_hint("货架已空")
			_:
				_map_shop_ui.set_hint("无法购买")
		on_map_shop_changed()
		return
	if kind == &"equipment":
		if bool(result.get("kept_new", true)):
			_map_shop_ui.set_hint("已装备")
		else:
			_map_shop_ui.set_hint("装备冲突：保留了旧装备")
	elif bool(result.get("destroyed", false)):
		_map_shop_ui.set_hint("生命归零，角色已销毁")
	else:
		_map_shop_ui.set_hint("消耗品已生效")
	on_map_shop_changed()


func _on_map_shop_team_seat_drop(entry_id: int, target_seat: int) -> void:
	if _phase != Phase.MAP_SHOP or _map_shop_service == null or _map_shop_ui.is_animating():
		return
	if _map_shop_service.try_swap_seat(entry_id, target_seat):
		_map_shop_ui.set_hint("已换座")
		on_map_shop_changed()
		return
	_map_shop_ui.set_hint("无法换座")
	on_map_shop_changed()


func exit_recruit() -> void:
	_close_recruit_shop()
	_unbind_recruit_session()
	_recruit_session = null
	_recruit_selected_candidate = -1
	_recruit_selected_replace_id = -1
	_recruit_pending_item_slot = -1
	_recruit_animating = false
	_recruit_team_slots.clear()
	if _arena != null:
		_arena.clear_recruit_mode()
		_arena.reset_half_slide()
	_hide_recruit_hud()
	_restore_combat_chrome_after_recruit()
	if _phase == Phase.RECRUIT:
		_set_phase(Phase.IDLE)


func _play_half_field_enter_animation(seconds: float) -> void:
	if _arena == null:
		return
	_recruit_animating = true
	if seconds <= 0.001:
		_arena.reset_half_slide()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_arena, "enemy_half_slide_y", 0.0, seconds)
	tween.tween_property(_arena, "ally_half_slide_y", 0.0, seconds)
	tween.tween_method(_redraw_arena_half_slide, 0.0, 1.0, seconds)
	await tween.finished
	if _arena != null:
		_arena.reset_half_slide()


# --- 流程 ---


func _begin_combat_from_prepare() -> void:
	## COMBAT.md §6.5：友方入座时间序 → 敌方配置书写序 → 清手牌 → 锁操作 → 游戏开始。
	_lock_phase_active = true
	_timestop_queue.clear()
	_reset_combo_display()
	_reset_tape_state()

	_spawn_combat_sim_from_lock(false)

	## 3) 双方生成之后：未入座手牌回抽、清空手牌、准备结束。
	_card_flow.return_hand_to_draw(_encounter_rng)
	_set_selected(-1)
	_rebuild_cards()

	## 4–5) 锁操作（进入 COMBAT 后不可改座/刷新/出牌）+ 触发游戏开始。
	## 开战技能先入队，由时停「先卡再结算」排空后再排行动队列（COMBAT_FEEDBACK §5）。
	_sim.defer_effect_resolve = true
	_sim.begin_combat()
	_lock_phase_active = false
	_set_phase(Phase.COMBAT)
	_update_tape_controls()
	_play_bench_exit_on_combat_start()


## 从当前准备座位 + _enemy_spawns 重建 sim；silent=true 时用于倒带重演（立刻排空技能、不绑统计）。
func _spawn_combat_sim_from_lock(silent: bool) -> void:
	var keep_lock := _lock_phase_active
	_teardown_sim()
	_lock_phase_active = keep_lock
	_bus = CombatEventBus.new()
	_bus.name = "RealtimeCombatEventBus"
	add_child(_bus)
	_bus.combat_event.connect(_on_combat_event)
	if not silent and not _combat_sandbox_mode and not _tape_stats_disabled:
		_stat_collector.bind_bus(_bus)
	_sim = RealtimeCombatSim.new(_bus)
	_sim.configure(_board_size, last_seed)
	_sim.set_economy(_economy)
	if _deck_state != null:
		_sim.set_deck_state(_deck_state)
	_sim.splash_triggered.connect(_arena.add_splash_fx)
	_sim.unit_died.connect(_on_unit_died)
	_sim.combat_finished.connect(_on_combat_finished)
	if not _sim.actor_turn_ended.is_connected(_on_actor_turn_ended):
		_sim.actor_turn_ended.connect(_on_actor_turn_ended)
	## 出手瞬间 hold：阻止同一步循环内立刻 _begin_next_actor_turn；tween 播完再 release。
	if not _sim.unit_attacked.is_connected(_on_unit_attacked_presentation):
		_sim.unit_attacked.connect(_on_unit_attacked_presentation)
	_sim.suppress_player_wipe_loss = false

	_arena.sim = _sim
	_arena.enemy_previews = []
	_arena.prepare_slots = _slots
	_arena.enemy_slots = _enemy_slots
	_arena.placement_active = false
	_arena.clear_fx()

	for slot_i in _slots.get_occupied_indices_by_seat_order():
		var entry := _slots.get_entry(slot_i)
		if entry == null:
			continue
		entry.refill_equipment_armor()
		var cell := _slots.get_cell(slot_i)
		var unit := UnitInstance.from_deck_entry(entry, cell, UnitInstance.Team.PLAYER)
		if unit == null:
			continue
		if unit.stats != null:
			unit.stats.deploy_time = 0.0
		_sim.add_unit(unit, Vector2(cell) + Vector2(0.5, 0.5))

	for spawn in _enemy_spawns:
		var place: Vector2 = spawn["position"]
		var seat_i: int = int(spawn.get("seat_index", -1))
		if seat_i >= 0 and _enemy_slots != null:
			var seat_cell := _enemy_slots.get_cell(seat_i)
			if seat_cell != Vector2i(-1, -1):
				place = Vector2(seat_cell) + Vector2(0.5, 0.5)
		## 必须每次新建实例：spawn["unit"] 会在首场战斗中被改血/改修饰，倒带重用会残血开局。
		var unit := _fresh_enemy_unit_for_spawn(spawn.get("unit") as UnitInstance, place)
		if unit == null:
			continue
		if unit.stats != null:
			unit.stats.deploy_time = 0.0
		_sim.add_unit(unit, place)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_refresh_hud()
	_refresh_cards()
	phase_changed.emit(phase)


func _roll_enemy_spawns(rng: RandomNumberGenerator) -> Array:
	var budget_cfg := _get_spawn_budget_config()
	if budget_cfg != null and budget_cfg.enabled:
		return _roll_enemy_spawns_budget(rng, budget_cfg)
	return _roll_enemy_spawns_legacy(rng)


func _roll_enemy_spawns_legacy(rng: RandomNumberGenerator) -> Array:
	## 配置书写顺序即生成序；座位按空敌座索引依次占用，不 shuffle 打乱生成序。
	var entries := _encounter.wave.roll_spawn_entries(_level.enemy_pool, _tier_index, rng)
	var units: Array[UnitData] = []
	for entry in entries:
		if entry == null or entry.unit == null:
			continue
		for _i in maxi(1, entry.count):
			units.append(entry.unit)

	var seat_count := _enemy_slots.slot_count
	if units.size() > seat_count:
		push_warning(
			"RealtimeBattleController: %d enemies but only %d enemy seats; extra enemies dropped"
			% [units.size(), seat_count]
		)
	var boss_seat := EnemyBudgetSpawner.back_center_seat_index(
		_enemy_slots.seat_cols, seat_count
	)
	var seat_fill := SeatLayout.iter_seats_center_out(
		_enemy_slots.seat_rows, _enemy_slots.seat_cols
	)
	var taken: Dictionary = {}
	var result: Array = []
	for i in mini(units.size(), seat_count):
		var ud: UnitData = units[i]
		var seat_i: int
		## Boss 首领（或 Boss 遭遇唯一敌）落后排水平居中。
		var want_center := (
			ud != null and ud.is_boss_leader
		) or (
			_encounter != null and _encounter.is_boss and units.size() == 1
		)
		if want_center and not taken.has(boss_seat):
			seat_i = boss_seat
		else:
			seat_i = -1
			for s in seat_fill:
				if s < 0 or s >= seat_count:
					continue
				if taken.has(s):
					continue
				seat_i = s
				break
			if seat_i < 0:
				for s2 in seat_count:
					if taken.has(s2):
						continue
					seat_i = s2
					break

		if seat_i < 0:
			break
		taken[seat_i] = true
		var cell := _enemy_slots.get_cell(seat_i)
		var unit := UnitInstance.from_unit_data(ud, cell, UnitInstance.Team.ENEMY)
		result.append({
			"unit": unit,
			"position": _enemy_spawn_visual_position(unit, cell),
			"seat_index": seat_i,
		})
	return result


func _roll_enemy_spawns_budget(rng: RandomNumberGenerator, budget_cfg: SpawnBudgetConfig) -> Array:
	var fallback: Array[UnitData] = []
	if _level != null:
		fallback = _level.enemy_pool
	## 进点瞬间整局队伍快照；准备换座不得重抽（本函数仅 start_encounter 调用一次）。
	var team_snap: Array = []
	if _deck_state != null:
		team_snap = _deck_state.get_entries()
	var seated := EnemyBudgetSpawner.roll(
		_encounter.wave,
		budget_cfg,
		fallback,
		_tier_index,
		_floor_index,
		_node_type,
		_enemy_slots.seat_rows,
		_enemy_slots.seat_cols,
		rng,
		team_snap,
		_map_floor_count,
		_forward_tier_unlock,
	)
	var result: Array = []
	for item in seated:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var unit_data: UnitData = item.get("unit_data") as UnitData
		if unit_data == null:
			continue
		var seat_i: int = int(item.get("seat_index", -1))
		if seat_i < 0 or seat_i >= _enemy_slots.slot_count:
			continue
		var cell := _enemy_slots.get_cell(seat_i)
		var unit := UnitInstance.from_unit_data(unit_data, cell, UnitInstance.Team.ENEMY)
		## 先 2★ 身体（与规格一致）；再跟队把场均拉到队均——若跟队后再 ×3，2★ 会相对队均暴涨。
		var star_lv := clampi(int(item.get("level", 1)), 1, 3)
		_apply_enemy_star_level(unit, star_lv)
		result.append({
			"unit": unit,
			"position": _enemy_spawn_visual_position(unit, cell),
			"seat_index": seat_i,
		})
	## 星级身体 → 面板跟队 → 层向 flat（flat 在跟队后加，不被均值归一吃掉）。
	var panel_units: Array = []
	for spawn in result:
		panel_units.append(spawn.get("unit"))
	EnemyPanelMatcher.apply_to_units(
		panel_units,
		team_snap,
		_floor_index,
		_node_type,
		budget_cfg,
	)
	EnemyPanelMatcher.apply_floor_flat_to_units(panel_units, _floor_index, budget_cfg)
	return result


## 敌方 2★：身体 ×3（等同三份 1★ 底模加总）；技能倍率由 unit.level 驱动。
func _apply_enemy_star_level(unit: UnitInstance, level: int) -> void:
	if unit == null:
		return
	var lv := clampi(level, 1, 3)
	unit.level = lv
	if lv <= 1 or unit.stats == null:
		return
	var body_mult := 1
	for _i in range(lv - 1):
		body_mult *= 3
	if body_mult <= 1:
		return
	unit.stats.attack = maxi(1, unit.stats.attack * body_mult)
	unit.stats.max_hp = maxi(1, unit.stats.max_hp * body_mult)
	unit.current_hp = unit.stats.max_hp


## 多格足迹：预览/开场表现落在足迹几何中心（2×2 四格正中），非锚座格心。
func _enemy_spawn_visual_position(unit: UnitInstance, seat_cell: Vector2i) -> Vector2:
	var size := Vector2i(1, 1)
	if unit != null:
		size = unit.get_footprint_size()
	if size.x <= 1 and size.y <= 1:
		return Vector2(seat_cell) + Vector2(0.5, 0.5)
	var origin := RealtimeCombatSim.pick_empty_footprint_origin(
		seat_cell, size, _board_size, UnitInstance.Team.ENEMY
	)
	if origin == Vector2i(-1, -1):
		origin = seat_cell
	return RtUnit.footprint_center_for(origin, size)


func _get_spawn_budget_config() -> SpawnBudgetConfig:
	if _spawn_budget_config != null:
		return _spawn_budget_config
	_spawn_budget_config = SpawnBudgetConfig.load_or_default()
	return _spawn_budget_config


func _resolve_node_type(encounter: EncounterData, node_type: int) -> MapNodeType.Type:
	if node_type >= 0:
		return node_type as MapNodeType.Type
	if encounter != null and encounter.is_boss:
		return MapNodeType.Type.BOSS
	if encounter != null and encounter.is_elite:
		return MapNodeType.Type.ELITE
	return MapNodeType.Type.COMBAT


func _build_enemy_previews(spawns: Array) -> Array:
	var previews: Array = []
	for spawn in spawns:
		var unit: UnitInstance = spawn["unit"]
		var stats := unit.stats if unit != null else null
		var label := ""
		if unit != null and unit.unit_data != null:
			label = unit.unit_data.display_name if not unit.unit_data.display_name.is_empty() else unit.unit_data.id
		var fp := unit.get_footprint_size() if unit != null else Vector2i(1, 1)
		previews.append({
			"position": spawn["position"],
			"radius": stats.body_radius if stats != null else 0.5,
			"visual_half_width": stats.get_visual_half_width() if stats != null else 0.0,
			"visual_half_height": stats.get_visual_half_height() if stats != null else 0.0,
			"footprint_w": fp.x,
			"footprint_h": fp.y,
			"label": label,
			"unit_id": unit.unit_data.id if unit != null and unit.unit_data != null else "",
			"unit": unit,
			"seat_index": int(spawn.get("seat_index", -1)),
			"attack": unit.get_effective_attack() if unit != null else 0,
			"hp": unit.current_hp if unit != null else 0,
		})
	return previews


func _teardown_sim() -> void:
	_lock_phase_active = false
	if _timestop_queue != null:
		_timestop_queue.clear()
	if _sim != null:
		_sim.dispose()
		_sim = null
	if _arena != null:
		_arena.sim = null
		_arena.enemy_previews = []
		_arena.prepare_slots = null
		_arena.enemy_slots = null
		_arena.placement_active = false
	_stat_collector.unbind_bus()
	if _bus != null and is_instance_valid(_bus):
		_bus.queue_free()
	_bus = null


func _disconnect_economy() -> void:
	if _economy != null and _economy.gold_changed.is_connected(_on_gold_changed):
		_economy.gold_changed.disconnect(_on_gold_changed)


## 按 DeckState 持久占位填充准备座位；备战（seat_index=-1）不上座、不自动填空。
func _load_persistent_seats_into_prepare() -> void:
	var rows := _slots.seat_rows if _slots.seat_rows > 0 else DeckConfig.DEFAULT_SEAT_ROWS
	var cols := _slots.seat_cols if _slots.seat_cols > 0 else DeckConfig.DEFAULT_SEAT_COLS
	_slots.configure_grid(rows, cols, _board_size, false)
	if _deck_state == null:
		return
	## 仅修复「座位下标合法但被他人占用」的冲突；不把备战自动塞进空座。
	for entry in _deck_state.get_entries():
		if entry == null or entry.seat_index < 0:
			continue
		if entry.seat_index >= _slots.slot_count:
			## 越界占位视为备战，避免开战幽灵座。
			entry.seat_index = -1
			entry.seat_assign_seq = 0
			continue
		var at := _deck_state.get_entry_at_seat(entry.seat_index)
		if at != null and at.entry_id != entry.entry_id:
			## 冲突：后来者退回备战（不抢空座）。
			entry.seat_index = -1
			entry.seat_assign_seq = 0
	var placed := 0
	## 按落座时间序放入，便于开战生成序与板子 seq 一致。
	var ordered: Array[DeckEntry] = []
	for entry in _deck_state.get_entries():
		if entry != null and entry.seat_index >= 0:
			ordered.append(entry)
	ordered.sort_custom(func(a: DeckEntry, b: DeckEntry) -> bool:
		if a.seat_assign_seq == b.seat_assign_seq:
			return a.seat_index < b.seat_index
		return a.seat_assign_seq < b.seat_assign_seq
	)
	for entry in ordered:
		if placed >= _deploy_cap:
			break
		if entry.seat_index < 0 or entry.seat_index >= _slots.slot_count:
			continue
		if not _slots.is_empty(entry.seat_index):
			continue
		if _slots.try_assign_with_seq(entry.seat_index, entry, entry.seat_assign_seq):
			placed += 1
	_refresh_bench_row()


func _sync_slot_visuals() -> void:
	if _arena != null:
		_arena.prepare_slots = _slots
		_arena.enemy_slots = _enemy_slots
		_sync_arena_bench()
		_arena.queue_redraw()


func _ensure_refresh_button() -> void:
	if _refresh_button != null and is_instance_valid(_refresh_button):
		return
	var existing := get_node_or_null("%RefreshButton") as Button
	if existing != null:
		_refresh_button = existing
	else:
		_refresh_button = Button.new()
		_refresh_button.name = "RefreshButton"
		_refresh_button.unique_name_in_owner = true
		_refresh_button.custom_minimum_size = Vector2(0, 36)
		_refresh_button.text = "刷新手牌"
		var dock_box := _start_button.get_parent() if _start_button != null else null
		if dock_box != null:
			dock_box.add_child(_refresh_button)
			dock_box.move_child(_refresh_button, _start_button.get_index())
		else:
			add_child(_refresh_button)
	if not _refresh_button.pressed.is_connected(_on_refresh_pressed):
		_refresh_button.pressed.connect(_on_refresh_pressed)
	_refresh_button.visible = false


func _ensure_prepare_action_row() -> void:
	if _prepare_action_row != null and is_instance_valid(_prepare_action_row):
		return
	if _start_button == null:
		return
	var dock_box := _start_button.get_parent()
	_prepare_action_row = HBoxContainer.new()
	_prepare_action_row.name = "PrepareActionRow"
	_prepare_action_row.unique_name_in_owner = true
	_prepare_action_row.add_theme_constant_override("separation", 8)
	_prepare_action_row.visible = false
	if dock_box != null:
		var start_i := _start_button.get_index()
		dock_box.add_child(_prepare_action_row)
		dock_box.move_child(_prepare_action_row, start_i)
		_start_button.reparent(_prepare_action_row)
	else:
		add_child(_prepare_action_row)
		_start_button.reparent(_prepare_action_row)
	_start_button.custom_minimum_size = Vector2(0, 40)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.size_flags_stretch_ratio = _PREPARE_START_STRETCH


func _ensure_layout_clipboard_buttons() -> void:
	_ensure_prepare_action_row()
	var row := _prepare_action_row
	if _copy_layout_button == null or not is_instance_valid(_copy_layout_button):
		_copy_layout_button = Button.new()
		_copy_layout_button.name = "CopyLayoutButton"
		_copy_layout_button.unique_name_in_owner = true
		_copy_layout_button.custom_minimum_size = Vector2(0, 40)
		_copy_layout_button.text = "复制布局"
		_copy_layout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_copy_layout_button.size_flags_stretch_ratio = _PREPARE_SECONDARY_STRETCH
		_copy_layout_button.pressed.connect(_on_copy_layout_pressed)
		if row != null:
			row.add_child(_copy_layout_button)
			## 复制在开战左侧。
			row.move_child(_copy_layout_button, maxi(_start_button.get_index(), 0))
		else:
			add_child(_copy_layout_button)
	if _paste_layout_button == null or not is_instance_valid(_paste_layout_button):
		_paste_layout_button = Button.new()
		_paste_layout_button.name = "PasteLayoutButton"
		_paste_layout_button.unique_name_in_owner = true
		_paste_layout_button.custom_minimum_size = Vector2(0, 40)
		_paste_layout_button.text = "粘贴布局"
		_paste_layout_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_paste_layout_button.size_flags_stretch_ratio = _PREPARE_SECONDARY_STRETCH
		_paste_layout_button.pressed.connect(_on_paste_layout_pressed)
		if row != null:
			row.add_child(_paste_layout_button)
			## 沙盒：粘贴 | 复制 | 开战。
			row.move_child(_paste_layout_button, 0)
		else:
			add_child(_paste_layout_button)
	_copy_layout_button.visible = false
	_paste_layout_button.visible = false


func _ensure_tape_controls() -> void:
	if _tape_row != null and is_instance_valid(_tape_row):
		_update_tape_controls()
		return
	_tape_row = HBoxContainer.new()
	_tape_row.name = "TapeRow"
	_tape_row.unique_name_in_owner = true
	_tape_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tape_row.add_theme_constant_override("separation", 8)
	_tape_prev_button = Button.new()
	_tape_prev_button.text = "上一动"
	_tape_prev_button.custom_minimum_size = Vector2(0, 36)
	_tape_prev_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tape_prev_button.pressed.connect(_on_tape_prev_pressed)
	## 中键：倍速与暂停合一（1×→2×→3×→暂停→1×）。
	_tape_play_speed_button = Button.new()
	_tape_play_speed_button.name = "TapePlaySpeedButton"
	_tape_play_speed_button.text = "倍速 1×"
	_tape_play_speed_button.custom_minimum_size = Vector2(0, 36)
	_tape_play_speed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tape_play_speed_button.pressed.connect(_on_tape_play_speed_pressed)
	_tape_next_button = Button.new()
	_tape_next_button.text = "下一动"
	_tape_next_button.custom_minimum_size = Vector2(0, 36)
	_tape_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tape_next_button.pressed.connect(_on_tape_next_pressed)
	_tape_row.add_child(_tape_prev_button)
	_tape_row.add_child(_tape_play_speed_button)
	_tape_row.add_child(_tape_next_button)
	var dock_box: Node = null
	if _prepare_action_row != null and is_instance_valid(_prepare_action_row):
		dock_box = _prepare_action_row.get_parent()
	elif _start_button != null:
		dock_box = _start_button.get_parent()
	if dock_box != null:
		dock_box.add_child(_tape_row)
		if _prepare_action_row != null and is_instance_valid(_prepare_action_row):
			dock_box.move_child(_tape_row, _prepare_action_row.get_index() + 1)
	else:
		add_child(_tape_row)
	_tape_row.visible = false


func _reset_tape_state() -> void:
	_tape_paused = false
	_tape_step_once = false
	_tape_pause_requested = false
	_tape_boundary_pending = false
	_tape_completed_turns = 0
	_tape_rewinding = false
	_tape_stats_disabled = false
	_update_tape_controls()


func _update_tape_controls() -> void:
	var in_combat := _phase == Phase.COMBAT
	if _tape_row != null:
		## 结算叠层：录音机整组隐藏。
		_tape_row.visible = in_combat
	if not in_combat:
		return
	if _tape_play_speed_button != null:
		if _tape_paused and not _tape_step_once:
			_tape_play_speed_button.text = "继续"
		else:
			_tape_play_speed_button.text = "倍速 %d×" % _current_speed_step_shown()
	if _tape_prev_button != null:
		_tape_prev_button.disabled = _tape_completed_turns <= 0 or _tape_rewinding


func _current_speed_step_index() -> int:
	for i in _SPEED_STEPS.size():
		if is_equal_approx(time_scale, _SPEED_STEPS[i]):
			return i
	return 0


func _current_speed_step_shown() -> int:
	return int(_SPEED_STEPS[_current_speed_step_index()])


func _on_copy_layout_pressed() -> void:
	copy_layout_to_clipboard()


func _on_paste_layout_pressed() -> void:
	paste_layout_from_clipboard()


func _ensure_paste_layout_dialog() -> void:
	if _paste_dialog != null and is_instance_valid(_paste_dialog):
		return
	## 全屏遮罩 + 居中小面板；按钮用与 Dock 相同的普通 Button（高 36/40）。
	var overlay := ColorRect.new()
	overlay.name = "PasteLayoutDialog"
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 280)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.16, 0.13, 0.11, 0.97)
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.42, 0.33, 0.22, 1)
	panel_style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	## 竖屏：约屏宽 86%、屏高 42%，避免再占满屏。
	panel.set_anchors_preset(Control.PRESET_CENTER)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var title := Label.new()
	title.text = "粘贴布局"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	body.add_child(title)
	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "把阵容/布局文本贴到下方，再点「应用」。"
	tip.add_theme_font_size_override("font_size", 13)
	body.add_child(tip)
	## TextEdit 自带纵向滚动；占满中间区域，底部按钮始终可见。
	_paste_edit = TextEdit.new()
	_paste_edit.placeholder_text = "PAC_BATTLE v1 …"
	_paste_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_paste_edit.scroll_fit_content_height = false
	_paste_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paste_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paste_edit.custom_minimum_size = Vector2(260, 100)
	body.add_child(_paste_edit)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.size_flags_vertical = Control.SIZE_SHRINK_END
	body.add_child(btn_row)
	_paste_cancel_button = Button.new()
	_paste_cancel_button.name = "PasteCancelButton"
	_paste_cancel_button.text = "取消"
	_paste_cancel_button.custom_minimum_size = Vector2(0, 40)
	_paste_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paste_cancel_button.pressed.connect(_hide_paste_layout_dialog)
	btn_row.add_child(_paste_cancel_button)
	_paste_apply_button = Button.new()
	_paste_apply_button.name = "PasteApplyButton"
	_paste_apply_button.text = "应用"
	_paste_apply_button.custom_minimum_size = Vector2(0, 40)
	_paste_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paste_apply_button.pressed.connect(_on_paste_dialog_confirmed)
	btn_row.add_child(_paste_apply_button)
	_paste_dialog = overlay
	add_child(_paste_dialog)
	## 按视口收紧面板，保证按钮始终在屏内。
	_paste_dialog.resized.connect(_fit_paste_layout_panel)
	call_deferred("_fit_paste_layout_panel")


func _fit_paste_layout_panel() -> void:
	if _paste_dialog == null or not is_instance_valid(_paste_dialog):
		return
	var center := _paste_dialog.get_child(0) as CenterContainer
	if center == null or center.get_child_count() < 1:
		return
	var panel := center.get_child(0) as Control
	if panel == null:
		return
	var vp := get_viewport_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return
	var w := clampf(vp.x * 0.86, 260.0, 420.0)
	var h := clampf(vp.y * 0.42, 240.0, 360.0)
	panel.custom_minimum_size = Vector2(w, h)


func _show_paste_layout_dialog(prefill: String) -> void:
	_ensure_paste_layout_dialog()
	_fit_paste_layout_panel()
	if _paste_edit != null:
		_paste_edit.text = prefill
		_paste_edit.select_all()
	_paste_dialog.visible = true
	_paste_dialog.move_to_front()
	## 下一帧再抢焦点，避免被 Dock 按钮吃掉。
	call_deferred("_focus_paste_edit")


func _hide_paste_layout_dialog() -> void:
	if _paste_dialog != null and is_instance_valid(_paste_dialog):
		_paste_dialog.visible = false


func _focus_paste_edit() -> void:
	if _paste_edit != null and is_instance_valid(_paste_edit):
		_paste_edit.grab_focus()


func _on_paste_dialog_confirmed() -> void:
	if _paste_edit == null:
		return
	var err: String = apply_layout_clipboard_text(_paste_edit.text, false)
	if err.is_empty():
		_hide_paste_layout_dialog()
		return
	## 失败时保持窗口，方便改正文。


## 中键：播放中 1×→2×→3×，再点则暂停；暂停时点「继续」回到 1× 播放。
func _on_tape_play_speed_pressed() -> void:
	if _phase != Phase.COMBAT or _sim == null:
		return
	if _tape_paused and not _tape_step_once:
		time_scale = _SPEED_STEPS[0]
		_tape_paused = false
		_tape_pause_requested = false
		_tape_step_once = false
		_tape_boundary_pending = false
		_update_tape_controls()
		_refresh_hud()
		return
	var idx := _current_speed_step_index()
	if idx < _SPEED_STEPS.size() - 1:
		time_scale = _SPEED_STEPS[idx + 1]
		_update_tape_controls()
		_refresh_hud()
		return
	## 已在最高倍速：请求暂停（动间冻结）。
	_tape_pause_requested = true
	_tape_step_once = false
	if (
		_sim.get_current_actor() == null
		and not _timestop_queue.is_blocking()
		and not _sim.has_pending_effects()
	):
		_tape_paused = true
		_tape_pause_requested = false
		_tape_boundary_pending = false
	_update_tape_controls()
	_refresh_hud()


func _on_tape_next_pressed() -> void:
	if _phase != Phase.COMBAT or _sim == null or _sim.is_finished():
		return
	## 上一动已结束、正兑现停住：只确认暂停，勿清边界再开下一动（避免连跳）。
	if _tape_boundary_pending:
		_tape_step_once = false
		_tape_pause_requested = false
		_tape_paused = true
		_update_tape_controls()
		return
	## 先置步进标志，再清演出门闩：即使收拍中脚本报错，下一帧仍能带着 step_once 重试解锁。
	_tape_paused = false
	_tape_pause_requested = false
	_tape_boundary_pending = false
	_tape_step_once = true
	_presentation_block_elapsed = 0.0
	_unstick_combat_presentation()
	_update_tape_controls()


func _on_tape_prev_pressed() -> void:
	if _phase != Phase.COMBAT or _sim == null:
		return
	if _tape_completed_turns <= 0:
		_show_hint("已到开局")
		_update_tape_controls()
		return
	_rewind_tape_to_turn(_tape_completed_turns - 1)


func _on_actor_turn_ended(completed_turns: int) -> void:
	if _tape_rewinding:
		_tape_completed_turns = completed_turns
		return
	_reset_combo_display()
	_tape_completed_turns = completed_turns
	if _tape_step_once or _tape_pause_requested:
		_tape_boundary_pending = true
	_update_tape_controls()
	## 击杀叠层等可能不经 ON_EFFECT_RESOLVED 的目标链；回合末再采一次存活友方。
	if (
		_run_stat_ledger != null
		and not _tape_stats_disabled
		and not _combat_sandbox_mode
		and _sim != null
	):
		_stat_collector.sample_player_units(_sim.get_units())


## 真倒带：同种子从锁阵重演到 target_turns（已完成一动数）。
func _rewind_tape_to_turn(target_turns: int) -> void:
	var target := maxi(0, target_turns)
	_tape_rewinding = true
	_timestop_queue.clear()
	_tape_stats_disabled = true
	_stat_collector.unbind_bus()
	_spawn_combat_sim_from_lock(true)
	if _sim == null:
		_tape_rewinding = false
		return
	## 与实战一致：开战前先 defer，开战技能入队后经 flush 排空并排行动队列。
	## 重演循环内保持 defer，每步后瞬时排空（等价播报时长为 0），避免与实战分叉提前终局。
	_sim.defer_effect_resolve = true
	_sim.begin_combat()
	_sim.flush_combat_start_lock()
	_tape_completed_turns = 0
	var guard := 0
	var max_steps := 30 * 60 * 10
	while _tape_completed_turns < target and not _sim.is_finished() and guard < max_steps:
		_sim.advance_fixed_step()
		_resolve_pending_effects_instant()
		guard += 1
	_tape_completed_turns = _sim.get_completed_actor_turns()
	_sim.release_presentation()
	_tape_rewinding = false
	_tape_paused = true
	_tape_step_once = false
	_tape_pause_requested = false
	_tape_boundary_pending = false
	if target <= 0 and _tape_completed_turns <= 0:
		_show_hint("已到开局")
	elif _tape_completed_turns < target and _sim.is_finished():
		## 重演已终局但仍少于目标：说明与实战仍有分叉；至少停在可继续倒带的状态。
		_show_hint("已到可回放尽头")
	_update_tape_controls()
	if _arena != null:
		_arena.clear_fx()
		_arena.queue_redraw()


## 倒带重演：不播介绍卡，按 FIFO 立刻结算队内全部待处理技能（含连锁）。
func _resolve_pending_effects_instant() -> void:
	if _sim == null:
		return
	var guard := 0
	while _sim.has_pending_effects() and guard < 256:
		_sim.resolve_next_pending_effect()
		guard += 1
	_sim.release_presentation()


## 从敌方预生成模板重建开战实例（满血、无本场临时层）。
## 必须拷贝模板上已结算的攻/血（跟队 + 星级身体 + 层向 flat），不可只读 .tres 底模。
func _fresh_enemy_unit_for_spawn(template: UnitInstance, place: Vector2) -> UnitInstance:
	if template == null or template.unit_data == null:
		return null
	var cell := Vector2i(floori(place.x), floori(place.y))
	var unit := UnitInstance.from_unit_data(template.unit_data, cell, UnitInstance.Team.ENEMY)
	if unit == null:
		return null
	unit.level = clampi(template.level, 1, 3)
	if template.stats != null and unit.stats != null:
		unit.stats.attack = maxi(1, template.stats.attack)
		unit.stats.max_hp = maxi(1, template.stats.max_hp)
	unit.current_hp = unit.get_effective_max_hp()
	return unit


func _apply_layout_payload(payload) -> String:
	if payload == null or _deck_state == null or _level == null:
		var err0 := "无法应用布局（未 setup）"
		_show_hint(err0)
		return err0
	var entries := BattleLayoutClipboard.build_deck_entries(payload)
	if entries.is_empty():
		var err := "没有有效友方（单位 id 无法解析）"
		_show_hint(err)
		return err
	var next_id := 0
	var next_seq := 0
	for entry in entries:
		next_id = maxi(next_id, entry.entry_id + 1)
		next_seq = maxi(next_seq, entry.seat_assign_seq)
	_deck_state.restore_roster({
		"entries": entries,
		"next_entry_id": next_id,
		"next_seat_seq": next_seq,
		"seat_cap_override": maxi(1, payload.seat_cap),
	})
	if payload.is_layout() and payload.has_enemies():
		_sandbox_enemy_override = payload.enemies.duplicate(true)
		if payload.seed != 0:
			rng_seed = payload.seed
	elif _combat_sandbox_mode:
		_sandbox_enemy_override = [
			{"unit_id": DEFAULT_SANDBOX_ENEMY_ID, "seat": 0, "level": 1},
		]
	else:
		_sandbox_enemy_override.clear()
	var encounter := _encounter
	if encounter == null:
		encounter = load(DEFAULT_SANDBOX_ENCOUNTER) as EncounterData
	if encounter == null:
		var err2 := "缺少默认遭遇"
		_show_hint(err2)
		return err2
	var node_type := BattleLayoutClipboard.node_type_from_encounter(payload.encounter_type)
	start_encounter(encounter, _tier_index, _floor_index, int(node_type))
	if _phase != Phase.PREPARE:
		var err3 := "粘贴后未能进入准备"
		_show_hint(err3)
		return err3
	_sync_slot_visuals()
	_refresh_hud()
	_refresh_cards()
	var ally_n := _slots.occupied_count() if _slots != null else 0
	var enemy_n := _enemy_spawns.size()
	_show_hint("已粘贴布局（我 %d / 敌 %d）" % [ally_n, enemy_n])
	return ""


func _build_enemy_spawns_from_override(rows: Array) -> Array:
	var spawns: Array = []
	if _enemy_slots == null:
		return spawns
	var seat_count := _enemy_slots.slot_count
	var used: Dictionary = {}
	for row in rows:
		var uid := String(row.get("unit_id", ""))
		var data := BattleLayoutClipboard.resolve_unit(uid)
		if data == null:
			continue
		var seat_i := int(row.get("seat", -1))
		if seat_i < 0 or seat_i >= seat_count or used.has(seat_i):
			seat_i = -1
			for i in seat_count:
				if not used.has(i):
					seat_i = i
					break
		if seat_i < 0:
			continue
		used[seat_i] = true
		var cell := _enemy_slots.get_cell(seat_i)
		var unit := UnitInstance.from_unit_data(data, cell, UnitInstance.Team.ENEMY)
		if unit == null:
			continue
		unit.level = clampi(int(row.get("level", 1)), 1, 3)
		spawns.append({
			"unit": unit,
			"position": _enemy_spawn_visual_position(unit, cell),
			"seat_index": seat_i,
		})
	return spawns


func _ensure_recruit_hud() -> void:
	if _recruit_hud != null and is_instance_valid(_recruit_hud):
		return
	_recruit_hud = PanelContainer.new()
	_recruit_hud.name = "RecruitHud"
	_recruit_hud.visible = false
	_recruit_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	_recruit_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.12, 0.92)
	style.set_content_margin_all(8.0)
	_recruit_hud.add_theme_stylebox_override("panel", style)
	## 放进 Dock：招募时保持底栏占位，Arena 格像素与准备/战斗一致。
	var dock_box: Node = null
	if _dock != null:
		dock_box = _dock.get_node_or_null("DockBox")
	if dock_box != null:
		dock_box.add_child(_recruit_hud)
	else:
		_recruit_hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_recruit_hud.offset_top = -132.0
		_recruit_hud.offset_bottom = 0.0
		add_child(_recruit_hud)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_recruit_hud.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)
	_recruit_title = Label.new()
	_recruit_title.text = "招募"
	_recruit_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_recruit_title)
	var gold_row := HBoxContainer.new()
	gold_row.name = "RecruitGoldRow"
	gold_row.add_theme_constant_override("separation", 4)
	top.add_child(gold_row)
	UiStatIcons.ensure_gold_icon(gold_row)
	_recruit_gold = Label.new()
	_recruit_gold.text = UiStatIcons.format_gold_label(0)
	gold_row.add_child(_recruit_gold)
	_recruit_seat = Label.new()
	_recruit_seat.text = "席位 0/0"
	top.add_child(_recruit_seat)

	_recruit_hint = Label.new()
	_recruit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recruit_hint.text = "将下半场候选人拖到上半场队伍"
	box.add_child(_recruit_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_recruit_refresh_btn = Button.new()
	_recruit_refresh_btn.text = "刷新"
	_recruit_refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recruit_refresh_btn.pressed.connect(_on_recruit_refresh_pressed)
	row.add_child(_recruit_refresh_btn)
	_recruit_reset_btn = Button.new()
	_recruit_reset_btn.text = "重置"
	_recruit_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recruit_reset_btn.pressed.connect(_on_recruit_reset_pressed)
	row.add_child(_recruit_reset_btn)
	_recruit_skip_btn = Button.new()
	_recruit_skip_btn.text = "跳过"
	_recruit_skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recruit_skip_btn.pressed.connect(_on_recruit_skip_pressed)
	row.add_child(_recruit_skip_btn)
	_recruit_finish_btn = Button.new()
	_recruit_finish_btn.text = "完成"
	_recruit_finish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recruit_finish_btn.pressed.connect(_on_recruit_finish_pressed)
	row.add_child(_recruit_finish_btn)


## 准备阶段底栏等效高度：手牌行 + 开战 + DockBox 间距 + panel 上下边距。
## 本版已取消准备刷新手牌，不再计入刷新钮高度。
## 开局招募时开战钮尚未显示，不能用当前 _dock.size（会偏矮 → Arena 变高）。
func _prepare_equivalent_dock_height() -> float:
	var hand_h := 88.0
	if _hand_row != null:
		hand_h = maxf(_hand_row.custom_minimum_size.y, hand_h)
	var start_h := 40.0
	if _start_button != null:
		start_h = maxf(_start_button.custom_minimum_size.y, start_h)
	var sep := 6.0
	var margin_tb := 14.0 ## StyleBoxFlat_dock content_margin top 6 + bottom 8
	return margin_tb + hand_h + sep + start_h


func _hide_combat_chrome_for_recruit() -> void:
	## 只藏手牌/开战/刷新；Dock 锁到准备等效高度，避免开局/胜后招募 Arena 变高变宽。
	if _dock != null:
		_dock.visible = true
		var keep_h := _prepare_equivalent_dock_height()
		if _dock.size.y > keep_h:
			keep_h = _dock.size.y
		_dock.custom_minimum_size.y = keep_h
	if _hand_row != null:
		_hand_row.visible = false
	if _prepare_action_row != null:
		_prepare_action_row.visible = false
	if _start_button != null:
		_start_button.visible = false
	if _refresh_button != null:
		_refresh_button.visible = false
	if _result_overlay != null:
		_result_overlay.visible = false


func _restore_combat_chrome_after_recruit() -> void:
	if _dock != null:
		_dock.visible = true
		_dock.custom_minimum_size.y = 0.0
	if _hand_row != null:
		_hand_row.visible = true


func _show_recruit_hud() -> void:
	_ensure_recruit_hud()
	if _recruit_hud != null:
		_recruit_hud.visible = true


func _hide_recruit_hud() -> void:
	if _recruit_hud != null:
		_recruit_hud.visible = false


func _bind_recruit_session() -> void:
	if _recruit_session == null:
		return
	if not _recruit_session.session_changed.is_connected(_on_recruit_session_changed):
		_recruit_session.session_changed.connect(_on_recruit_session_changed)


func _unbind_recruit_session() -> void:
	if _recruit_session == null:
		return
	if _recruit_session.session_changed.is_connected(_on_recruit_session_changed):
		_recruit_session.session_changed.disconnect(_on_recruit_session_changed)


func _on_recruit_session_changed() -> void:
	_sync_recruit_arena()
	_refresh_recruit_hud()
	if _pending_merge_fx.is_empty():
		return
	## 座位已重建后再播残影飞入 / 升星弹跳。
	await _drain_pending_merge_fx()


func _drain_pending_merge_fx() -> void:
	if _arena == null or _phase != Phase.RECRUIT:
		_pending_merge_fx.clear()
		return
	_recruit_animating = true
	_refresh_recruit_hud()
	while not _pending_merge_fx.is_empty():
		var fx: Dictionary = _pending_merge_fx.pop_front()
		var level := int(fx.get("level", 2))
		if _recruit_hint != null:
			_recruit_hint.text = "%d★ 三合一！" % level
		flash_hint("%d★ 三合一！" % level)
		await _arena.play_triple_merge_animation(
			int(fx.get("seat", -1)),
			fx.get("seats", []) as Array,
			String(fx.get("unit_id", "")),
			level,
		)
	_recruit_animating = false
	_refresh_recruit_hud()


func _sync_recruit_arena() -> void:
	if _arena == null or _recruit_session == null:
		return
	_rebuild_recruit_team_slots()
	_arena.recruit_active = true
	_arena.recruit_team_slots = _recruit_team_slots
	_arena.recruit_candidates = _build_recruit_candidate_previews()
	_arena.recruit_items = _build_recruit_item_previews()
	_arena.recruit_selected_candidate = _recruit_selected_candidate
	_arena.recruit_selected_replace_id = _recruit_selected_replace_id
	## 按当前选中/拖动候选人判断；满员但可三合一时不进换人态。
	if _recruit_selected_candidate >= 0:
		_arena.recruit_needs_replace = _recruit_session.needs_replace_for_candidate(
			_recruit_selected_candidate
		)
	else:
		_arena.recruit_needs_replace = _recruit_session.needs_replace()
	_arena.recruit_pending_item_slot = _recruit_pending_item_slot
	_arena.recruit_sell_cell = _build_recruit_sell_cell()
	_arena.recruit_lock_cell = _build_recruit_lock_cell()
	_arena.prepare_slots = null
	_arena.enemy_slots = null
	_arena.enemy_previews = []
	_arena.sim = null
	_arena.placement_active = false
	_sync_arena_bench()
	_arena.queue_redraw()


func _rebuild_recruit_team_slots() -> void:
	var seat_rows := DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := DeckConfig.DEFAULT_SEAT_COLS
	if _deck_state != null:
		var config := _deck_state.get_config()
		if config != null:
			seat_rows = config.get_seat_rows()
			seat_cols = config.get_seat_cols()
	## 上半场落点用敌半场区域，行序与我半场一致（前排在上），seat_index 与准备共用。
	_recruit_team_slots.configure_grid(seat_rows, seat_cols, _board_size, true, true)
	if _recruit_session == null or _recruit_session.deck == null:
		return
	var deck := _recruit_session.deck
	## 只放已入座成员；备战不自动填上区空座。
	for entry in deck.get_entries():
		if entry == null or entry.seat_index < 0:
			continue
		var seat_i := entry.seat_index
		if seat_i >= _recruit_team_slots.slot_count:
			continue
		if not _recruit_team_slots.is_empty(seat_i):
			continue
		_recruit_team_slots.try_assign_with_seq(seat_i, entry, entry.seat_assign_seq)
	_refresh_bench_row()


func _build_recruit_candidate_previews() -> Array:
	var result: Array = []
	if _recruit_session == null:
		return result
	var count := _recruit_session.get_candidate_slot_count()
	var cells := _build_recruit_candidate_cells(count)
	var list := _recruit_session.get_candidates()
	for i in list.size():
		var unit: UnitData = list[i]
		var cell := cells[i] if i < cells.size() else NO_CELL
		var cost := _recruit_session.get_recruit_cost(unit) if unit != null else 0
		result.append({
			"index": i,
			"unit": unit,
			"cell": cell,
			"cost": cost,
			"affordable": _recruit_session.can_afford_recruit(i) if unit != null else false,
			"locked": _recruit_session.is_candidate_locked(i),
			"needs_replace": _recruit_session.needs_replace_for_candidate(i) if unit != null else false,
			"label": unit.display_name if unit != null else "",
		})
	return result


func _build_recruit_item_previews() -> Array:
	var result: Array = []
	if _recruit_shop == null or not _recruit_shop.is_open():
		return result
	var items := _recruit_shop.get_item_offers()
	var cells := _build_recruit_item_cells(items.size())
	for i in items.size():
		var item: PrepareItemData = items[i]
		var cell := cells[i] if i < cells.size() else NO_CELL
		var cost := _recruit_shop.get_item_cost(item) if item != null else 0
		result.append({
			"index": i,
			"item": item,
			"cell": cell,
			"cost": cost,
			"affordable": _recruit_shop.can_afford_item(i) if item != null else false,
			"label": item.get_display_name() if item != null else "",
		})
	return result


func _build_recruit_candidate_cells(count: int) -> Array[Vector2i]:
	var n := maxi(1, count)
	## 招募半场第 1 行：候选人一行占满宽度（gap=0）；mid 行留给备战中缝。
	var mid := BoardHalf.midline_row(_board_size.y)
	var y := clampi(mid + 1, mid, maxi(mid, _board_size.y - 2))
	var gap := 0
	var block_w := n
	if block_w > _board_size.x:
		block_w = _board_size.x
	var start_x := (_board_size.x - block_w) / 2
	start_x = clampi(start_x, 0, maxi(0, _board_size.x - 1))
	var cells: Array[Vector2i] = []
	for i in n:
		var x := clampi(start_x + i * (1 + gap), 0, maxi(0, _board_size.x - 1))
		cells.append(Vector2i(x, y))
	return cells


## 招募半场第 2 行 y：候选人下一行（cand_y+1）；道具/锁定/出售共用，禁止落到 +2。
func _recruit_action_row_y() -> int:
	var mid := BoardHalf.midline_row(_board_size.y)
	var cand_count := RecruitSession.CANDIDATE_COUNT
	if _recruit_session != null:
		cand_count = _recruit_session.get_candidate_slot_count()
	var cand := _build_recruit_candidate_cells(cand_count)
	var y := mid + 2
	if not cand.is_empty():
		y = cand[0].y + 1
	return clampi(y, mid, maxi(mid, _board_size.y - 1))


func _build_recruit_item_cells(count: int) -> Array[Vector2i]:
	var n := maxi(0, count)
	if n <= 0:
		return []
	var y := _recruit_action_row_y()
	## 左右各留一格给 lock / sell；道具居中落在中间列（5 宽 → x=1..3）。
	var inner_left := 1 if _board_size.x >= 3 else 0
	var inner_right := (_board_size.x - 2) if _board_size.x >= 3 else maxi(0, _board_size.x - 1)
	var inner_w := maxi(1, inner_right - inner_left + 1)
	var place_n := mini(n, inner_w)
	var start_x := inner_left + (inner_w - place_n) / 2
	start_x = clampi(start_x, 0, maxi(0, _board_size.x - 1))
	var cells: Array[Vector2i] = []
	for i in n:
		if i >= place_n:
			## 超出内宽时仍保持同行：夹在内区右端，不落到下一行。
			var x_overflow := clampi(inner_right, 0, maxi(0, _board_size.x - 1))
			cells.append(Vector2i(x_overflow, y))
			continue
		var x := clampi(start_x + i, 0, maxi(0, _board_size.x - 1))
		cells.append(Vector2i(x, y))
	return cells


## 出售落点：动作行右侧，与道具/锁定同行。
func _build_recruit_sell_cell() -> Vector2i:
	return _build_recruit_side_action_cell(true)


## 锁定落点：动作行左侧，与道具/出售同行；候选人拖入切换锁定。
func _build_recruit_lock_cell() -> Vector2i:
	return _build_recruit_side_action_cell(false)


func _build_recruit_side_action_cell(on_right: bool) -> Vector2i:
	var y := _recruit_action_row_y()
	var x := (_board_size.x - 1) if on_right else 0
	x = clampi(x, 0, maxi(0, _board_size.x - 1))
	## 窄板：若与对侧动作格同格，向内挤一格，仍保持同行（不落到 cand_y+2）。
	if not on_right and _arena != null and _arena.recruit_sell_cell == Vector2i(x, y):
		x = clampi(x + 1, 0, maxi(0, _board_size.x - 1))
	return Vector2i(x, y)


func _refresh_recruit_hud() -> void:
	if _recruit_session == null:
		return
	var gold := _recruit_session.economy.gold if _recruit_session.economy != null else 0
	var deck := _recruit_session.deck
	var roster_n := deck.size() if deck != null else 0
	var seated_n := deck.get_seated_count() if deck != null else 0
	var bench_n := deck.get_bench_count() if deck != null else 0
	var cap := _recruit_session.get_seat_cap()
	if _recruit_gold != null:
		_recruit_gold.text = UiStatIcons.format_gold_label(gold)
		var gold_row := _recruit_gold.get_parent() as Control
		if gold_row != null:
			UiStatIcons.ensure_gold_icon(gold_row)
	if _recruit_seat != null:
		_recruit_seat.text = "入座 %d/%d 备战 %d/%d" % [
			seated_n, cap, bench_n, DeckState.BENCH_CAPACITY,
		]
	if _recruit_hint != null:
		if _recruit_pending_item_slot >= 0:
			_recruit_hint.text = "点上区队伍角色使用药水，或拖到角色上"
		elif _recruit_session.require_nonempty_roster and roster_n < 1:
			_recruit_hint.text = "开局招募：至少招募 1 名单位后才能继续"
		elif _recruit_session.needs_replace():
			_recruit_hint.text = "拥有已满：先出售腾位，或拖候选人到上区替换（旧人不退金）；可三合一时可点买"
		else:
			_recruit_hint.text = "点买优先上场；备战可拖空座/点按自动上阵；座位可拖回备战"
	if _recruit_refresh_btn != null:
		_recruit_refresh_btn.disabled = _recruit_animating or not _recruit_session.can_refresh()
		_recruit_refresh_btn.text = "刷新（%d 金）" % _recruit_session.get_refresh_cost()
	if _recruit_reset_btn != null:
		_recruit_reset_btn.disabled = _recruit_animating
	if _recruit_skip_btn != null:
		## 开局隐藏跳过；胜后显示。
		_recruit_skip_btn.visible = not _recruit_session.require_nonempty_roster
		_recruit_skip_btn.disabled = _recruit_animating or not _recruit_session.can_skip()
	if _recruit_finish_btn != null:
		_recruit_finish_btn.disabled = _recruit_animating or not _recruit_session.can_finish()
	if _gold_label != null:
		_gold_label.text = UiStatIcons.format_gold_label(gold)
	if _phase_label != null:
		_phase_label.text = "招募"
	if _pop_label != null:
		_pop_label.text = "入座 %d/%d 备战 %d/%d" % [
			seated_n, cap, bench_n, DeckState.BENCH_CAPACITY,
		]
	if _encounter_label != null:
		_encounter_label.text = "招募"


func _on_recruit_drop(candidate_index: int, replace_entry_id: int, seat_index: int = -1) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	## 拖放路径禁止盖到已上场：即便信号误带 replace_id 也不替换。
	if replace_entry_id >= 0:
		_on_recruit_drop_rejected(&"occupied_seat")
		return
	_try_recruit(candidate_index, -1, seat_index)


func _on_recruit_drop_rejected(reason: StringName) -> void:
	if _phase != Phase.RECRUIT or _recruit_hint == null:
		return
	match reason:
		&"occupied_seat":
			_recruit_hint.text = "不能拖到已上场角色上，请拖到空座位"
		_:
			_recruit_hint.text = "无法放置"


func _on_recruit_team_seat_drop(entry_id: int, target_seat: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	if _is_bench_entry(entry_id):
		if try_move_bench_to_seat(entry_id, target_seat):
			_recruit_selected_replace_id = -1
			if _recruit_hint != null:
				_recruit_hint.text = "已上阵"
			return
		if _recruit_hint != null:
			_recruit_hint.text = "备战只能上到空座位"
		return
	if _recruit_session.try_swap_seat(entry_id, target_seat):
		_recruit_selected_replace_id = -1
		if _recruit_hint != null:
			_recruit_hint.text = "已换座"
		return
	if _recruit_hint != null:
		_recruit_hint.text = "无法换座"


## 招募：拖上区已入座成员松手落在备战格 → 入备战。
func _on_recruit_team_bench_drop(entry_id: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	if not _is_seated_entry(entry_id):
		return
	if try_move_seat_to_bench(entry_id):
		_recruit_selected_replace_id = -1
		if _recruit_hint != null:
			_recruit_hint.text = "已移入备战"
		return
	if _recruit_hint != null:
		_recruit_hint.text = "备战已满"


func _on_recruit_empty_seat_pressed(seat_index: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating:
		return
	if _selected_entry_id >= 0 and _is_bench_entry(_selected_entry_id):
		if try_move_bench_to_seat(_selected_entry_id, seat_index):
			if _recruit_hint != null:
				_recruit_hint.text = "已上阵"
			return
		if _recruit_hint != null:
			_recruit_hint.text = "无法上阵（上场席位已满？）"


func _on_recruit_sell(entry_id: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	var result := _recruit_session.try_sell(entry_id)
	if result.get("ok", false):
		_recruit_selected_replace_id = -1
		if _recruit_hint != null:
			_recruit_hint.text = "已出售，获得 %d 金" % int(result.get("gold", 0))
		return
	if _recruit_hint != null:
		_recruit_hint.text = "无法出售（%s）" % String(result.get("reason", "unknown"))


func _on_recruit_candidate_pressed(candidate_index: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	_recruit_selected_candidate = candidate_index
	## 点买：优先上场空座 / 上场满则备战；都满则失败（替换仅拖到已占座）。
	_try_recruit(candidate_index, -1)


func _on_recruit_team_pressed(entry_id: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	## 待用药水：点上区成员结算。
	if _recruit_pending_item_slot >= 0:
		_try_apply_recruit_potion(_recruit_pending_item_slot, entry_id)
		return
	_recruit_selected_replace_id = entry_id
	_sync_recruit_arena()
	if _recruit_selected_candidate >= 0 and _recruit_session.needs_replace_for_candidate(
		_recruit_selected_candidate
	):
		_try_recruit(_recruit_selected_candidate, entry_id)


func _on_recruit_item_pressed(item_slot: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_shop == null or not _recruit_shop.is_open():
		return
	var item := _recruit_shop.get_item_offer(item_slot)
	if item == null:
		return
	if item.item_type == PrepareItemData.ItemType.BANNER:
		var result := _recruit_shop.try_buy_banner(item_slot, _deck_state)
		if int(result.get("result", RecruitShopService.BuyResult.FAILED)) != RecruitShopService.BuyResult.OK:
			var reason := String(result.get("reason", ""))
			match reason:
				"cant_afford":
					_show_recruit_item_hint("金币不足")
				"cap_maxed":
					_show_recruit_item_hint("席位已达上限")
				_:
					_show_recruit_item_hint("无法购买旗帜")
			return
		_recruit_pending_item_slot = -1
		_show_recruit_item_hint("席位上限 +1（当前 %d）" % _deck_state.get_max_size())
		_sync_recruit_arena()
		_refresh_recruit_hud()
		return
	## 药水：进入选目标；也可拖到上区角色。
	_recruit_pending_item_slot = item_slot
	_show_recruit_item_hint("点上区队伍角色使用药水，或拖到角色上")
	_sync_recruit_arena()


func _on_recruit_item_drop(item_slot: int, entry_id: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating:
		return
	_try_apply_recruit_potion(item_slot, entry_id)


func _try_apply_recruit_potion(item_slot: int, entry_id: int) -> void:
	if _recruit_shop == null or not _recruit_shop.is_open() or _deck_state == null:
		return
	var result := _recruit_shop.try_buy_potion_on_entry(item_slot, _deck_state, entry_id)
	_recruit_pending_item_slot = -1
	if int(result.get("result", RecruitShopService.BuyResult.FAILED)) != RecruitShopService.BuyResult.OK:
		var reason := String(result.get("reason", ""))
		match reason:
			"cant_afford":
				_show_recruit_item_hint("金币不足")
			"no_target":
				_show_recruit_item_hint("无效目标")
			_:
				_show_recruit_item_hint("无法使用道具")
		_sync_recruit_arena()
		return
	_show_recruit_item_hint("道具已生效")
	_sync_recruit_arena()
	_refresh_recruit_hud()


func _show_recruit_item_hint(text: String) -> void:
	if _recruit_hint != null:
		_recruit_hint.text = text
	else:
		_show_hint(text)


func _get_recruit_shop_config() -> RecruitShopConfig:
	if _recruit_shop_config != null:
		return _recruit_shop_config
	_recruit_shop_config = RecruitShopConfig.load_or_default()
	return _recruit_shop_config


func _open_recruit_shop() -> void:
	var deck := _deck_state
	if _recruit_session != null and _recruit_session.deck != null:
		deck = _recruit_session.deck
	_recruit_shop.configure(_get_recruit_shop_config(), _economy)
	_recruit_shop.open_shop(deck)
	if not _recruit_shop.shop_changed.is_connected(_on_recruit_shop_changed):
		_recruit_shop.shop_changed.connect(_on_recruit_shop_changed)
	_recruit_pending_item_slot = -1


func _close_recruit_shop() -> void:
	if _recruit_shop != null:
		if _recruit_shop.shop_changed.is_connected(_on_recruit_shop_changed):
			_recruit_shop.shop_changed.disconnect(_on_recruit_shop_changed)
		_recruit_shop.close_shop()
	_recruit_pending_item_slot = -1


func _on_recruit_shop_changed() -> void:
	if _phase != Phase.RECRUIT:
		return
	_sync_recruit_arena()
	_refresh_recruit_hud()


func _try_recruit(candidate_index: int, replace_entry_id: int, seat_index: int = -1) -> void:
	var result := _recruit_session.try_recruit(candidate_index, replace_entry_id, seat_index)
	if result.get("ok", false):
		_recruit_selected_candidate = -1
		_recruit_selected_replace_id = -1
		_try_show_party_bark_after_recruit()
		return
	var reason := String(result.get("reason", ""))
	if _recruit_hint == null:
		return
	match reason:
		"no_gold":
			_recruit_hint.text = "金币不足"
		"roster_full", "need_replace":
			_recruit_hint.text = "拥有已满：请出售腾位，或点选上区角色替换"
		"seat_cap_full":
			_recruit_hint.text = "上场席位已满"
		_:
			_recruit_hint.text = "无法招募（%s）" % reason


## 进队结算后：评估队伍台词并挂到说话人纸片上（Run 一次）。
func _try_show_party_bark_after_recruit() -> void:
	if _phase != Phase.RECRUIT or _recruit_session == null or _arena == null:
		return
	var bark := PartyBarkService.pick_recruit_join_bark(
		_recruit_session.deck,
		_recruit_session.played_party_bark_ids,
	)
	if bark == null:
		return
	_recruit_session.played_party_bark_ids = PartyBarkService.mark_played(
		_recruit_session.played_party_bark_ids,
		bark.id,
	)
	## session_changed 已 sync；再等一帧确保座位纸片已画好。
	await get_tree().process_frame
	if _phase != Phase.RECRUIT or _arena == null:
		return
	_arena.show_party_bark(bark.speaker_unit_id, bark.line)


func _on_recruit_refresh_pressed() -> void:
	if _recruit_animating or _recruit_session == null:
		return
	if not _recruit_session.try_refresh():
		if _recruit_hint != null:
			_recruit_hint.text = "金币不足，无法刷新"


func _on_recruit_candidate_lock(candidate_index: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	var unit := _recruit_session.get_candidate(candidate_index)
	if unit == null:
		if _recruit_hint != null:
			_recruit_hint.text = "空槽无法锁定"
		return
	var locked := _recruit_session.toggle_candidate_lock(candidate_index)
	_recruit_selected_candidate = candidate_index
	if _recruit_hint != null:
		if locked:
			_recruit_hint.text = "已锁定 %s（刷新保留）" % unit.display_name
		else:
			_recruit_hint.text = "已解锁 %s" % unit.display_name
	_sync_recruit_arena()
	_refresh_recruit_hud()


func _on_recruit_reset_pressed() -> void:
	if _recruit_animating or _recruit_session == null:
		return
	_recruit_session.reset()
	_recruit_selected_candidate = -1
	_recruit_selected_replace_id = -1
	_recruit_pending_item_slot = -1
	if _recruit_shop != null and _recruit_shop.is_open():
		_recruit_shop.restore_snapshot()


func _on_recruit_skip_pressed() -> void:
	if _recruit_animating or _recruit_session == null:
		return
	if not _recruit_session.can_skip():
		return
	_recruit_session.skip()
	exit_recruit()
	recruit_finished.emit(false)


func _on_recruit_finish_pressed() -> void:
	if _recruit_animating or _recruit_session == null:
		return
	if not _recruit_session.can_finish():
		return
	_recruit_session.finish()
	exit_recruit()
	recruit_finished.emit(true)


# --- 回调 ---


func _on_board_pressed(tile_pos: Vector2) -> void:
	if _phase == Phase.PREPARE:
		var cell := Vector2i(floori(tile_pos.x), floori(tile_pos.y))
		var slot_index := _slots.find_slot_at_cell(cell)
		if slot_index < 0:
			if _selected_entry_id >= 0 and _card_flow.is_in_hand(_selected_entry_id):
				try_assign_to_slot(_selected_entry_id, cell)
			return
		## 已选中座位上的成员 → 换座到目标座。
		if _selected_entry_id >= 0:
			var from_i := _slots.find_slot_by_entry(_selected_entry_id)
			if from_i >= 0:
				if from_i == slot_index:
					_set_selected(-1)
					return
				try_swap_prepare_seats(from_i, slot_index)
				return
			if _card_flow.is_in_hand(_selected_entry_id):
				try_assign_to_slot(_selected_entry_id, cell)
				return
			## 备战选中 → 仅空座上阵（不可拖回座位人到备战）。
			if _is_bench_entry(_selected_entry_id):
				if _slots.is_empty(slot_index):
					if try_move_bench_to_seat(_selected_entry_id, slot_index):
						return
					_show_hint("无法上阵（上场席位已满？）")
				else:
					_show_hint("备战只能拖到空座位")
				return
		## 点已占座：选中以便换座（不收回手牌）。
		var seated := _slots.get_entry(slot_index)
		if seated != null:
			_set_selected(seated.entry_id)
		return
	if _phase == Phase.COMBAT and _sim != null:
		if _selected_entry_id >= 0:
			_show_hint("开战后不能出牌")
			_set_selected(-1)
			return
		if _find_player_unit_at(tile_pos) != null:
			_show_hint("已上场单位不可移动")


func _on_card_dropped(entry_id: int, tile_pos: Vector2) -> void:
	if _phase != Phase.PREPARE:
		_show_hint("开战后不能出牌")
		return
	var cell := Vector2i(floori(tile_pos.x), floori(tile_pos.y))
	try_assign_to_slot(entry_id, cell)


func _on_card_pressed(entry_id: int) -> void:
	if _phase != Phase.PREPARE:
		_show_hint("开战后不能出牌")
		return
	if not _card_flow.is_in_hand(entry_id):
		return
	_set_selected(-1 if _selected_entry_id == entry_id else entry_id)


func _on_hand_card_long_press(entry_id: int) -> void:
	if _phase != Phase.PREPARE or _arena == null:
		return
	var entry := _find_hand_entry(entry_id)
	if entry == null:
		return
	var card := _find_hand_card(entry_id)
	var anchor := Vector2(_arena.size.x * 0.5, _arena.size.y * 0.35)
	if card != null and is_instance_valid(card):
		var global_center := card.get_global_rect().get_center()
		anchor = _arena.get_global_transform_with_canvas().affine_inverse() * global_center
	_arena.show_deck_entry_info(entry, anchor)


func _on_hand_card_long_press_ended(_entry_id: int) -> void:
	if _arena != null:
		_arena.hide_unit_info()


func _on_start_pressed() -> void:
	try_start_combat()


func _on_refresh_pressed() -> void:
	try_refresh_hand()


func _on_continue_pressed() -> void:
	continue_after_result()


func _on_unit_died(rt: RtUnit) -> void:
	## 侧倒淡出；淡出后运动层移除残影，不再留在场上。
	_arena.add_death_fx(rt.position, maxf(rt.get_visual_half_width(), rt.get_visual_half_height()), rt.is_player())
	_arena.play_unit_death(rt)


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if event_type == CombatEvents.ON_EFFECT_RESOLVED:
		_on_effect_resolved_feedback(payload)
		return
	if event_type != CombatEvents.ON_DEATH or payload.target == null or _economy == null:
		return
	## 击杀敌方不掉金（愿景定稿）；胜利结算走 grant_floor_gold。
	## 友方 death_grant_gold（增益亡者遗金）若仍挂载则保留。
	if payload.target.team == UnitInstance.Team.PLAYER and payload.target.death_grant_gold > 0:
		_economy.grant(payload.target.death_grant_gold)


## 锁阵：立刻播动画/UI。战斗内：由「先卡再结算」拍捕获；其它路径入结果拍。
func _on_effect_resolved_feedback(payload: CombatEventPayload) -> void:
	if payload == null:
		return
	if _resolving_presented_skill:
		_last_resolved_payload = payload
		return
	if _lock_phase_active or _phase != Phase.COMBAT:
		_present_effect_feedback(payload, true)
		return
	## 非门控路径（兼容）：已结算则只播结果拍。
	if _timestop_queue.is_blocking():
		return
	if _sim != null:
		_sim.hold_for_presentation()
	if _timestop_queue.enqueue_resolved(payload, time_scale):
		_present_effect_result(payload, true)


## 出手瞬间：卡住固定步，等冲撞/回位 tween 播完（倒带 silent 路径不 hold，避免重演卡住）。
func _on_unit_attacked_presentation(_attacker: RtUnit, _target: RtUnit) -> void:
	if _sim == null or _tape_rewinding:
		return
	_sim.hold_for_presentation()
	## 同帧立刻 sync，避免等 arena._process 才开 tween 时被提前 release。
	if _arena != null:
		_arena.sync_combat_motion_now()


## 战斗推进：有待结算技能则插入展示步；否则推进行动队列。
func _tick_combat_presentation(delta: float) -> void:
	if _sim == null:
		return
	var scaled_dt := delta * time_scale
	if _sim.presentation_hold:
		_sim.advance_attack_windup_under_hold(scaled_dt)
	if (
		_sim.has_started()
		and not _sim.is_action_queue_seeded()
		and not _sim.has_pending_effects()
	):
		_sim.try_seed_action_queue()
	## 用户已点「下一动」：优先拆掉时停/出击门闩，否则 step_once 永远进不了步进循环（假死）。
	if _tape_step_once and (
		(_timestop_queue != null and _timestop_queue.is_blocking())
		or _sim.has_pending_effects()
		or (_arena != null and _arena.has_active_combat_action_tween() and not _sim.is_actor_turn_active())
	):
		_unstick_combat_presentation()
	if _timestop_queue.is_blocking():
		_sim.hold_for_presentation()
		## 跨帧仍停在 AWAITING_RESOLVE：上一拍 card_done 处理中断，强制收拍以免假死。
		if _timestop_queue.is_awaiting_resolve():
			_resolve_skill_card_safe()
			_presentation_block_elapsed = 0.0
			return
		_presentation_block_elapsed += delta
		if _presentation_block_elapsed >= PRESENTATION_STUCK_SECONDS:
			_unstick_combat_presentation()
			_presentation_block_elapsed = 0.0
			return
		var done := _timestop_queue.tick(delta, time_scale)
		if done == &"card_done":
			_resolve_skill_card_safe()
		elif done == &"result_done":
			_on_skill_result_done()
			_presentation_block_elapsed = 0.0
		return
	if _sim.has_pending_effects():
		_sim.hold_for_presentation()
		_presentation_block_elapsed = 0.0
		_start_next_skill_card()
		return
	## 一动已交权且出击/回位仍在播：保持 hold，勿在 windup（turn 仍 active）时因 tween 卡住。
	var action_busy := _arena != null and _arena.has_active_combat_action_tween()
	if action_busy and not _sim.is_actor_turn_active():
		_sim.hold_for_presentation()
		_presentation_block_elapsed += delta
		if _presentation_block_elapsed >= PRESENTATION_STUCK_SECONDS:
			_arena.finish_combat_action_tweens()
			_presentation_block_elapsed = 0.0
			_sim.release_presentation()
		return
	_presentation_block_elapsed = 0.0
	## 一动逻辑已结束且演出排空：兑现暂停 / 下一动停住。
	if _tape_boundary_pending:
		_tape_boundary_pending = false
		_tape_step_once = false
		_tape_pause_requested = false
		_tape_paused = true
		_update_tape_controls()
		_sim.release_presentation()
		return
	if _tape_paused and not _tape_step_once:
		_sim.release_presentation()
		return
	_sim.release_presentation()
	## 下一动 / 请求暂停：按固定步推进，避免倍速一帧连跳多动。
	if _tape_step_once or _tape_pause_requested:
		var guard := 0
		while guard < 360 and not _sim.is_finished():
			if _sim.has_pending_effects():
				_sim.hold_for_presentation()
				_start_next_skill_card()
				return
			if _tape_boundary_pending:
				break
			## 上一动出手后的回位尚未结束：先等演出，再继续步进/兑现边界。
			if (
				_arena != null
				and _arena.has_active_combat_action_tween()
				and not _sim.is_actor_turn_active()
			):
				_sim.hold_for_presentation()
				return
			_sim.advance_fixed_step()
			guard += 1
			## unit_attacked 已 hold：同循环内勿再开下一动。
			if _sim.presentation_hold:
				return
		## 本动尾巴技能仍须演完再停。
		if _sim.has_pending_effects():
			_sim.hold_for_presentation()
			_start_next_skill_card()
			return
		if _tape_boundary_pending:
			_tape_boundary_pending = false
			_tape_step_once = false
			_tape_pause_requested = false
			_tape_paused = true
			_update_tape_controls()
		return
	_sim.step(delta * time_scale)


func _start_next_skill_card() -> void:
	var batch := _sim.peek_pending_effect_batch()
	if batch == null:
		_sim.release_presentation()
		return
	_timestop_queue.begin_card(batch.owner, batch.spec, time_scale)
	_combo_tracker.register_skill_intro_card(batch.owner)
	_refresh_combo_hud_from_tracker()
	_presentation_block_elapsed = 0.0
	_show_skill_trigger_info_for_owner(batch.owner)


## 卡拍结束：先离开 AWAITING（避免结算脚本中断后永久假死），再写真值与结果拍。
func _resolve_skill_card_safe() -> void:
	_last_resolved_payload = null
	## 先进入 RESULT，保证即便 resolve 中途 SCRIPT ERROR，时停也不会粘在 AWAITING_RESOLVE。
	if _timestop_queue != null:
		_timestop_queue.begin_result(null, time_scale)
	_resolving_presented_skill = true
	if _sim != null and _sim.has_pending_effects():
		_sim.resolve_next_pending_effect()
	_resolving_presented_skill = false
	var payload := _last_resolved_payload
	_last_resolved_payload = null
	if _timestop_queue != null:
		_timestop_queue.begin_result(payload, time_scale)
	if payload != null:
		_present_effect_result(payload, true)


func _on_skill_card_done() -> void:
	_resolve_skill_card_safe()


func _on_skill_result_done() -> void:
	## 「下一动」推进中：勿再开下一张介绍卡，改为静默排空待结算，否则会再次挡步进。
	if _tape_step_once and _sim != null and _sim.has_pending_effects():
		_drain_pending_effects_silent()
		_timestop_queue.clear()
		_presentation_block_elapsed = 0.0
		_sim.try_seed_action_queue()
		_sim.release_presentation()
		return
	if _sim != null and _sim.has_pending_effects():
		_start_next_skill_card()
		return
	if _sim != null:
		_sim.try_seed_action_queue()
	_timestop_queue.clear()
	_presentation_block_elapsed = 0.0
	if _sim != null:
		_sim.release_presentation()


## 「下一动」/看门狗：拆掉时停、待结算队列与出击 tween，恢复可步进状态。
func _unstick_combat_presentation() -> void:
	if _arena != null:
		if _arena.has_active_combat_action_tween():
			_arena.finish_combat_action_tweens()
		_arena.hide_unit_info()
	if _timestop_queue != null and _timestop_queue.is_blocking():
		var phase := _timestop_queue.get_phase()
		if (
			phase == RealtimeTimestopQueue.Phase.SHOW_CARD
			or phase == RealtimeTimestopQueue.Phase.AWAITING_RESOLVE
		):
			_resolve_skill_card_safe()
		_timestop_queue.clear()
	if _sim != null and _sim.has_pending_effects():
		_drain_pending_effects_silent()
	if _sim != null:
		_sim.try_seed_action_queue()
		_sim.release_presentation()
	_presentation_block_elapsed = 0.0


## 不播介绍卡：顺序结算剩余技能批次（「下一动」解锁用；真值仍写入）。
func _drain_pending_effects_silent() -> void:
	if _sim == null:
		return
	var guard := 0
	while _sim.has_pending_effects() and guard < 64:
		_last_resolved_payload = null
		_resolving_presented_skill = true
		_sim.resolve_next_pending_effect()
		_resolving_presented_skill = false
		var payload := _last_resolved_payload
		_last_resolved_payload = null
		if payload != null:
			_present_effect_result(payload, false)
		guard += 1


## 锁阵等：介绍卡 + 结果数字（已结算）。
func _present_effect_feedback(payload: CombatEventPayload, with_callout: bool = false) -> void:
	_show_skill_trigger_info_card(payload)
	_present_effect_result(payload, with_callout)


## 技能结果反馈：效果管线已结算后的数字/短提示；普攻命中不走此路径。
func _present_effect_result(payload: CombatEventPayload, with_callout: bool = false) -> void:
	if _arena == null or payload == null:
		return
	var pops := RealtimeEffectFeedback.build_popups(payload)
	var callout_center := Vector2.ZERO
	var callout_player := true
	var saw_center := false
	for pop in pops:
		var target: UnitInstance = pop.get("target")
		var center := _resolve_feedback_center(target, payload)
		if not saw_center:
			callout_center = center
			callout_player = bool(pop.get("is_player", true))
			saw_center = true
		var tip := ""
		if bool(pop.get("show_tip", false)):
			tip = String(pop.get("tip", ""))
		var amount := int(pop.get("amount", 0))
		_arena.add_feedback_popup(
			pop["kind"],
			String(pop["text"]),
			center,
			bool(pop.get("is_player", true)),
			int(pop.get("unit_id", -1)),
			amount,
			String(pop.get("merge_key", "")),
			tip,
		)
		if pop["kind"] == RealtimeEffectFeedback.KIND_GOLD and amount > 0:
			_arena.spawn_gold_coin_burst(center, amount)
	if with_callout:
		if not saw_center:
			callout_center = _resolve_feedback_center(null, payload)
			var owner := payload.effect_owner if payload.effect_owner != null else payload.source
			if owner != null:
				callout_player = owner.team == UnitInstance.Team.PLAYER
		_arena.add_skill_callout(callout_center, "", callout_player)


func _resolve_feedback_center(target: UnitInstance, payload: CombatEventPayload) -> Vector2:
	if _sim != null and target != null:
		var rt := _sim.find_unit(target)
		if rt != null:
			return rt.position
	if target != null:
		return Vector2(target.grid_pos) + Vector2(0.5, 0.5)
	var owner: UnitInstance = null
	if payload != null:
		owner = payload.effect_owner if payload.effect_owner != null else payload.source
	if _sim != null and owner != null:
		var owner_rt := _sim.find_unit(owner)
		if owner_rt != null:
			return owner_rt.position
	if owner != null:
		return Vector2(owner.grid_pos) + Vector2(0.5, 0.5)
	return Vector2(_board_size) * 0.5


func _show_skill_trigger_info_card(payload: CombatEventPayload) -> void:
	if payload == null:
		return
	var owner := payload.effect_owner if payload.effect_owner != null else payload.source
	_show_skill_trigger_info_for_owner(owner)


func _show_skill_trigger_info_for_owner(owner: UnitInstance) -> void:
	if _arena == null or owner == null:
		return
	var tile := Vector2(owner.grid_pos) + Vector2(0.5, 0.5)
	var atk := owner.get_effective_attack() if owner.has_method("get_effective_attack") else 0
	var hp := owner.current_hp
	if _sim != null:
		var rt := _sim.find_unit(owner)
		if rt != null:
			atk = rt.get_effective_attack()
			hp = rt.get_current_hp()
			tile = rt.position
	_arena.show_skill_trigger_info(owner, owner.team == UnitInstance.Team.PLAYER, atk, hp, tile)


func _on_combat_finished(won: bool) -> void:
	if _deck_state != null:
		_deck_state.refill_all_equipment_armor()
	_timestop_queue.clear()
	_won = won
	_last_encounter_elapsed_seconds = _sim.elapsed_seconds if _sim != null else 0.0
	_floor_gold = 0
	if (
		won
		and _economy != null
		and not _combat_sandbox_mode
		and not _final_trial_active
	):
		## 层结算金取代波次金；仅胜利发放（与原 grant_wave_gold 时机对齐）。
		_floor_gold = _economy.grant_floor_gold(_floor_index)
	_boss_final_trial_offer = _should_offer_final_trial_after_boss()
	_result_label.text = "胜利" if won else "失败"
	if _final_trial_active:
		var layer := FinalTrialBalance.display_layer_for_wave(_final_trial_wave_index)
		var stat := FinalTrialBalance.stat_for_wave(_final_trial_wave_index)
		if won:
			_result_detail.text = (
				"试炼第 %d 层通过  敌方 %d/%d" % [layer, stat, stat]
			)
		else:
			_result_detail.text = (
				"试炼结束  通过 %d 层" % _final_trial_wave_index
			)
		_update_result_action_buttons()
	elif _combat_sandbox_mode:
		_result_detail.text = (
			"沙盒·用时 %s" % _format_time(_sim.elapsed_seconds)
			if won else "沙盒·用时 %s  我方全灭" % _format_time(_sim.elapsed_seconds)
		)
		if _continue_button != null:
			_continue_button.text = "再来一局"
	else:
		_result_detail.text = (
			"用时 %s  层金 +%d" % [_format_time(_sim.elapsed_seconds), _floor_gold]
			if won else "用时 %s  我方全灭" % _format_time(_sim.elapsed_seconds)
		)
		if _boss_final_trial_offer:
			_result_detail.text += "\n可继续通关，或挑战最终试炼"
		if _continue_button != null:
			_continue_button.text = "继续"
		_update_result_action_buttons()
	_result_overlay.visible = true
	print("RealtimeBattle: finished won=%s elapsed=%.2fs steps=%d" % [won, _sim.elapsed_seconds, _sim.fixed_step_count])
	_set_phase(Phase.RESULT)
	_update_tape_controls()
	combat_resolved.emit(won)


func _on_gold_changed(_amount: int) -> void:
	_refresh_hud()


func _find_player_unit_at(tile_pos: Vector2) -> RtUnit:
	if _sim == null:
		return null
	var best: RtUnit = null
	var best_dist := INF
	for item in _sim.get_units():
		var rt := item as RtUnit
		if not rt.is_player():
			continue
		var dist := rt.position.distance_to(tile_pos)
		if dist <= maxf(0.5, rt.get_radius()) and dist < best_dist:
			best = rt
			best_dist = dist
	return best


# --- HUD / 手牌 ---


func _ensure_tier_unlock_toast() -> void:
	if _tier_toast != null:
		return
	_tier_toast_wrap = CenterContainer.new()
	_tier_toast_wrap.name = "TierUnlockToastWrap"
	_tier_toast_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tier_toast_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_toast_wrap.z_index = 48
	_tier_toast = TIER_UNLOCK_TOAST_SCENE.instantiate() as TierUnlockToast
	_tier_toast_wrap.add_child(_tier_toast)
	add_child(_tier_toast_wrap)


func _maybe_show_tier_unlock_toast() -> void:
	if _combat_sandbox_mode:
		return
	if _floor_index <= 0:
		return
	_ensure_tier_unlock_toast()
	var max_tier := TierUnlock.get_max_unlocked_tier(
		_floor_index, _map_floor_count, _forward_tier_unlock
	)
	if max_tier <= _announced_max_tier:
		return
	_announced_max_tier = max_tier
	if _tier_toast != null:
		_tier_toast.show_unlock(max_tier)


## 新 Run 时重置品阶解锁提示（由 Run 入口调用）。
func reset_tier_unlock_announcements() -> void:
	_announced_max_tier = 1
	if _tier_toast != null:
		_tier_toast.hide_immediately()


func _show_hint(text: String) -> void:
	_hint_text = text
	_hint_remaining = HINT_SECONDS


func _set_selected(entry_id: int) -> void:
	_selected_entry_id = entry_id
	var entry := _find_hand_entry(entry_id)
	if entry == null and _phase == Phase.PREPARE and entry_id >= 0:
		var slot_i := _slots.find_slot_by_entry(entry_id)
		if slot_i >= 0:
			entry = _slots.get_entry(slot_i)
	if entry == null and entry_id >= 0 and _deck_state != null:
		entry = _deck_state.get_entry(entry_id)
	## 手牌入座才开投放虚影；已入座换座不走 placement ghost。
	_arena.placement_active = (
		entry != null and _phase == Phase.PREPARE and _card_flow.is_in_hand(entry_id)
	)
	if entry != null and entry.unit != null and _arena.placement_active:
		_arena.ghost_label = entry.get_display_name()
		_arena.ghost_unit_id = entry.get_unit_id()
		var stats := entry.unit.stats
		_arena.ghost_radius = stats.body_radius if stats != null else 0.7
		_arena.ghost_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
		_arena.ghost_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	for card in _cards:
		card.selected = card.get_entry_id() == entry_id
	_refresh_bench_row()


func _find_hand_entry(entry_id: int) -> DeckEntry:
	for entry in _card_flow.get_hand():
		if entry.entry_id == entry_id:
			return entry
	return null


func _find_hand_card(entry_id: int) -> RealtimeHandCard:
	for card in _cards:
		if card != null and is_instance_valid(card) and card.get_entry_id() == entry_id:
			return card
	return null


func _rebuild_cards() -> void:
	if _arena != null and _arena.is_info_card_visible():
		_arena.hide_unit_info()
	for card in _cards:
		card.queue_free()
	_cards.clear()
	for entry in _card_flow.get_hand():
		var card := RealtimeHandCard.new()
		_hand_row.add_child(card)
		card.setup(entry)
		card.card_pressed.connect(_on_card_pressed)
		card.card_long_press.connect(_on_hand_card_long_press)
		card.card_long_press_ended.connect(_on_hand_card_long_press_ended)
		_cards.append(card)
	_refresh_cards()
	_refresh_bench_row()


func _ensure_bench_row() -> void:
	## 保留节点名以免旧场景/测试引用崩溃；不再作为主 UI。
	if _bench_row != null and is_instance_valid(_bench_row):
		_bench_row.visible = false
		return
	_bench_row = HBoxContainer.new()
	_bench_row.name = "BenchRow"
	_bench_row.unique_name_in_owner = true
	_bench_row.visible = false
	_bench_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bench_buttons.clear()
	if _hand_row != null and _hand_row.get_parent() != null:
		var parent := _hand_row.get_parent()
		parent.add_child(_bench_row)
		parent.move_child(_bench_row, _hand_row.get_index())
	elif _dock != null:
		var dock_box := _dock.get_node_or_null("DockBox")
		if dock_box != null:
			dock_box.add_child(_bench_row)
		else:
			_dock.add_child(_bench_row)
	else:
		add_child(_bench_row)


func _rebuild_bench_slots() -> void:
	## 招募：备战夹在队伍半场与招募半场之间（midline）；准备/战斗仍在友方半场下方。
	var row_y := -1
	if _phase == Phase.RECRUIT:
		row_y = BoardHalf.midline_row(_board_size.y)
	_bench_slots.configure_bench_row(_board_size, DeckState.BENCH_CAPACITY, row_y)
	if _deck_state == null:
		return
	var bench := _deck_state.get_bench_entries()
	for i in mini(bench.size(), _bench_slots.slot_count):
		var entry := bench[i]
		if entry != null:
			_bench_slots.try_assign(i, entry)


func _sync_arena_bench() -> void:
	_rebuild_bench_slots()
	if _arena == null:
		return
	var show_bench := (
		_phase == Phase.PREPARE
		or _phase == Phase.RECRUIT
		or _phase == Phase.COMBAT
	)
	_arena.bench_visible = show_bench
	_arena.bench_interactive = (
		not _final_trial_active
		and (_phase == Phase.PREPARE or _phase == Phase.RECRUIT)
	)
	_arena.bench_slots = _bench_slots if show_bench else null
	if _phase == Phase.PREPARE or _phase == Phase.RECRUIT:
		_arena.bench_slide_y = 0.0
	_sync_bench_triple_merge_hints()
	_arena.queue_redraw()


func _sync_bench_triple_merge_hints() -> void:
	if _arena == null:
		return
	_arena.bench_triple_merge_hint_entry_ids.clear()
	if _deck_state == null:
		return
	if _phase != Phase.PREPARE and _phase != Phase.RECRUIT:
		return
	for entry_id in _deck_state.get_bench_triple_merge_hint_entry_ids():
		_arena.bench_triple_merge_hint_entry_ids[entry_id] = true


func _refresh_bench_row() -> void:
	_ensure_bench_row()
	if _bench_row != null and is_instance_valid(_bench_row):
		_bench_row.visible = false
	_sync_arena_bench()


func _refresh_cards() -> void:
	var in_prepare := _phase == Phase.PREPARE
	var in_recruit := _phase == Phase.RECRUIT
	for card in _cards:
		card.available = in_prepare
		card.status_text = ""
		if not in_prepare and card.selected:
			_set_selected(-1)
	var show_prepare_actions := in_prepare and not in_recruit and not _final_trial_active
	if _prepare_action_row != null:
		_prepare_action_row.visible = show_prepare_actions
	if _start_button != null:
		_start_button.visible = show_prepare_actions
		var can_start := _slots.occupied_count() >= 1
		if _combat_sandbox_mode:
			can_start = can_start and not _enemy_spawns.is_empty()
		_start_button.disabled = not can_start
	if _refresh_button != null:
		## 本版取消准备刷新手牌：始终隐藏。
		_refresh_button.visible = false
		_refresh_button.disabled = true
		_refresh_button.text = "刷新手牌（已禁用）"
	if _copy_layout_button != null:
		_copy_layout_button.visible = show_prepare_actions
	if _paste_layout_button != null:
		_paste_layout_button.visible = show_prepare_actions and _combat_sandbox_mode
	_refresh_bench_row()
	_update_tape_controls()


func _combat_phase_status_text() -> String:
	if _sim == null:
		return "战斗中·观战"
	var round_i := _sim.get_round_index()
	var actor := _sim.get_current_actor()
	var scale_txt := " ×%.0f" % time_scale
	if actor == null:
		return "战斗中·第%d回合%s" % [round_i, scale_txt]
	var name := actor.get_display_name()
	var side := "友" if actor.is_player() else "敌"
	return "第%d回合·%s[%s]%s" % [round_i, side, name, scale_txt]


func _refresh_hud() -> void:
	if _encounter_label == null:
		return
	if _phase == Phase.RECRUIT:
		_refresh_recruit_hud()
		return
	if _phase == Phase.MAP_SHOP:
		_refresh_map_shop_hud()
		return
	if _final_trial_active:
		var layer := FinalTrialBalance.display_layer_for_wave(_final_trial_wave_index)
		var stat := FinalTrialBalance.stat_for_wave(_final_trial_wave_index)
		_encounter_label.text = "最终试炼 · 第 %d 层（%d/%d）" % [layer, stat, stat]
	elif _encounter != null:
		var encounter_name := _encounter.display_name
		if _floor_index > 0:
			_encounter_label.text = "第 %d 层 · %s" % [_floor_index, encounter_name]
		else:
			_encounter_label.text = encounter_name
	else:
		_encounter_label.text = "实时战斗"
	_gold_label.text = UiStatIcons.format_gold_label(_economy.gold if _economy != null else 0)
	var hand_n := _card_flow.get_hand().size()
	var draw_n := _card_flow.get_draw_count()
	var discard_n := _card_flow.get_discard_count()
	var seated_n := _slots.occupied_count()
	var bench_n := _deck_state.get_bench_count() if _deck_state != null else 0
	_pop_label.text = "入座 %d/%d 备战 %d/%d" % [
		seated_n,
		_deploy_cap,
		bench_n,
		DeckState.BENCH_CAPACITY,
	]
	if hand_n + draw_n + discard_n > 0:
		_pop_label.text += "  手 %d 库 %d 弃 %d" % [hand_n, draw_n, discard_n]
	var elapsed := _sim.elapsed_seconds if _sim != null else 0.0
	_timer_label.text = _format_time(elapsed)
	if not _hint_text.is_empty():
		_phase_label.text = _hint_text
		_phase_label.modulate = Color(1.0, 0.75, 0.45)
		return
	_phase_label.modulate = Color.WHITE
	match _phase:
		Phase.PREPARE:
			if _final_trial_active:
				_phase_label.text = "最终试炼·阵容锁定"
			elif _selected_entry_id >= 0 and _is_bench_entry(_selected_entry_id):
				_phase_label.text = "上场已满：拖到空座或先腾位"
			elif _selected_entry_id >= 0 and _is_seated_entry(_selected_entry_id):
				_phase_label.text = "拖换座，或点备战格下阵"
			else:
				_phase_label.text = "准备·换座 / 点备战上阵 / 拖备战"
		Phase.COMBAT:
			_phase_label.text = _combat_phase_status_text()
		Phase.RESULT:
			_phase_label.text = "胜利" if _won else "失败"
		Phase.RECRUIT:
			_phase_label.text = "招募"
		Phase.ENCHANT:
			_phase_label.text = "附魔"
		Phase.MAP_SHOP:
			_phase_label.text = "商店"
		_:
			_phase_label.text = "等待"


func _refresh_map_shop_hud() -> void:
	var gold := _map_shop_service.get_gold() if _map_shop_service != null else (
		_economy.gold if _economy != null else 0
	)
	if _gold_label != null:
		_gold_label.text = UiStatIcons.format_gold_label(gold)
	if _phase_label != null:
		_phase_label.text = "商店"
		_phase_label.modulate = Color.WHITE
	if _encounter_label != null:
		_encounter_label.text = "地图商店"
	if _pop_label != null and _deck_state != null:
		_pop_label.text = "席位 %d/%d" % [_deck_state.size(), _deck_state.get_max_size()]
	if _timer_label != null:
		_timer_label.text = ""


static func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
