class_name RunState
extends RefCounted

## 指挥官开局 / 满血上限（与 resources/units/realtime/commander.tres 对齐）。
const COMMANDER_MAX_HP := 30

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
## 指挥官当前生命：跨遭遇继承；开局 / 整局重置为满血。
var commander_hp: int = COMMANDER_MAX_HP


func reset_progress() -> void:
	run_depth = 0
	shop_visit_count = 0
	completed_encounter_count = 0
	final_trial_floors_cleared = 0
	current_node_id = -1
	run_started_at_msec = 0
	commander_hp = COMMANDER_MAX_HP
	map_state = MapState.new()


func get_commander_hp(max_hp: int = COMMANDER_MAX_HP) -> int:
	return clampi(commander_hp, 0, maxi(0, max_hp))


## max_hp：当前有效上限（含队伍强化）；缺省为开局底值。
func set_commander_hp(hp: int, max_hp: int = COMMANDER_MAX_HP) -> void:
	commander_hp = clampi(hp, 0, maxi(0, max_hp))


func is_commander_alive(max_hp: int = COMMANDER_MAX_HP) -> bool:
	return get_commander_hp(max_hp) > 0


func mark_run_started() -> void:
	run_started_at_msec = Time.get_ticks_msec()


## 自 mark_run_started 起的现实秒数（含地图/招募/商店/战斗观战）。
func get_run_elapsed_real_seconds() -> float:
	if run_started_at_msec <= 0:
		return 0.0
	return maxf(0.0, float(Time.get_ticks_msec() - run_started_at_msec) / 1000.0)
