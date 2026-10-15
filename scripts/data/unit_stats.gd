class_name UnitStats
extends Resource

enum MovementPattern {
	ORTHOGONAL,
	LINE,
	ROOK,
	KNIGHT,
	DIAGONAL,
	BISHOP,
	QUEEN,
	TELEPORT,
}

@export var max_hp: int = 10
@export var attack: int = 3
@export var attack_range: int = 1
@export var movement_pattern: MovementPattern = MovementPattern.ORTHOGONAL
## 一回合（一动）最多可走的八向格数；0 = 本动不挪步。主路径与旧网格工具环共用。
@export_range(0, 8, 1) var steps_per_turn: int = 1
@export_range(0, 100, 1) var crit_rate_percent: int = 5

## 主路径战斗（格坐标）。长度单位为逻辑格（tile），时间单位为秒。
@export_group("Combat")
## 两次攻击之间的间隔（秒）；回合制一动内最多出手一次，本字段主要给旧并行/工具路径用。
@export_range(0.1, 10.0, 0.05) var attack_interval: float = 1.2
## 首次攻击前摇（秒），进入射程后到第一次出手
@export_range(0.0, 5.0, 0.05) var attack_windup: float = 0.3
## 攻击距离（格，切比雪夫）
@export_range(0.0, 12.0, 0.05) var attack_reach: float = 0.8
## 索敌半径（格）；范围内无敌人时向全场最近敌人前进
@export_range(0.0, 32.0, 0.1) var sight_range: float = 5.5
## 碰撞圆半径（格）
@export_range(0.1, 2.0, 0.05) var body_radius: float = 0.7
## 视觉剪影半宽（格）；0 = 按碰撞半径 ×1.3 推算
@export_range(0.0, 4.0, 0.05) var visual_half_width: float = 0.0
## 视觉剪影半高（格）；0 = 按碰撞半径 ×1.6 推算（脚小身大）
@export_range(0.0, 4.0, 0.05) var visual_half_height: float = 0.0
## 推挤质量；越大越难被推开
@export_range(0.1, 20.0, 0.1) var mass: float = 1.0
## 投射物速度（格/秒）；0 = 近战即时命中
@export_range(0.0, 40.0, 0.5) var projectile_speed: float = 0.0
## 溅射半径（格，以目标为圆心）；0 = 单体
@export_range(0.0, 4.0, 0.05) var splash_radius: float = 0.0
## 落地后多久才开始行动（秒）。玩家篇已取消部署时间；主路径投放会强制为 0。
@export_range(0.0, 5.0, 0.05) var deploy_time: float = 0.0


func duplicate_stats() -> UnitStats:
	var copy := UnitStats.new()
	copy.max_hp = max_hp
	copy.attack = attack
	copy.attack_range = attack_range
	copy.movement_pattern = movement_pattern
	copy.steps_per_turn = steps_per_turn
	copy.crit_rate_percent = crit_rate_percent
	copy.attack_interval = attack_interval
	copy.attack_windup = attack_windup
	copy.attack_reach = attack_reach
	copy.sight_range = sight_range
	copy.body_radius = body_radius
	copy.visual_half_width = visual_half_width
	copy.visual_half_height = visual_half_height
	copy.mass = mass
	copy.projectile_speed = projectile_speed
	copy.splash_radius = splash_radius
	copy.deploy_time = deploy_time
	return copy


func get_visual_half_width() -> float:
	if visual_half_width > 0.0:
		return visual_half_width
	return maxf(0.05, body_radius * 1.3)


func get_visual_half_height() -> float:
	if visual_half_height > 0.0:
		return visual_half_height
	return maxf(0.05, body_radius * 1.6)
