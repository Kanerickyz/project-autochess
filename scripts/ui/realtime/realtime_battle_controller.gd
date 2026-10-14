class_name RealtimeBattleController
extends Control
## 竖屏实时战斗关卡：准备抽选入角色槽 → 开战纯观战（见 Features/PLAYER.md / COMBAT.md）。
## 逻辑由 RealtimeCombatSim 固定步推进；本节点只做流程、输入与 HUD。

signal encounter_completed(won: bool)
signal phase_changed(phase: Phase)
## 战斗刚分出胜负（结算遮罩出现时）；encounter_completed 在玩家点“继续”后才发出
signal combat_resolved(won: bool)

enum Phase { IDLE, PREPARE, COMBAT, RESULT }

const HINT_SECONDS := 2.0
const NO_CELL := Vector2i(-1, -1)
const DEFAULT_BOARD_SIZE := Vector2i(9, 16)

## 0 = 每场随机；非 0 = 固定种子（抽牌、敌人组成与落点、模拟）
@export var rng_seed: int = 0
## 战斗推进倍速（仅表现层；不影响结果）
@export_range(0.25, 8.0, 0.25) var time_scale: float = 1.0

var last_seed: int = 0

var _deck_state: DeckState
var _economy: RunEconomy
var _level: LevelData
var _encounter: EncounterData
var _tier_index: int = 0
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
var _wave_gold: int = 0
var _hint_text: String = ""
var _hint_remaining: float = 0.0
var _enemy_spawns: Array = []
var _encounter_rng: RandomNumberGenerator

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

var _refresh_button: Button


