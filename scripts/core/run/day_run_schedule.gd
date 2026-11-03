class_name DayRunSchedule
extends RefCounted
## 十五天固定日程：每天 招募 → 战斗 → 商店 → 战斗 → 事件 → 战斗 → 结束一天。
## 第 1 天招募连续 6 次三选一；第 2 天起每天 1 次。第 15 天第三场为 Boss，胜后通关。

enum Step { RECRUIT, COMBAT, SHOP, EVENT }

const DAY_COUNT := 15
const FIRST_DAY_RECRUIT_PICKS := 6
const DAILY_RECRUIT_PICKS := 1
const PICK_OPTION_COUNT := 3
const STEPS_PER_DAY: Array[Step] = [
	Step.RECRUIT,
	Step.COMBAT,
	Step.SHOP,
	Step.COMBAT,
	Step.EVENT,
	Step.COMBAT,
]

var day: int = 1
var step_index: int = 0


func reset() -> void:
	day = 1
	step_index = 0


func get_day() -> int:
	return day


func get_day_count() -> int:
	return DAY_COUNT


func get_step() -> Step:
	return STEPS_PER_DAY[clampi(step_index, 0, STEPS_PER_DAY.size() - 1)]


func get_step_index() -> int:
	return step_index


func get_steps_per_day() -> int:
	return STEPS_PER_DAY.size()


## 当天第几场战斗（1..3）；非战斗步返回当天已开打的场数。
func get_battle_index() -> int:
	var n := 0
	for i in mini(step_index + 1, STEPS_PER_DAY.size()):
		if STEPS_PER_DAY[i] == Step.COMBAT:
			n += 1
	return n


func get_battles_per_day() -> int:
	var n := 0
	for s in STEPS_PER_DAY:
		if s == Step.COMBAT:
			n += 1
	return n


func get_recruit_pick_count() -> int:
	return FIRST_DAY_RECRUIT_PICKS if day <= 1 else DAILY_RECRUIT_PICKS


## 第 1 天招募强制拿满；之后每天可跳过。
func can_skip_recruit() -> bool:
	return day > 1


func is_boss_battle() -> bool:
	return (
		day >= DAY_COUNT
		and get_step() == Step.COMBAT
		and get_battle_index() >= get_battles_per_day()
	)


func is_last_step_of_day() -> bool:
	return step_index >= STEPS_PER_DAY.size() - 1


## 推进到下一步；跨天时 day+1、step 归零。返回 true 表示进入了新的一天。
func advance() -> bool:
	if is_last_step_of_day():
		day += 1
		step_index = 0
		return true
	step_index += 1
	return false


func is_finished() -> bool:
	return day > DAY_COUNT


static func step_label(step: Step) -> String:
	match step:
		Step.RECRUIT:
			return "招募"
		Step.COMBAT:
			return "战斗"
		Step.SHOP:
			return "商店"
		Step.EVENT:
			return "事件"
	return ""


func get_step_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for s in STEPS_PER_DAY:
		out.append(step_label(s))
	return out
