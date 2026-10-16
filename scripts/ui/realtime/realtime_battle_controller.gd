class_name RealtimeBattleController
extends Control
## 竖屏实时战斗关卡：准备抽选入角色槽 → 开战纯观战（见 Features/PLAYER.md / COMBAT.md）。
## 逻辑由 RealtimeCombatSim 固定步推进；本节点只做流程、输入与 HUD。

signal encounter_completed(won: bool)
signal phase_changed(phase: Phase)
## 战斗刚分出胜负（结算遮罩出现时）；encounter_completed 在玩家点“继续”后才发出
signal combat_resolved(won: bool)
## 招募阶段结束（完成/跳过）；由 Run 接线回地图。
signal recruit_finished(kept_changes: bool)

enum Phase { IDLE, PREPARE, COMBAT, RESULT, RECRUIT }

const HINT_SECONDS := 2.0
const NO_CELL := Vector2i(-1, -1)
const DEFAULT_BOARD_SIZE := Vector2i(9, 16)
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
## 层预算抽阵上下文（Run 传入；沙盒/测试可省略并按 encounter 旗标推断）。
var _floor_index: int = 0
var _node_type: MapNodeType.Type = MapNodeType.Type.COMBAT
var _spawn_budget_config: SpawnBudgetConfig = null
var _board_size: Vector2i = DEFAULT_BOARD_SIZE
var _phase: Phase = Phase.IDLE
var _card_flow: EncounterCardFlow = EncounterCardFlow.new()
var _slots: PrepareSlotBoard = PrepareSlotBoard.new()
## 敌方座位几何（镜像 2×5）；准备预览 / 开战落点用，不存 DeckEntry。
var _enemy_slots: PrepareSlotBoard = PrepareSlotBoard.new()
var _deploy_cap: int = DeckConfig.DEFAULT_DEPLOY_CAP
var _cards: Array[RealtimeHandCard] = []
var _selected_entry_id: int = -1
var _sim: RealtimeCombatSim
var _bus: CombatEventBus
var _won: bool = false
var _floor_gold: int = 0
var _hint_text: String = ""
var _hint_remaining: float = 0.0
var _enemy_spawns: Array = []
var _encounter_rng: RandomNumberGenerator
## 开战锁阵阶段：部署/开战技能只播动画·UI，不走时停队列。
var _lock_phase_active: bool = false
var _timestop_queue: RealtimeTimestopQueue = RealtimeTimestopQueue.new()
## 胜后半场退出后保留 slide，供招募同屏滑入（不重置边框/草地）。
var _preserve_half_slide_for_recruit: bool = false
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
## 招募半场道具行（生命/力量药水、旗帜）；不挂准备阶段。
var _recruit_shop: RecruitShopService = RecruitShopService.new()
var _recruit_shop_config: RecruitShopConfig = null
var _recruit_pending_item_slot: int = -1

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
@onready var _dock: Control = $Layout/Dock

var _refresh_button: Button


