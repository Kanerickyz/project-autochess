class_name QueuedEffectBatch
extends RefCounted

var owner: UnitInstance
var spec: EffectSpec
var payload: CombatEventPayload
var depth: int
var entries: Array[QueuedEffectStep] = []
