class_name BoardCameraRig
extends Node

@export var camera_config: BoardCombatCameraConfig = preload(
	"res://resources/ui/default_board_combat_camera.tres"
)

var _camera: Camera3D
var _camera_shake: CameraShake3D
var _board_scene: BoardScene3D
var _transition_tween: Tween
var _combat_active: bool = false
var _active_camera_cfg: BoardCombatCameraConfig
var _layout_aspect: float = 16.0 / 9.0


func bind(camera: Camera3D, board_scene: BoardScene3D, camera_shake: CameraShake3D = null) -> void:
	_camera = camera
	_board_scene = board_scene
	_camera_shake = camera_shake


func get_camera() -> Camera3D:
	return _camera


func get_camera_shake_3d() -> CameraShake3D:
	return _camera_shake


func get_board_scene() -> BoardScene3D:
	return _board_scene


func is_combat_active() -> bool:
	return _combat_active


func layout_for_viewport(side_inset: float = 0.0) -> void:
	var vp := get_viewport().get_visible_rect().size
	var play_w := maxf(100.0, vp.x - side_inset)
	var play_h := maxf(
		100.0,
		vp.y - BoardLayout.PLAY_MARGIN_TOP - BoardLayout.PLAY_MARGIN_BOTTOM,
	)
	_layout_aspect = play_w / play_h
	apply_prepare_pose()


func apply_prepare_pose() -> void:
	var cfg := _resolve_camera_config()
	_active_camera_cfg = cfg
	_apply_camera_pose(cfg.prepare_elevation_deg, cfg.prepare_yaw_deg, cfg)
	if _camera != null:
		_camera.make_current()
	if _camera_shake != null:
		_camera_shake.reset()


func play_enter_combat() -> void:
	## No prepare↔combat camera switch: stay in top-down pose.
	_kill_transition_tween()
	if _board_scene != null:
		_board_scene.sync_units()
	apply_prepare_pose()
	_combat_active = true


func play_exit_combat() -> void:
	## No prepare↔combat camera switch: stay in top-down pose.
	_kill_transition_tween()
	if _board_scene != null:
		_board_scene.sync_units()
		_board_scene.refresh()
	_combat_active = false
	if _camera_shake != null:
		_camera_shake.reset()
	apply_prepare_pose()


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
	var size_from_width := half_w / maxf(_layout_aspect, 0.01)
	return maxf(half_h, size_from_width) * cfg.ortho_padding * cfg.ortho_size_multiplier


func _resolve_camera_config() -> BoardCombatCameraConfig:
	if camera_config != null:
		return camera_config
	return BoardCombatCameraConfig.new()


func _kill_transition_tween() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
