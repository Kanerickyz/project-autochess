class_name BoardController
extends Node2D

enum BoardSizeMode {
	USE_LEVEL_DATA,
	CUSTOM,
}

const DEV_LEVEL := preload("res://resources/levels/dev_6x6.tres")
const DEFAULT_ECONOMY := preload("res://resources/economy/default_economy.tres")
const DEFAULT_SHOP_POOL := preload("res://resources/shop/dev_shop_pool.tres")
const DEFAULT_DECK_CONFIG := preload("res://resources/deck/default_deck.tres")
const DEFAULT_LEVEL_CONFIG := preload("res://resources/deck/default_level_config.tres")
const _AttackRangePreview := preload("res://scripts/combat/attack_range_preview.gd")
const _BoardCameraRigScript := preload("res://scripts/ui/board_camera_rig.gd")

@export_group("Board Size")
@export var size_mode: BoardSizeMode = BoardSizeMode.USE_LEVEL_DATA
@export_range(1, 24, 1) var board_width: int = 4
@export_range(1, 24, 1) var board_height: int = 8

@export_group("Level")
@export var level_data: LevelData

@export_group("Economy")
@export var economy_config: EconomyConfig
@export var shop_pool_config: ShopPoolConfig
@export var deck_config: DeckConfig

@export_group("Run")
@export var run_mode_enabled: bool = false
## 直接运行 main.tscn 时启用线性波次（不走地图）
@export var linear_dev_mode: bool = true

signal encounter_completed(won: bool)
signal shop_visit_completed()

@onready var _board_world: Node3D = $BoardWorld
@onready var _board_scene: BoardScene3D = $BoardWorld/BoardScene3D
@onready var _camera_rig: _BoardCameraRigScript = $BoardCameraRig
@onready var _combat_camera: Camera3D = $CombatCamera3D
@onready var _combat_presentation: CombatPresentation = $CombatPresentation
@onready var _board_vfx_layer: Node2D = %BoardVfxLayer
@onready var _camera_shake_3d: CameraShake3D = $CombatCamera3D/CameraShake3D
@onready var _combat_arena: CombatArena = $CombatArena
@onready var _start_button: Button = %StartCombatButton
@onready var _next_wave_button: Button = %NextWaveButton
@onready var _shop_phase_screen: ShopPhaseScreen = %ShopPhaseScreen
@onready var _finish_shop_button: Button = _shop_phase_screen.finish_button
@onready var _status_label: Label = %StatusLabel
@onready var _player_hud: PlayerHUD = %PlayerHUD
@onready var _shop_panel: ShopPanel = _shop_phase_screen.shop_panel
@onready var _hand_panel: HandPanel = %HandPanel
@onready var _deck_replace_modal: DeckReplaceModal = %DeckReplaceModal
@onready var _buff_attach_modal: BuffAttachModal = %BuffAttachModal
@onready var _unit_tooltip: UnitTooltip = %UnitTooltip
@onready var _combat_victory_overlay: CombatVictoryOverlay = %CombatVictoryOverlay
@onready var _ui_layer: CanvasLayer = $UI

const COMBAT_RESULT_HOLD_SEC := 2.5
const COMBAT_VICTORY_PRE_OVERLAY_HOLD_SEC := 1.25

var board_grid: BoardGrid = BoardGrid.new()
var match_state: MatchStateMachine = MatchStateMachine.new()
var match_flow: MatchFlowController = MatchFlowController.new()
var run_economy: RunEconomy = RunEconomy.new()
var deck_state: DeckState = DeckState.new()
var shop_service: ShopService = ShopService.new()
var shop_effect_resolver: ShopEffectResolver = ShopEffectResolver.new()
var shop_deck_binder: ShopDeckBinder = ShopDeckBinder.new()
var board_ui_binder: BoardUiBinder = BoardUiBinder.new()
var prepare_placement: PreparePlacementController = PreparePlacementController.new()

var _rng := RandomNumberGenerator.new()
var _selected_entry_id: int = -1
var _wave_hand_entry_ids: Array[int] = []
var _pending_replace_slot: int = -1
var _pending_buff_slot: int = -1
var _pending_buff_card: BuffCardData
var _economy_bus_connected: bool = false
var _hovered_board_unit: UnitInstance
var _hovered_hand_entry: DeckEntry
var _hovered_shop_offer: ShopOffer
var _combat_layout_snapshot: Array[Dictionary] = []
var _combat_status_base: String = ""
var _placement_drag: PlacementDragController
## PREPARE-only: drag board units to move / withdraw.
var _prepare_drag_enabled: bool = false
## PREPARE + COMBAT: drag / click hand cards onto empty cells.
var _hand_deploy_drag_enabled: bool = false
var _pending_defeat_reset: bool = false
var _pending_run_reset_on_shop: bool = false
## 本 Run 内进入商店的次数（首店=1），用于 Tier 解锁，与 wave_index 解耦。
var _shop_visit_count: int = 0
var _last_shop_max_tier: int = 0
var _pending_wave_entries: Array[SpawnScheduleEntry] = []
var _wave_placement_rng_state: int = 0
var _locked_spawn_placements: Array = []
var _last_preview_placements: Array = []
var _board_animating: bool = false
var _shop_ui_animating: bool = false
var _encounter_tier_index: int = 0
var _linear_wave_index: int = 0
var _run_controller: RunController
var _current_encounter_label: String = ""
var _awaiting_run_shop_finish: bool = false


func _ready() -> void:
	_rng.randomize()
	if level_data == null:
		level_data = DEV_LEVEL
	if economy_config == null:
		economy_config = DEFAULT_ECONOMY
	if shop_pool_config == null:
		shop_pool_config = DEFAULT_SHOP_POOL
	if deck_config == null:
		deck_config = DEFAULT_DECK_CONFIG
	if deck_config.level_config == null:
		deck_config.level_config = DEFAULT_LEVEL_CONFIG

	match_flow = MatchFlowController.new(match_state)
	_init_economy_system()
	_sync_exports_from_level_data()
	_camera_rig.bind(_combat_camera, _board_scene, _camera_shake_3d)
	_setup_board()
	_bind_combat_presentation()
	shop_deck_binder.configure(
		_shop_panel, _hand_panel, shop_service, deck_state, run_economy
	)
	board_ui_binder.configure(_status_label, _player_hud, _unit_tooltip)
	_board_scene.cell_clicked.connect(_on_cell_clicked)
	_board_scene.unit_hover_changed.connect(_on_unit_hover_changed)
	_board_scene.grid_cell_hover_changed.connect(_on_grid_cell_hover_changed)
	_start_button.pressed.connect(_on_start_combat_pressed)
	_next_wave_button.pressed.connect(_on_next_wave_pressed)
	_finish_shop_button.pressed.connect(_on_finish_shop_pressed)
	_combat_arena.combat_ended.connect(_on_combat_ended)
	_combat_arena.combat_tick_processed.connect(_on_combat_tick_processed)

	_shop_panel.character_buy_pressed.connect(_on_shop_character_buy_pressed)
	_shop_panel.buff_buy_pressed.connect(_on_shop_buff_buy_pressed)
	_shop_panel.refresh_pressed.connect(_on_shop_refresh_pressed)
	_shop_panel.offer_hovered.connect(_on_shop_offer_hovered)
	_shop_panel.offer_unhovered.connect(_on_shop_offer_unhovered)
	_hand_panel.entry_pressed.connect(_on_deck_entry_pressed)
	_hand_panel.entry_sell_pressed.connect(_on_deck_entry_sell_pressed)
	_hand_panel.entry_hovered.connect(_on_hand_entry_hovered)
	_hand_panel.entry_unhovered.connect(_on_hand_entry_unhovered)
	_hand_panel.entry_drag_started.connect(_on_hand_entry_drag_started)
	_setup_placement_drag()
	_mount_start_combat_button()
	_deck_replace_modal.entry_selected.connect(_on_deck_replace_selected)
	_deck_replace_modal.cancelled.connect(_on_deck_replace_cancelled)
	_buff_attach_modal.entry_selected.connect(_on_buff_attach_selected)
	_buff_attach_modal.cancelled.connect(_on_buff_attach_cancelled)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	run_economy.gold_changed.connect(_on_gold_changed)
	shop_service.shop_changed.connect(_refresh_shop_ui)
	deck_state.deck_changed.connect(_on_deck_changed)

	_reset_run()
	if run_mode_enabled:
		set_run_visible(false)
		return
	await get_tree().process_frame
	if linear_dev_mode and level_data != null and not level_data.waves.is_empty():
		_start_linear_dev_run()
	else:
		_enter_shop_phase(true, false)
		_set_status(_get_shop_status_text("商店阶段：购买或出售角色卡/增益卡，完成后进入部署"))


