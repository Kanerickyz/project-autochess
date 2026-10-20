class_name EnchantSession
extends RefCounted

signal session_changed
signal session_finished(did_fuse: bool)

var deck: DeckState

var is_active: bool = false
var slot_a_entry_id: int = -1
var slot_b_entry_id: int = -1
var fused_this_visit: bool = false


func configure(p_deck: DeckState) -> void:
	deck = p_deck


func begin() -> void:
	if deck == null:
		push_error("EnchantSession.begin: deck missing")
		return
	slot_a_entry_id = -1
	slot_b_entry_id = -1
	fused_this_visit = false
	is_active = true
	session_changed.emit()


func get_material_entry_ids() -> Array[int]:
	var out: Array[int] = []
	if deck == null:
		return out
	for entry in deck.get_entries():
		if entry != null and AbilityComposer.can_use_as_enchant_material(entry):
			out.append(entry.entry_id)
	return out


func set_slot(slot: StringName, entry_id: int) -> bool:
	if fused_this_visit or not is_active:
		return false
	if entry_id < 0:
		if slot == &"a":
			slot_a_entry_id = -1
		elif slot == &"b":
			slot_b_entry_id = -1
		else:
			return false
		session_changed.emit()
		return true
	var entry := deck.get_entry(entry_id) if deck != null else null
	if not AbilityComposer.can_use_as_enchant_material(entry):
		return false
	if slot == &"a":
		if entry_id == slot_b_entry_id:
			return false
		slot_a_entry_id = entry_id
	elif slot == &"b":
		if entry_id == slot_a_entry_id:
			return false
		slot_b_entry_id = entry_id
	else:
		return false
	session_changed.emit()
	return true


func can_fuse() -> bool:
	return (
		is_active
		and not fused_this_visit
		and slot_a_entry_id >= 0
		and slot_b_entry_id >= 0
		and slot_a_entry_id != slot_b_entry_id
	)


func try_fuse() -> Dictionary:
	if not can_fuse():
		return {"ok": false, "error": "cannot_fuse"}
	var result := EnchantFusionService.fuse(deck, slot_a_entry_id, slot_b_entry_id)
	if result.get("ok", false):
		fused_this_visit = true
		slot_a_entry_id = -1
		slot_b_entry_id = -1
		session_changed.emit()
	return result


func preview_ability() -> AbilityData:
	if not can_fuse() or deck == null:
		return null
	var a := deck.get_entry(slot_a_entry_id)
	var b := deck.get_entry(slot_b_entry_id)
	return AbilityComposer.compose(a, b)


func skip() -> void:
	if not is_active:
		return
	is_active = false
	session_finished.emit(false)


func finish_after_fuse() -> void:
	if not is_active or not fused_this_visit:
		return
	is_active = false
	session_finished.emit(true)
