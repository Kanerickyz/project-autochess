class_name RealtimeBattleController
extends Control
## 竖屏实时战斗关卡：进遭遇即开战，抽打弃手牌轮转出牌、结算遮罩（见 Features/PLAYER.md）。
## 逻辑由 RealtimeCombatSim 固定步推进；本节点只做流程、输入与 HUD。

signal encounter_completed(won: bool)
signal phase_changed(phase: Phase)
## 战斗刚分出胜负（结算遮罩出现时）；encounter_completed 在玩家点“继续”后才发出
signal combat_resolved(won: bool)

enum Phase { IDLE, PREPARE, COMBAT, RESULT }

## 敌人随机落点避开最靠中线的行数
const ENEMY_MIDLINE_MARGIN_ROWS := 2
const HINT_SECONDS := 2.0
const NO_CELL := Vector2i(-1, -1)

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
var _board_size: Vector2i = Vector2i(18, 32)
var _phase: Phase = Phase.IDLE
var _card_flow: EncounterCardFlow = EncounterCardFlow.new()
var _command: CommandResource = CommandResource.new()
var _cards: Array[RealtimeHandCard] = []
var _selected_entry_id: int = -1
var _sim: RealtimeCombatSim
var _bus: CombatEventBus
var _won: bool = false
var _wave_gold: int = 0
var _hint_text: String = ""
var _hint_remaining: float = 0.0

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


