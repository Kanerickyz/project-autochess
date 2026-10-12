class_name SandboxController
extends Node2D

enum Phase { EDIT, COMBAT }

const BOARD_DEFAULTS := preload("res://resources/levels/board_act1.tres")
const SANDBOX_SIDE_INSET := 352.0
const _BoardCameraRigScript := preload("res://scripts/ui/board_camera_rig.gd")

@onready var _board_world: Node3D = $BoardWorld
@onready var _board_scene: BoardScene3D = $BoardWorld/BoardScene3D
@onready var _camera_rig: _BoardCameraRigScript = $BoardCameraRig
@onready var _combat_camera: Camera3D = $CombatCamera3D
@onready var _combat_presentation: CombatPresentation = $CombatPresentation
@onready var _board_vfx_layer: Node2D = %BoardVfxLayer
@onready var _camera_shake_3d: CameraShake3D = $CombatCamera3D/CameraShake3D
@onready var _combat_arena: CombatArena = $CombatArena
@onready var _palette: SandboxUnitPalette = %SandboxUnitPalette
@onready var _status_label: Label = %StatusLabel
@onready var _unit_tooltip: UnitTooltip = %UnitTooltip
@onready var _combat_skill_callout: CombatSkillCallout = %CombatSkillCallout

var board_grid: BoardGrid = BoardGrid.new()
var phase: Phase = Phase.EDIT
var _hovered_board_unit: UnitInstance
var _palette_hover_active: bool = false


func _ready() -> void:
	_camera_rig.bind(_combat_camera, _board_scene, _camera_shake_3d)
	_setup_board()
	_bind_combat_presentation()
	_combat_presentation.set_skill_callout(_combat_skill_callout)
	_board_scene.cell_clicked.connect(_on_cell_clicked)
	_board_scene.cell_right_clicked.connect(_on_cell_right_clicked)
	_board_scene.unit_hover_changed.connect(_on_unit_hover_changed)
	_combat_arena.combat_ended.connect(_on_combat_ended)
	_combat_arena.combat_tick_processed.connect(_on_combat_tick_processed)

	_palette.clear_pressed.connect(_on_clear_pressed)
	_palette.start_combat_pressed.connect(_on_start_combat_pressed)
	_palette.back_pressed.connect(_on_back_pressed)
	_palette.unit_selected.connect(_on_unit_selected)
	_palette.team_changed.connect(_on_team_changed)
	_palette.unit_hovered.connect(_on_palette_unit_hovered)
	_palette.unit_unhovered.connect(_on_palette_unit_unhovered)

	_board_world.visible = true
	_palette.set_edit_mode(true)
	_refresh_combat_ready()
	_set_status("选择单位后左键空格放置；右键点击已有单位可移除")
	call_deferred("_deferred_board_layout")


func _process(_delta: float) -> void:
	if _unit_tooltip == null or not _unit_tooltip.visible:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	_unit_tooltip.set_avoid_rects([_palette.get_global_rect()])
	_unit_tooltip.follow_mouse(mouse_pos)


func _show_board_unit_tooltip(unit: UnitInstance) -> void:
	_unit_tooltip.clear_placement_hints()
	_unit_tooltip.set_avoid_rects([_palette.get_global_rect()])
	_unit_tooltip.show_unit(unit, get_viewport().get_mouse_position())


func _show_palette_unit_tooltip(unit: UnitInstance) -> void:
	var palette_rect := _palette.get_global_rect()
	_unit_tooltip.set_avoid_rects([palette_rect])
	_unit_tooltip.set_anchor_left_rect(palette_rect)
	_unit_tooltip.show_unit(unit, get_viewport().get_mouse_position())


func _setup_board() -> void:
	var size := Vector2i(8, 8)
	if BOARD_DEFAULTS != null:
		size = BOARD_DEFAULTS.get_board_size()
	var blocked: Array[Vector2i] = []
	if BOARD_DEFAULTS != null:
		blocked = BOARD_DEFAULTS.blocked_cells
	board_grid.configure(size, blocked)
	_configure_board_presentation()
	_board_scene.sync_units()
	_board_scene.set_character_phase(UnitCardDisplay.CharacterPhase.PREPARE)


func _configure_board_presentation() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var pixel_cell := BoardLayout.compute_cell_size(board_grid, vp_size)
	_board_scene.setup(board_grid, _combat_camera, _board_vfx_layer, pixel_cell)
	_camera_rig.layout_for_viewport(SANDBOX_SIDE_INSET)


func _deferred_board_layout() -> void:
	_configure_board_presentation()
	_board_scene.refresh()
	_camera_rig.apply_prepare_pose()


func _bind_combat_presentation() -> void:
	_combat_presentation.setup(_board_scene)
	_combat_presentation.set_camera_shake_3d(_camera_shake_3d)