func reload_board() -> void:
	if not is_node_ready():
		return
	board_grid.clear_units()
	match_state.reset()
	_reset_run()
	_linear_wave_index = 0
	_setup_board()
	if run_mode_enabled:
		set_run_visible(false)
		return
	if linear_dev_mode and level_data != null and not level_data.waves.is_empty():
		_start_linear_dev_run()
	else:
		_enter_shop_phase(true, false)
		_set_status(_get_shop_status_text("商店阶段：购买或出售角色卡/增益卡，完成后进入部署"))


func initialize_for_run(run_controller: RunController) -> void:
	_run_controller = run_controller
	if run_controller.get_board_defaults() != null:
		level_data = run_controller.get_board_defaults()
	_sync_exports_from_level_data()
	_setup_board()
	_reset_run()
	_linear_wave_index = 0
	_encounter_tier_index = run_controller.get_encounter_tier_index()
	_shop_visit_count = run_controller.run_state.shop_visit_count
	_last_shop_max_tier = 0
	set_run_visible(false)


func set_run_visible(is_visible: bool) -> void:
	visible = is_visible
	if _ui_layer != null:
		_ui_layer.visible = is_visible


func start_run_encounter(encounter: EncounterData, tier_index: int) -> void:
	_encounter_tier_index = tier_index
	match_state.set_encounter(encounter)
	_apply_encounter_board(encounter)
	_current_encounter_label = encounter.display_name if encounter != null else "遭遇战"
	set_run_visible(true)
	_enter_prepare_phase(false)


func start_map_shop(shop_wave: int) -> void:
	_shop_visit_count = maxi(1, shop_wave)
	_awaiting_run_shop_finish = true
	set_run_visible(true)
	_enter_shop_phase(true, false)
	_set_status(_get_shop_status_text("地图商店：购买完成后返回地图"))


func grant_bonus_gold(amount: int) -> void:
	run_economy.grant(amount)


func heal_all_player_units() -> void:
	_reset_player_hp()


func _apply_encounter_board(encounter: EncounterData) -> void:
	if level_data == null:
		return
	var size := level_data.get_board_size()
	if encounter != null and encounter.has_board_override():
		size = encounter.get_board_size(size)
	_configure_board_grid(size, encounter)
	_configure_board_presentation()
	_camera_rig.layout_for_viewport()


func _get_blocked_cells_for_encounter(encounter: EncounterData) -> Array[Vector2i]:
	if level_data == null:
		return []
	if encounter != null:
		return encounter.get_blocked_cells(level_data.blocked_cells)
	return level_data.blocked_cells


func _configure_board_grid(size: Vector2i, encounter: EncounterData = null) -> void:
	if _should_generate_terrain(encounter):
		var tileset := _resolve_terrain_tileset(encounter)
		var terrain_rng := _make_terrain_rng(encounter)
		var terrain_map := WfcGenerator.generate(size, tileset, terrain_rng)
		board_grid.configure_from_terrain(size, terrain_map, tileset)
		return
	var blocked: Array[Vector2i] = []
	if encounter != null:
		blocked = _get_blocked_cells_for_encounter(encounter)
	else:
		blocked = _get_blocked_cells()
	board_grid.configure(size, blocked)


func _should_generate_terrain(encounter: EncounterData = null) -> bool:
	var level_default := level_data != null and level_data.generate_terrain
	if encounter != null:
		return encounter.should_generate_terrain(level_default)
	return level_default


func _resolve_terrain_tileset(encounter: EncounterData = null) -> TerrainTileset:
	var fallback: TerrainTileset = null
	if level_data != null:
		fallback = level_data.resolve_terrain_tileset()
	if encounter != null:
		return encounter.resolve_terrain_tileset(fallback)
	if fallback != null:
		return fallback
	return TerrainTileset.load_or_default()


func _make_terrain_rng(encounter: EncounterData = null) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var seed_value := 0
	if encounter != null and encounter.terrain_seed != 0:
		seed_value = encounter.terrain_seed
	elif level_data != null and level_data.terrain_seed != 0:
		seed_value = level_data.terrain_seed
	if seed_value != 0:
		var salt := 0
		if encounter != null and not encounter.id.is_empty():
			salt = int(hash(encounter.id))
		rng.seed = seed_value ^ salt
	else:
		rng.seed = _rng.randi()
	return rng


func _start_linear_dev_run() -> void:
	_linear_wave_index = 0
	_encounter_tier_index = 0
	match_state.reset()
	_enter_shop_phase(true, false)
	_set_status(_get_shop_status_text("线性开发关：购买完成后进入第 1 波部署"))


func _set_linear_encounter_from_wave() -> void:
	if level_data == null or _linear_wave_index >= level_data.waves.size():
		match_state.set_encounter(null)
		return
	var encounter := EncounterData.new()
	encounter.display_name = "第 %d 波" % (_linear_wave_index + 1)
	encounter.wave = level_data.waves[_linear_wave_index]
	match_state.set_encounter(encounter)
	_encounter_tier_index = _linear_wave_index
	_current_encounter_label = encounter.display_name


func get_board_size() -> Vector2i:
	return _resolve_board_size()


func _init_economy_system() -> void:
	run_economy.configure(economy_config)
	deck_state.configure(deck_config)
	shop_service.configure(shop_pool_config, run_economy, _rng)
	_configure_shop_resolver()
	_shop_panel.setup(
		shop_service.get_character_slot_count(),
		shop_service.get_buff_slot_count(),
	)


func _configure_shop_resolver() -> void:
	shop_effect_resolver.configure(deck_state, shop_service, run_economy, _rng)


func _reset_run() -> void:
	run_economy.reset()
	deck_state.reset_from_config()
	_shop_visit_count = 0
	_last_shop_max_tier = 0
	_selected_entry_id = -1
	clear_wave_hand()
	_clear_pending_shop()
	_on_gold_changed(run_economy.gold)


func _enter_shop_phase(reroll_shop: bool = true, animate_ui: bool = false) -> void:
	if _pending_defeat_reset:
		_apply_defeat_reset()
		_pending_defeat_reset = false
	if _pending_run_reset_on_shop:
		_linear_wave_index = 0
		_pending_run_reset_on_shop = false

	clear_wave_hand()
	if not _awaiting_run_shop_finish:
		_shop_visit_count += 1
	var new_max_tier := TierUnlock.get_max_unlocked_tier(_get_shop_wave())
	var tier_just_unlocked := new_max_tier > _last_shop_max_tier and _last_shop_max_tier > 0
	match_flow.enter_shop()
	_set_prepare_drag_enabled(false)
	_set_hand_deploy_drag_enabled(false)
	_clear_wave_preview()
	_clear_pending_shop()
	if reroll_shop:
		shop_service.roll_shop(_get_shop_wave())
	_refresh_shop_ui()
	_hovered_board_unit = null
	_hovered_hand_entry = null
	_hovered_shop_offer = null
	board_ui_binder.hide_tooltip()

	if animate_ui:
		_shop_ui_animating = true
		_set_board_transition_locked(true)
		_update_ui()
		_hand_panel.play_shop_reveal()
		await _shop_phase_screen.play_show()
		_shop_ui_animating = false
		_set_board_transition_locked(false)
		_update_ui()
	else:
		_update_ui()
		_shop_phase_screen.show_instant()
		_hand_panel.show_shop_instant()

	if tier_just_unlocked:
		_shop_panel.show_tier_unlock(new_max_tier)
	_last_shop_max_tier = new_max_tier


func _enter_prepare_phase(clear_player_units: bool = false) -> void:
	_enter_prepare_phase_async(clear_player_units)


func _enter_prepare_phase_async(clear_player_units: bool = false) -> void:
	if _board_animating or _shop_ui_animating or _shop_phase_screen.transition_active:
		return
	_board_animating = true
	match_flow.enter_prepare()
	_shop_panel.hide_tier_unlock()
	_hovered_shop_offer = null
	board_ui_binder.hide_tooltip()
	if clear_player_units:
		board_grid.clear_team(UnitInstance.Team.PLAYER)
	_selected_entry_id = -1
	_draw_wave_hand()
	_refresh_hand_ui()
	_shop_ui_animating = true
	_set_board_transition_locked(true)
	if _shop_phase_screen.visible:
		await _shop_phase_screen.play_hide()
	_shop_ui_animating = false
	_bind_combat_presentation()
	_configure_board_presentation()
	_board_scene.prepare_board_reveal_hidden()
	_board_world.visible = true
	_update_ui()
	await _board_scene.play_board_reveal()
	_board_scene.refresh()
	_log_empty_cells()
	_set_prepare_drag_enabled(true)
	_set_hand_deploy_drag_enabled(true)
	_roll_wave_preview()
	_set_board_transition_locked(false)
	_board_animating = false
	_update_ui()


