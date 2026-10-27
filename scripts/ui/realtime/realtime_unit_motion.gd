class_name RealtimeUnitMotion
extends Node
## Run 战场单位程序动画（纯表现）：只产出绘制用偏移 / 旋转 / 缩放 / 闪白与镜头震动，
## 不改 RtUnit 与战斗结算。通过轮询 RtUnit 的状态与时间戳识别蓄力、出手、受击，
## 死亡由控制器生成残影：侧倒淡出结束后移除，不再绘制。

## 一格步进：小丑牌式抬起跳 + 朝向倾斜 + 影加深（脚底为轴）。
const WALK_TILT := 0.16
const WALK_HOP_TILES := 0.1
const WALK_LEAN := 0.12
const WALK_SQUASH := Vector2(1.08, 0.92)
const WALK_SHADOW_MUL := 1.55
## 非行动者 / 准备席待机：轻呼吸起伏（战斗用 idle_tween；准备/招募用 sample_idle）。
const IDLE_BOB_TILES := 0.045
const IDLE_SQUASH := Vector2(1.04, 0.96)
const IDLE_CYCLE := 1.15
const IDLE_PHASE_STEP := 0.07
## 长按焦点：小丑牌式抬起 / 倾斜 / 放大。
const INSPECT_LIFT_TILES := 0.18
const INSPECT_SCALE := 1.14
const INSPECT_KICK_TILES := 0.22
const INSPECT_KICK_TILT := 0.28
const INSPECT_SETTLE_SEC := 0.2
const INSPECT_KICK_DECAY := 9.0
const INSPECT_DIM_ALPHA := 0.58
const INSPECT_DIM_SCALE := 0.94
## 拖角色：与检视同语汇的小丑牌式抬起 / 速度倾斜 / 影加深。
const DRAG_LIFT_TILES := 0.24
const DRAG_SCALE := 1.22
const DRAG_PICKUP_SEC := 0.18
const DRAG_TILT_MAX := 0.42
const DRAG_TILT_PER_SPEED := 0.085
const DRAG_SWAY_TILES := 0.1
const DRAG_SHADOW_MUL := 1.95
const DRAG_HOLD_ALPHA := 1.0
## 近战蓄力 / 出手 / 受击 / 死亡：与拖影同语汇（BACK 过冲、倾斜、影）。
const WINDUP_PULL_TILES := 0.18
const WINDUP_LIFT_TILES := 0.05
const WINDUP_TILT := 0.22
const WINDUP_SQUASH := Vector2(1.14, 0.86)
const WINDUP_SHADOW_MUL := 1.45
const LUNGE_SECONDS := 0.09
const LUNGE_ATTACKER_TILES := 0.42
const LUNGE_TARGET_TILES := 0.18
const LUNGE_TILT := 0.28
const LUNGE_SCALE := Vector2(0.86, 1.16)
const LUNGE_SHADOW_MUL := 1.75
const RECOVER_SECONDS := 0.22
const RANGED_RECOIL_TILES := 0.14
const RANGED_TILT := 0.18
const HIT_KNOCK_TILES := 0.14
const HIT_TILT := 0.32
const HIT_SQUASH := Vector2(1.16, 0.86)
const HIT_SHADOW_MUL := 1.65
const HIT_FLASH_SECONDS := 0.16
## 震屏（像素）：幅度随实际扣血；下限保证可读，上限防糊屏。
const SHAKE_BASE_PX := 1.2
const SHAKE_PER_DAMAGE_PX := 1.1
const SHAKE_MIN_PX := 1.5
const SHAKE_MAX_PX := 14.0
const SHAKE_SECONDS := 0.22
const DEATH_SECONDS := 0.55
const DEATH_KICK_TILT := 0.55
const DEATH_TILT := 1.45
const DEATH_SHADOW_MUL := 2.1


class Pose:
	extends RefCounted
	## 偏移以「格」为单位，绘制时乘格宽，缩放随棋盘变化。
	var offset := Vector2.ZERO
	var rotation := 0.0
	var scale := Vector2.ONE
	var flash := 0.0
	var alpha := 1.0
	## 接触阴影倍率（拖影 / 检视抬起时加深外扩）。
	var shadow_mul := 1.0
	var tween: Tween
	## 闪白独立淡出，不会被后续蓄力 / 冲撞 tween 打断而卡白。
	var flash_tween: Tween
	## 待机呼吸：与出手 tween 分离，避免被蓄力/冲撞打断后卡在非零偏移。
	var idle_offset := Vector2.ZERO
	var idle_scale := Vector2.ONE
	var idle_tween: Tween
	var idle_requested := false
	## 冲刺途中受击（反伤等同帧结算）只闪白震屏，不打断冲撞位移。
	var lunging := false


