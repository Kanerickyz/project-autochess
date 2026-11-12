class_name RunState
extends RefCounted

var rng_seed: int = 0
var map_state: MapState = MapState.new()
var run_depth: int = 0
var shop_visit_count: int = 0
var completed_encounter_count: int = 0
## Boss 后最终试炼通关层数（失败时记录已通过波数；未进入试炼为 0）。
var final_trial_floors_cleared: int = 0
var current_node_id: int = -1
## 本局开始时刻（引擎 ticks msec）；用于远征统计现实用时，不受战斗倍速影响。
var run_started_at_msec: int = 0
## 本局已持有徽章 id（跨遭遇保留；整局失败 / reset_progress 清空；卖人/三合一不丢）。
## 上限见 BadgeCatalog.MAX_OWNED（文档未定格数，实现默认 8）。
var owned_badge_ids: PackedStringArray = PackedStringArray()


func reset_progress() -> void:
	run_depth = 0
	shop_visit_count = 0
	completed_encounter_count = 0
	final_trial_floors_cleared = 0
	current_node_id = -1
	run_started_at_msec = 0
	owned_badge_ids = PackedStringArray()
	map_state = MapState.new()


func get_owned_badge_ids() -> PackedStringArray:
	return owned_badge_ids.duplicate()


func has_badge(badge_id: String) -> bool:
	if badge_id.is_empty():
		return false
	return badge_id in owned_badge_ids


func get_owned_badge_count() -> int:
	return owned_badge_ids.size()


## 加入徽章；已持有同 id 失败。满员时 FIFO 替换最早一枚。
## 返回 {ok, reason, replaced, replaced_id}。
func add_badge(badge_id: String) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "empty",
		"replaced": false,
		"replaced_id": "",
	}
	if badge_id.is_empty():
		return result
	if has_badge(badge_id):
		result["reason"] = "duplicate"
		return result
	if owned_badge_ids.size() >= BadgeCatalog.MAX_OWNED:
		var dropped := str(owned_badge_ids[0])
		owned_badge_ids.remove_at(0)
		result["replaced"] = true
		result["replaced_id"] = dropped
	owned_badge_ids.append(badge_id)
	result["ok"] = true
	result["reason"] = "added"
	return result


func clear_badges() -> void:
	owned_badge_ids = PackedStringArray()


func mark_run_started() -> void:
	run_started_at_msec = Time.get_ticks_msec()


## 自 mark_run_started 起的现实秒数（含地图/招募/商店/战斗观战）。
func get_run_elapsed_real_seconds() -> float:
	if run_started_at_msec <= 0:
		return 0.0
	return maxf(0.0, float(Time.get_ticks_msec() - run_started_at_msec) / 1000.0)
