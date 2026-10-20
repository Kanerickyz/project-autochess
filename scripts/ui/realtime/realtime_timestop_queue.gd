class_name RealtimeTimestopQueue
extends RefCounted
## 战斗内技能行动播报队列（Features/COMBAT_FEEDBACK §5.2）。
## 两拍：SHOW_CARD（介绍卡，尚未改真值）→ RESULT（结算后结果数字/短提示）。
## 待结算批次仍在 EffectResolver 队里；本队列只管表现时钟与阶段。

enum Phase {
	IDLE,
	SHOW_CARD,
	## 卡拍已结束、等待控制器 process_next_step；tick 不再推进。
	AWAITING_RESOLVE,
	RESULT,
}

## 介绍卡可读时长（与 arena SKILL_INFO_SECONDS 同量级）。
const CARD_PAUSE_SECONDS := 1.0
## 结算后结果反馈时停。
const RESULT_PAUSE_SECONDS := 0.4
## 加速后单拍墙钟下限，仍须可扫读。
const MIN_PAUSE_SECONDS := 0.12

var _phase: int = Phase.IDLE
var _card_owner: UnitInstance = null
var _card_spec: EffectSpec = null
var _result_payload: CombatEventPayload = null
## 逻辑剩余时停；每帧减去 delta * time_scale（加速缩短墙钟寿命）。
var _remaining: float = 0.0


func clear() -> void:
	_phase = Phase.IDLE
	_card_owner = null
	_card_spec = null
	_result_payload = null
	_remaining = 0.0


func is_blocking() -> bool:
	return _phase != Phase.IDLE


func size() -> int:
	return 1 if _phase != Phase.IDLE else 0


func get_phase() -> int:
	return _phase


func get_card_owner() -> UnitInstance:
	return _card_owner


func get_card_spec() -> EffectSpec:
	return _card_spec


func get_result_payload() -> CombatEventPayload:
	return _result_payload


## 开始「先卡」拍；调用方应立刻展示介绍卡（尚未 process_next_step）。
func begin_card(owner: UnitInstance, spec: EffectSpec, time_scale: float = 1.0) -> void:
	_phase = Phase.SHOW_CARD
	_card_owner = owner
	_card_spec = spec
	_result_payload = null
	_remaining = _pause_remaining(CARD_PAUSE_SECONDS, time_scale)


## 卡拍结束并完成结算后，进入结果拍；调用方应立刻播结果数字/短提示。
func begin_result(payload: CombatEventPayload, time_scale: float = 1.0) -> void:
	_phase = Phase.RESULT
	_result_payload = payload
	_remaining = _pause_remaining(RESULT_PAUSE_SECONDS, time_scale)


## 兼容旧「结算后入队」路径：直接进入结果拍（无先卡）。
func enqueue_resolved(payload: CombatEventPayload, time_scale: float = 1.0) -> bool:
	if payload == null:
		return false
	if _phase != Phase.IDLE:
		## 已在播报中：把后续结果挂到队尾不适用两拍模型；调用方应走 EffectResolver 待结算队列。
		return false
	begin_result(payload, time_scale)
	return true


## 推进表现时钟。返回本帧完成的阶段：&"card_done" | &"result_done" | &""。
func tick(delta: float, time_scale: float = 1.0) -> StringName:
	if _phase == Phase.IDLE or _phase == Phase.AWAITING_RESOLVE:
		return &""
	var scale := maxf(0.25, time_scale)
	_remaining -= delta * scale
	if _remaining > 0.0:
		return &""
	_remaining = 0.0
	if _phase == Phase.SHOW_CARD:
		_phase = Phase.AWAITING_RESOLVE
		return &"card_done"
	if _phase == Phase.RESULT:
		_phase = Phase.IDLE
		_card_owner = null
		_card_spec = null
		_result_payload = null
		return &"result_done"
	return &""


func _pause_remaining(base_seconds: float, time_scale: float) -> float:
	## 墙钟 = remaining/scale >= MIN；等价 remaining >= max(base, MIN*scale)
	var scale := maxf(0.25, time_scale)
	return maxf(base_seconds, MIN_PAUSE_SECONDS * scale)