class Tracked:
	extends RefCounted
	var pose := Pose.new()
	var winding := false
	var last_attack := RtUnit.NEVER
	var last_hit := RtUnit.NEVER
	## 近战蓄力时给目标迎击的 partner（instance_id）；取消蓄力时一并 soft_home。
	var windup_partner_id: int = 0


class Corpse:
	extends RefCounted
	var unit_id := ""
	var is_player := true
	var position := Vector2.ZERO
	var half_height := 0.5
	var pose := Pose.new()
	var done := false


## 观战倍速：动画随之缩短。
var speed_scale := 1.0
var shake_strength := 0.0

var _tracked: Dictionary = {}
var _corpses: Array[Corpse] = []
var _shake_tween: Tween


func clear() -> void:
	for tracked: Tracked in _tracked.values():
		_kill_all(tracked.pose)
	_tracked.clear()
	for corpse in _corpses:
		_kill_all(corpse.pose)
	_corpses.clear()
	if _shake_tween != null:
		_shake_tween.kill()
	shake_strength = 0.0


## 测试 / 切场景：打断全部 tween 并归零姿态，避免卡在蓄力偏移。
func force_home_all() -> void:
	for tracked: Tracked in _tracked.values():
		_kill_all(tracked.pose)
		_reset_pose_visual(tracked.pose)
	for corpse in _corpses:
		_kill_all(corpse.pose)
	_corpses.clear()


func _reset_pose_visual(pose: Pose) -> void:
	if pose == null:
		return
	pose.offset = Vector2.ZERO
	pose.rotation = 0.0
	pose.scale = Vector2.ONE
	pose.alpha = 1.0
	pose.flash = 0.0
	pose.shadow_mul = 1.0
	pose.idle_offset = Vector2.ZERO
	pose.idle_scale = Vector2.ONE
	pose.lunging = false


func get_pose(rt: RtUnit) -> Pose:
	var tracked: Tracked = _tracked.get(rt.get_instance_id())
	return tracked.pose if tracked != null else null


## 存活单位是否仍有出击 / 回位 action tween（不含 idle / flash / 残影）。
func has_active_action_tween() -> bool:
	for tracked: Tracked in _tracked.values():
		if tracked != null and _is_busy(tracked.pose):
			return true
	return false


func get_corpses() -> Array[Corpse]:
	return _corpses


func get_shake_offset() -> Vector2:
	if shake_strength <= 0.01:
		return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength


## 时钟采样待机（准备席 / 招募 / 图鉴）：与战斗 Tween 呼吸同参数，无节点开销。
## 返回 { "offset": Vector2（格）, "scale": Vector2 }。
static func sample_idle(time_sec: float, seed: int) -> Dictionary:
	var phase := float(absi(seed) % 17) * IDLE_PHASE_STEP
	var wave := (1.0 - cos((time_sec + phase) * TAU / IDLE_CYCLE)) * 0.5
	return {
		"offset": Vector2(0.0, -IDLE_BOB_TILES * wave),
		"scale": Vector2.ONE.lerp(IDLE_SQUASH, wave),
	}