func _draw_wave_hand() -> void:
	var count := 5
	if deck_config != null:
		count = deck_config.draw_count
	var drawn := DrawService.draw_wave_hand(deck_state, count, _rng)
	_wave_hand_entry_ids.clear()
	for entry in drawn:
		if entry != null:
			_wave_hand_entry_ids.append(entry.entry_id)


func clear_wave_hand() -> void:
	_wave_hand_entry_ids.clear()
	_selected_entry_id = -1


func _get_wave_hand_entries() -> Array[DeckEntry]:
	var entries: Array[DeckEntry] = []
	for entry_id in _wave_hand_entry_ids:
		var entry := deck_state.get_entry(entry_id)
		if entry != null:
			entries.append(entry)
	return entries


func _is_in_wave_hand(entry_id: int) -> bool:
	return _wave_hand_entry_ids.has(entry_id)


func _is_deploy_phase() -> bool:
	var phase := match_state.phase
	return (
		phase == MatchStateMachine.Phase.PREPARE
		or phase == MatchStateMachine.Phase.COMBAT
	)


func _set_board_transition_locked(locked: bool) -> void:
	_start_button.disabled = locked
	_finish_shop_button.disabled = locked
	if locked:
		_hand_panel.set_interactive(false)
		_shop_panel.set_interactive(false)
	elif is_node_ready():
		_update_ui()


func _on_deck_changed() -> void:
	if match_state.phase == MatchStateMachine.Phase.COMBAT:
		return
	_sync_deployed_units_from_deck()
	_refresh_hand_ui()
	if _board_world.visible:
		_board_scene.refresh()
		if _hovered_board_unit != null and _unit_tooltip != null:
			_unit_tooltip.refresh_if_showing(_hovered_board_unit)


func _sync_deployed_units_from_deck() -> void:
	var to_remove: Array[UnitInstance] = []
	for unit in board_grid.get_units_by_team(UnitInstance.Team.PLAYER, true):
		if unit.deck_entry_id < 0:
			continue
		var entry := deck_state.get_entry(unit.deck_entry_id)
		if entry == null:
			to_remove.append(unit)
			continue
		UnitInstance.sync_from_deck_entry(unit, entry)

	for unit in to_remove:
		board_grid.remove_unit(unit)
		if _selected_entry_id == unit.deck_entry_id:
			_selected_entry_id = -1
		if _hovered_board_unit == unit:
			_hovered_board_unit = null
			if _unit_tooltip != null:
				_unit_tooltip.hide_tooltip()


func _get_deployed_entry_ids() -> Dictionary:
	var deployed: Dictionary = {}
	for unit in board_grid.get_units_by_team(UnitInstance.Team.PLAYER, true):
		if unit.deck_entry_id >= 0:
			deployed[unit.deck_entry_id] = true
	return deployed


func _count_player_units_on_board() -> int:
	return board_grid.get_units_by_team(UnitInstance.Team.PLAYER, true).size()


func _is_entry_deployed(entry_id: int) -> bool:
	return _get_deployed_entry_ids().has(entry_id)


func _can_deploy_more() -> bool:
	return _count_player_units_on_board() < deck_state.get_max_board_units()


func _resolve_board_size() -> Vector2i:
	match size_mode:
		BoardSizeMode.USE_LEVEL_DATA:
			if level_data != null:
				return level_data.get_board_size()
			return Vector2i(board_width, board_height)
		BoardSizeMode.CUSTOM:
			return Vector2i(board_width, board_height)
	return Vector2i(6, 6)


func _get_blocked_cells() -> Array[Vector2i]:
	if level_data == null:
		return []
	return level_data.blocked_cells


func _sync_exports_from_level_data() -> void:
	if level_data == null or size_mode != BoardSizeMode.USE_LEVEL_DATA:
		return
	var size := level_data.get_board_size()
	board_width = size.x
	board_height = size.y


func _setup_board() -> void:
	var size := _resolve_board_size()
	_configure_board_grid(size, null)
	_configure_board_presentation()
	_board_scene.sync_units()
	_board_scene.set_character_phase(UnitCardDisplay.CharacterPhase.PREPARE)
	_camera_rig.apply_prepare_pose()
	_board_scene.prepare_board_reveal_hidden()
	_board_world.visible = false
	_log_empty_cells()


func _configure_board_presentation() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if _hand_panel != null:
		_hand_panel.layout_as_bottom_dock(vp_size.y)
	var pixel_cell := BoardLayout.compute_cell_size(board_grid, vp_size)
	_board_scene.setup(board_grid, _combat_camera, _board_vfx_layer, pixel_cell)
	## Side gutters + bottom dock: arena frames as an inset playable box (CR-like).
	_camera_rig.layout_for_viewport()


func _layout_board() -> void:
	_configure_board_presentation()


func _on_viewport_size_changed() -> void:
	if not is_node_ready() or _board_scene == null:
		return
	_layout_board()
	if _board_world != null and _board_world.visible:
		_board_scene.refresh()


func _bind_combat_presentation() -> void:
	_combat_presentation.setup(_board_scene)
	_combat_presentation.set_camera_shake_3d(_camera_shake_3d)


func _mount_start_combat_button() -> void:
	if _hand_panel == null or _start_button == null:
		return
	var host := _hand_panel.get_start_button_host()
	if host == null:
		return
	if _start_button.get_parent() == host:
		return
	_start_button.reparent(host)
	_start_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_button.offset_left = 0.0
	_start_button.offset_top = 0.0
	_start_button.offset_right = 0.0
	_start_button.offset_bottom = 0.0
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _on_cell_clicked(cell: Vector2i) -> void:
	if not _is_deploy_phase():
		return
	if _board_animating or _board_scene.board_transition_active:
		return
	if _placement_drag != null and _placement_drag.is_dragging():
		return
	if prepare_placement.drag_tracking:
		return

	if board_grid.get_unit(cell) != null:
		return

	if _selected_entry_id < 0:
		_set_status("请先点选手牌，或拖拽至棋盘空格")
		return

	try_deploy_entry(_selected_entry_id, cell, true)


func try_deploy_entry(entry_id: int, cell: Vector2i, clear_selection: bool = false) -> bool:
	if not _is_deploy_phase():
		return false
	if not _is_in_wave_hand(entry_id):
		_set_status("该单位不在本波手牌中")
		return false
	if board_grid.is_blocked(cell):
		_set_status("该格不可放置")
		return false
	if not BoardHalf.is_player_deploy_cell(cell, board_grid.get_size().y):
		_set_status("只能放在我方半场空格")
		return false
	if board_grid.get_unit(cell) != null:
		_set_status("该格已被占用")
		return false
	if _is_entry_deployed(entry_id):
		if clear_selection:
			_selected_entry_id = -1
			_refresh_hand_ui()
		_set_status("该单位已在场上")
		return false
	if not _can_deploy_more():
		var max_units := deck_state.get_max_board_units()
		_set_status("人口已满（%d/%d）" % [_count_player_units_on_board(), max_units])
		return false

	var entry := deck_state.get_entry(entry_id)
	if entry == null:
		if clear_selection:
			_selected_entry_id = -1
			_refresh_hand_ui()
		return false

	var unit := UnitInstance.from_deck_entry(
		entry,
		cell,
		UnitInstance.Team.PLAYER,
	)
	if unit == null:
		return false

	if not board_grid.place(unit, cell):
		return false

	if clear_selection:
		_selected_entry_id = -1
	_board_scene.refresh()
	if match_state.phase == MatchStateMachine.Phase.COMBAT:
		_get_active_board_presentation().sync_units()
	_refresh_hand_ui()
	_log_empty_cells()
	if match_state.phase == MatchStateMachine.Phase.PREPARE:
		_stabilize_enemy_preview()
	_set_status("已上场 %s" % entry.get_display_name())
	return true


func try_withdraw_at(cell: Vector2i) -> bool:
	if match_state.phase != MatchStateMachine.Phase.PREPARE:
		return false
	var existing := board_grid.get_unit(cell)
	if existing == null or existing.team != UnitInstance.Team.PLAYER:
		return false
	if existing.deck_entry_id == _selected_entry_id:
		_selected_entry_id = -1
	board_grid.remove(cell)
	_board_scene.refresh()
	_refresh_hand_ui()
	_log_empty_cells()
	_stabilize_enemy_preview()
	_set_status("已从棋盘撤回单位")
	return true


func try_withdraw_unit(unit: UnitInstance) -> bool:
	if unit == null:
		return false
	var cell := board_grid.find_cell_of(unit)
	if cell == Vector2i(-1, -1):
		return false
	return try_withdraw_at(cell)


