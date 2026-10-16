class_name RealtimeUnitMotion
extends Node
## Run 战场单位程序动画（纯表现）：只产出绘制用偏移 / 旋转 / 缩放 / 闪白与镜头震动，
## 不改 RtUnit 与战斗结算。通过轮询 RtUnit 的状态与时间戳识别蓄力、出手、受击，
## 死亡由控制器转发 unit_died 后生成残影单独播放。

## 一格步进内左右各摆一次；脚底为旋转轴。
const WALK_TILT := 0.13
const WALK_HOP_TILES := 0.07
## 近战蓄力：后撤 + 压扁；出手：冲向目标，撞上瞬间结算受击表现。
const WINDUP_PULL_TILES := 0.16
const WINDUP_SQUASH := Vector2(1.1, 0.88)
const LUNGE_SECONDS := 0.08
const LUNGE_ATTACKER_TILES := 0.38
const LUNGE_TARGET_TILES := 0.16
const RECOVER_SECONDS := 0.2
const RANGED_RECOIL_TILES := 0.12
const HIT_KNOCK_TILES := 0.1
const HIT_FLASH_SECONDS := 0.16
const SHAKE_MELEE_PX := 5.0
const SHAKE_RANGED_PX := 2.5
const SHAKE_SECONDS := 0.22
const DEATH_SECONDS := 0.5
const DEATH_TILT := 1.35


class Pose:
	extends RefCounted
	## 偏移以「格」为单位，绘制时乘格宽，缩放随棋盘变化。
	var offset := Vector2.ZERO
	var rotation := 0.0
	var scale := Vector2.ONE
	var flash := 0.0
	var alpha := 1.0
	var tween: Tween
	## 闪白独立淡出，不会被后续蓄力 / 冲撞 tween 打断而卡白。
	var flash_tween: Tween
	## 冲刺途中受击（反伤等同帧结算）只闪白震屏，不打断冲撞位移。
	var lunging := false


class Tracked:
	extends RefCounted
	var pose := Pose.new()
	var winding := false
	var last_attack := RtUnit.NEVER
	var last_hit := RtUnit.NEVER


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


func get_pose(rt: RtUnit) -> Pose:
	var tracked: Tracked = _tracked.get(rt.get_instance_id())
	return tracked.pose if tracked != null else null


func get_corpses() -> Array[Corpse]:
	return _corpses


func get_shake_offset() -> Vector2:
	if shake_strength <= 0.01:
		return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength


## 每帧由战场视图调用：同步场上单位，识别蓄力 / 出手 / 受击，并更新行走摆动。
func sync_units(units: Array) -> void:
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
		var winding := rt.state == RtUnit.State.ATTACKING and rt.target != null and rt.attack_timer > 0.0
		if winding and not tracked.winding:
			_play_windup(rt, tracked)
		tracked.winding = winding
		if rt.last_attack_time != tracked.last_attack:
			tracked.last_attack = rt.last_attack_time
			tracked.winding = false
			_play_strike(rt, tracked)
	for item in units:
		var rt := item as RtUnit
		if rt == null:
			continue
		var tracked: Tracked = _tracked[rt.get_instance_id()]
		if rt.last_hit_time != tracked.last_hit:
			tracked.last_hit = rt.last_hit_time
			_play_hit(tracked.pose, Vector2.ZERO, SHAKE_RANGED_PX)
	_prune_corpses()