## 长按焦点：小丑牌式抬起 / 倾斜 / 放大（格单位偏移 + 弧度旋转）。
## elapsed：本焦点开始后的秒；kick_dir：滑动切换水平方向（-1/0/+1）；
## finger_delta_tiles：手指相对焦点中心的格偏移（已钳制更好）。
## 返回 { offset, rotation, scale, alpha, shadow_mul }。
static func sample_inspect_focus(
	elapsed: float,
	kick_dir: float,
	finger_delta_tiles: Vector2,
	focused: bool,
) -> Dictionary:
	if not focused:
		return {
			"offset": Vector2(0.0, 0.02),
			"rotation": 0.0,
			"scale": Vector2.ONE * INSPECT_DIM_SCALE,
			"alpha": INSPECT_DIM_ALPHA,
			"shadow_mul": 0.7,
		}
	var t := clampf(elapsed / INSPECT_SETTLE_SEC, 0.0, 1.0)
	## 近似 TRANS_BACK 落位：先略过冲再回。
	var overshoot := 1.0 + 1.7 * pow(1.0 - t, 3.0) * sin(t * PI)
	var lift := clampf(t * overshoot, 0.0, 1.35)
	var kick := exp(-maxf(0.0, elapsed) * INSPECT_KICK_DECAY)
	var dir := signf(kick_dir)
	var finger := Vector2(
		clampf(finger_delta_tiles.x, -0.55, 0.55),
		clampf(finger_delta_tiles.y, -0.4, 0.4),
	)
	return {
		"offset": Vector2(
			dir * INSPECT_KICK_TILES * kick + finger.x * 0.14,
			-INSPECT_LIFT_TILES * lift + finger.y * 0.08 - kick * 0.06,
		),
		"rotation": dir * INSPECT_KICK_TILT * kick + finger.x * 0.1,
		"scale": Vector2.ONE * (1.0 + (INSPECT_SCALE - 1.0) * lift + 0.08 * kick),
		"alpha": 1.0,
		"shadow_mul": 1.0 + 0.9 * lift + 0.4 * kick,
	}


## 拖角色跟手：小丑牌式抬起过冲 + 水平速度倾斜 + 阴影加深。
## elapsed：拖起后秒；velocity_tiles：平滑后的指针速度（格/秒）。
## 返回 { offset, rotation, scale, alpha, shadow_mul }。
static func sample_drag_hold(elapsed: float, velocity_tiles: Vector2) -> Dictionary:
	var t := clampf(elapsed / DRAG_PICKUP_SEC, 0.0, 1.0)
	## 与检视相同的 BACK 过冲曲线，拎起瞬间略弹。
	var overshoot := 1.0 + 1.7 * pow(1.0 - t, 3.0) * sin(t * PI)
	var lift := clampf(t * overshoot, 0.0, 1.35)
	var speed_x := velocity_tiles.x
	var tilt := clampf(speed_x * DRAG_TILT_PER_SPEED, -DRAG_TILT_MAX, DRAG_TILT_MAX)
	## 停下后倾斜慢慢回正（仍保留一点抬起）。
	var settle := 1.0 - exp(-maxf(0.0, elapsed - DRAG_PICKUP_SEC) * 4.5)
	if elapsed < DRAG_PICKUP_SEC:
		settle = 0.0
	tilt *= 1.0 - 0.35 * settle
	var sway := clampf(speed_x * 0.012, -DRAG_SWAY_TILES, DRAG_SWAY_TILES)
	return {
		"offset": Vector2(sway + tilt * 0.12, -DRAG_LIFT_TILES * lift),
		"rotation": tilt,
		"scale": Vector2.ONE * (1.0 + (DRAG_SCALE - 1.0) * lift),
		"alpha": DRAG_HOLD_ALPHA,
		"shadow_mul": 1.0 + (DRAG_SHADOW_MUL - 1.0) * lift,
	}


## 每帧由战场视图调用：同步场上单位，识别蓄力 / 出手 / 受击，并更新行走摆动。
## current_actor：当前行动者不播待机；其余存活单位在未出手/未步进时进入呼吸待机。
func sync_units(units: Array, current_actor: RtUnit = null) -> void:
	var seen: Dictionary = {}
	for item in units:
		var rt := item as RtUnit
		if rt == null:
			continue
		var key := rt.get_instance_id()
		seen[key] = true
		if not _tracked.has(key):
			var fresh := Tracked.new()
			fresh.last_attack = rt.last_attack_time
			fresh.last_hit = rt.last_hit_time
			_tracked[key] = fresh
	for key in _tracked.keys():
		if not seen.has(key):
			_kill_all((_tracked[key] as Tracked).pose)
			_tracked.erase(key)
	for item in units:
		var rt := item as RtUnit
		if rt == null:
			continue
		var tracked: Tracked = _tracked[rt.get_instance_id()]
		## 出手后 state 仍停在 ATTACKING（计时器 ≤ 0），只把计时中的前摇视为蓄力。
		var was_winding := tracked.winding
		var winding := (
			rt.state == RtUnit.State.ATTACKING
			and rt.target != null
			and rt.attack_timer > 0.0
			and (current_actor == null or current_actor == rt)
		)
		if was_winding and not winding and current_actor != rt:
			_soft_home(tracked.pose)
			_soft_home_partner(tracked)
			tracked.winding = false
			was_winding = false
		if winding and not was_winding:
			_play_windup(rt, tracked)
		var did_strike := rt.last_attack_time != tracked.last_attack
		if did_strike:
			tracked.last_attack = rt.last_attack_time
			tracked.winding = false
			tracked.windup_partner_id = 0
			_play_strike(rt, tracked)
		elif was_winding and not winding:
			## 蓄力取消（无出手）：自身与迎击 partner 弹回，避免卡姿。
			_soft_home(tracked.pose)
			_soft_home_partner(tracked)
			tracked.winding = false
		else:
			tracked.winding = winding
	for item in units:
		var rt := item as RtUnit
		if rt == null:
			continue
		var tracked: Tracked = _tracked[rt.get_instance_id()]
		if rt.last_hit_time != tracked.last_hit:
			tracked.last_hit = rt.last_hit_time
			_play_hit(tracked.pose, Vector2.ZERO, shake_px_for_damage(rt.last_hit_amount))
	_sync_idle_states(units, current_actor)
	_prune_corpses()


