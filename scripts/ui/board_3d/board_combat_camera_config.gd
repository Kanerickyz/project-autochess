class_name BoardCombatCameraConfig
extends Resource

## 经典等距正交仰角：atan(1/sqrt(2)) ≈ 35.264°
const ISOMETRIC_ELEVATION_DEG := 35.264

@export_group("Prepare")
## Top-down battlefield view (no combat camera switch).
@export_range(60.0, 89.9, 0.1) var prepare_elevation_deg: float = 78.0
@export_range(-180.0, 180.0, 0.1) var prepare_yaw_deg: float = 0.0

@export_group("Combat")
## Unused for camera pose (kept for resource compat); view stays prepare/top-down.
@export_range(30.0, 75.0, 0.1) var combat_elevation_deg: float = ISOMETRIC_ELEVATION_DEG
@export_range(-180.0, 180.0, 0.1) var combat_yaw_deg: float = 45.0

@export_group("Orbit")
## 0 = 按棋盘尺寸自动计算
@export var camera_distance: float = 0.0
@export var ortho_size_multiplier: float = 1.15
@export var ortho_padding: float = 1.08

@export_group("Transition")
@export var transition_duration: float = 0.65
@export_range(0.1, 1.0, 0.01) var fade_ratio: float = 0.55