func _ready() -> void:
	_arena.board_pressed.connect(_on_board_pressed)
	_arena.card_dropped.connect(_on_card_dropped)
	_start_button.pressed.connect(_on_start_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_ensure_refresh_button()
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
		_arena.presentation_time_scale = time_scale
	if _phase == Phase.COMBAT and _sim != null:
		var scaled := delta * time_scale
		_sim.step(scaled)
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


## 进入遭遇：构筑库 → 抽选手牌 → PREPARE；敌方落点可预览，开战时再刷怪。
func start_encounter(encounter: EncounterData, tier_index: int) -> void:
	if _deck_state == null or _level == null:
		push_error("RealtimeBattleController.start_encounter: call setup() first")
		return
	if encounter == null or encounter.wave == null:
		push_error("RealtimeBattleController.start_encounter: encounter or encounter.wave is null")
		return
	_teardown_sim()
	_encounter = encounter
	_tier_index = tier_index
	_won = false
	_wave_gold = 0
	_selected_entry_id = -1
	_result_overlay.visible = false
	_board_size = encounter.get_board_size(_level.get_board_size())

	last_seed = rng_seed if rng_seed != 0 else randi()
	_encounter_rng = RandomNumberGenerator.new()
	_encounter_rng.seed = last_seed
	print("RealtimeBattle: encounter=%s tier=%d seed=%d board=%s" % [encounter.id, tier_index, last_seed, _board_size])

	var config := _deck_state.get_config()
	_card_flow.configure_from_deck_config(config)
	_card_flow.begin_from_deck(_deck_state, _encounter_rng)
	var seat_rows := config.get_seat_rows() if config != null else DeckConfig.DEFAULT_SEAT_ROWS
	var seat_cols := config.get_seat_cols() if config != null else DeckConfig.DEFAULT_SEAT_COLS
	_deploy_cap = config.get_deploy_cap() if config != null else DeckConfig.DEFAULT_DEPLOY_CAP
	_slots.configure_grid(seat_rows, seat_cols, _board_size, false)
	_enemy_slots.configure_grid(seat_rows, seat_cols, _board_size, true)
	_enemy_spawns = _roll_enemy_spawns(_encounter_rng)

	_arena.board_size = _board_size
	_arena.sim = null
	_arena.clear_fx()
	_arena.prepare_slots = _slots
	_arena.enemy_slots = _enemy_slots
	_arena.enemy_previews = _build_enemy_previews(_enemy_spawns)
	_arena.placement_active = false
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


func get_max_board_units() -> int:
	## 本场上场人数上限（deploy_cap）；空座可多于上限。
	return get_deploy_cap()


func get_player_unit_count() -> int:
	return _sim.count_alive(UnitInstance.Team.PLAYER) if _sim != null else 0


func is_entry_on_field(entry_id: int) -> bool:
	if _phase == Phase.PREPARE:
		return _slots.find_slot_by_entry(entry_id) >= 0
	return _sim != null and _sim.find_unit_by_deck_entry(entry_id) != null


## 准备：把手牌放入空角色座位。cell 为最近空座吸附；成功返回空串。
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
	if _selected_entry_id == entry_id:
		_set_selected(-1)
	_sync_slot_visuals()
	_rebuild_cards()
	return ""


## 准备：从槽收回到手牌（手牌未满）。
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
	_sync_slot_visuals()
	_rebuild_cards()
	return true


## 点击格子收回（若点在已占用槽上）。
func try_recall_at(tile_pos: Vector2) -> bool:
	if _phase != Phase.PREPARE:
		return false
	var cell := Vector2i(floori(tile_pos.x), floori(tile_pos.y))
	var slot_index := _slots.find_slot_at_cell(cell)
	if slot_index < 0:
		return false
	return try_recall_slot(slot_index)


## 刷新未入槽手牌（上限见 DeckConfig.max_refresh；免费）。
func try_refresh_hand() -> bool:
	if _phase != Phase.PREPARE:
		_show_hint("仅准备阶段可刷新")
		return false
	if not _card_flow.can_refresh():
		if _card_flow.get_hand().is_empty():
			_show_hint("没有可刷新的手牌")
		else:
			_show_hint("刷新次数已用尽")
		return false
	var ok := _card_flow.try_refresh(_encounter_rng)
	if ok:
		_set_selected(-1)
		_rebuild_cards()
	return ok


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


## 结算后“继续”：释放本场战斗并发出 encounter_completed。
func continue_after_result() -> void:
	if _phase != Phase.RESULT:
		return
	var won := _won
	_result_overlay.visible = false
	_teardown_sim()
	_card_flow.clear()
	_slots.clear()
	_enemy_slots.clear()
	_enemy_spawns.clear()
	_rebuild_cards()
	_set_phase(Phase.IDLE)
	encounter_completed.emit(won)


# --- 流程 ---


func _begin_combat_from_prepare() -> void:
	_card_flow.return_hand_to_draw(_encounter_rng)
	_set_selected(-1)
	_rebuild_cards()

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

	for i in _slots.slot_count:
		var entry := _slots.get_entry(i)
		if entry == null:
			continue
		var cell := _slots.get_cell(i)
		var unit := UnitInstance.from_deck_entry(entry, cell, UnitInstance.Team.PLAYER)
		if unit == null:
			continue
		if unit.stats != null:
			unit.stats.deploy_time = 0.0
		_sim.add_unit(unit, Vector2(cell) + Vector2(0.5, 0.5))

	for spawn in _enemy_spawns:
		_sim.add_unit(spawn["unit"], spawn["position"])

	_arena.sim = _sim
	_arena.enemy_previews = []
	_arena.prepare_slots = _slots
	_arena.enemy_slots = _enemy_slots
	_arena.placement_active = false
	_arena.clear_fx()
	_sim.begin_combat()
	_set_phase(Phase.COMBAT)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_refresh_hud()
	_refresh_cards()
	phase_changed.emit(phase)


func _roll_enemy_spawns(rng: RandomNumberGenerator) -> Array:
	var entries := _encounter.wave.roll_spawn_entries(_level.enemy_pool, _tier_index, rng)
	var units: Array[UnitData] = []
	for entry in entries:
		if entry == null or entry.unit == null:
			continue
		for _i in maxi(1, entry.count):
			units.append(entry.unit)

	## 敌方落点：镜像座位表随机分配（可不填满）；不再扫整片敌半场。
	var seat_indices: Array[int] = []
	for i in _enemy_slots.slot_count:
		seat_indices.append(i)
	for i in range(seat_indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := seat_indices[i]
		seat_indices[i] = seat_indices[j]
		seat_indices[j] = tmp
	if units.size() > seat_indices.size():
		push_warning(
			"RealtimeBattleController: %d enemies but only %d enemy seats; extra enemies dropped"
			% [units.size(), seat_indices.size()]
		)
	var result: Array = []
	for i in mini(units.size(), seat_indices.size()):
		var seat_i: int = seat_indices[i]
		var cell := _enemy_slots.get_cell(seat_i)
		var unit := UnitInstance.from_unit_data(units[i], cell, UnitInstance.Team.ENEMY)
		result.append({
			"unit": unit,
			"position": Vector2(cell) + Vector2(0.5, 0.5),
			"seat_index": seat_i,
		})
	return result


func _build_enemy_previews(spawns: Array) -> Array:
	var previews: Array = []
	for spawn in spawns:
		var unit: UnitInstance = spawn["unit"]
		var stats := unit.stats if unit != null else null
		var label := ""
		if unit != null and unit.unit_data != null:
			label = unit.unit_data.display_name if not unit.unit_data.display_name.is_empty() else unit.unit_data.id
		previews.append({
			"position": spawn["position"],
			"radius": stats.body_radius if stats != null else 0.5,
			"visual_half_width": stats.get_visual_half_width() if stats != null else 0.0,
			"visual_half_height": stats.get_visual_half_height() if stats != null else 0.0,
			"label": label,
			"seat_index": int(spawn.get("seat_index", -1)),
			"attack": unit.get_effective_attack() if unit != null else 0,
			"hp": unit.current_hp if unit != null else 0,
		})
	return previews


func _teardown_sim() -> void:
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


# --- 回调 ---


func _on_board_pressed(tile_pos: Vector2) -> void:
	if _phase == Phase.PREPARE:
		var cell := Vector2i(floori(tile_pos.x), floori(tile_pos.y))
		var slot_index := _slots.find_slot_at_cell(cell)
		if slot_index >= 0 and not _slots.is_empty(slot_index):
			if _selected_entry_id < 0:
				try_recall_slot(slot_index)
			return
		if _selected_entry_id >= 0:
			try_assign_to_slot(_selected_entry_id, cell)
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


func _on_start_pressed() -> void:
	try_start_combat()


func _on_refresh_pressed() -> void:
	try_refresh_hand()


func _on_continue_pressed() -> void:
	continue_after_result()


func _on_unit_died(rt: RtUnit) -> void:
	_arena.add_death_fx(rt.position, maxf(rt.get_visual_half_width(), rt.get_visual_half_height()), rt.is_player())


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if event_type == CombatEvents.ON_EFFECT_RESOLVED:
		_present_effect_feedback(payload)
		return
	if event_type != CombatEvents.ON_DEATH or payload.target == null or _economy == null:
		return
	if payload.target.team == UnitInstance.Team.ENEMY:
		_economy.grant_kill_gold(payload.target.unit_data)
	elif payload.target.death_grant_gold > 0:
		_economy.grant(payload.target.death_grant_gold)


## 技能因果反馈：只接效果管线已结算；普攻命中不走此路径。
func _present_effect_feedback(payload: CombatEventPayload) -> void:
	if _arena == null or payload == null:
		return
	var pops := RealtimeEffectFeedback.build_popups(payload)
	for pop in pops:
		var target: UnitInstance = pop.get("target")
		var center := _resolve_feedback_center(target, payload)
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
	_won = won
	if won and _economy != null:
		_wave_gold = _economy.grant_wave_gold(_encounter.wave)
	_result_label.text = "胜利" if won else "失败"
	_result_detail.text = (
		"用时 %s  波次金 +%d" % [_format_time(_sim.elapsed_seconds), _wave_gold]
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
	_arena.placement_active = entry != null and _phase == Phase.PREPARE
	if entry != null and entry.unit != null:
		_arena.ghost_label = entry.get_display_name()
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


func _rebuild_cards() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	for entry in _card_flow.get_hand():
		var card := RealtimeHandCard.new()
		_hand_row.add_child(card)
		card.setup(entry)
		card.card_pressed.connect(_on_card_pressed)
		_cards.append(card)
	_refresh_cards()


func _refresh_cards() -> void:
	var in_prepare := _phase == Phase.PREPARE
	for card in _cards:
		card.available = in_prepare
		card.status_text = ""
		if not in_prepare and card.selected:
			_set_selected(-1)
	if _start_button != null:
		_start_button.visible = in_prepare
		_start_button.disabled = _slots.occupied_count() < 1
	if _refresh_button != null:
		_refresh_button.visible = in_prepare
		_refresh_button.disabled = not _card_flow.can_refresh()
		_refresh_button.text = "刷新手牌（剩 %d）" % _card_flow.get_refresh_remaining()


func _refresh_hud() -> void:
	if _encounter_label == null:
		return
	_encounter_label.text = _encounter.display_name if _encounter != null else "实时战斗"
	_gold_label.text = "金币 %d" % (_economy.gold if _economy != null else 0)
	var hand_n := _card_flow.get_hand().size()
	var draw_n := _card_flow.get_draw_count()
	var discard_n := _card_flow.get_discard_count()
	var seated_n := _slots.occupied_count()
	var refresh_left := _card_flow.get_refresh_remaining()
	_pop_label.text = "入座 %d/%d  手 %d 库 %d 弃 %d  刷 %d" % [
		seated_n, _deploy_cap, hand_n, draw_n, discard_n, refresh_left,
	]
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
				"准备·选人入座" if _selected_entry_id < 0 else "点空座入阵 / 点已占座收回"
			)
		Phase.COMBAT:
			_phase_label.text = "战斗中·观战"
		Phase.RESULT:
			_phase_label.text = "胜利" if _won else "失败"
		_:
			_phase_label.text = "等待"


static func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