func try_reposition_unit(unit: UnitInstance, to_cell: Vector2i) -> bool:
	if match_state.phase != MatchStateMachine.Phase.PREPARE:
		return false
	if unit == null or unit.team != UnitInstance.Team.PLAYER:
		return false
	var from_cell := board_grid.find_cell_of(unit)
	if from_cell == Vector2i(-1, -1):
		return false
	if from_cell == to_cell:
		return true
	if board_grid.is_blocked(to_cell):
		_set_status("该格不可放置")
		return false
	if not BoardHalf.is_player_deploy_cell(to_cell, board_grid.get_size().y):
		_set_status("只能放在我方半场空格")
		return false

	var occupant := board_grid.get_unit(to_cell)
	var status_msg := "已移动单位"
	if occupant != null:
		if occupant.team != UnitInstance.Team.PLAYER:
			_set_status("该格不可放置")
			return false
		if not board_grid.swap_units_at(from_cell, to_cell):
			_set_status("无法互换位置")
			return false
		status_msg = "已互换位置"
	elif not board_grid.move_unit_for(unit, to_cell):
		_set_status("无法移动至该格")
		return false

	_board_scene.refresh()
	_log_empty_cells()
	_stabilize_enemy_preview()
	_set_status(status_msg)
	return true


func is_hand_drop_zone(viewport_pos: Vector2) -> bool:
	if _hand_panel == null or not _hand_panel.visible:
		return false
	return _hand_panel.get_withdraw_drop_rect().has_point(viewport_pos)


func _is_valid_board_drop_at(
	cell: Vector2i,
	drag_source: PlacementDragController.Source,
	dragging_unit: UnitInstance = null,
) -> bool:
	return cell != Vector2i(-1, -1) and _can_drop_on_board_cell(cell, drag_source, dragging_unit)


func _resolve_board_drop_cell(
	viewport_pos: Vector2,
	drag_source: PlacementDragController.Source,
	board_unit: UnitInstance,
	from_cell: Vector2i,
) -> Vector2i:
	var cell := _board_scene.get_cell_at_viewport_pos(viewport_pos)
	if _is_valid_board_drop_at(cell, drag_source, board_unit):
		return cell
	if (
		drag_source == PlacementDragController.Source.BOARD
		and _is_valid_board_drop_at(prepare_placement.last_valid_drop_cell, drag_source, board_unit)
	):
		return prepare_placement.last_valid_drop_cell
	if (
		drag_source == PlacementDragController.Source.BOARD
		and from_cell != Vector2i(-1, -1)
		and _is_valid_board_drop_at(from_cell, drag_source, board_unit)
	):
		return from_cell
	return cell


func _can_drop_on_board_cell(
	cell: Vector2i,
	drag_source: PlacementDragController.Source,
	dragging_unit: UnitInstance = null,
) -> bool:
	if not board_grid.in_bounds(cell) or board_grid.is_blocked(cell):
		return false
	match drag_source:
		PlacementDragController.Source.HAND:
			if board_grid.get_unit(cell) != null:
				return false
			return BoardHalf.is_player_deploy_cell(cell, board_grid.get_size().y)
		PlacementDragController.Source.BOARD:
			if not BoardHalf.is_player_deploy_cell(cell, board_grid.get_size().y):
				return false
			var occupant := board_grid.get_unit(cell)
			if occupant == null:
				return true
			if dragging_unit == null:
				return false
			if occupant == dragging_unit:
				return true
			return occupant.team == UnitInstance.Team.PLAYER
	return false


func _setup_placement_drag() -> void:
	if _placement_drag != null:
		return
	_placement_drag = PlacementDragController.new()
	_placement_drag.name = "PlacementDragController"
	_ui_layer.add_child(_placement_drag)
	_placement_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	_placement_drag.set_enabled(false)


func _set_prepare_drag_enabled(enabled: bool) -> void:
	_prepare_drag_enabled = enabled
	_sync_placement_drag_enabled()
	if not enabled:
		_cancel_board_unit_drag_only()


func _set_hand_deploy_drag_enabled(enabled: bool) -> void:
	_hand_deploy_drag_enabled = enabled
	_sync_placement_drag_enabled()
	if not enabled and _placement_drag != null and _placement_drag.is_dragging():
		if _placement_drag.source == PlacementDragController.Source.HAND:
			_cancel_active_drag()


func _sync_placement_drag_enabled() -> void:
	if _placement_drag == null:
		return
	_placement_drag.set_enabled(_prepare_drag_enabled or _hand_deploy_drag_enabled)


func _cancel_board_unit_drag_only() -> void:
	if _placement_drag != null and _placement_drag.is_dragging():
		if _placement_drag.source == PlacementDragController.Source.BOARD:
			_cancel_active_drag()
			return
	prepare_placement.reset_gesture()
	_board_scene.clear_all_unit_drag_visuals()
	_board_scene.set_prepare_drag_mode(false)
	_board_scene.set_drag_hover_cell(Vector2i(-1, -1), false)


func _cancel_active_drag() -> void:
	_board_scene.clear_all_unit_drag_visuals()
	prepare_placement.reset_gesture()
	if _placement_drag != null:
		_placement_drag.cancel_drag()
	_board_scene.set_prepare_drag_mode(false)
	_board_scene.set_drag_hover_cell(Vector2i(-1, -1), false)
	_hand_panel.set_scroll_interactive(true)


