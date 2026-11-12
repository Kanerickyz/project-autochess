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

@export var max_hp: int = 30
@export var attack: int = 3
@export var attack_range: int = 1
@export var movement_pattern: MovementPattern = MovementPattern.ORTHOGONAL
## 一回合（一动）最多可走的八向格数；0 = 本动不挪步。旧网格工具环 / 兼容字段；主路径移速见 move_speed。
@export_range(0, 8, 1) var steps_per_turn: int = 1

## 主路径战斗（连续坐标，单位仍为逻辑格）。长度单位为逻辑格（tile），时间单位为秒。
@export_group("Combat")
## 连续平面移速（格/秒）。≤0 时按 steps_per_turn 推导：max(0.5, steps)；steps=0 → 不移动。
@export_range(0.0, 10.0, 0.05) var move_speed: float = 0.0
## 两次攻击之间的间隔（秒）；并行下按此连打。默认 1.5。
@export_range(0.1, 10.0, 0.05) var attack_interval: float = 1.5
## 首次攻击前摇（秒），进入射程后到第一次出手
## 进距后首刀前摇；主路径默认 0（无蓄力）。测试可设大值卡住出手。
@export_range(0.0, 5.0, 0.05) var attack_windup: float = 0.0
## 攻击距离（格；主路径按碰撞圆边缘欧氏距）
@export_range(0.0, 12.0, 0.05) var attack_reach: float = 0.8
## 普攻暴击率（0–1）；默认 5%（约每 20 次保底 1 次，未中则实际概率递增）。
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.05
## 暴击伤害倍率（相对本次攻击基数）；默认 1.5 倍。
@export_range(1.0, 5.0, 0.05) var crit_multiplier: float = 1.5
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


## 主路径解析移速：显式 move_speed 优先；否则由 steps_per_turn 推导。
func get_move_speed() -> float:
	if move_speed > 0.0:
		return move_speed
	if steps_per_turn <= 0:
		return 0.0
	return maxf(0.5, float(steps_per_turn))


func duplicate_stats() -> UnitStats:
	var copy := UnitStats.new()
	copy.max_hp = max_hp
	copy.attack = attack
	copy.attack_range = attack_range
	copy.movement_pattern = movement_pattern
	copy.steps_per_turn = steps_per_turn
	copy.move_speed = move_speed
	copy.attack_interval = attack_interval
	copy.attack_windup = attack_windup
	copy.attack_reach = attack_reach
	copy.crit_chance = crit_chance
	copy.crit_multiplier = crit_multiplier
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
