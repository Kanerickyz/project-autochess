class_name RosterBudget
extends RefCounted
## 阵容攻/血预算（入座占用）。备战与入手不占；开局赠队可 seed 占用但不扣开局余额。

signal budget_changed

const OPENING_ATK_REMAINING := 2
const OPENING_HP_REMAINING := 2
const VICTORY_CHOICE_HP := 5
const VICTORY_CHOICE_ATK := 2
const VICTORY_CHOICE_GOLD := 8

var remaining_atk: int = OPENING_ATK_REMAINING
var remaining_hp: int = OPENING_HP_REMAINING
## entry_id → {"atk": int, "hp": int}
var _occupied: Dictionary = {}


func reset() -> void:
	remaining_atk = OPENING_ATK_REMAINING
	remaining_hp = OPENING_HP_REMAINING
	_occupied.clear()
	budget_changed.emit()


func get_remaining_atk() -> int:
	return remaining_atk


func get_remaining_hp() -> int:
	return remaining_hp


func get_occupied_atk() -> int:
	var total := 0
	for key in _occupied.keys():
		var row: Dictionary = _occupied[key]
		total += int(row.get("atk", 0))
	return total


func get_occupied_hp() -> int:
	var total := 0
	for key in _occupied.keys():
		var row: Dictionary = _occupied[key]
		total += int(row.get("hp", 0))
	return total


func is_occupying(entry_id: int) -> bool:
	return _occupied.has(entry_id)


func get_occupation(entry_id: int) -> Dictionary:
	if not _occupied.has(entry_id):
		return {"atk": 0, "hp": 0}
	var row: Dictionary = _occupied[entry_id]
	return {"atk": int(row.get("atk", 0)), "hp": int(row.get("hp", 0))}


func can_afford(atk_cost: int, hp_cost: int) -> bool:
	return atk_cost >= 0 and hp_cost >= 0 and remaining_atk >= atk_cost and remaining_hp >= hp_cost


func try_occupy(entry_id: int, atk_cost: int, hp_cost: int) -> bool:
	if entry_id < 0:
		return false
	if _occupied.has(entry_id):
		return true
	if not can_afford(atk_cost, hp_cost):
		return false
	remaining_atk -= atk_cost
	remaining_hp -= hp_cost
	_occupied[entry_id] = {"atk": atk_cost, "hp": hp_cost}
	budget_changed.emit()
	return true


## 开局赠队：记占用但不扣减开局 2/2。
func seed_occupy_without_cost(entry_id: int, atk_cost: int, hp_cost: int) -> void:
	if entry_id < 0:
		return
	_occupied[entry_id] = {"atk": maxi(0, atk_cost), "hp": maxi(0, hp_cost)}
	budget_changed.emit()


func release(entry_id: int) -> Dictionary:
	var empty := {"atk": 0, "hp": 0}
	if not _occupied.has(entry_id):
		return empty
	var row: Dictionary = _occupied[entry_id]
	var atk := int(row.get("atk", 0))
	var hp := int(row.get("hp", 0))
	_occupied.erase(entry_id)
	remaining_atk += atk
	remaining_hp += hp
	budget_changed.emit()
	return {"atk": atk, "hp": hp}


func grant_atk(amount: int) -> void:
	if amount <= 0:
		return
	remaining_atk += amount
	budget_changed.emit()


func grant_hp(amount: int) -> void:
	if amount <= 0:
		return
	remaining_hp += amount
	budget_changed.emit()


func capture() -> Dictionary:
	var occ: Dictionary = {}
	for key in _occupied.keys():
		var row: Dictionary = _occupied[key]
		occ[int(key)] = {"atk": int(row.get("atk", 0)), "hp": int(row.get("hp", 0))}
	return {
		"remaining_atk": remaining_atk,
		"remaining_hp": remaining_hp,
		"occupied": occ,
	}


func restore(snapshot: Dictionary) -> void:
	remaining_atk = int(snapshot.get("remaining_atk", OPENING_ATK_REMAINING))
	remaining_hp = int(snapshot.get("remaining_hp", OPENING_HP_REMAINING))
	_occupied.clear()
	var occ: Dictionary = snapshot.get("occupied", {})
	for key in occ.keys():
		var row: Dictionary = occ[key]
		_occupied[int(key)] = {"atk": int(row.get("atk", 0)), "hp": int(row.get("hp", 0))}
	budget_changed.emit()