## 伤害 → 震屏像素；amount≤0 时仍给可读下限。
static func shake_px_for_damage(amount: int) -> float:
	var raw := SHAKE_BASE_PX + float(maxi(0, amount)) * SHAKE_PER_DAMAGE_PX
	return clampf(raw, SHAKE_MIN_PX, SHAKE_MAX_PX)


## 行走：小丑牌式抬起跳 + 摆动倾斜 + 朝向微倾 + 影加深；与步进插值同步。
## 返回 { offset, rotation, scale, shadow_mul }（格单位 / 弧度）。
func walk_pose(rt: RtUnit) -> Dictionary:
	if rt == null or not rt.is_stepping():
		return {
			"offset": Vector2.ZERO,
			"rotation": 0.0,
			"scale": Vector2.ONE,
			"shadow_mul": 1.0,
		}
	var t := rt.step_t
	var hop := absf(sin(t * PI))
	## 与拖影相同的过冲峰值：中段略弹高。
	var overshoot := 1.0 + 0.45 * hop * (1.0 - hop)
	var lift := hop * overshoot
	var move := rt.step_to - rt.step_from
	var dir := move.normalized() if move.length_squared() > 0.0001 else Vector2.ZERO
	## 左右摆在 1/4、3/4 步峰值；朝向 lean 在腾空中段峰值，避免只采到中点时 tilt=0。
	var sway := sin(t * TAU) * WALK_TILT
	var lean := dir.x * WALK_LEAN * hop
	var yaw := sway + lean
	if absf(yaw) < 0.04:
		yaw = signf(dir.x if not is_zero_approx(dir.x) else 1.0) * WALK_TILT * hop
	return {
		"offset": Vector2(dir.x * 0.03 * hop, -WALK_HOP_TILES * lift),
		"rotation": yaw,
		"scale": Vector2.ONE.lerp(WALK_SQUASH, hop),
		"shadow_mul": 1.0 + (WALK_SHADOW_MUL - 1.0) * lift,
	}


