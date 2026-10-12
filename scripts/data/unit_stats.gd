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
@export_range(1, 8, 1) var steps_per_turn: int = 1
@export_range(0, 100, 1) var crit_rate_percent: int = 5

## 实时战斗（连续坐标）。长度单位为逻辑格（tile），时间单位为秒。
@export_group("Realtime")
## 移动速度（格/秒）
@export_range(0.0, 10.0, 0.05) var move_speed: float = 1.0
## 两次攻击之间的间隔（秒）
@export_range(0.1, 10.0, 0.05) var attack_interval: float = 1.2
## 首次攻击前摇（秒），进入射程后到第一次出手
@export_range(0.0, 5.0, 0.05) var attack_windup: float = 0.3
## 攻击距离（格，按双方碰撞圆边缘计算）
@export_range(0.0, 12.0, 0.05) var attack_reach: float = 0.8
## 索敌半径（格）；范围内无敌人时向全场最近敌人前进
@export_range(0.0, 32.0, 0.1) var sight_range: float = 5.5
## 碰撞圆半径（格）
@export_range(0.1, 2.0, 0.05) var body_radius: float = 0.4
## 推挤质量；越大越难被推开
@export_range(0.1, 20.0, 0.1) var mass: float = 1.0
## 投射物速度（格/秒）；0 = 近战即时命中
@export_range(0.0, 40.0, 0.5) var projectile_speed: float = 0.0
## 溅射半径（格，以目标为圆心）；0 = 单体
@export_range(0.0, 4.0, 0.05) var splash_radius: float = 0.0
## 落地后多久才开始行动（秒）
@export_range(0.0, 5.0, 0.05) var deploy_time: float = 1.0


func duplicate_stats() -> UnitStats:
	var copy := UnitStats.new()
	copy.max_hp = max_hp
	copy.attack = attack
	copy.attack_range = attack_range
	copy.movement_pattern = movement_pattern
	copy.steps_per_turn = steps_per_turn
	copy.crit_rate_percent = crit_rate_percent
	copy.move_speed = move_speed
	copy.attack_interval = attack_interval
	copy.attack_windup = attack_windup
	copy.attack_reach = attack_reach
	copy.sight_range = sight_range
	copy.body_radius = body_radius
	copy.mass = mass
	copy.projectile_speed = projectile_speed
	copy.splash_radius = splash_radius
	copy.deploy_time = deploy_time
	return copy
