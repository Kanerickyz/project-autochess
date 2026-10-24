class_name CombatAnimationConfig
extends RefCounted

## 基准动画时长；运行时由 CombatPaceConfig 按 combat_tick 缩放。

const DUR_MOVE := 0.22
const DUR_SLIDE_CHARGE_PER_CELL := 0.16
const DUR_ATTACK_OUT := 0.12
const DUR_ATTACK_BACK := 0.16
const DUR_HIT_FLASH := 0.10
const DUR_DEATH_FLASH := 0.06
const DUR_DEATH := 0.22
const DUR_DEATH_CELL_PULSE := 0.16
const DUR_DEATH_SPARK := 0.14
const DEATH_FLASH_TINT := Color(2.2, 2.2, 2.2, 1.0)
const DEATH_PLAYER_CELL_TINT := Color(1.15, 1.2, 1.35, 1.0)
const DEATH_ENEMY_CELL_TINT := Color(1.35, 0.55, 0.48, 1.0)
const DEATH_PLAYER_SPARK_TINT := Color(0.85, 0.92, 1.0, 0.8)
const DEATH_ENEMY_SPARK_TINT := Color(1.0, 0.55, 0.45, 0.85)
const DEATH_SHAKE := 1.8
const DEATH_SQUASH := Vector2(1.15, 0.72)
const DUR_SPAWN := 0.22
const BOARD_CELL_RISE_DUR := 0.20
const BOARD_CELL_REVEAL_DELAY := 0.12
const BOARD_CELL_REVEAL_JITTER := 0.06
const BOARD_CELL_RISE_OFFSET := 1.0
const BOARD_CELL_REVEAL_SCALE := 0.90
const BOARD_CELL_ALPHA_FADE_RATIO := 0.72
const BOARD_FRAME_FADE_DUR := 0.12
const COMBAT_VIEW_TRANSITION_DUR := 0.65
const DUR_TURN_ORDER_SCROLL := 0.25
const COMBAT_VIEW_FADE_RATIO := 0.55
const DUR_BODY_REVEAL := 0.65
const IDLE_HEAD_BOB_PX := 4
const IDLE_HEAD_BOB_X_PX := 1.5
## 头部 idle 绕圈一周的时间（秒）
const IDLE_HEAD_BOB_CYCLE := 1
## 一圈里用于下落（经过最底点）的时间占比；越小上升越慢
const IDLE_HEAD_BOB_FALL_TIME_FRAC := 0.32
## 下落加速强度（>1 越大越快、越“砸”向底点）
const IDLE_HEAD_BOB_FALL_ACCEL := 2.6
## 上升减速强度（>1 越大越慢、越“飘”回上方）
const IDLE_HEAD_BOB_RISE_DECEL := 1
const IDLE_HEAD_BOB_PHASE_STEP := 0.06
const SHOP_UI_RISE_DUR := 0.24
const SHOP_UI_REVEAL_DELAY := 0.08
const SHOP_UI_REVEAL_JITTER := 0.05
const SHOP_UI_REVEAL_SCALE := 0.92
const SHOP_UI_ALPHA_FADE_RATIO := 0.75
const SHOP_HAND_RISE_DUR := 0.22
const SHOP_HAND_RISE_OFFSET := 72.0
const SHOP_HAND_ALPHA_FADE_RATIO := 0.78
const COMBAT_RESULT_OVERLAY_FADE_IN := 0.5
const COMBAT_RESULT_OVERLAY_HOLD_SEC := 4.5
const COMBAT_RESULT_OVERLAY_FADE_OUT := 0.45
const DUR_DAMAGE_POPUP := 0.65
const DUR_DAMAGE_POP_IN := 0.12
const DUR_DAMAGE_POP_SETTLE := 0.06
const DUR_DAMAGE_POP_FLOAT := 0.45
const CLASH_TRAVEL_RATIO := 0.42
const CLASH_TRAVEL_RATIO_ATTACK := 0.52
const CLASH_TRAVEL_RATIO_DEFEND := 0.18
const CLASH_ATTACK_IMPACT_SCALE := 1.28
const DUR_MELEE_CLASH_SPARK := 0.12
const MELEE_CLASH_SPARK_TINT := Color(1.0, 0.92, 0.75, 0.85)
const MELEE_CLASH_SPARK_SCALE_END := 1.6
const MELEE_CLASH_CELL_PULSE_TINT := Color(1.15, 0.95, 0.7, 1.0)
const DUR_MELEE_CLASH_CELL_PULSE := 0.14
const FUSE_EXPLODE_CELL_TINT := Color(1.35, 0.22, 0.18, 1.0)
const DUR_FUSE_EXPLODE_CELL_PULSE := 0.2
const DUR_FUSE_EXPLODE_PREVIEW := 0.16
const MELEE_CLASH_SHAKE := 2.5
const MOVE_HOP_HEIGHT := 0.12
const SLIDE_WINDUP_RATIO := 0.10
const SLIDE_OVERSHOOT_RATIO := 0.08
const SLIDE_WINDUP_FRAC := 0.12
const SLIDE_CHARGE_FRAC := 0.68
const SLIDE_STRETCH := 1.14
const SLIDE_SQUASH := 0.86

