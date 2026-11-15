class_name EnchantSession
extends RefCounted
## 地图附魔神龛：选人 + 战斗词条（Run 持久）。

signal session_changed
signal session_finished(did_confirm: bool)

var deck: DeckState
var economy: RunEconomy

var is_active: bool = false
var confirmed_this_visit: bool = false
var selected_entry_id: int = -1
var selected_trait_index: int = -1
var trait_offers: Array[Dictionary] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func configure(p_deck: DeckState, p_economy: RunEconomy = null, _p_sandbox_unused: bool = false) -> void:
	deck = p_deck
	economy = p_economy


func begin() -> void:
	if deck == null:
		push_error("EnchantSession.begin: deck missing")
		return
	selected_entry_id = -1
	selected_trait_index = -1
	confirmed_this_visit = false
	trait_offers = EnchantTraitCatalog.roll_offers(_rng)
	is_active = true
	session_changed.emit()


func get_seated_entry_ids() -> Array[int]:
	var out: Array[int] = []
	if deck == null:
		return out
	for entry in deck.get_entries():
		if entry == null or entry.seat_index < 0:
			continue
		out.append(entry.entry_id)
	return out


func select_entry(entry_id: int) -> bool:
	if not is_active or confirmed_this_visit:
		return false
	if entry_id < 0:
		selected_entry_id = -1
		session_changed.emit()
		return true
	if not entry_id in get_seated_entry_ids():
		return false
	selected_entry_id = entry_id
	session_changed.emit()
	return true


func select_trait(index: int) -> bool:
	if not is_active or confirmed_this_visit:
		return false
	if index < 0 or index >= trait_offers.size():
		return false
	selected_trait_index = index
	session_changed.emit()
	return true


func can_confirm() -> bool:
	return (
		is_active
		and not confirmed_this_visit
		and selected_entry_id >= 0
		and selected_trait_index >= 0
		and selected_trait_index < trait_offers.size()
	)


func try_confirm() -> Dictionary:
	if not can_confirm() or deck == null:
		return {"ok": false, "error": "cannot_confirm"}
	var entry := deck.get_entry(selected_entry_id)
	if entry == null:
		return {"ok": false, "error": "no_entry"}
	var offer: Dictionary = trait_offers[selected_trait_index]
	var status_id: StringName = offer.get("id", &"")
	var stacks: int = int(offer.get("stacks", 1))
	if not EnchantTraitCatalog.is_allowed(status_id):
		return {"ok": false, "error": "invalid_trait"}
	entry.set_enchant_trait(status_id, stacks)
	confirmed_this_visit = true
	deck.deck_changed.emit()
	session_changed.emit()
	return {"ok": true}


func skip() -> void:
	if not is_active:
		return
	selected_entry_id = -1
	selected_trait_index = -1
	is_active = false
	session_finished.emit(false)


func finish_after_confirm() -> void:
	if not is_active or not confirmed_this_visit:
		return
	is_active = false
	session_finished.emit(true)


func finish_after_fuse() -> void:
	finish_after_confirm()


## 旧熔炉 API（试验场等）；主路径不再使用。
var fused_this_visit: bool:
	get:
		return confirmed_this_visit


func get_material_entry_ids() -> Array[int]:
	return get_seated_entry_ids()


func get_success_percent() -> float:
	return 0.0


func reset_forge() -> void:
	select_entry(-1)
	select_trait(-1)


func randomize_ab_slots(_rng2: RandomNumberGenerator = null) -> bool:
	return false


func set_slot(_slot: StringName, _entry_id: int) -> bool:
	return false


func can_fuse() -> bool:
	return false


func try_fuse() -> Dictionary:
	return {"ok": false, "error": "furnace_removed"}


func preview_ability() -> AbilityData:
	return null


func build_preview_fused_entry() -> DeckEntry:
	return null


func set_test_unit_roll(_roll: float) -> void:
	pass


func clear_test_unit_roll() -> void:
	pass