class_name BoardCombatStage
## LEGACY — not on main gameplay path. See scripts/_legacy/README.md.
extends Control

const BOARD_SCENE_SCRIPT := preload("res://scripts/ui/board_3d/board_scene_3d.gd")
const CAMERA_SHAKE_3D_SCRIPT := preload("res://scripts/ui/camera_shake_3d.gd")

@export var camera_config: BoardCombatCameraConfig = preload(
	"res://resources/ui/default_board_combat_camera.tres"
)

var _subviewport: SubViewport
var _viewport_container: SubViewportContainer
var _vfx_layer: Node2D
var _directional_light: DirectionalLight3D
var _camera: Camera3D
var _camera_shake: CameraShake3D
var _board_scene: BoardScene3D
var _transition_tween: Tween
var _combat_active: bool = false
var _active_camera_cfg: BoardCombatCameraConfig


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_build_scene_tree()


func get_board_scene() -> BoardScene3D:
	return _board_scene


func get_camera() -> Camera3D:
	return _camera


func get_camera_shake_3d() -> CameraShake3D:
	return _camera_shake


func is_combat_active() -> bool:
	return _combat_active


func play_enter_combat(grid: BoardGrid, board_view: BoardView) -> void:
	_kill_transition_tween()
	_layout_to_match_board(board_view)
	visible = true
	modulate.a = 0.0
	board_view.board_transition_active = true

	var pixel_cell := board_view.cell_size
	_board_scene.setup(grid, _camera, _subviewport, _vfx_layer, pixel_cell)
	_board_scene.sync_units()

	var cfg := _resolve_camera_config()
	_active_camera_cfg = cfg
	_apply_camera_pose(cfg.prepare_elevation_deg, cfg.prepare_yaw_deg, cfg)
	_camera.make_current()
	if _camera_shake != null:
		_camera_shake.reset()

	var duration := cfg.transition_duration
	if duration <= 0.0:
		duration = CombatAnimationConfig.COMBAT_VIEW_TRANSITION_DUR

	var from_pose := Vector2(cfg.prepare_elevation_deg, cfg.prepare_yaw_deg)
	var to_pose := Vector2(cfg.combat_elevation_deg, cfg.combat_yaw_deg)

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		duration * cfg.fade_ratio,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(
		board_view,
		"modulate:a",
		0.0,
		duration * cfg.fade_ratio,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.tween_method(
		_apply_camera_pose_from_vector,
		from_pose,
		to_pose,
		duration,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _transition_tween.finished
	_transition_tween = null

	board_view.visible = false
	board_view.modulate.a = 1.0
	board_view.board_transition_active = false
	_combat_active = true


func play_exit_combat(board_view: BoardView) -> void:
	if not _combat_active and modulate.a <= 0.01:
		visible = false
		return

	_kill_transition_tween()
	board_view.sync_units()
	board_view.refresh()
	board_view.visible = true
	board_view.modulate.a = 0.0
	board_view.board_transition_active = true

	var cfg := _resolve_camera_config()
	_active_camera_cfg = cfg
	var duration := cfg.transition_duration
	if duration <= 0.0:
		duration = CombatAnimationConfig.COMBAT_VIEW_TRANSITION_DUR

	var from_pose := Vector2(cfg.combat_elevation_deg, cfg.combat_yaw_deg)
	var to_pose := Vector2(cfg.prepare_elevation_deg, cfg.prepare_yaw_deg)

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		duration * cfg.fade_ratio,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(
		board_view,
		"modulate:a",
		1.0,
		duration * cfg.fade_ratio,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_method(
		_apply_camera_pose_from_vector,
		from_pose,
		to_pose,
		duration,
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await _transition_tween.finished
	_transition_tween = null

	visible = false
	modulate.a = 0.0
	board_view.board_transition_active = false
	_combat_active = false
	if _camera_shake != null:
		_camera_shake.reset()


func layout_to_board_view(board_view: BoardView) -> void:
	_layout_to_match_board(board_view)


func _apply_camera_pose_from_vector(pose: Vector2) -> void:
	var cfg := _active_camera_cfg if _active_camera_cfg != null else _resolve_camera_config()
	_apply_camera_pose(pose.x, pose.y, cfg)


func _apply_camera_pose(elevation_deg: float, yaw_deg: float, cfg: BoardCombatCameraConfig) -> void:
	if _camera == null or _board_scene == null:
		return
	var center := _board_scene.get_board_center_3d()
	var distance := _resolve_camera_distance(cfg)
	var offset := _camera_orbit_offset(elevation_deg, yaw_deg, distance)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = center + offset
	_camera.look_at(center, Vector3.UP)
	_camera.size = _compute_ortho_size(elevation_deg, yaw_deg, cfg)


func _camera_orbit_offset(elevation_deg: float, yaw_deg: float, distance: float) -> Vector3:
	var elev := deg_to_rad(elevation_deg)
	var yaw := deg_to_rad(yaw_deg)
	return Vector3(
		distance * cos(elev) * sin(yaw),
		distance * sin(elev),
		distance * cos(elev) * cos(yaw),
	)


func _resolve_camera_distance(cfg: BoardCombatCameraConfig) -> float:
	if cfg.camera_distance > 0.0:
		return cfg.camera_distance
	if _board_scene == null:
		return 40.0
	var bounds := _board_scene.get_board_bounds_3d()
	var extent := maxf(bounds.size.x, bounds.size.z)
	return extent * 1.35


func _compute_ortho_size(elevation_deg: float, yaw_deg: float, cfg: BoardCombatCameraConfig) -> float:
	if _board_scene == null or _camera == null:
		return 10.0
	var center := _board_scene.get_board_center_3d()
	var distance := _resolve_camera_distance(cfg)
	var offset := _camera_orbit_offset(elevation_deg, yaw_deg, distance)
	_camera.position = center + offset
	_camera.look_at(center, Vector3.UP)

	var bounds := _board_scene.get_board_bounds_3d()
	var corners: Array[Vector3] = [
		bounds.position,
		bounds.position + Vector3(bounds.size.x, 0.0, 0.0),
		bounds.position + Vector3(0.0, bounds.size.y, 0.0),
		bounds.position + Vector3(bounds.size.x, bounds.size.y, 0.0),
		bounds.position + Vector3(0.0, 0.0, bounds.size.z),
		bounds.position + Vector3(bounds.size.x, 0.0, bounds.size.z),
		bounds.position + Vector3(0.0, bounds.size.y, bounds.size.z),
		bounds.position + bounds.size,
	]

	var cam_xform := _camera.global_transform.affine_inverse()
	var min_v := Vector2(INF, INF)
	var max_v := Vector2(-INF, -INF)
	for corner in corners:
		var local := cam_xform * corner
		min_v.x = minf(min_v.x, local.x)
		min_v.y = minf(min_v.y, local.y)
		max_v.x = maxf(max_v.x, local.x)
		max_v.y = maxf(max_v.y, local.y)

	var half_h := (max_v.y - min_v.y) * 0.5
	var half_w := (max_v.x - min_v.x) * 0.5
	var aspect := 1.0
	if _subviewport != null and _subviewport.size.y > 0:
		aspect = float(_subviewport.size.x) / float(_subviewport.size.y)
	var size_from_width := half_w / maxf(aspect, 0.01)
	return maxf(half_h, size_from_width) * cfg.ortho_padding * cfg.ortho_size_multiplier


func _build_scene_tree() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "ViewportContainer"
	_viewport_container.stretch = true
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_viewport_container)

	_subviewport = SubViewport.new()
	_subviewport.name = "SubViewport"
	_subviewport.transparent_bg = true
	_subviewport.handle_input_locally = false
	_subviewport.size = Vector2i(BoardLayout.VIEWPORT_WIDTH, BoardLayout.VIEWPORT_HEIGHT)
	_viewport_container.add_child(_subviewport)

	var world := Node3D.new()
	world.name = "BoardCombatWorld"
	_subviewport.add_child(world)

	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.09, 0.11, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.85
	env.environment = environment
	world.add_child(env)

	_directional_light = DirectionalLight3D.new()
	_directional_light.name = "DirectionalLight"
	_directional_light.rotation_degrees = Vector3(-55.0, 45.0, 0.0)
	_directional_light.light_energy = 1.2
	_directional_light.shadow_enabled = true
	world.add_child(_directional_light)

	_camera = Camera3D.new()
	_camera.name = "CombatCamera3D"
	world.add_child(_camera)

	_camera_shake = CAMERA_SHAKE_3D_SCRIPT.new()
	_camera_shake.name = "CameraShake3D"
	_camera.add_child(_camera_shake)
	_camera_shake.bind_camera(_camera)

	_board_scene = BOARD_SCENE_SCRIPT.new()
	_board_scene.name = "BoardScene3D"
	world.add_child(_board_scene)

	_vfx_layer = Node2D.new()
	_vfx_layer.name = "VfxOverlay"
	add_child(_vfx_layer)


func _layout_to_match_board(board_view: BoardView) -> void:
	if board_view == null:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	var pixel_size := board_view.get_board_pixel_size()
	position = board_view.position
	size = pixel_size
	var pad := pixel_size * 0.12
	position -= pad
	size += pad * 2.0
	if _subviewport != null:
		_subviewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if _vfx_layer != null:
		_vfx_layer.position = position


func _resolve_camera_config() -> BoardCombatCameraConfig:
	if camera_config != null:
		return camera_config
	return BoardCombatCameraConfig.new()


func _kill_transition_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