func _input(event: InputEvent) -> void:
	if _placement_drag != null and _placement_drag.is_dragging():
		_handle_active_drag_input(event)
		return
	if not _prepare_drag_enabled:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if prepare_placement.drag_tracking and prepare_placement.should_promote_to_drag(motion.position):
			var unit := prepare_placement.drag_unit
			var from_cell := prepare_placement.drag_from_cell
			prepare_placement.drag_tracking = false
			_begin_board_drag(unit, from_cell, motion.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_try_begin_board_drag_tracking(mb.position)
		elif prepare_placement.drag_tracking:
			_finish_board_drag_tracking(mb.position)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if match_state.phase == MatchStateMachine.Phase.COMBAT:
		if event.is_action_pressed("combat_pause") and _combat_arena.is_running():
			var paused := _combat_arena.toggle_pause()
			var pause_hint := "（已暂停，%s 继续）" % _combat_pause_action_label()
			_set_status(_combat_status_base + (pause_hint if paused else ""))
			get_viewport().set_input_as_handled()
			return


func _combat_pause_action_label() -> String:
	var events := InputMap.action_get_events("combat_pause")
	for ev in events:
		if ev is InputEventKey:
			var key_ev := ev as InputEventKey
			var code := key_ev.keycode if key_ev.keycode != KEY_NONE else key_ev.physical_keycode
			if code != KEY_NONE:
				return OS.get_keycode_string(code)
	return "暂停键"


func _handle_active_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_active_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
			return
		_finish_active_drag(mb.position)
		get_viewport().set_input_as_handled()


func _on_hand_entry_drag_started(entry_id: int, viewport_pos: Vector2) -> void:
	if not _hand_deploy_drag_enabled:
		return
	if not _is_in_wave_hand(entry_id):
		return
	var entry := deck_state.get_entry(entry_id)
	if entry == null or _is_entry_deployed(entry_id):
		return
	_selected_entry_id = entry_id
	_refresh_hand_ui()
	_begin_hand_drag(entry_id, viewport_pos)


func _begin_hand_drag(entry_id: int, viewport_pos: Vector2) -> void:
	var entry := deck_state.get_entry(entry_id)
	if entry == null:
		return
	_hand_panel.set_scroll_interactive(false)
	_board_scene.set_prepare_drag_mode(true)
	_placement_drag.begin_hand_drag(
		entry_id,
		entry,
		deck_state.get_level_config(),
		viewport_pos,
	)
	_update_active_drag(viewport_pos)


func _try_begin_board_drag_tracking(viewport_pos: Vector2) -> void:
	if _hand_panel.get_global_rect().has_point(viewport_pos):
		return
	var unit := _board_scene.get_player_unit_at_viewport_pos(viewport_pos)
	if unit == null:
		return
	prepare_placement.drag_tracking = true
	prepare_placement.drag_press_pos = viewport_pos
	prepare_placement.drag_unit = unit
	prepare_placement.drag_from_cell = board_grid.find_cell_of(unit)


func _finish_board_drag_tracking(viewport_pos: Vector2) -> void:
	if not prepare_placement.drag_tracking:
		return
	var unit := prepare_placement.drag_unit
	var from_cell := prepare_placement.drag_from_cell
	prepare_placement.drag_tracking = false
	prepare_placement.drag_unit = null
	prepare_placement.drag_from_cell = Vector2i(-1, -1)
	if unit == null:
		return
	if prepare_placement.should_promote_to_drag(viewport_pos):
		_begin_board_drag(unit, from_cell, viewport_pos)
		_finish_active_drag(viewport_pos)
		get_viewport().set_input_as_handled()
		return
	try_withdraw_at(from_cell)


func _begin_board_drag(unit: UnitInstance, from_cell: Vector2i, viewport_pos: Vector2) -> void:
	var entry := deck_state.get_entry(unit.deck_entry_id)
	if entry == null:
		entry = _entry_from_unit(unit)
	prepare_placement.last_valid_drop_cell = from_cell
	_board_scene.set_board_unit_drag_visual(unit, true)
	_board_scene.set_prepare_drag_mode(true)
	_placement_drag.begin_board_drag(
		unit,
		entry,
		deck_state.get_level_config(),
		viewport_pos,
		from_cell,
	)
	_update_active_drag(viewport_pos)


func _entry_from_unit(unit: UnitInstance) -> DeckEntry:
	if unit == null:
		return null
	var entry := DeckEntry.new()
	entry.entry_id = unit.deck_entry_id
	entry.unit = unit.unit_data
	entry.level = unit.level
	return entry


func _update_active_drag(viewport_pos: Vector2) -> void:
	if _placement_drag == null or not _placement_drag.is_dragging():
		return
	_placement_drag.update_drag(viewport_pos)
	var cell := _board_scene.get_cell_at_viewport_pos(viewport_pos)
	var valid := _is_valid_board_drop_at(
		cell,
		_placement_drag.source,
		_placement_drag.board_unit,
	)
	if valid:
		prepare_placement.last_valid_drop_cell = cell
	_board_scene.set_drag_hover_cell(cell, valid)


func _finish_active_drag(viewport_pos: Vector2) -> void:
	if _placement_drag == null or not _placement_drag.is_dragging():
		_cancel_active_drag()
		return

	var drag_source := _placement_drag.source
	var entry_id := _placement_drag.entry_id
	var board_unit := _placement_drag.board_unit
	var from_cell := _placement_drag.from_cell
	if drag_source == PlacementDragController.Source.BOARD and board_unit != null:
		_board_scene.set_board_unit_drag_visual(board_unit, false)
	_placement_drag.end_drag(viewport_pos)

	var cell := _resolve_board_drop_cell(viewport_pos, drag_source, board_unit, from_cell)
	if _is_valid_board_drop_at(cell, drag_source, board_unit):
		match drag_source:
			PlacementDragController.Source.HAND:
				try_deploy_entry(entry_id, cell, true)
			PlacementDragController.Source.BOARD:
				if board_unit != null:
					try_reposition_unit(board_unit, cell)
		_cancel_active_drag()
		return

	if is_hand_drop_zone(viewport_pos):
		if drag_source == PlacementDragController.Source.BOARD and board_unit != null:
			try_withdraw_unit(board_unit)
		_cancel_active_drag()
		return

	if drag_source == PlacementDragController.Source.BOARD and board_unit != null:
		_board_scene.refresh()
	_cancel_active_drag()


func _on_deck_entry_sell_pressed(entry_id: int) -> void:
	if match_state.phase != MatchStateMachine.Phase.SHOP:
		return
	if _pending_replace_slot >= 0 or _pending_buff_slot >= 0:
		return

	var entry := deck_state.get_entry(entry_id)
	if entry == null or entry.unit == null:
		return

	var price := run_economy.get_sell_price(entry)
	var display_name := entry.get_display_name()
	_resolve_shop_abilities(ShopEvents.ON_SELL, entry)
	if not deck_state.remove_entry(entry_id):
		return

	run_economy.grant(price)
	_refresh_hand_ui()
	_refresh_shop_ui()
	_set_status("已出售 %s，+%d 金" % [display_name, price])


func _on_deck_entry_pressed(entry_id: int) -> void:
	if not _is_deploy_phase():
		return
	if not _is_in_wave_hand(entry_id):
		_set_status("该单位不在本波手牌中")
		return
	if _is_entry_deployed(entry_id):
		_set_status("该单位已在场上")
		return

	_selected_entry_id = entry_id if _selected_entry_id != entry_id else -1
	_refresh_hand_ui()
	_sync_attack_range_preview()
	if _selected_entry_id >= 0:
		var entry := deck_state.get_entry(_selected_entry_id)
		if entry != null:
			_set_status("已选中：%s — 点击或拖拽至棋盘上场" % entry.get_display_name())
	else:
		_set_status("已取消选中")


func _on_shop_character_buy_pressed(slot_index: int) -> void:
	if match_state.phase != MatchStateMachine.Phase.SHOP:
		return

	var offer := shop_service.get_character_offer(slot_index)
	if offer == null:
		return

	_buy_character_offer(slot_index, offer)


func _on_shop_buff_buy_pressed(slot_index: int) -> void:
	if match_state.phase != MatchStateMachine.Phase.SHOP:
		return

	var offer := shop_service.get_buff_offer(slot_index)
	if offer == null:
		return

	_buy_buff_offer(slot_index, offer)


func _buy_character_offer(slot_index: int, offer: ShopOffer) -> void:
	var buy_result := shop_service.try_buy_character(slot_index, deck_state)
	var result: ShopService.BuyCharacterResult = buy_result.get(
		"result",
		ShopService.BuyCharacterResult.FAILED,
	)
	var affected_entry: DeckEntry = buy_result.get("entry")
	match result:
		ShopService.BuyCharacterResult.ADDED_NEW:
			_resolve_shop_abilities(ShopEvents.ON_BUY, affected_entry)
			_refresh_shop_ui()
			_refresh_hand_ui()
			_set_status("已购买角色卡 %s 至牌库" % offer.get_display_name())
			return
		ShopService.BuyCharacterResult.MERGED:
			_resolve_shop_abilities(ShopEvents.ON_BUY, affected_entry)
			_refresh_shop_ui()
			_refresh_hand_ui()
			_set_status("已合并 %s 至牌库（+1 经验）" % offer.get_display_name())
			return
		ShopService.BuyCharacterResult.MERGED_LEVEL_UP:
			_resolve_shop_abilities(ShopEvents.ON_BUY, affected_entry)
			_resolve_shop_abilities(ShopEvents.ON_LEVEL_UP, affected_entry)
			_refresh_shop_ui()
			_refresh_hand_ui()
			_set_status("已合并 %s 并升级！" % offer.get_display_name())
			return

	if deck_state.is_full() and not DeckUpgradeService.has_merge_target(
		deck_state,
		offer.unit.id if offer.unit != null else "",
	):
		_pending_replace_slot = slot_index
		_deck_replace_modal.show_entries(deck_state.get_entries())
		_set_status("牌库已满，请选择要替换的条目")
	elif offer.unit != null and _all_deck_copies_max_level(offer.unit.id):
		_set_status("牌库中该角色已满级，无法继续合并")
	else:
		_set_status("购买失败：金币不足")


func _all_deck_copies_max_level(unit_id: String) -> bool:
	if unit_id.is_empty():
		return false
	var config := deck_state.get_level_config()
	var found := false
	for entry in deck_state.get_entries():
		if entry == null or entry.get_unit_id() != unit_id:
			continue
		found = true
		if not DeckUpgradeService.is_max_level(entry, config):
			return false
	return found


func _buy_buff_offer(slot_index: int, _offer: ShopOffer) -> void:
	var buff := shop_service.try_buy_buff(slot_index)
	if buff == null:
		_set_status("购买失败：金币不足")
		return

	_pending_buff_slot = slot_index
	_pending_buff_card = buff
	_buff_attach_modal.show_for_buff(buff, deck_state.get_entries())
	_set_status("请选择要附加增益的目标角色")


func _on_deck_replace_selected(replace_entry_id: int) -> void:
	if _pending_replace_slot < 0:
		return
	var offer := shop_service.get_character_offer(_pending_replace_slot)
	var name_str := offer.get_display_name() if offer != null else "角色卡"
	var new_entry := shop_service.finalize_character_with_replace(
		_pending_replace_slot,
		deck_state,
		replace_entry_id,
	)
	if new_entry != null:
		_resolve_shop_abilities(ShopEvents.ON_BUY, new_entry)
		_set_status("已替换牌库条目，加入 %s" % name_str)
		_refresh_shop_ui()
		_refresh_hand_ui()
	else:
		_set_status("替换失败")
	_pending_replace_slot = -1


func _on_deck_replace_cancelled() -> void:
	_pending_replace_slot = -1
	_set_status("已取消替换")


func _on_buff_attach_selected(entry_id: int) -> void:
	if _pending_buff_card == null or _pending_buff_slot < 0:
		return
	if deck_state.attach_buff(entry_id, _pending_buff_card):
		shop_service.clear_buff_slot(_pending_buff_slot)
		var entry := deck_state.get_entry(entry_id)
		var target_name := entry.get_display_name() if entry != null else "角色"
		_set_status(
			"已将 %s 附加至 %s"
			% [_pending_buff_card.display_name, target_name]
		)
		_refresh_shop_ui()
		_refresh_hand_ui()
	else:
		run_economy.grant(_pending_buff_card.shop_cost)
		_set_status("附加失败，已退还金币")
	_clear_pending_shop()


func _on_buff_attach_cancelled() -> void:
	if _pending_buff_card != null:
		run_economy.grant(_pending_buff_card.shop_cost)
	_set_status("已取消增益附加，金币已退还")
	_clear_pending_shop()


func _clear_pending_shop() -> void:
	_pending_replace_slot = -1
	_pending_buff_slot = -1
	_pending_buff_card = null


func _on_shop_refresh_pressed() -> void:
	if match_state.phase != MatchStateMachine.Phase.SHOP:
		return
	if shop_service.refresh(_get_shop_wave()):
		_refresh_shop_ui()
		_set_status(_get_shop_status_text("商店已刷新"))
	else:
		_set_status("刷新失败：金币不足")


func _on_start_combat_pressed() -> void:
	if match_state.phase != MatchStateMachine.Phase.PREPARE:
		return
	if _board_animating or _board_scene.board_transition_active:
		return
	var deployed_count := _count_player_units_on_board()
	if deployed_count == 0:
		_set_status("请先在棋盘上放置至少一个单位")
		return
	var max_units := deck_state.get_max_board_units()
	if deployed_count > max_units:
		_set_status("场上单位超过上限（%d/%d）" % [deployed_count, max_units])
		return
	if not match_state.has_active_encounter():
		_set_status("未配置遭遇战")
		return

	_selected_entry_id = -1
	_stabilize_enemy_preview()
	_locked_spawn_placements = _last_preview_placements.duplicate(true)
	_set_prepare_drag_enabled(false)
	_set_hand_deploy_drag_enabled(true)
	_board_scene.clear_enemy_preview()
	match_flow.enter_combat()
	_update_ui()
	_launch_combat_async()


func _launch_combat_async() -> void:
	_board_animating = true
	_set_board_transition_locked(true)
	var dur := _get_combat_transition_duration()
	_board_scene.play_body_reveal(dur)
	await _camera_rig.play_enter_combat()
	_board_scene.set_combat_view_active(true)
	_board_animating = false
	_set_board_transition_locked(false)
	_begin_combat_wave()


func _on_next_wave_pressed() -> void:
	if match_state.phase != MatchStateMachine.Phase.RESOLVE:
		return
	_enter_shop_phase(true)
	_set_status(_get_shop_status_text("商店阶段：购买完成后进入部署"))


func _apply_defeat_reset() -> void:
	_combat_layout_snapshot.clear()
	board_grid.clear_team(UnitInstance.Team.ENEMY)
	board_grid.clear_team(UnitInstance.Team.PLAYER)
	_reset_player_hp()
	match_state.reset()
	_linear_wave_index = 0
	_encounter_tier_index = 0
	_shop_visit_count = 0
	_last_shop_max_tier = 0
	deck_state.reset_from_config()
	clear_wave_hand()
	_clear_wave_preview()
	_board_scene.refresh()


func _on_finish_shop_pressed() -> void:
	if match_state.phase != MatchStateMachine.Phase.SHOP:
		return
	if _board_animating or _shop_ui_animating or _shop_phase_screen.transition_active:
		return
	if _awaiting_run_shop_finish:
		_awaiting_run_shop_finish = false
		_shop_ui_animating = true
		_set_board_transition_locked(true)
		if _shop_phase_screen.visible:
			await _shop_phase_screen.play_hide()
		_shop_ui_animating = false
		_set_board_transition_locked(false)
		set_run_visible(false)
		shop_visit_completed.emit()
		return
	if linear_dev_mode and level_data != null and not level_data.waves.is_empty():
		_set_linear_encounter_from_wave()
	_enter_prepare_phase_async()


func _begin_combat_wave() -> void:
	var wave := match_state.get_current_wave()
	if wave == null:
		_set_status("波次数据缺失")
		_enter_prepare_phase()
		return

	_clear_all_stat_modifiers()
	_capture_combat_layout()
	var encounter_label := _current_encounter_label
	if encounter_label.is_empty():
		encounter_label = "遭遇战"
	_combat_status_base = "%s 战斗中…" % encounter_label
	_set_status(_combat_status_base)
	_combat_arena.set_presentation(_combat_presentation)
	_bind_combat_presentation()
	_combat_arena.start_combat(
		board_grid,
		wave,
		_encounter_tier_index,
		_get_enemy_spawn_pool(),
		_pending_wave_entries,
		_locked_spawn_placements,
		deck_state,
	)
	_connect_economy_combat_events()
	_get_active_board_presentation().sync_units()


func _get_active_board_presentation() -> Node:
	return _board_scene


func _connect_economy_combat_events() -> void:
	_disconnect_economy_combat_events()
	if _combat_arena.event_bus == null:
		return
	_combat_arena.event_bus.combat_event.connect(_on_combat_event_for_economy)
	_economy_bus_connected = true


func _disconnect_economy_combat_events() -> void:
	if not _economy_bus_connected:
		return
	if _combat_arena.event_bus != null and is_instance_valid(_combat_arena.event_bus):
		if _combat_arena.event_bus.combat_event.is_connected(_on_combat_event_for_economy):
			_combat_arena.event_bus.combat_event.disconnect(_on_combat_event_for_economy)
	_economy_bus_connected = false


func _on_combat_event_for_economy(
	event_type: StringName,
	payload: CombatEventPayload,
) -> void:
	if payload.target == null:
		return
	if event_type == CombatEvents.ON_KILL:
		if payload.target.team != UnitInstance.Team.ENEMY:
			return
		run_economy.grant_kill_gold(payload.target.unit_data)
		return
	if event_type == CombatEvents.ON_DEATH:
		if payload.target.team != UnitInstance.Team.PLAYER:
			return
		if payload.target.death_grant_gold > 0:
			run_economy.grant(payload.target.death_grant_gold)


func _resolve_shop_abilities(trigger: StringName, owner_entry: DeckEntry) -> void:
	if owner_entry == null:
		return
	_configure_shop_resolver()
	shop_effect_resolver.resolve(trigger, owner_entry)


func _get_shop_wave() -> int:
	return maxi(1, _shop_visit_count)


func _get_enemy_spawn_pool() -> Array[UnitData]:
	if level_data != null and not level_data.enemy_pool.is_empty():
		return level_data.enemy_pool
	if shop_pool_config == null:
		return []
	# Legacy fallback: shop character pool doubled as enemy pool before LevelData.enemy_pool.
	if not shop_pool_config.character_pool.is_empty():
		return shop_pool_config.character_pool
	return shop_pool_config.pool


func _roll_wave_preview() -> void:
	_pending_wave_entries.clear()
	_wave_placement_rng_state = 0
	_last_preview_placements.clear()
	_locked_spawn_placements.clear()

	var wave := match_state.get_current_wave()
	if wave == null:
		if _board_scene != null:
			_board_scene.clear_enemy_preview()
		_update_prepare_status_text()
		return

	var pool := _get_enemy_spawn_pool()
	_pending_wave_entries = wave.roll_spawn_entries(pool, _encounter_tier_index, _rng)
	_wave_placement_rng_state = _rng.state
	_refresh_enemy_preview()


func _refresh_enemy_preview(update_status: bool = true) -> Array:
	var placements: Array[Dictionary] = []
	if not _pending_wave_entries.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.state = _wave_placement_rng_state
		placements = SpawnSystem.simulate_spawn_entries(
			board_grid,
			_pending_wave_entries,
			rng,
		)
	_last_preview_placements = placements.duplicate(true)
	if _board_scene != null and match_state.phase == MatchStateMachine.Phase.PREPARE:
		_board_scene.set_enemy_preview(_last_preview_placements)
		if update_status:
			_update_prepare_status_text()
	return _last_preview_placements


func _stabilize_enemy_preview() -> void:
	if _pending_wave_entries.is_empty() or _last_preview_placements.is_empty():
		return
	_last_preview_placements = SpawnSystem.stabilize_placements(
		board_grid,
		_last_preview_placements,
	)
	if _board_scene != null and match_state.phase == MatchStateMachine.Phase.PREPARE:
		_board_scene.set_enemy_preview(_last_preview_placements)


func _clear_wave_preview() -> void:
	_pending_wave_entries.clear()
	_wave_placement_rng_state = 0
	_locked_spawn_placements.clear()
	_last_preview_placements.clear()
	if _board_scene != null:
		_board_scene.clear_enemy_preview()


func _update_prepare_status_text() -> void:
	if match_state.phase != MatchStateMachine.Phase.PREPARE:
		return
	var encounter_label := _current_encounter_label
	if encounter_label.is_empty():
		encounter_label = "部署"
	var max_units := deck_state.get_max_board_units()
	var enemy_count := _last_preview_placements.size()
	var summary := _format_enemy_preview_summary()
	var base := (
		"部署阶段：本波敌人 %d 个（半透明预览），拖拽或选中单位上场（最多 %d 个），完成后开始%s"
		% [enemy_count, max_units, encounter_label]
	)
	if summary.is_empty():
		_set_status(base)
	else:
		_set_status("%s — %s" % [base, summary])


func _format_enemy_preview_summary() -> String:
	var counts: Dictionary = {}
	for item in _last_preview_placements:
		if item == null or not item is Dictionary:
			continue
		var unit_data: UnitData = item.get("unit")
		if unit_data == null:
			continue
		var display_name := unit_data.display_name
		counts[display_name] = int(counts.get(display_name, 0)) + 1
	var parts: PackedStringArray = []
	for display_name in counts.keys():
		var count: int = counts[display_name]
		if count > 1:
			parts.append("%s×%d" % [display_name, count])
		else:
			parts.append(display_name)
	return "，".join(parts)


func _get_shop_status_text(base: String) -> String:
	var max_tier := TierUnlock.get_max_unlocked_tier(_get_shop_wave())
	return "%s（第 %d 次 · 最高 Tier %d）" % [base, _shop_visit_count, max_tier]


func _on_combat_tick_processed() -> void:
	# Deaths free population / “在场” badges — refresh cycle hand UI each tick.
	_refresh_hand_ui()
	if not _combat_arena.is_running():
		_get_active_board_presentation().sync_units()


func _on_combat_ended(won: bool) -> void:
	if _camera_shake_3d != null:
		_camera_shake_3d.reset()
	_disconnect_economy_combat_events()
	# Tear down per-combat bus before shop/prepare so listeners cannot leak across phases.
	if _combat_arena != null:
		_combat_arena.stop_combat()
	_set_hand_deploy_drag_enabled(false)
	clear_wave_hand()
	match_flow.enter_resolve()
	_board_scene.sync_units()
	await _resolve_combat_after_hold(won)


func _resolve_combat_after_hold(won: bool) -> void:
	if _board_animating or _shop_ui_animating or _shop_phase_screen.transition_active:
		return
	_board_animating = true
	_set_board_transition_locked(true)

	if _camera_rig.is_combat_active():
		_board_scene.set_combat_view_active(false)
		var dur := _get_combat_transition_duration()
		_board_scene.play_body_hide(dur)
		await _camera_rig.play_exit_combat()
		_board_scene.set_character_phase(UnitCardDisplay.CharacterPhase.PREPARE)
		_bind_combat_presentation()

	if not won:
		var wave_number := _encounter_tier_index + 1
		_set_status("战斗失败…")
		await get_tree().create_timer(COMBAT_RESULT_HOLD_SEC).timeout
		await _combat_victory_overlay.play_defeat(wave_number)
		await _board_scene.play_board_hide()
		_board_world.visible = false
		_board_animating = false
		_set_board_transition_locked(false)
		if run_mode_enabled:
			set_run_visible(false)
			encounter_completed.emit(false)
			return
		_pending_defeat_reset = true
		await _enter_shop_phase(true, true)
		_set_status(_get_shop_status_text("战斗失败 — 重置牌库并重新购买"))
		_board_animating = false
		_set_board_transition_locked(false)
		return

	var completed_wave := match_state.get_current_wave()
	var wave_gold := run_economy.grant_wave_gold(completed_wave)
	var wave_number := _encounter_tier_index + 1
	var encounter := match_state.current_encounter
	var is_boss := encounter != null and encounter.is_boss
	var level_complete := false
	if linear_dev_mode and level_data != null and not level_data.waves.is_empty():
		level_complete = _linear_wave_index >= level_data.waves.size() - 1
	elif is_boss:
		level_complete = true

	_set_status("战斗胜利！+%d 金" % wave_gold)
	await get_tree().create_timer(COMBAT_VICTORY_PRE_OVERLAY_HOLD_SEC).timeout
	await _combat_victory_overlay.play_victory(wave_gold, wave_number, level_complete)

	board_grid.clear_team(UnitInstance.Team.ENEMY)
	_restore_combat_layout()
	_clear_all_stat_modifiers()
	_board_scene.sync_units()

	await _board_scene.play_board_hide()
	_board_world.visible = false
	_board_animating = false
	_set_board_transition_locked(false)

	if run_mode_enabled:
		set_run_visible(false)
		encounter_completed.emit(true)
		return

	if linear_dev_mode and level_data != null and not level_data.waves.is_empty():
		_linear_wave_index += 1
		if _linear_wave_index < level_data.waves.size():
			await _enter_shop_phase(true, true)
			_set_status(_get_shop_status_text("波次胜利！+%d 金 — 商店阶段：购买单位" % wave_gold))
		else:
			_pending_run_reset_on_shop = true
			await _enter_shop_phase(true, true)
			_set_status(_get_shop_status_text("关卡完成！+%d 金 — 进入商店继续" % wave_gold))
		return

	await _enter_shop_phase(true, true)
	_set_status(_get_shop_status_text("波次胜利！+%d 金 — 商店阶段" % wave_gold))


func _reset_player_hp() -> void:
	for unit in board_grid.get_units_by_team(UnitInstance.Team.PLAYER, true):
		if unit.stats != null:
			unit.current_hp = unit.stats.max_hp


func _update_ui() -> void:
	var in_shop := match_state.phase == MatchStateMachine.Phase.SHOP
	var in_prepare := match_state.phase == MatchStateMachine.Phase.PREPARE
	var in_resolve := match_state.phase == MatchStateMachine.Phase.RESOLVE
	var in_combat := match_state.phase == MatchStateMachine.Phase.COMBAT

	_sync_shop_visibility(in_shop)
	if not _board_animating and not _board_scene.board_transition_active:
		_board_world.visible = not in_shop
	if in_shop:
		_hovered_board_unit = null

	_start_button.visible = in_prepare
	_start_button.disabled = _board_animating
	_finish_shop_button.disabled = (_board_animating or _shop_ui_animating) and in_shop
	_next_wave_button.visible = false
	_finish_shop_button.visible = in_shop

	_hand_panel.visible = in_shop or in_prepare or in_combat
	_hand_panel.set_mode(
		HandPanel.Mode.SELL if in_shop else HandPanel.Mode.DEPLOY
	)
	_hand_panel.set_start_button_host_visible(in_prepare)
	if in_resolve:
		_start_button.visible = false
		_finish_shop_button.visible = false
		_hand_panel.visible = false
	_shop_panel.set_interactive(
		in_shop
		and not _board_animating
		and not _shop_ui_animating
		and not _shop_phase_screen.transition_active
	)
	_hand_panel.set_interactive(
		(in_shop or in_prepare or in_combat)
		and not _board_animating
		and not _shop_ui_animating
		and not _shop_phase_screen.transition_active
	)

	if in_prepare:
		_hand_panel.set_title("手牌 · 拖到己方半场")
	elif in_combat:
		_hand_panel.set_title("补人")

	if in_prepare and match_state.has_active_encounter():
		var label := _current_encounter_label
		if label.is_empty():
			label = "战斗"
		_start_button.text = "开始%s" % label

	_refresh_shop_ui()
	_refresh_hand_ui()
	_sync_board_cell_highlights()


func _sync_shop_visibility(in_shop: bool) -> void:
	if _shop_ui_animating or _shop_phase_screen.transition_active:
		return
	if in_shop:
		if not _shop_phase_screen.visible:
			_shop_phase_screen.show_instant()
			_hand_panel.show_shop_instant()
	else:
		_shop_phase_screen.visible = false


func _sync_board_cell_highlights() -> void:
	if not is_node_ready() or _board_scene == null:
		return
	var active := (
		_is_deploy_phase()
		and _selected_entry_id >= 0
		and _is_in_wave_hand(_selected_entry_id)
		and not _is_entry_deployed(_selected_entry_id)
		and _can_deploy_more()
	)
	_board_scene.set_placement_mode(active, board_grid)
	_sync_attack_range_preview()


func _sync_attack_range_preview() -> void:
	if not is_node_ready() or _board_scene == null:
		return
	var source := _resolve_range_preview_source()
	if source.is_empty():
		_board_scene.clear_range_preview_cells()
		return
	var cells := _AttackRangePreview.get_cells(
		board_grid,
		source.origin,
		source.unit,
	)
	_board_scene.set_range_preview_cells(cells)


func _resolve_range_preview_source() -> Dictionary:
	var phase := match_state.phase
	if phase != MatchStateMachine.Phase.PREPARE and phase != MatchStateMachine.Phase.COMBAT:
		return {}

	if _hovered_board_unit != null:
		var board_cell := board_grid.find_cell_of(_hovered_board_unit)
		if board_cell != Vector2i(-1, -1):
			return { "origin": board_cell, "unit": _hovered_board_unit }

	if _hovered_hand_entry != null:
		var hand_cell := _find_deployed_cell_for_entry(_hovered_hand_entry.entry_id)
		if hand_cell != Vector2i(-1, -1):
			var hand_unit := UnitInstance.from_deck_entry(
				_hovered_hand_entry,
				hand_cell,
				UnitInstance.Team.PLAYER,
			)
			if hand_unit != null:
				return { "origin": hand_cell, "unit": hand_unit }

	if _is_deploy_phase() and _selected_entry_id >= 0:
		if _find_deployed_cell_for_entry(_selected_entry_id) == Vector2i(-1, -1):
			var hover_cell := _board_scene.get_hovered_grid_cell()
			if _is_placeable_preview_cell(hover_cell):
				var entry := deck_state.get_entry(_selected_entry_id)
				if entry != null and entry.unit != null:
					var preview_unit := UnitInstance.from_deck_entry(
						entry,
						hover_cell,
						UnitInstance.Team.PLAYER,
					)
					if preview_unit != null:
						return { "origin": hover_cell, "unit": preview_unit }

	return {}


func _find_deployed_cell_for_entry(entry_id: int) -> Vector2i:
	for unit in board_grid.get_units_by_team(UnitInstance.Team.PLAYER, true):
		if unit.deck_entry_id == entry_id:
			return board_grid.find_cell_of(unit)
	return Vector2i(-1, -1)


func _is_placeable_preview_cell(cell: Vector2i) -> bool:
	if not board_grid.in_bounds(cell) or board_grid.is_blocked(cell):
		return false
	if board_grid.get_unit(cell) != null:
		return false
	return BoardHalf.is_player_deploy_cell(cell, board_grid.get_size().y)


func _refresh_shop_ui() -> void:
	if not is_node_ready():
		return
	shop_deck_binder.refresh_shop()


func _refresh_hand_ui() -> void:
	if not is_node_ready():
		return
	var in_shop := match_state.phase == MatchStateMachine.Phase.SHOP
	var use_wave_hand := not in_shop and _is_deploy_phase()
	shop_deck_binder.refresh_hand(
		_get_deployed_entry_ids(),
		_selected_entry_id,
		_get_wave_hand_entries() if use_wave_hand else ([] as Array[DeckEntry]),
		use_wave_hand,
	)
	if use_wave_hand:
		_hand_panel.set_population(
			_count_player_units_on_board(),
			deck_state.get_max_board_units(),
		)
	_sync_board_cell_highlights()


func _on_gold_changed(amount: int) -> void:
	board_ui_binder.set_gold(amount)
	_refresh_shop_ui()


func _on_unit_hover_changed(unit: UnitInstance) -> void:
	_hovered_board_unit = unit
	if not _board_world.visible:
		return
	if match_state.phase == MatchStateMachine.Phase.SHOP:
		return
	if unit == null:
		if _hovered_hand_entry == null and _hovered_shop_offer == null:
			_unit_tooltip.hide_tooltip()
		_sync_attack_range_preview()
		return
	_hovered_hand_entry = null
	_hovered_shop_offer = null
	_unit_tooltip.show_unit(unit, get_viewport().get_mouse_position())
	_sync_attack_range_preview()


func _on_grid_cell_hover_changed(cell: Vector2i) -> void:
	_sync_attack_range_preview()
	if not _board_world.visible:
		return
	if match_state.phase == MatchStateMachine.Phase.SHOP:
		return
	if _hovered_hand_entry != null or _hovered_shop_offer != null:
		return
	if _board_scene == null:
		return
	var unit := _board_scene.get_unit_at_cell(cell)
	if unit != null:
		if _hovered_board_unit != unit:
			_hovered_board_unit = unit
			_unit_tooltip.show_unit(unit, get_viewport().get_mouse_position())
	elif _hovered_board_unit != null:
		_hovered_board_unit = null
		_unit_tooltip.hide_tooltip()


func _on_hand_entry_hovered(entry: DeckEntry) -> void:
	_hovered_hand_entry = entry
	_hovered_board_unit = null
	_hovered_shop_offer = null
	_unit_tooltip.show_deck_entry(
		entry,
		get_viewport().get_mouse_position(),
		deck_state.get_level_config(),
	)
	_sync_attack_range_preview()


func _on_hand_entry_unhovered() -> void:
	_hovered_hand_entry = null
	if _hovered_board_unit == null and _hovered_shop_offer == null:
		_unit_tooltip.hide_tooltip()
	_sync_attack_range_preview()


func _on_shop_offer_hovered(offer: ShopOffer) -> void:
	_hovered_shop_offer = offer
	_hovered_board_unit = null
	_hovered_hand_entry = null
	_unit_tooltip.show_shop_offer(offer, get_viewport().get_mouse_position())


func _on_shop_offer_unhovered() -> void:
	_hovered_shop_offer = null
	if _hovered_board_unit == null and _hovered_hand_entry == null:
		_unit_tooltip.hide_tooltip()


func _process(_delta: float) -> void:
	if _unit_tooltip.visible:
		_unit_tooltip.follow_mouse(get_viewport().get_mouse_position())


func _set_status(text: String) -> void:
	board_ui_binder.set_status(text)


func _clear_all_stat_modifiers() -> void:
	for unit in board_grid.get_all_units():
		var inst: UnitInstance = unit as UnitInstance
		inst.stat_modifiers.clear()
	if board_grid.cell_effects != null:
		board_grid.cell_effects.clear()


func _capture_combat_layout() -> void:
	_combat_layout_snapshot.clear()
	for unit in board_grid.get_all_units():
		var inst: UnitInstance = unit as UnitInstance
		if inst.team != UnitInstance.Team.PLAYER:
			continue
		if inst.deck_entry_id < 0:
			continue
		board_grid.sync_unit_grid_pos(inst)
		var cell := board_grid.find_cell_of(inst)
		if cell == Vector2i(-1, -1):
			continue
		_combat_layout_snapshot.append({
			"entry_id": inst.deck_entry_id,
			"cell": cell,
		})


func _find_player_unit_by_entry(entry_id: int) -> UnitInstance:
	for unit in board_grid.get_units_by_team(UnitInstance.Team.PLAYER, false):
		if unit.deck_entry_id == entry_id:
			return unit
	return null


func _restore_player_unit_to_cell(
	unit: UnitInstance,
	entry: DeckEntry,
	cell: Vector2i,
) -> void:
	UnitInstance.sync_from_deck_entry(unit, entry)
	unit.current_hp = unit.get_effective_max_hp()
	var current := board_grid.find_cell_of(unit)
	if current == cell:
		unit.grid_pos = cell
		return
	if current != Vector2i(-1, -1):
		board_grid.move_unit_for(unit, cell)
	else:
		board_grid.place(unit, cell)


func _restore_combat_layout() -> void:
	_clear_combat_token_units()
	var restored_entries: Dictionary = {}
	for snapshot in _combat_layout_snapshot:
		var entry_id: int = snapshot.get("entry_id", -1)
		var cell: Vector2i = snapshot.get("cell", Vector2i.ZERO)
		var entry := deck_state.get_entry(entry_id)
		if entry == null:
			continue
		var unit := _find_player_unit_by_entry(entry_id)
		if unit == null:
			unit = UnitInstance.from_deck_entry(
				entry,
				cell,
				UnitInstance.Team.PLAYER,
			)
			if unit == null:
				continue
			if not board_grid.place(unit, cell):
				push_warning(
					"Failed to restore player unit entry %d at %s"
					% [entry_id, str(cell)]
				)
				continue
		else:
			_restore_player_unit_to_cell(unit, entry, cell)
		restored_entries[entry_id] = true

	var to_remove: Array[UnitInstance] = []
	for unit in board_grid.get_units_by_team(UnitInstance.Team.PLAYER, false):
		if unit.deck_entry_id >= 0 and not restored_entries.has(unit.deck_entry_id):
			to_remove.append(unit)
	for unit in to_remove:
		board_grid.remove_unit(unit)
	_combat_layout_snapshot.clear()


func _clear_combat_token_units() -> void:
	var to_remove: Array[UnitInstance] = []
	for unit in board_grid.get_units_by_team(UnitInstance.Team.PLAYER, false):
		if unit.deck_entry_id < 0:
			to_remove.append(unit)
	for unit in to_remove:
		board_grid.remove_unit(unit)


func _get_combat_transition_duration() -> float:
	if _camera_rig != null and _camera_rig.camera_config != null:
		return _camera_rig.camera_config.transition_duration
	return CombatAnimationConfig.DUR_BODY_REVEAL


func _log_empty_cells() -> void:
	var empty := board_grid.get_empty_cells()
	var size := board_grid.get_size()
	var deployed := _count_player_units_on_board()
	print(
		"[Board] %dx%d | empty: %d / %d | deck: %d | deployed: %d / %d"
		% [
			size.x,
			size.y,
			empty.size(),
			size.x * size.y,
			deck_state.size(),
			deployed,
			deck_state.get_max_board_units(),
		]
	)
