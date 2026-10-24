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

	var panel := compute_fused_panel(a, b)
	var atk: int = panel["display_attack"]
	var hp: int = panel["display_max_hp"]
	var base_atk: int = panel["base_attack"]
	var base_hp: int = panel["base_max_hp"]

	var inherit_seat := a.seat_index
	var inherit_seq := a.seat_assign_seq
	var buff_sources := [a, b]

	if not deck.remove_entry(entry_id_a):
		result["error"] = "remove_a_failed"
		return result
	if not deck.remove_entry(entry_id_b):
		result["error"] = "remove_b_failed"
		return result

	var product := deck.add_fused_enchant_entry(ability, atk, hp, base_atk, base_hp)
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


## 融合失败：永久移除两名原料，不产出熔印者。
static func sacrifice_materials(deck: DeckState, entry_id_a: int, entry_id_b: int) -> Dictionary:
	var result := {"ok": false, "error": ""}
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
	if not deck.remove_entry(entry_id_a):
		result["error"] = "remove_a_failed"
		return result
	if not deck.remove_entry(entry_id_b):
		result["error"] = "remove_b_failed"
		return result
	result["ok"] = true
	return result


## 熔印者面板：攻、血为两名原料当前展示值之和（与 unit.stats + bonus 一致）。
static func compute_fused_panel(a: DeckEntry, b: DeckEntry) -> Dictionary:
	var base_atk := 1
	var base_hp := 1
	if FUSED_UNIT != null and FUSED_UNIT.stats != null:
		base_atk = FUSED_UNIT.stats.attack
		base_hp = FUSED_UNIT.stats.max_hp
	return {
		"display_attack": (
			DeckUpgradeService.get_display_attack(a) + DeckUpgradeService.get_display_attack(b)
		),
		"display_max_hp": (
			DeckUpgradeService.get_display_max_hp(a) + DeckUpgradeService.get_display_max_hp(b)
		),
		"base_attack": base_atk,
		"base_max_hp": base_hp,
	}


static func apply_fused_panel_to_entry(entry: DeckEntry, a: DeckEntry, b: DeckEntry) -> void:
	if entry == null or a == null or b == null:
		return
	var panel := compute_fused_panel(a, b)
	entry.bonus_attack = int(panel["display_attack"]) - int(panel["base_attack"])
	entry.bonus_max_hp = int(panel["display_max_hp"]) - int(panel["base_max_hp"])


static func _merge_buffs(product: DeckEntry, sources: Array) -> void:
	if product == null:
		return
	for src in sources:
		if src == null:
			continue
		for buff in src.attached_buffs:
			if buff != null:
				product.attached_buffs.append(buff)