func _ready() -> void:
	_arena.board_pressed.connect(_on_board_pressed)
	_arena.card_dropped.connect(_on_card_dropped)
	_arena.recruit_drop.connect(_on_recruit_drop)
	_arena.recruit_candidate_pressed.connect(_on_recruit_candidate_pressed)
	_arena.recruit_team_pressed.connect(_on_recruit_team_pressed)
	_arena.recruit_sell.connect(_on_recruit_sell)
	_arena.recruit_team_seat_drop.connect(_on_recruit_team_seat_drop)
	_arena.recruit_item_pressed.connect(_on_recruit_item_pressed)
	_arena.recruit_item_drop.connect(_on_recruit_item_drop)
	_start_button.pressed.connect(_on_start_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_ensure_refresh_button()
	_ensure_recruit_hud()
	_result_overlay.visible = false
	if _start_button != null:
		_start_button.visible = false
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
		## 时停队列仅兼容钩子（COMBAT_FEEDBACK 已废止为主通道）；主推进为行动队列依次一动。
		if _timestop_queue.is_blocking():
			_sim.hold_for_presentation()
			var started := _timestop_queue.tick(delta, time_scale)
			if started != null:
				_present_effect_feedback(started, true)
			if not _timestop_queue.is_blocking():
				_sim.release_presentation()
		else:
			_sim.release_presentation()
			_sim.step(delta * time_scale)
		if _arena != null:
			_arena.queue_redraw()
	_refresh_hud()
	_refresh_cards()


# --- 公开接口 ---


func setup(deck_state: DeckState, economy: RunEconomy, level: LevelData) -> void:
	_disconnect_economy()
	_deck_state = deck_state
	_economy = economy
	_level = level
	if _economy != null:
		_economy.gold_changed.connect(_on_gold_changed)
	_refresh_hud()


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
	_enemy_spawns = _roll_enemy_spawns(_encounter_rng)
	_load_persistent_seats_into_prepare()

	_arena.board_size = _board_size
	_arena.sim = null
	_arena.clear_fx()
	_arena.clear_recruit_mode()
	_arena.reset_half_slide()
	_arena.prepare_slots = _slots
	_arena.enemy_slots = _enemy_slots
	_arena.enemy_previews = _build_enemy_previews(_enemy_spawns)
	_arena.placement_active = false
	_preserve_half_slide_for_recruit = false
	_hide_recruit_hud()
	_restore_combat_chrome_after_recruit()
	_rebuild_cards()
	_set_phase(Phase.PREPARE)


func get_phase() -> Phase:
	return _phase


func get_sim() -> RealtimeCombatSim:
	return _sim


func get_arena() -> RealtimeArenaView:
	return _arena


func get_board_size() -> Vector2i:
	return _board_size


func get_hand() -> Array[DeckEntry]:
	return _card_flow.get_hand()


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
	_begin_combat_from_prepare()
	return true


## 结算后“继续”：胜则先播半场退出，再释放本场并发出 encounter_completed。
## 无 await：半场演出用 Tween 回调，避免 headless 测试卡在空协程上。
## 胜场保留半场 slide，供随后 enter_recruit 同屏滑入（草地/边框不断）。
func continue_after_result() -> void:
	if _phase != Phase.RESULT:
		return
	var won := _won
	_result_overlay.visible = false
	_preserve_half_slide_for_recruit = won
	if won and half_exit_seconds > 0.001 and _arena != null:
		_play_half_field_exit_then_continue(won, half_exit_seconds)
		return
	_complete_continue(won)


func _complete_continue(won: bool) -> void:
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


func _half_slide_travel() -> float:
	if _arena == null:
		return 220.0
	return maxf(_arena.size.y * 0.65, 220.0)


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

	_bus = CombatEventBus.new()
	_bus.name = "RealtimeCombatEventBus"
	add_child(_bus)
	_bus.combat_event.connect(_on_combat_event)
	_sim = RealtimeCombatSim.new(_bus)
	_sim.configure(_board_size, last_seed)
	_sim.splash_triggered.connect(_arena.add_splash_fx)
	_sim.unit_died.connect(_on_unit_died)
	_sim.combat_finished.connect(_on_combat_finished)
	## 开战纯观战：场上全灭即败（不再因牌区剩余而抑制）。
	_sim.suppress_player_wipe_loss = false

	_arena.sim = _sim
	_arena.enemy_previews = []
	_arena.prepare_slots = _slots
	_arena.enemy_slots = _enemy_slots
	_arena.placement_active = false
	_arena.clear_fx()

	## 1) 友方按入座时间序依次生成；每体当下结算部署时技能。
	for slot_i in _slots.get_occupied_indices_by_seat_order():
		var entry := _slots.get_entry(slot_i)
		if entry == null:
			continue
		var cell := _slots.get_cell(slot_i)
		var unit := UnitInstance.from_deck_entry(entry, cell, UnitInstance.Team.PLAYER)
		if unit == null:
			continue
		if unit.stats != null:
			unit.stats.deploy_time = 0.0
		_sim.add_unit(unit, Vector2(cell) + Vector2(0.5, 0.5))

	## 2) 敌方按遭遇配置书写顺序依次生成（_enemy_spawns 已保序）。
	## 逻辑落点用座位格心；spawn.position 可能是多格足迹几何中心（仅供预览）。
	for spawn in _enemy_spawns:
		var place: Vector2 = spawn["position"]
		var seat_i: int = int(spawn.get("seat_index", -1))
		if seat_i >= 0 and _enemy_slots != null:
			var seat_cell := _enemy_slots.get_cell(seat_i)
			if seat_cell != Vector2i(-1, -1):
				place = Vector2(seat_cell) + Vector2(0.5, 0.5)
		_sim.add_unit(spawn["unit"], place)

	## 3) 双方生成之后：未入座手牌回抽、清空手牌、准备结束。
	_card_flow.return_hand_to_draw(_encounter_rng)
	_set_selected(-1)
	_rebuild_cards()

	## 4–5) 锁操作（进入 COMBAT 后不可改座/刷新/出牌）+ 触发游戏开始。
	_sim.begin_combat()
	_lock_phase_active = false
	_set_phase(Phase.COMBAT)


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
	var center_seat := EnemyBudgetSpawner.front_center_seat_index(_enemy_slots.seat_cols)
	var taken: Dictionary = {}
	var result: Array = []
	for i in mini(units.size(), seat_count):
		var ud: UnitData = units[i]
		var seat_i: int
		## Boss 首领（或 Boss 遭遇唯一敌）落前排水平居中。
		var want_center := (
			ud != null and ud.is_boss_leader
		) or (
			_encounter != null and _encounter.is_boss and units.size() == 1
		)
		if want_center and not taken.has(center_seat):
			seat_i = center_seat
		else:
			seat_i = -1
			for s in seat_count:
				if taken.has(s):
					continue
				seat_i = s
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
		result.append({
			"unit": unit,
			"position": _enemy_spawn_visual_position(unit, cell),
			"seat_index": seat_i,
		})
	return result


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
	if _bus != null and is_instance_valid(_bus):
		_bus.queue_free()
	_bus = null


func _disconnect_economy() -> void:
	if _economy != null and _economy.gold_changed.is_connected(_on_gold_changed):
		_economy.gold_changed.disconnect(_on_gold_changed)


## 按 DeckState 持久占位填充准备座位（非空板手牌抽选）。
func _load_persistent_seats_into_prepare() -> void:
	var rows := _slots.seat_rows if _slots.seat_rows > 0 else DeckConfig.DEFAULT_SEAT_ROWS
	var cols := _slots.seat_cols if _slots.seat_cols > 0 else DeckConfig.DEFAULT_SEAT_COLS
	_slots.configure_grid(rows, cols, _board_size, false)
	if _deck_state == null:
		return
	## 补齐缺座成员到首空座（不刷新已有合法占位的落座时间）。
	for entry in _deck_state.get_entries():
		if entry == null:
			continue
		if entry.seat_index >= 0 and entry.seat_index < _slots.slot_count:
			var at := _deck_state.get_entry_at_seat(entry.seat_index)
			if at == null or at.entry_id == entry.entry_id:
				continue
		var empty := _deck_state.find_first_empty_seat()
		if empty >= 0:
			_deck_state.assign_seat(entry.entry_id, empty)
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


func _sync_slot_visuals() -> void:
	if _arena != null:
		_arena.prepare_slots = _slots
		_arena.enemy_slots = _enemy_slots
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
	_recruit_gold = Label.new()
	_recruit_gold.text = "金币 0"
	top.add_child(_recruit_gold)
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
	_arena.recruit_needs_replace = _recruit_session.needs_replace()
	_arena.recruit_pending_item_slot = _recruit_pending_item_slot
	_arena.recruit_sell_cell = _build_recruit_sell_cell()
	_arena.prepare_slots = null
	_arena.enemy_slots = null
	_arena.enemy_previews = []
	_arena.sim = null
	_arena.placement_active = false
	_arena.queue_redraw()


func _rebuild_recruit_team_slots() -> void:
	var seat_rows := DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := DeckConfig.DEFAULT_SEAT_COLS
	if _deck_state != null:
		var config := _deck_state.get_config()
		if config != null:
			seat_rows = config.get_seat_rows()
			seat_cols = config.get_seat_cols()
	## 上半场用敌方座位几何展示队伍（与准备同一套友方占位数据）。
	_recruit_team_slots.configure_grid(seat_rows, seat_cols, _board_size, true)
	if _recruit_session == null or _recruit_session.deck == null:
		return
	var deck := _recruit_session.deck
	for entry in deck.get_entries():
		if entry == null:
			continue
		var seat_i := entry.seat_index
		if seat_i < 0 or seat_i >= _recruit_team_slots.slot_count or not _recruit_team_slots.is_empty(seat_i):
			seat_i = -1
			for i in _recruit_team_slots.slot_count:
				if _recruit_team_slots.is_empty(i) and deck.is_seat_free(i):
					seat_i = i
					break
			if seat_i < 0:
				continue
			deck.assign_seat(entry.entry_id, seat_i)
		_recruit_team_slots.try_assign_with_seq(seat_i, entry, entry.seat_assign_seq)


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
	## 两行布局：候选人上行；相对我半场略偏上（为道具行留空）。
	var mid := BoardHalf.midline_row(_board_size.y)
	var y := clampi(mid + 1, mid, maxi(mid, _board_size.y - 3))
	## 5 槽时 gap=1 才能塞进 9 列。
	var gap := 1 if n >= 5 else 2
	var block_w := n + (n - 1) * gap
	var start_x := (_board_size.x - block_w) / 2
	start_x = clampi(start_x, 0, maxi(0, _board_size.x - 1))
	var cells: Array[Vector2i] = []
	for i in n:
		var x := clampi(start_x + i * (1 + gap), 0, maxi(0, _board_size.x - 1))
		cells.append(Vector2i(x, y))
	return cells


func _build_recruit_item_cells(count: int) -> Array[Vector2i]:
	var n := maxi(0, count)
	if n <= 0:
		return []
	var cand_count := RecruitSession.CANDIDATE_COUNT
	if _recruit_session != null:
		cand_count = _recruit_session.get_candidate_slot_count()
	var cand := _build_recruit_candidate_cells(cand_count)
	var mid := BoardHalf.midline_row(_board_size.y)
	var y := mid + 3
	if not cand.is_empty():
		y = cand[0].y + 2
	y = clampi(y, mid, maxi(mid, _board_size.y - 2))
	var gap := 1
	var block_w := n + (n - 1) * gap
	var start_x := (_board_size.x - block_w) / 2
	start_x = clampi(start_x, 0, maxi(0, _board_size.x - 1))
	var cells: Array[Vector2i] = []
	for i in n:
		var x := clampi(start_x + i * (1 + gap), 0, maxi(0, _board_size.x - 1))
		cells.append(Vector2i(x, y))
	return cells


## 出售落点：道具行右侧或下方，不与候选人/道具槽重叠。
func _build_recruit_sell_cell() -> Vector2i:
	var mid := BoardHalf.midline_row(_board_size.y)
	var cand_count := RecruitSession.CANDIDATE_COUNT
	if _recruit_session != null:
		cand_count = _recruit_session.get_candidate_slot_count()
	var cand := _build_recruit_candidate_cells(cand_count)
	var item_n := 0
	if _recruit_shop != null and _recruit_shop.is_open():
		item_n = _recruit_shop.get_item_offers().size()
	var items := _build_recruit_item_cells(item_n)
	var y := mid + 4
	if not items.is_empty():
		y = items[0].y
	elif not cand.is_empty():
		y = cand[0].y + 2
	y = clampi(y, mid, maxi(mid, _board_size.y - 1))
	var x := _board_size.x - 1
	if not items.is_empty():
		x = clampi(items[items.size() - 1].x + 2, 0, maxi(0, _board_size.x - 1))
	var cell := Vector2i(x, y)
	for c in cand:
		if c == cell:
			cell.y = clampi(y + 1, mid, maxi(mid, _board_size.y - 1))
			break
	for c2 in items:
		if c2 == cell:
			cell.y = clampi(cell.y + 1, mid, maxi(mid, _board_size.y - 1))
			break
	return cell


func _refresh_recruit_hud() -> void:
	if _recruit_session == null:
		return
	var gold := _recruit_session.economy.gold if _recruit_session.economy != null else 0
	var seats := _recruit_session.deck.size() if _recruit_session.deck != null else 0
	var cap := _recruit_session.get_seat_cap()
	if _recruit_gold != null:
		_recruit_gold.text = "金币 %d" % gold
	if _recruit_seat != null:
		_recruit_seat.text = "席位 %d/%d" % [seats, cap]
	if _recruit_hint != null:
		if _recruit_pending_item_slot >= 0:
			_recruit_hint.text = "点上区队伍角色使用药水，或拖到角色上"
		elif _recruit_session.require_nonempty_roster and seats < 1:
			_recruit_hint.text = "开局招募：至少招募 1 名单位后才能继续"
		elif _recruit_session.needs_replace():
			_recruit_hint.text = "队伍已满：将候选人拖到要替换的成员上（旧人不退金）；可换座或拖成员到出售槽腾位"
		else:
			_recruit_hint.text = "上行招人；下行道具（药水拖到上区角色；旗帜扩席位）"
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
		_gold_label.text = "金币 %d" % gold
	if _phase_label != null:
		_phase_label.text = "招募"
	if _pop_label != null:
		_pop_label.text = "席位 %d/%d" % [seats, cap]
	if _encounter_label != null:
		_encounter_label.text = "招募"


func _on_recruit_drop(candidate_index: int, replace_entry_id: int, seat_index: int = -1) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	_try_recruit(candidate_index, replace_entry_id, seat_index)


func _on_recruit_team_seat_drop(entry_id: int, target_seat: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	if _recruit_session.try_swap_seat(entry_id, target_seat):
		_recruit_selected_replace_id = -1
		if _recruit_hint != null:
			_recruit_hint.text = "已换座"
		return
	if _recruit_hint != null:
		_recruit_hint.text = "无法换座"


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
	if not _recruit_session.needs_replace():
		_try_recruit(candidate_index, -1)
		return
	if _recruit_selected_replace_id >= 0:
		_try_recruit(candidate_index, _recruit_selected_replace_id)
	else:
		if _recruit_hint != null:
			_recruit_hint.text = "请先点选上半场要替换的成员，或把候选人拖到成员上"
		_sync_recruit_arena()


func _on_recruit_team_pressed(entry_id: int) -> void:
	if _phase != Phase.RECRUIT or _recruit_animating or _recruit_session == null:
		return
	## 待用药水：点上区成员结算。
	if _recruit_pending_item_slot >= 0:
		_try_apply_recruit_potion(_recruit_pending_item_slot, entry_id)
		return
	_recruit_selected_replace_id = entry_id
	_sync_recruit_arena()
	if _recruit_selected_candidate >= 0 and _recruit_session.needs_replace():
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
		return
	var reason := String(result.get("reason", ""))
	if _recruit_hint == null:
		return
	match reason:
		"no_gold":
			_recruit_hint.text = "金币不足"
		"need_replace":
			_recruit_hint.text = "队伍已满：请指定替换目标"
		_:
			_recruit_hint.text = "无法招募（%s）" % reason


func _on_recruit_refresh_pressed() -> void:
	if _recruit_animating or _recruit_session == null:
		return
	if not _recruit_session.try_refresh():
		if _recruit_hint != null:
			_recruit_hint.text = "金币不足，无法刷新"


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


## 锁阵：立刻播动画/UI；实时战斗：入时停播报队列（含高频；普攻不经此路径）。
func _on_effect_resolved_feedback(payload: CombatEventPayload) -> void:
	if payload == null:
		return
	if _lock_phase_active or _phase != Phase.COMBAT:
		_present_effect_feedback(payload, true)
		return
	var started := _timestop_queue.enqueue(payload, time_scale)
	if _sim != null:
		_sim.hold_for_presentation()
	if started:
		_present_effect_feedback(payload, true)


## 技能因果反馈：只接效果管线已结算；普攻命中不走此路径。
func _present_effect_feedback(payload: CombatEventPayload, with_callout: bool = false) -> void:
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
		_arena.add_feedback_popup(
			pop["kind"],
			String(pop["text"]),
			center,
			bool(pop.get("is_player", true)),
			int(pop.get("unit_id", -1)),
			int(pop.get("amount", 0)),
			String(pop.get("merge_key", "")),
			tip,
		)
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
	var owner := payload.effect_owner if payload.effect_owner != null else payload.source
	if _sim != null and owner != null:
		var owner_rt := _sim.find_unit(owner)
		if owner_rt != null:
			return owner_rt.position
	if owner != null:
		return Vector2(owner.grid_pos) + Vector2(0.5, 0.5)
	return Vector2(_board_size) * 0.5


func _on_combat_finished(won: bool) -> void:
	_timestop_queue.clear()
	_won = won
	if won and _economy != null:
		## 层结算金取代波次金；仅胜利发放（与原 grant_wave_gold 时机对齐）。
		_floor_gold = _economy.grant_floor_gold(_floor_index)
	_result_label.text = "胜利" if won else "失败"
	_result_detail.text = (
		"用时 %s  层金 +%d" % [_format_time(_sim.elapsed_seconds), _floor_gold]
		if won else "用时 %s  我方全灭" % _format_time(_sim.elapsed_seconds)
	)
	_result_overlay.visible = true
	print("RealtimeBattle: finished won=%s elapsed=%.2fs steps=%d" % [won, _sim.elapsed_seconds, _sim.fixed_step_count])
	_set_phase(Phase.RESULT)
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


func _refresh_cards() -> void:
	var in_prepare := _phase == Phase.PREPARE
	var in_recruit := _phase == Phase.RECRUIT
	for card in _cards:
		card.available = in_prepare
		card.status_text = ""
		if not in_prepare and card.selected:
			_set_selected(-1)
	if _start_button != null:
		_start_button.visible = in_prepare and not in_recruit
		_start_button.disabled = _slots.occupied_count() < 1
	if _refresh_button != null:
		## 本版取消准备刷新手牌：始终隐藏。
		_refresh_button.visible = false
		_refresh_button.disabled = true
		_refresh_button.text = "刷新手牌（已禁用）"


func _combat_phase_status_text() -> String:
	if _sim == null:
		return "战斗中·观战"
	var round_i := _sim.get_round_index()
	var actor := _sim.get_current_actor()
	var scale_txt := ""
	if time_scale > 1.01:
		scale_txt = " ×%.2g" % time_scale
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
	_encounter_label.text = _encounter.display_name if _encounter != null else "实时战斗"
	_gold_label.text = "金币 %d" % (_economy.gold if _economy != null else 0)
	var hand_n := _card_flow.get_hand().size()
	var draw_n := _card_flow.get_draw_count()
	var discard_n := _card_flow.get_discard_count()
	var seated_n := _slots.occupied_count()
	_pop_label.text = "入座 %d/%d" % [seated_n, _deploy_cap]
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
			_phase_label.text = (
				"准备·点座位换阵" if _selected_entry_id < 0 else "点目标座位换座"
			)
		Phase.COMBAT:
			_phase_label.text = _combat_phase_status_text()
		Phase.RESULT:
			_phase_label.text = "胜利" if _won else "失败"
		Phase.RECRUIT:
			_phase_label.text = "招募"
		_:
			_phase_label.text = "等待"


static func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
