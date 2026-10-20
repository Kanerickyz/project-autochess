class_name EnchantFusionService
extends RefCounted

const FUSED_UNIT := preload("res://resources/units/fused_enchant.tres")


static func fuse(deck: DeckState, entry_id_a: int, entry_id_b: int) -> Dictionary:
	var result := {"ok": false, "entry": null, "error": ""}
	if deck == null:
		result["error"] = "deck_missing"
		return result
	if entry_id_a == entry_id_b:
		result["error"] = "same_entry"
		return result
	var a := deck.get_entry(entry_id_a)
	var b := deck.get_entry(entry_id_b)
	if not AbilityComposer.can_use_as_enchant_material(a):
		result["error"] = "invalid_a"
		return result
	if not AbilityComposer.can_use_as_enchant_material(b):
		result["error"] = "invalid_b"
		return result
	var ability := AbilityComposer.compose(a, b)
	if ability == null:
		result["error"] = "compose_failed"
		return result

	var atk := ceili(
		(
			float(DeckUpgradeService.get_display_attack(a))
			+ float(DeckUpgradeService.get_display_attack(b))
		)
		/ 2.0
	)
	var hp := ceili(
		(
			float(DeckUpgradeService.get_display_max_hp(a))
			+ float(DeckUpgradeService.get_display_max_hp(b))
		)
		/ 2.0
	)
	var base_atk := 1
	var base_hp := 1
	if FUSED_UNIT != null and FUSED_UNIT.stats != null:
		base_atk = FUSED_UNIT.stats.attack
		base_hp = FUSED_UNIT.stats.max_hp

	var inherit_seat := a.seat_index
	var inherit_seq := a.seat_assign_seq
	var crit_bonus := a.bonus_crit_rate_percent + b.bonus_crit_rate_percent
	var buff_sources := [a, b]

	if not deck.remove_entry(entry_id_a):
		result["error"] = "remove_a_failed"
		return result
	if not deck.remove_entry(entry_id_b):
		result["error"] = "remove_b_failed"
		return result

	var product := deck.add_fused_enchant_entry(ability, atk, hp, base_atk, base_hp, crit_bonus)
	if product == null:
		result["error"] = "add_failed"
		return result
	_merge_buffs(product, buff_sources)
	if inherit_seat >= 0 and deck.is_seat_free(inherit_seat):
		deck.assign_seat(product.entry_id, inherit_seat)
		product.seat_assign_seq = inherit_seq
	result["ok"] = true
	result["entry"] = product
	return result


static func _merge_buffs(product: DeckEntry, sources: Array) -> void:
	if product == null:
		return
	for src in sources:
		if src == null:
			continue
		for buff in src.attached_buffs:
			if buff != null:
				product.attached_buffs.append(buff)
