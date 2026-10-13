class_name RealtimeBattleController
extends Control
## 竖屏实时战斗关卡：准备阶段投放/收回、开战、战斗中 cycle 补人、结算遮罩。
## 逻辑由 RealtimeCombatSim 固定步推进；本节点只做流程、输入与 HUD。

signal encounter_completed(won: bool)
signal phase_changed(phase: Phase)
## 战斗刚分出胜负（结算遮罩出现时）；encounter_completed 在玩家点“继续”后才发出
signal combat_resolved(won: bool)

enum Phase { IDLE, PREPARE, COMBAT, RESULT }

const DEFAULT_DRAW_COUNT := 5
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
var _hand: Array[DeckEntry] = []
var _cards: Array[RealtimeHandCard] = []
var _selected_entry_id: int = -1
var _pending_enemies: Array = []
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
		_sim.step(delta * time_scale)
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


## 进入准备阶段：抽本场手牌、生成并预览敌人落点。
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

	_hand = DrawService.draw_wave_hand(_deck_state, _resolve_draw_count(), rng)
	_pending_enemies = _roll_enemy_spawns(rng)

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
	_arena.enemy_previews = _build_enemy_previews()
	_rebuild_cards()
	_set_phase(Phase.PREPARE)


func get_phase() -> Phase:
	return _phase


func get_sim() -> RealtimeCombatSim:
	return _sim


func get_board_size() -> Vector2i:
	return _board_size


func get_hand() -> Array[DeckEntry]:
	return _hand.duplicate()


func get_pending_enemy_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for spawn in _pending_enemies:
		out.append(spawn["position"])
	return out


func get_max_board_units() -> int:
	return _deck_state.get_max_board_units() if _deck_state != null else 5


func get_player_unit_count() -> int:
	return _sim.count_alive(UnitInstance.Team.PLAYER) if _sim != null else 0


func is_entry_on_field(entry_id: int) -> bool:
	return _sim != null and _sim.find_unit_by_deck_entry(entry_id) != null


## 打出手牌到格子；成功返回空串，失败返回原因（同时显示在 HUD）。
func try_deploy(entry_id: int, cell: Vector2i) -> String:
	var reason := _validate_deploy(entry_id, cell)
	if not reason.is_empty():
		_show_hint(reason)
		return reason
	var entry := _find_hand_entry(entry_id)
	var unit := UnitInstance.from_deck_entry(entry, cell, UnitInstance.Team.PLAYER)
	if unit == null:
		_show_hint("无法生成单位")
		return "无法生成单位"
	_sim.add_unit(unit, Vector2(cell) + Vector2(0.5, 0.5))
	if _selected_entry_id == entry_id:
		_set_selected(-1)
	_refresh_cards()
	return ""


## 准备阶段收回己方单位；成功返回 true。
func try_recall_at(tile_pos: Vector2) -> bool:
	if _phase != Phase.PREPARE or _sim == null:
		return false
	var rt := _find_player_unit_at(tile_pos)
	if rt == null:
		return false
	return _sim.remove_unit(rt)


func try_start_combat() -> bool:
	if _phase != Phase.PREPARE or _sim == null:
		return false
	if get_player_unit_count() < 1:
		_show_hint("至少投放 1 名单位才能开战")
		return false
	for spawn in _pending_enemies:
		_sim.add_unit(spawn["unit"], spawn["position"])
	_pending_enemies.clear()
	_sim.begin_combat()
	_arena.enemy_previews = []
	_set_selected(-1)
	_set_phase(Phase.COMBAT)
	return true


## 结算后“继续”：释放本场战斗并发出 encounter_completed。
func continue_after_result() -> void:
	if _phase != Phase.RESULT:
		return
	var won := _won
	_result_overlay.visible = false
	_teardown_sim()
	_hand.clear()
	_rebuild_cards()
	_set_phase(Phase.IDLE)
	encounter_completed.emit(won)


# --- 流程 ---


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_refresh_hud()
	_refresh_cards()
	phase_changed.emit(phase)


func _resolve_draw_count() -> int:
	var count := _deck_state.get_draw_count() if _deck_state != null else 0
	return count if count > 0 else DEFAULT_DRAW_COUNT


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


func _build_enemy_previews() -> Array:
	var previews: Array = []
	for spawn in _pending_enemies:
		var unit := spawn["unit"] as UnitInstance
		var label := unit.unit_data.display_name if unit.unit_data != null else unit.id
		var stats := unit.stats
		var body_r := stats.body_radius if stats != null else 0.7
		previews.append({
			"position": spawn["position"],
			"radius": body_r,
			"visual_half_width": stats.get_visual_half_width() if stats != null else body_r * 1.3,
			"visual_half_height": stats.get_visual_half_height() if stats != null else body_r * 1.6,
			"label": label,
		})
	return previews