func play_death(rt: RtUnit, unit_id: String, half_height: float) -> void:
	if rt == null:
		return
	var corpse := Corpse.new()
	corpse.unit_id = unit_id
	corpse.is_player = rt.is_player()
	corpse.position = rt.position
	corpse.half_height = half_height
	var tracked: Tracked = _tracked.get(rt.get_instance_id())
	if tracked != null:
		corpse.pose.offset = tracked.pose.offset
		corpse.pose.scale = tracked.pose.scale
		corpse.pose.rotation = tracked.pose.rotation
		corpse.pose.shadow_mul = tracked.pose.shadow_mul
	_corpses.append(corpse)
	var fall_dir := -1.0 if rt.is_player() else 1.0
	var pose := corpse.pose
	pose.flash = 1.0
	var tween := _new_tween(pose)
	## 先小丑牌式踢起倾斜，再侧倒缩小淡出。
	var kick_rot := pose.rotation + DEATH_KICK_TILT * fall_dir
	var kick_off := pose.offset + Vector2(0.1 * fall_dir, -0.2)
	tween.tween_property(pose, "rotation", kick_rot, DEATH_SECONDS * 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "offset", kick_off, DEATH_SECONDS * 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "shadow_mul", DEATH_SHADOW_MUL, DEATH_SECONDS * 0.18)
	tween.parallel().tween_property(pose, "scale", Vector2(1.08, 1.12), DEATH_SECONDS * 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(pose, "rotation", DEATH_TILT * fall_dir, DEATH_SECONDS * 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		pose, "offset", kick_off + Vector2(0.22 * fall_dir, 0.08), DEATH_SECONDS * 0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(pose, "flash", 0.0, DEATH_SECONDS * 0.35)
	tween.tween_property(pose, "scale", Vector2(0.72, 0.5), DEATH_SECONDS * 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(pose, "alpha", 0.0, DEATH_SECONDS * 0.4)
	tween.parallel().tween_property(pose, "shadow_mul", 0.4, DEATH_SECONDS * 0.4)
	tween.tween_callback(func() -> void:
		corpse.done = true
		corpse.pose.alpha = 0.0
	)


func _play_windup(rt: RtUnit, tracked: Tracked) -> void:
	var dir := _dir_to(rt, rt.target)
	var windup := maxf(0.08, rt.get_stats().attack_windup if rt.get_stats() != null else 0.3)
	var pose := tracked.pose
	var tilt := _tilt_for_dir(-dir) * WINDUP_TILT
	var pulled := -dir * WINDUP_PULL_TILES + Vector2(0.0, -WINDUP_LIFT_TILES)
	var tween := _new_tween(pose)
	tween.tween_property(pose, "offset", pulled, windup * 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "scale", WINDUP_SQUASH, windup * 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "rotation", tilt, windup * 0.8) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "shadow_mul", WINDUP_SHADOW_MUL, windup * 0.8)
	tracked.windup_partner_id = 0
	## 近战目标同步蓄力迎击，形成「双方对冲」。
	if _is_melee(rt) and rt.target != null and rt.target.is_alive():
		var partner_id := rt.target.get_instance_id()
		var target_tracked: Tracked = _tracked.get(partner_id)
		if target_tracked != null and not target_tracked.winding and not _is_busy(target_tracked.pose):
			tracked.windup_partner_id = partner_id
			var tpose := target_tracked.pose
			var ttween := _new_tween(tpose)
			var t_pull := dir * WINDUP_PULL_TILES * 0.65 + Vector2(0.0, -WINDUP_LIFT_TILES * 0.6)
			ttween.tween_property(tpose, "offset", t_pull, windup * 0.8) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ttween.parallel().tween_property(tpose, "scale", Vector2(1.08, 0.9), windup * 0.8) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ttween.parallel().tween_property(tpose, "rotation", _tilt_for_dir(dir) * WINDUP_TILT * 0.7, windup * 0.8)
			ttween.parallel().tween_property(tpose, "shadow_mul", 1.3, windup * 0.8)


func _play_strike(rt: RtUnit, tracked: Tracked) -> void:
	var target := rt.target
	var dir := _dir_to(rt, target)
	var pose := tracked.pose
	if not _is_melee(rt):
		var recoil := _new_tween(pose)
		var recoiled := -dir * RANGED_RECOIL_TILES + Vector2(0.0, -0.04)
		recoil.tween_property(pose, "offset", recoiled, LUNGE_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		recoil.parallel().tween_property(pose, "scale", Vector2(0.9, 1.12), LUNGE_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		recoil.parallel().tween_property(pose, "rotation", _tilt_for_dir(-dir) * RANGED_TILT, LUNGE_SECONDS)
		recoil.parallel().tween_property(pose, "shadow_mul", 1.4, LUNGE_SECONDS)
		_tween_home(recoil, pose)
		return
	var lunge := _new_tween(pose)
	pose.lunging = true
	var lunged := dir * LUNGE_ATTACKER_TILES + Vector2(0.0, -0.06)
	lunge.tween_property(pose, "offset", lunged, LUNGE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	lunge.parallel().tween_property(pose, "scale", LUNGE_SCALE, LUNGE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	lunge.parallel().tween_property(pose, "rotation", _tilt_for_dir(dir) * LUNGE_TILT, LUNGE_SECONDS)
	lunge.parallel().tween_property(pose, "shadow_mul", LUNGE_SHADOW_MUL, LUNGE_SECONDS)
	lunge.tween_callback(func() -> void: pose.lunging = false)
	_tween_home(lunge, pose)
	if target == null:
		return
	## 扣血已在出手瞬间结算；用 last_hit_amount 驱动震幅。
	var hit_shake := shake_px_for_damage(target.last_hit_amount)
	var target_tracked: Tracked = _tracked.get(target.get_instance_id())
	if target_tracked == null:
		## 目标已在本步被击杀：残影自己播放闪白，这里只补震屏。
		create_tween().tween_callback(_shake.bind(hit_shake)).set_delay(LUNGE_SECONDS / maxf(0.25, speed_scale))
		return
	## 撞上瞬间才播受击；同步时间戳，避免轮询再播一次。
	target_tracked.last_hit = target.last_hit_time
	var tpose := target_tracked.pose
	var charge := _new_tween(tpose)
	charge.tween_property(tpose, "offset", -dir * LUNGE_TARGET_TILES, LUNGE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	charge.parallel().tween_property(tpose, "rotation", _tilt_for_dir(-dir) * LUNGE_TILT * 0.7, LUNGE_SECONDS)
	## 撞上后走 _play_hit → 始终 _tween_home（攻击者 mid-lunge 早退除外）。
	charge.tween_callback(_play_hit.bind(tpose, dir, hit_shake))


## 打断当前 action tween（若有），再 BACK 弹回原位。
func _soft_home(pose: Pose) -> void:
	if pose == null:
		return
	var tween := _new_tween(pose)
	_tween_home(tween, pose)


func _soft_home_partner(tracked: Tracked) -> void:
	if tracked == null or tracked.windup_partner_id == 0:
		return
	var partner: Tracked = _tracked.get(tracked.windup_partner_id)
	tracked.windup_partner_id = 0
	if partner != null:
		_soft_home(partner.pose)


## 受击：闪白 + 小丑牌式踢退倾斜压扁 + 影加深 + BACK 弹回 + 镜头震动。
func _play_hit(pose: Pose, knock_dir: Vector2, shake_px: float) -> void:
	_flash(pose)
	if pose.lunging and _is_busy(pose):
		_shake(shake_px)
		return
	var knock := knock_dir
	if knock.length_squared() < 0.0001:
		knock = Vector2(0.0, 1.0)
	else:
		knock = knock.normalized()
	var kicked := pose.offset + knock * HIT_KNOCK_TILES + Vector2(0.0, -0.05)
	var tilt := _tilt_for_dir(knock) * HIT_TILT
	var tween := _new_tween(pose)
	tween.tween_property(pose, "offset", kicked, 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "scale", HIT_SQUASH, 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "rotation", pose.rotation + tilt, 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "shadow_mul", HIT_SHADOW_MUL, 0.06)
	_tween_home(tween, pose)
	_shake(shake_px)


func _flash(pose: Pose) -> void:
	if pose.flash_tween != null:
		pose.flash_tween.kill()
	pose.flash = 1.0
	pose.flash_tween = create_tween()
	pose.flash_tween.set_speed_scale(maxf(0.25, speed_scale))
	pose.flash_tween.tween_interval(0.05)
	pose.flash_tween.tween_property(pose, "flash", 0.0, HIT_FLASH_SECONDS)


func _tween_home(tween: Tween, pose: Pose) -> void:
	## 落座同款：BACK 弹性回正（位移 / 缩放 / 倾斜 / 影）。
	tween.tween_property(pose, "offset", Vector2.ZERO, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "scale", Vector2.ONE, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "rotation", 0.0, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "shadow_mul", 1.0, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _shake(strength_px: float) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	shake_strength = maxf(shake_strength, strength_px)
	_shake_tween = create_tween()
	_shake_tween.set_speed_scale(maxf(0.25, speed_scale))
	_shake_tween.tween_property(self, "shake_strength", 0.0, SHAKE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _sync_idle_states(units: Array, current_actor: RtUnit) -> void:
	for item in units:
		var rt := item as RtUnit
		if rt == null:
			continue
		var tracked: Tracked = _tracked.get(rt.get_instance_id())
		if tracked == null:
			continue
		if _should_idle(rt, tracked, current_actor):
			_ensure_idle(rt, tracked.pose)
		else:
			_stop_idle(tracked.pose)


func _should_idle(rt: RtUnit, tracked: Tracked, current_actor: RtUnit) -> bool:
	if rt == null or not rt.is_alive():
		return false
	if rt.is_deploying():
		return false
	if current_actor != null and rt == current_actor:
		return false
	if rt.is_stepping():
		return false
	if tracked.winding:
		return false
	if _is_busy(tracked.pose):
		return false
	return true


func _ensure_idle(rt: RtUnit, pose: Pose) -> void:
	if pose == null:
		return
	if pose.idle_requested and pose.idle_tween != null and pose.idle_tween.is_valid() and pose.idle_tween.is_running():
		pose.idle_tween.set_speed_scale(maxf(0.25, speed_scale))
		return
	_start_idle(rt, pose)


func _start_idle(rt: RtUnit, pose: Pose) -> void:
	_kill_idle_tween(pose)
	pose.idle_requested = true
	pose.idle_offset = Vector2.ZERO
	pose.idle_scale = Vector2.ONE
	var phase := 0.0
	if rt != null:
		phase = float(abs(rt.get_instance_id()) % 17) * IDLE_PHASE_STEP
	if phase > 0.0:
		pose.idle_tween = create_tween()
		pose.idle_tween.set_speed_scale(maxf(0.25, speed_scale))
		pose.idle_tween.tween_interval(phase)
		pose.idle_tween.tween_callback(_begin_idle_loop.bind(pose))
	else:
		_begin_idle_loop(pose)


func _begin_idle_loop(pose: Pose) -> void:
	if pose == null or not pose.idle_requested:
		return
	_kill_idle_tween(pose)
	var peak_offset := Vector2(0.0, -IDLE_BOB_TILES)
	var peak_scale := IDLE_SQUASH
	var half := IDLE_CYCLE * 0.5
	pose.idle_tween = create_tween().set_loops()
	pose.idle_tween.set_speed_scale(maxf(0.25, speed_scale))
	pose.idle_tween.tween_property(pose, "idle_offset", peak_offset, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pose.idle_tween.parallel().tween_property(pose, "idle_scale", peak_scale, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pose.idle_tween.tween_property(pose, "idle_offset", Vector2.ZERO, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pose.idle_tween.parallel().tween_property(pose, "idle_scale", Vector2.ONE, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle(pose: Pose) -> void:
	if pose == null:
		return
	pose.idle_requested = false
	_kill_idle_tween(pose)
	pose.idle_offset = Vector2.ZERO
	pose.idle_scale = Vector2.ONE


func _kill_idle_tween(pose: Pose) -> void:
	if pose == null:
		return
	if pose.idle_tween != null and pose.idle_tween.is_valid():
		pose.idle_tween.kill()
	pose.idle_tween = null


func _new_tween(pose: Pose) -> Tween:
	_stop_idle(pose)
	_kill(pose)
	pose.tween = create_tween()
	pose.tween.set_speed_scale(maxf(0.25, speed_scale))
	return pose.tween


func _kill(pose: Pose) -> void:
	if pose != null and pose.tween != null:
		pose.tween.kill()
		pose.tween = null
	if pose != null:
		pose.lunging = false


func _is_busy(pose: Pose) -> bool:
	return pose.tween != null and pose.tween.is_valid() and pose.tween.is_running()


func _kill_all(pose: Pose) -> void:
	_kill(pose)
	_stop_idle(pose)
	if pose != null and pose.flash_tween != null:
		pose.flash_tween.kill()
		pose.flash_tween = null


func _prune_corpses() -> void:
	if _corpses.is_empty():
		return
	var keep: Array[Corpse] = []
	for corpse in _corpses:
		if corpse.done or corpse.pose.alpha <= 0.02:
			_kill_all(corpse.pose)
			continue
		keep.append(corpse)
	_corpses = keep


func _dir_to(rt: RtUnit, target: RtUnit) -> Vector2:
	if rt == null or target == null:
		return Vector2.UP if rt != null and rt.is_player() else Vector2.DOWN
	var dir := rt.position.direction_to(target.position)
	if dir == Vector2.ZERO:
		return Vector2.UP if rt.is_player() else Vector2.DOWN
	return dir


## 水平分量主导的小丑牌式倾斜符号（右倾为正）。
func _tilt_for_dir(dir: Vector2) -> float:
	if absf(dir.x) >= absf(dir.y) * 0.35:
		return signf(dir.x) if not is_zero_approx(dir.x) else 1.0
	return signf(dir.x) * 0.55 if not is_zero_approx(dir.x) else (1.0 if dir.y >= 0.0 else -1.0)


func _is_melee(rt: RtUnit) -> bool:
	var stats := rt.get_stats()
	return stats == null or stats.projectile_speed <= 0.0
