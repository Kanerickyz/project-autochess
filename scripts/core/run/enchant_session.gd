class_name EnchantSession
extends RefCounted

signal session_changed
signal session_finished(did_fuse: bool)

var deck: DeckState
var economy: RunEconomy

var is_active: bool = false
var slot_a_entry_id: int = -1
var slot_b_entry_id: int = -1
var fused_this_visit: bool = false

var _test_roll_override: float = -1.0


func configure(p_deck: DeckState, p_economy: RunEconomy = null, _p_sandbox_unused: bool = false) -> void:
	deck = p_deck
	economy = p_economy


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


func get_success_percent() -> float:
	return EnchantPricing.compute_success_percent()


func reset_forge() -> void:
	if not is_active or fused_this_visit:
		return
	slot_a_entry_id = -1
	slot_b_entry_id = -1
	session_changed.emit()


## 从可熔原料中随机抽两名不同队员放入 A/B（试验场快捷）。
func randomize_ab_slots(rng: RandomNumberGenerator = null) -> bool:
	if not is_active or fused_this_visit:
		return false
	var ids := get_material_entry_ids()
	if ids.size() < 2:
		return false
	var pick_rng := rng
	if pick_rng == null:
		pick_rng = RandomNumberGenerator.new()
		pick_rng.randomize()
	var i := pick_rng.randi_range(0, ids.size() - 1)
	var j := pick_rng.randi_range(0, ids.size() - 2)
	if j >= i:
		j += 1
	slot_a_entry_id = ids[i]
	slot_b_entry_id = ids[j]
	session_changed.emit()
	return true


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
	else:
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
	var roll := _sample_unit_interval()
	var success := EnchantPricing.roll_succeeds(roll)
	if success:
		var result := EnchantFusionService.fuse(deck, slot_a_entry_id, slot_b_entry_id)
		if result.get("ok", false):
			fused_this_visit = true
			slot_a_entry_id = -1
			slot_b_entry_id = -1
			result["success"] = true
			session_changed.emit()
			return result
		return result
	var fail := EnchantFusionService.sacrifice_materials(deck, slot_a_entry_id, slot_b_entry_id)
	if not fail.get("ok", false):
		return fail
	slot_a_entry_id = -1
	slot_b_entry_id = -1
	session_changed.emit()
	return {"ok": true, "success": false, "error": ""}


func preview_ability() -> AbilityData:
	if not can_fuse() or deck == null:
		return null
	var a := deck.get_entry(slot_a_entry_id)
	var b := deck.get_entry(slot_b_entry_id)
	return AbilityComposer.compose(a, b)


func build_preview_fused_entry() -> DeckEntry:
	if not can_fuse() or deck == null:
		return null
	var a := deck.get_entry(slot_a_entry_id)
	var b := deck.get_entry(slot_b_entry_id)
	var ability := AbilityComposer.compose(a, b)
	if ability == null or EnchantFusionService.FUSED_UNIT == null:
		return null
	var entry := DeckEntry.new()
	entry.unit = EnchantFusionService.FUSED_UNIT
	entry.runtime_main_ability = ability.duplicate(true) as AbilityData
	EnchantFusionService.apply_fused_panel_to_entry(entry, a, b)
	return entry


func skip() -> void:
	if not is_active:
		return
	slot_a_entry_id = -1
	slot_b_entry_id = -1
	is_active = false
	session_finished.emit(false)


func finish_after_fuse() -> void:
	if not is_active or not fused_this_visit:
		return
	is_active = false
	session_finished.emit(true)


func set_test_unit_roll(roll: float) -> void:
	_test_roll_override = clampf(roll, 0.0, 1.0)


func clear_test_unit_roll() -> void:
	_test_roll_override = -1.0


func _sample_unit_interval() -> float:
	if _test_roll_override >= 0.0:
		return _test_roll_override
	return randf()