func _validate_deploy(entry_id: int, cell: Vector2i) -> String:
	if _sim == null or (_phase != Phase.PREPARE and _phase != Phase.COMBAT):
		return "当前不可投放"
	if cell.x < 0 or cell.y < 0 or cell.x >= _board_size.x or cell.y >= _board_size.y:
		return "请投放到战场内"
	if not BoardHalf.is_player_deploy_cell(cell, _board_size.y):
		return "敌方半场不可投放"
	if _find_hand_entry(entry_id) == null:
		return "该牌不在本场手牌中"
	if is_entry_on_field(entry_id):
		return "该单位已在场"
	if get_player_unit_count() >= get_max_board_units():
		return "人口已满 (%d/%d)" % [get_player_unit_count(), get_max_board_units()]
	if _is_cell_occupied(cell):
		return "该格已有单位"
	return ""


func _is_cell_occupied(cell: Vector2i) -> bool:
	for item in _sim.get_units():
		if (item as RtUnit).get_cell() == cell:
			return true
	return false


func _find_hand_entry(entry_id: int) -> DeckEntry:
	for entry in _hand:
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
	_pending_enemies.clear()


func _disconnect_economy() -> void:
	if _economy != null and _economy.gold_changed.is_connected(_on_gold_changed):
		_economy.gold_changed.disconnect(_on_gold_changed)


# --- 回调 ---


func _on_board_pressed(tile_pos: Vector2) -> void:
	if _sim == null:
		return
	if _phase == Phase.PREPARE and try_recall_at(tile_pos):
		_show_hint("已收回")
		return
	if _selected_entry_id >= 0:
		try_deploy(_selected_entry_id, _arena.tile_to_cell(tile_pos))
		return
	if _phase == Phase.COMBAT and _find_player_unit_at(tile_pos) != null:
		_show_hint("已上场单位不可移动")


func _on_card_dropped(entry_id: int, tile_pos: Vector2) -> void:
	try_deploy(entry_id, _arena.tile_to_cell(tile_pos))


func _on_card_pressed(entry_id: int) -> void:
	if _phase != Phase.PREPARE and _phase != Phase.COMBAT:
		return
	if is_entry_on_field(entry_id):
		_show_hint("该单位已在场")
		_set_selected(-1)
		return
	_set_selected(-1 if _selected_entry_id == entry_id else entry_id)


func _on_start_pressed() -> void:
	try_start_combat()


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
	for entry in _hand:
		var card := RealtimeHandCard.new()
		_hand_row.add_child(card)
		card.setup(entry)
		card.card_pressed.connect(_on_card_pressed)
		_cards.append(card)
	_refresh_cards()


func _refresh_cards() -> void:
	var deploy_phase := _phase == Phase.PREPARE or _phase == Phase.COMBAT
	for card in _cards:
		var on_field := is_entry_on_field(card.get_entry_id())
		card.available = deploy_phase and not on_field
		card.status_text = "在场" if on_field else ""
		if on_field and card.selected:
			_set_selected(-1)
	if _start_button != null:
		var preparing := _phase == Phase.PREPARE
		_start_button.disabled = not preparing or get_player_unit_count() < 1
		match _phase:
			Phase.COMBAT:
				_start_button.text = "战斗中"
			Phase.RESULT:
				_start_button.text = "已结束"
			_:
				_start_button.text = "开始战斗"


func _refresh_hud() -> void:
	if _encounter_label == null:
		return
	_encounter_label.text = _encounter.display_name if _encounter != null else "实时战斗"
	_gold_label.text = "金币 %d" % (_economy.gold if _economy != null else 0)
	_pop_label.text = "人口 %d/%d" % [get_player_unit_count(), get_max_board_units()]
	var elapsed := _sim.elapsed_seconds if _sim != null else 0.0
	_timer_label.text = _format_time(elapsed)
	if not _hint_text.is_empty():
		_phase_label.text = _hint_text
		_phase_label.modulate = Color(1.0, 0.75, 0.45)
		return
	_phase_label.modulate = Color.WHITE
	match _phase:
		Phase.PREPARE:
			_phase_label.text = "准备：选牌后点下半场" if _selected_entry_id < 0 else "点下半场格子投放"
		Phase.COMBAT:
			_phase_label.text = "战斗中·可补人"
		Phase.RESULT:
			_phase_label.text = "胜利" if _won else "失败"
		_:
			_phase_label.text = "等待"


static func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
