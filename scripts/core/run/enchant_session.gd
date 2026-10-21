class_name EnchantSession
extends RefCounted

signal session_changed
signal session_finished(did_fuse: bool)

var deck: DeckState
var economy: RunEconomy
## 主菜单试验场：不扣 Run 金币，仍累计 G。
var sandbox_free_gold: bool = false

var is_active: bool = false
var slot_a_entry_id: int = -1
var slot_b_entry_id: int = -1
var fused_this_visit: bool = false
var gold_invested_g: int = 0

var _test_roll_override: float = -1.0


func configure(p_deck: DeckState, p_economy: RunEconomy = null, p_sandbox_free_gold: bool = false) -> void:
	deck = p_deck
	economy = p_economy
	sandbox_free_gold = p_sandbox_free_gold


func begin() -> void:
	if deck == null:
		push_error("EnchantSession.begin: deck missing")
		return
	slot_a_entry_id = -1
	slot_b_entry_id = -1
	fused_this_visit = false
	gold_invested_g = 0
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


func get_expected_price() -> int:
	if not can_fuse() or deck == null:
		return 0
	var a := deck.get_entry(slot_a_entry_id)
	var b := deck.get_entry(slot_b_entry_id)
	return EnchantPricing.compute_expected_price(a, b)


func get_success_percent() -> float:
	return EnchantPricing.compute_success_percent(gold_invested_g, get_expected_price())


func is_guaranteed_success() -> bool:
	var p := get_expected_price()
	return p > 0 and gold_invested_g >= p


func can_invest_gold() -> bool:
	if not is_active or fused_this_visit or not can_fuse():
		return false
	if sandbox_free_gold:
		return true
	return economy != null and economy.can_afford(1)


func try_invest_gold() -> bool:
	if not can_invest_gold():
		return false
	if not sandbox_free_gold:
		if economy == null or not economy.spend(1):
			return false
	gold_invested_g += 1
	session_changed.emit()
	return true


func reset_forge() -> void:
	if not is_active or fused_this_visit:
		return
	gold_invested_g = 0
	slot_a_entry_id = -1
	slot_b_entry_id = -1
	session_changed.emit()


func set_slot(slot: StringName, entry_id: int) -> bool:
	if fused_this_visit or not is_active:
		return false
	var recipe_changed := false
	if entry_id < 0:
		if slot == &"a" and slot_a_entry_id >= 0:
			recipe_changed = true
			slot_a_entry_id = -1
		elif slot == &"b" and slot_b_entry_id >= 0:
			recipe_changed = true
			slot_b_entry_id = -1
		elif slot == &"a":
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
			if slot_a_entry_id != entry_id:
				recipe_changed = true
			slot_a_entry_id = entry_id
		elif slot == &"b":
			if entry_id == slot_a_entry_id:
				return false
			if slot_b_entry_id != entry_id:
				recipe_changed = true
			slot_b_entry_id = entry_id
		else:
			return false
	if recipe_changed:
		gold_invested_g = 0
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
	var expected_p := get_expected_price()
	var roll := _sample_unit_interval()
	var success := EnchantPricing.roll_succeeds(gold_invested_g, expected_p, roll)
	gold_invested_g = 0
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