## 行走摆动跟随步进进度，与移动插值严格同步。
func walk_pose(rt: RtUnit) -> Vector2:
	if rt == null or not rt.is_stepping():
		return Vector2.ZERO
	var t := rt.step_t
	return Vector2(sin(t * TAU) * WALK_TILT, -absf(sin(t * PI)) * WALK_HOP_TILES)


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
	_corpses.append(corpse)
	var fall_dir := -1.0 if rt.is_player() else 1.0
	var pose := corpse.pose
	pose.flash = 1.0
	var tween := _new_tween(pose)
	tween.tween_interval(LUNGE_SECONDS)
	tween.tween_property(pose, "rotation", DEATH_TILT * fall_dir, DEATH_SECONDS * 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(pose, "offset", pose.offset + Vector2(0.18 * fall_dir, -0.12), DEATH_SECONDS * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "flash", 0.0, DEATH_SECONDS * 0.4)
	tween.tween_property(pose, "scale", Vector2(0.75, 0.55), DEATH_SECONDS * 0.45)
	tween.parallel().tween_property(pose, "alpha", 0.0, DEATH_SECONDS * 0.45)
	tween.tween_callback(func() -> void: corpse.done = true)


func _play_windup(rt: RtUnit, tracked: Tracked) -> void:
	var dir := _dir_to(rt, rt.target)
	var windup := maxf(0.08, rt.get_stats().attack_windup if rt.get_stats() != null else 0.3)
	var pose := tracked.pose
	var tween := _new_tween(pose)
	tween.tween_property(pose, "offset", -dir * WINDUP_PULL_TILES, windup * 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "scale", WINDUP_SQUASH, windup * 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	## 近战目标同步蓄力迎击，形成「双方对冲」。
	if _is_melee(rt) and rt.target != null and rt.target.is_alive():
		var target_tracked: Tracked = _tracked.get(rt.target.get_instance_id())
		if target_tracked != null and not target_tracked.winding and not _is_busy(target_tracked.pose):
			var tpose := target_tracked.pose
			var ttween := _new_tween(tpose)
			ttween.tween_property(tpose, "offset", dir * WINDUP_PULL_TILES * 0.6, windup * 0.8) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			ttween.parallel().tween_property(tpose, "scale", Vector2(1.05, 0.93), windup * 0.8)


func _play_strike(rt: RtUnit, tracked: Tracked) -> void:
	var target := rt.target
	var dir := _dir_to(rt, target)
	var pose := tracked.pose
	if not _is_melee(rt):
		var recoil := _new_tween(pose)
		recoil.tween_property(pose, "offset", -dir * RANGED_RECOIL_TILES, LUNGE_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		recoil.parallel().tween_property(pose, "scale", Vector2(0.92, 1.08), LUNGE_SECONDS)
		_tween_home(recoil, pose)
		return
	var lunge := _new_tween(pose)
	pose.lunging = true
	lunge.tween_property(pose, "offset", dir * LUNGE_ATTACKER_TILES, LUNGE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	lunge.parallel().tween_property(pose, "scale", Vector2(0.9, 1.12), LUNGE_SECONDS)
	lunge.tween_callback(func() -> void: pose.lunging = false)
	_tween_home(lunge, pose)
	if target == null:
		return
	var target_tracked: Tracked = _tracked.get(target.get_instance_id())
	if target_tracked == null:
		## 目标已在本步被击杀：残影自己播放闪白，这里只补震屏。
		create_tween().tween_callback(_shake.bind(SHAKE_MELEE_PX)).set_delay(LUNGE_SECONDS / maxf(0.25, speed_scale))
		return
	## 撞上瞬间才播受击；同步时间戳，避免轮询再播一次。
	target_tracked.last_hit = target.last_hit_time
	var tpose := target_tracked.pose
	var charge := _new_tween(tpose)
	charge.tween_property(tpose, "offset", -dir * LUNGE_TARGET_TILES, LUNGE_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	charge.tween_callback(_play_hit.bind(tpose, dir, SHAKE_MELEE_PX))


## 受击：闪白 + 沿来向小幅击退 + 镜头震动。
func _play_hit(pose: Pose, knock_dir: Vector2, shake_px: float) -> void:
	_flash(pose)
	if pose.lunging and _is_busy(pose):
		_shake(shake_px)
		return
	var tween := _new_tween(pose)
	tween.tween_property(pose, "offset", pose.offset + knock_dir * HIT_KNOCK_TILES, 0.05)
	tween.parallel().tween_property(pose, "scale", Vector2(1.12, 0.9), 0.05)
	tween.tween_property(pose, "offset", Vector2.ZERO, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "scale", Vector2.ONE, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	tween.tween_property(pose, "offset", Vector2.ZERO, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pose, "scale", Vector2.ONE, RECOVER_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(strength_px: float) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	shake_strength = maxf(shake_strength, strength_px)
	_shake_tween = create_tween()
	_shake_tween.set_speed_scale(maxf(0.25, speed_scale))
	_shake_tween.tween_property(self, "shake_strength", 0.0, SHAKE_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _new_tween(pose: Pose) -> Tween:
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
	if pose != null and pose.flash_tween != null:
		pose.flash_tween.kill()
		pose.flash_tween = null


func _prune_corpses() -> void:
	if _corpses.is_empty():
		return
	var keep: Array[Corpse] = []
	for corpse in _corpses:
		if not corpse.done:
			keep.append(corpse)
	_corpses = keep


func _dir_to(rt: RtUnit, target: RtUnit) -> Vector2:
	if rt == null or target == null:
		return Vector2.UP if rt != null and rt.is_player() else Vector2.DOWN
	var dir := rt.position.direction_to(target.position)
	if dir == Vector2.ZERO:
		return Vector2.UP if rt.is_player() else Vector2.DOWN
	return dir


func _is_melee(rt: RtUnit) -> bool:
	var stats := rt.get_stats()
	return stats == null or stats.projectile_speed <= 0.0