func _on_cell_clicked(cell: Vector2i) -> void:
	if phase != Phase.EDIT:
		return
	if not board_grid.in_bounds(cell) or board_grid.is_blocked(cell):
		_set_status("该格不可放置")
		return

	if board_grid.get_unit(cell) != null:
		_set_status("该格已有单位，右键移除")
		return

	var unit_data := _palette.get_selected_unit()
	if unit_data == null:
		_set_status("请先在右侧选择一个单位")
		return

	var team := _palette.get_selected_team()
	var unit := UnitInstance.from_unit_data(unit_data, cell, team)
	if unit == null:
		return
	unit.level = _palette.get_selected_level()
	unit.current_hp = unit.get_effective_max_hp()

	if not board_grid.place(unit, cell):
		_set_status("放置失败")
		return

	_board_scene.refresh()
	_refresh_combat_ready()
	var team_label := "友方" if team == UnitInstance.Team.PLAYER else "敌方"
	_set_status("已放置 %s（%s Lv%d）" % [unit_data.display_name, team_label, unit.level])


func _on_cell_right_clicked(cell: Vector2i) -> void:
	if phase != Phase.EDIT:
		return
	if not board_grid.in_bounds(cell) or board_grid.is_blocked(cell):
		return

	var existing := board_grid.get_unit(cell)
	if existing == null:
		return

	board_grid.remove(cell)
	_board_scene.refresh()
	_refresh_combat_ready()
	_set_status("已移除单位")


func _on_clear_pressed() -> void:
	if phase != Phase.EDIT:
		return
	board_grid.clear_units()
	board_grid.cell_effects.clear()
	_board_scene.refresh()
	_refresh_combat_ready()
	_set_status("棋盘已清空")


func _on_start_combat_pressed() -> void:
	if phase != Phase.EDIT:
		return
	if not _can_start_combat():
		_set_status("请至少放置 1 个友方和 1 个敌方单位")
		return

	_unit_tooltip.hide_tooltip()
	phase = Phase.COMBAT
	_palette.set_edit_mode(false)
	_set_status("战斗中…")

	var dur := _get_combat_transition_duration()
	_board_scene.play_body_reveal(dur)
	await _camera_rig.play_enter_combat()
	_board_scene.set_combat_view_active(true)
	_bind_combat_presentation()
	_combat_arena.set_presentation(_combat_presentation)
	_combat_arena.start_combat(
		board_grid,
		null,
		0,
		[],
		[],
		[],
		null,
	)
	_board_scene.sync_units()


func _on_combat_ended(_won: bool) -> void:
	_combat_arena.stop_combat()
	if _camera_rig.is_combat_active():
		_board_scene.set_combat_view_active(false)
		var dur := _get_combat_transition_duration()
		_board_scene.play_body_hide(dur)
		await _camera_rig.play_exit_combat()
		_board_scene.set_character_phase(UnitCardDisplay.CharacterPhase.PREPARE)
		_bind_combat_presentation()
	else:
		_camera_rig.apply_prepare_pose()
	board_grid.clear_units()
	board_grid.cell_effects.clear()
	_board_scene.refresh()

	phase = Phase.EDIT
	_palette.set_edit_mode(true)
	_refresh_combat_ready()
	_set_status("战斗结束，棋盘已清空 — 可继续摆盘")


func _on_combat_tick_processed() -> void:
	if not _combat_arena.is_running():
		_board_scene.sync_units()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")


func _on_unit_selected(_unit_data: UnitData) -> void:
	_set_status("已选单位：%s — 左键空格放置" % _unit_data.display_name)


func _on_team_changed(team: UnitInstance.Team) -> void:
	var label := "友方" if team == UnitInstance.Team.PLAYER else "敌方"
	_set_status("当前阵营：%s" % label)


func _on_unit_hover_changed(unit: UnitInstance) -> void:
	_hovered_board_unit = unit
	if unit != null:
		_palette_hover_active = false
		_show_board_unit_tooltip(unit)
		return
	if not _palette_hover_active:
		_unit_tooltip.hide_tooltip()


func _on_palette_unit_hovered(unit_data: UnitData) -> void:
	if phase != Phase.EDIT or unit_data == null:
		return
	_palette_hover_active = true
	var preview := UnitInstance.from_unit_data(
		unit_data,
		Vector2i.ZERO,
		_palette.get_selected_team(),
	)
	if preview == null:
		return
	preview.level = _palette.get_selected_level()
	preview.current_hp = preview.get_effective_max_hp()
	_show_palette_unit_tooltip(preview)


func _on_palette_unit_unhovered() -> void:
	_palette_hover_active = false
	if _hovered_board_unit != null:
		_show_board_unit_tooltip(_hovered_board_unit)
	else:
		_unit_tooltip.hide_tooltip()


func _can_start_combat() -> bool:
	return (
		not board_grid.get_units_by_team(UnitInstance.Team.PLAYER, true).is_empty()
		and not board_grid.get_units_by_team(UnitInstance.Team.ENEMY, true).is_empty()
	)


func _refresh_combat_ready() -> void:
	_palette.set_combat_ready(_can_start_combat())


func _get_combat_transition_duration() -> float:
	if _camera_rig != null and _camera_rig.camera_config != null:
		return _camera_rig.camera_config.transition_duration
	return CombatAnimationConfig.DUR_BODY_REVEAL


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
