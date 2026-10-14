class_name RealtimeTimestopQueue
extends RefCounted
## 实时战斗技能时停播报队列（Features/COMBAT_FEEDBACK §5.2）。
## 效果真值已由 EffectResolver 结算；本队列只暂停固定步模拟并播 UI/动画。

const DEFAULT_PAUSE_SECONDS := 0.4
## 加速后单条时停墙钟下限，仍须可扫读。
const MIN_PAUSE_SECONDS := 0.12

var _pending: Array = []
var _active: CombatEventPayload = null
## 逻辑剩余时停；每帧减去 delta * time_scale（加速缩短墙钟寿命）。
var _remaining: float = 0.0


func clear() -> void:
	_pending.clear()
	_active = null
	_remaining = 0.0


func is_blocking() -> bool:
	return _active != null or not _pending.is_empty()


func size() -> int:
	var n := _pending.size()
	if _active != null:
		n += 1
	return n


func get_active() -> CombatEventPayload:
	return _active


## 入队；连锁追加队尾。返回是否刚从空队列启动播报（调用方应立刻展示）。
func enqueue(payload: CombatEventPayload, time_scale: float = 1.0) -> bool:
	if payload == null:
		return false
	_pending.append(payload)
	if _active == null:
		return _start_next(time_scale)
	return false


## 推进表现时钟；time_scale>1 缩短时停墙钟。返回本帧新启动的 payload（若有）。
func tick(delta: float, time_scale: float = 1.0) -> CombatEventPayload:
	if _active == null:
		if _pending.is_empty():
			return null
		_start_next(time_scale)
		return _active
	var scale := maxf(0.25, time_scale)
	_remaining -= delta * scale
	if _remaining > 0.0:
		return null
	_active = null
	_remaining = 0.0
	if _pending.is_empty():
		return null
	_start_next(time_scale)
	return _active


func _start_next(time_scale: float) -> bool:
	if _pending.is_empty():
		return false
	_active = _pending.pop_front() as CombatEventPayload
	## 墙钟 = remaining/scale >= MIN；等价 remaining >= max(DEFAULT, MIN*scale)
	var scale := maxf(0.25, time_scale)
	_remaining = maxf(DEFAULT_PAUSE_SECONDS, MIN_PAUSE_SECONDS * scale)
	return _active != null