const DUR_TELEPORT_DEPART_FRAC := 0.30
const TELEPORT_DEPART_SQUASH := Vector2(1.35, 0.55)
const TELEPORT_ARRIVE_SCALE_START := 0.35
const TELEPORT_TINT := Color(0.55, 0.35, 0.85, 1.0)
const TELEPORT_GHOST_ALPHA := 0.45
const TELEPORT_GHOST_SCALE_END := 1.25
const TELEPORT_CELL_PULSE_FRAC := 0.55

const SHAKE_BASE := 2.0
const SHAKE_PER_DAMAGE := 1.4
const SHAKE_MAX_AMPLITUDE := 16.0
const SHAKE_DECAY := 10.0
const SHAKE_SKILL_MULT := 1.25
## 全局震屏幅度缩放（1.0 = 原强度）
const SHAKE_AMPLITUDE_SCALE := 0.1

const KNOCKBACK_PX := 8.0
const MIN_IMPACT_DURATION := 0.07

const DAMAGE_POP_OVERSHOOT_LIGHT := 1.25
const DAMAGE_POP_OVERSHOOT_MEDIUM := 1.40
const DAMAGE_POP_OVERSHOOT_HEAVY := 1.55
const DAMAGE_POP_FONT_MULT_LIGHT := 1.0
const DAMAGE_POP_FONT_MULT_MEDIUM := 1.08
const DAMAGE_POP_FONT_MULT_HEAVY := 1.18
const DAMAGE_POP_DRIFT_PX := 6.0


static func damage_pop_tier(amount: int) -> int:
	if amount >= 5:
		return 2
	if amount >= 3:
		return 1
	return 0


static func damage_pop_overshoot(amount: int) -> float:
	match damage_pop_tier(amount):
		2:
			return DAMAGE_POP_OVERSHOOT_HEAVY
		1:
			return DAMAGE_POP_OVERSHOOT_MEDIUM
		_:
			return DAMAGE_POP_OVERSHOOT_LIGHT


static func damage_pop_font_mult(amount: int) -> float:
	match damage_pop_tier(amount):
		2:
			return DAMAGE_POP_FONT_MULT_HEAVY
		1:
			return DAMAGE_POP_FONT_MULT_MEDIUM
		_:
			return DAMAGE_POP_FONT_MULT_LIGHT


static func shake_intensity(amount: int, skill_style: bool) -> float:
	var intensity := SHAKE_BASE + float(amount) * SHAKE_PER_DAMAGE
	if skill_style:
		intensity *= SHAKE_SKILL_MULT
	return intensity


static func death_cell_tint(team: UnitInstance.Team) -> Color:
	if team == UnitInstance.Team.PLAYER:
		return DEATH_PLAYER_CELL_TINT
	return DEATH_ENEMY_CELL_TINT


static func death_spark_tint(team: UnitInstance.Team) -> Color:
	if team == UnitInstance.Team.PLAYER:
		return DEATH_PLAYER_SPARK_TINT
	return DEATH_ENEMY_SPARK_TINT