func _ready() -> void:
	_arena.board_pressed.connect(_on_board_pressed)
	_arena.card_dropped.connect(_on_card_dropped)
	_start_button.pressed.connect(_on_start_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
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
	if _phase == Phase.COMBAT and _sim != null:
		var scaled := delta * time_scale
		_card_flow.tick(scaled)
		_command.tick(scaled)
		_sync_wipe_loss_suppression()
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


## 进入遭遇：由构筑库建抽打弃、起手抽牌，敌人一次刷出并直接开战（无准备阶段）。
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
	var rng := RandomNumberGenerator.new()
	rng.seed = last_seed
	print("RealtimeBattle: encounter=%s tier=%d seed=%d board=%s" % [encounter.id, tier_index, last_seed, _board_size])

	_card_flow.configure_from_deck_config(_deck_state.get_config())
	_card_flow.begin_from_deck(_deck_state, rng)
	_command.configure()
	_command.reset(CommandResource.DEFAULT_START)
	var enemy_spawns := _roll_enemy_spawns(rng)

	_bus = CombatEventBus.new()
	_bus.name = "RealtimeCombatEventBus"
	add_child(_bus)
	_bus.combat_event.connect(_on_combat_event)
	_sim = RealtimeCombatSim.new(_bus)
	_sim.configure(_board_size, last_seed)
	_sim.splash_triggered.connect(_arena.add_splash_fx)
	_sim.unit_died.connect(_on_unit_died)
	_sim.combat_finished.connect(_on_combat_finished)

	_arena.board_size = _board_size
	_arena.sim = _sim
	_arena.clear_fx()
	_arena.enemy_previews = []
	for spawn in enemy_spawns:
		_sim.add_unit(spawn["unit"], spawn["position"])
	_sim.begin_combat()
	_sync_wipe_loss_suppression()
	_rebuild_cards()
	_set_phase(Phase.COMBAT)


func get_phase() -> Phase:
	return _phase


func get_sim() -> RealtimeCombatSim:
	return _sim


func get_board_size() -> Vector2i:
	return _board_size


func get_hand() -> Array[DeckEntry]:
	return _card_flow.get_hand()


func get_command_current() -> float:
	return _command.get_current()


func get_command_max() -> float:
	return _command.get_max()


func get_pending_enemy_positions() -> Array[Vector2]:
	## 进遭遇即开战，无预览落点列表；保留空实现供旧测试调用。
	return []


func get_max_board_units() -> int:
	## Legacy；玩家篇已取消人口硬顶。
	return _deck_state.get_max_board_units() if _deck_state != null else 5


func get_player_unit_count() -> int:
	return _sim.count_alive(UnitInstance.Team.PLAYER) if _sim != null else 0


func is_entry_on_field(entry_id: int) -> bool:
	## 取消一张一体后不再用「在场」挡打出；保留查询供调试。
	return _sim != null and _sim.find_unit_by_deck_entry(entry_id) != null


## 打出手牌到格子；成功返回空串，失败返回原因（同时显示在 HUD）。
func try_deploy(entry_id: int, cell: Vector2i) -> String:
	var reason := _validate_deploy(entry_id, cell)
	if not reason.is_empty():
		_show_hint(reason)
		return reason
	var entry := _find_hand_entry(entry_id)
	if entry == null:
		_show_hint("该牌不在手牌中")
		return "该牌不在手牌中"
	var unit := UnitInstance.from_deck_entry(entry, cell, UnitInstance.Team.PLAYER)
	if unit == null:
		_show_hint("无法生成单位")
		return "无法生成单位"
	# 玩家篇：取消部署时间；落地即可行动。
	if unit.stats != null:
		unit.stats.deploy_time = 0.0
	var cmd_cost := entry.get_command_cost()
	if not _command.try_spend(cmd_cost):
		_show_hint("号令不足（需 %d）" % cmd_cost)
		return "号令不足（需 %d）" % cmd_cost
	if _card_flow.try_play(entry_id) == null:
		# 牌流失败时退回已扣号令，避免白扣。
		_command.refund(cmd_cost)
		_show_hint("无法打出")
		return "无法打出"
	_sim.add_unit(unit, Vector2(cell) + Vector2(0.5, 0.5))
	_sync_wipe_loss_suppression()
	if _selected_entry_id == entry_id:
		_set_selected(-1)
	_rebuild_cards()
	return ""


## 准备阶段已取消；保留空实现以免旧调用报错。
func try_recall_at(_tile_pos: Vector2) -> bool:
	return false


## 进遭遇即开战；保留接口，恒返回当前是否已在战斗。
func try_start_combat() -> bool:
	return _phase == Phase.COMBAT and _sim != null


## 结算后“继续”：释放本场战斗并发出 encounter_completed。
func continue_after_result() -> void:
	if _phase != Phase.RESULT:
		return
	var won := _won
	_result_overlay.visible = false
	_teardown_sim()
	_card_flow.clear()
	_command.clear()
	_rebuild_cards()
	_set_phase(Phase.IDLE)
	encounter_completed.emit(won)


func _sync_wipe_loss_suppression() -> void:
	if _sim == null:
		return
	# 场上暂无友方但牌区尚有牌时不判负（开局 0 人、死后待补人）。
	_sim.suppress_player_wipe_loss = _card_flow.has_cards_remaining()


# --- 流程 ---


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

	var cells := _enemy_spawn_cells()
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	if units.size() > cells.size():
		push_warning(
			"RealtimeBattleController: %d enemies but only %d spawn cells; extra enemies dropped"
			% [units.size(), cells.size()]
		)
	var result: Array = []
	for i in mini(units.size(), cells.size()):
		var unit := UnitInstance.from_unit_data(units[i], cells[i], UnitInstance.Team.ENEMY)
		result.append({"unit": unit, "position": Vector2(cells[i]) + Vector2(0.5, 0.5)})
	return result


func _enemy_spawn_cells() -> Array[Vector2i]:
	var mid := BoardHalf.midline_row(_board_size.y)
	var max_row := mid - ENEMY_MIDLINE_MARGIN_ROWS
	if max_row <= 0:
		max_row = mid
	var cells: Array[Vector2i] = []
	for y in max_row:
		for x in _board_size.x:
			cells.append(Vector2i(x, y))
	return cells


func _validate_deploy(entry_id: int, cell: Vector2i) -> String:
	if _sim == null or _phase != Phase.COMBAT:
		return "当前不可投放"
	if cell.x < 0 or cell.y < 0 or cell.x >= _board_size.x or cell.y >= _board_size.y:
		return "请投放到战场内"
	if not BoardHalf.is_player_deploy_cell(cell, _board_size.y):
		return "敌方半场不可投放"
	if not _card_flow.is_in_hand(entry_id):
		return "该牌不在手牌中"
	if not _card_flow.is_ready(entry_id):
		var left := _card_flow.get_cooldown_remaining(entry_id)
		return "冷却中 %.1fs" % left
	var entry := _find_hand_entry(entry_id)
	if entry == null:
		return "该牌不在手牌中"
	var cmd_cost := entry.get_command_cost()
	if not _command.can_afford(cmd_cost):
		return "号令不足（需 %d）" % cmd_cost
	if _is_cell_occupied(cell):
		return "该格已有单位"
	return ""


func _is_cell_occupied(cell: Vector2i) -> bool:
	for item in _sim.get_units():
		if (item as RtUnit).get_cell() == cell:
			return true
	return false


func _find_hand_entry(entry_id: int) -> DeckEntry:
	for entry in _card_flow.get_hand():
		if entry.entry_id == entry_id:
			return entry
	return null


func _find_player_unit_at(tile_pos: Vector2) -> RtUnit:
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


func _teardown_sim() -> void:
	if _sim != null:
		_sim.dispose()
		_sim = null
	if _arena != null:
		_arena.sim = null
		_arena.enemy_previews = []
	if _bus != null and is_instance_valid(_bus):
		_bus.queue_free()
	_bus = null


func _disconnect_economy() -> void:
	if _economy != null and _economy.gold_changed.is_connected(_on_gold_changed):
		_economy.gold_changed.disconnect(_on_gold_changed)


# --- 回调 ---


func _on_board_pressed(tile_pos: Vector2) -> void:
	if _sim == null:
		return
	if _selected_entry_id >= 0:
		try_deploy(_selected_entry_id, _arena.tile_to_cell(tile_pos))
		return
	if _phase == Phase.COMBAT and _find_player_unit_at(tile_pos) != null:
		_show_hint("已上场单位不可移动")


func _on_card_dropped(entry_id: int, tile_pos: Vector2) -> void:
	try_deploy(entry_id, _arena.tile_to_cell(tile_pos))


func _on_card_pressed(entry_id: int) -> void:
	if _phase != Phase.COMBAT:
		return
	if not _card_flow.is_ready(entry_id):
		_show_hint("冷却中 %.1fs" % _card_flow.get_cooldown_remaining(entry_id))
		_set_selected(-1)
		return
	var entry := _find_hand_entry(entry_id)
	if entry != null and not _command.can_afford(entry.get_command_cost()):
		_show_hint("号令不足（需 %d）" % entry.get_command_cost())
		_set_selected(-1)
		return
	_set_selected(-1 if _selected_entry_id == entry_id else entry_id)


func _on_start_pressed() -> void:
	pass


func _on_continue_pressed() -> void:
	continue_after_result()


func _on_unit_died(rt: RtUnit) -> void:
	_arena.add_death_fx(rt.position, maxf(rt.get_visual_half_width(), rt.get_visual_half_height()), rt.is_player())


func _on_combat_event(event_type: StringName, payload: CombatEventPayload) -> void:
	if event_type != CombatEvents.ON_DEATH or payload.target == null or _economy == null:
		return
	if payload.target.team == UnitInstance.Team.ENEMY:
		_economy.grant_kill_gold(payload.target.unit_data)
	elif payload.target.death_grant_gold > 0:
		_economy.grant(payload.target.death_grant_gold)


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


# --- HUD / 手牌 ---


func _show_hint(text: String) -> void:
	_hint_text = text
	_hint_remaining = HINT_SECONDS


func _set_selected(entry_id: int) -> void:
	_selected_entry_id = entry_id
	var entry := _find_hand_entry(entry_id)
	_arena.placement_active = entry != null
	if entry != null and entry.unit != null:
		_arena.ghost_label = entry.get_display_name()
		var stats := entry.unit.stats
		_arena.ghost_radius = stats.body_radius if stats != null else 0.7
		_arena.ghost_visual_half_width = stats.get_visual_half_width() if stats != null else 0.0
		_arena.ghost_visual_half_height = stats.get_visual_half_height() if stats != null else 0.0
	for card in _cards:
		card.selected = card.get_entry_id() == entry_id


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
	var in_combat := _phase == Phase.COMBAT
	for card in _cards:
		var entry_id := card.get_entry_id()
		var entry := _find_hand_entry(entry_id)
		var cmd_cost := entry.get_command_cost() if entry != null else 1
		var cooled := _card_flow.is_ready(entry_id)
		var affordable := _command.can_afford(cmd_cost)
		var ready := in_combat and cooled and affordable
		card.available = ready
		card.command_cost = cmd_cost
		var cd := _card_flow.get_cooldown_remaining(entry_id)
		if cd > 0.0:
			card.status_text = "%.1fs" % cd
		elif not affordable:
			card.status_text = "号令%d" % cmd_cost
		else:
			card.status_text = ""
		if not ready and card.selected:
			_set_selected(-1)
	if _start_button != null:
		_start_button.visible = false


func _refresh_hud() -> void:
	if _encounter_label == null:
		return
	_encounter_label.text = _encounter.display_name if _encounter != null else "实时战斗"
	_gold_label.text = "金币 %d" % (_economy.gold if _economy != null else 0)
	var hand_n := _card_flow.get_hand().size()
	var draw_n := _card_flow.get_draw_count()
	var discard_n := _card_flow.get_discard_count()
	var cmd_cur := _command.get_current()
	var cmd_max := int(_command.get_max())
	_pop_label.text = "号令 %.1f/%d  手 %d 库 %d 弃 %d" % [cmd_cur, cmd_max, hand_n, draw_n, discard_n]
	var elapsed := _sim.elapsed_seconds if _sim != null else 0.0
	_timer_label.text = _format_time(elapsed)
	if not _hint_text.is_empty():
		_phase_label.text = _hint_text
		_phase_label.modulate = Color(1.0, 0.75, 0.45)
		return
	_phase_label.modulate = Color.WHITE
	match _phase:
		Phase.COMBAT:
			_phase_label.text = "战斗中·拖拽手牌到我半场" if _selected_entry_id < 0 else "点我半场投放"
		Phase.RESULT:
			_phase_label.text = "胜利" if _won else "失败"
		_:
			_phase_label.text = "等待"


static func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
