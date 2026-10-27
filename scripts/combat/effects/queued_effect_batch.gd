class_name QueuedEffectBatch
extends RefCounted

var owner: UnitInstance
var spec: EffectSpec
var payload: CombatEventPayload
var depth: int
## 增益卡战斗结算播报（如亡者遗金）；介绍卡展示增益文案而非主技能。
var display_buff: BuffCardData
var entries: Array[QueuedEffectStep] = []
