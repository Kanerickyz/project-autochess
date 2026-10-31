class_name VictoryBoostSession
extends RefCounted
## 胜后免费强化：按最高已解锁品阶对整队（入座+备战）一名成员永久 +攻/+血。
## 不扣金；不进 Buff 系统；写入 DeckEntry.bonus_attack / bonus_max_hp。

signal session_changed

var deck: DeckState
var map_floor: int = 1
var floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT
var forward_only: bool = false

var is_active: bool = false
var selected_entry_id: int = -1
var boost_amount: int = 1
var applied: bool = false


func configure(
	p_deck: DeckState,
	p_map_floor: int = 1,
	p_floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT,
	p_forward_only: bool = false,
) -> void:
	deck = p_deck
	map_floor = maxi(1, p_map_floor)
	floor_count = maxi(1, p_floor_count)
	forward_only = p_forward_only


func begin() -> void:
	if deck == null:
		push_error("VictoryBoostSession.begin: deck missing")
		return
	selected_entry_id = -1
	applied = false
	boost_amount = compute_boost_amount(map_floor, floor_count, forward_only)
	is_active = true
	session_changed.emit()


static func compute_boost_amount(
	p_map_floor: int,
	p_floor_count: int = TierUnlock.DEFAULT_FLOOR_COUNT,
	p_forward_only: bool = false,
) -> int:
	## 最高已解锁品阶 1/2/3 → 本档 +1/+2/+3。
	return TierUnlock.get_max_unlocked_tier(p_map_floor, p_floor_count, p_forward_only)


func has_boostable_roster() -> bool:
	return get_boostable_entry_ids().size() > 0


func get_boostable_entry_ids() -> Array[int]:
	var out: Array[int] = []
	if deck == null:
		return out
	for entry in deck.get_entries():
		if entry == null:
			continue
		## 整队：已入座 + 备战；不含战斗代理（DeckEntry 本就无代理）。
		out.append(entry.entry_id)
	return out


func can_select(entry_id: int) -> bool:
	if not is_active or applied or entry_id < 0 or deck == null:
		return false
	return deck.get_entry(entry_id) != null


func select_entry(entry_id: int) -> bool:
	if not can_select(entry_id):
		return false
	selected_entry_id = entry_id
	session_changed.emit()
	return true


func can_confirm() -> bool:
	return is_active and not applied and selected_entry_id >= 0 and can_select(selected_entry_id)


## 写入永久加成；成功后 applied=true，会话仍可展示短停，由控制器再 end()。
func apply_boost() -> bool:
	if not can_confirm():
		return false
	var entry := deck.get_entry(selected_entry_id)
	if entry == null:
		return false
	var amount := maxi(1, boost_amount)
	entry.bonus_attack += amount
	deck.add_bonus_max_hp(entry, amount)
	deck.deck_changed.emit()
	applied = true
	session_changed.emit()
	return true


func end() -> void:
	is_active = false
	session_changed.emit()


func skip() -> void:
	if not is_active or applied:
		return
	selected_entry_id = -1
	is_active = false
	session_changed.emit()


func reset() -> void:
	is_active = false
	selected_entry_id = -1
	applied = false
	boost_amount = 1
