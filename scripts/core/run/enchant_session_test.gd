class_name EnchantSessionTest
extends RefCounted

const _HurtAbility := preload("res://resources/abilities/hurt_gain_atk_small.tres")
const _CritAbility := preload("res://resources/abilities/crit_extra_damage_mid.tres")
const _FusedUnit := preload("res://resources/units/fused_enchant.tres")

static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_forge_slot_spacing()
	_test_fuse_creates_fused_enchant()
	_test_preview_fused_entry_panel()
	_test_fused_skips_triple_merge()
	_test_session_once_per_visit()
	if _failures == 0:
		print("EnchantSessionTest: all tests passed")
	else:
		push_error("EnchantSessionTest: %d failure(s)" % _failures)
	return _failures == 0


static func _deck_with_two() -> DeckState:
	var deck := DeckState.new()
	var config := DeckConfig.new()
	config.max_size = 5
	deck.configure(config)
	var u1 := UnitData.new()
	u1.id = "test_a"
	u1.stats = UnitStats.new()
	u1.stats.attack = 4
	u1.stats.max_hp = 6
	u1.ability = _HurtAbility
	var u2 := UnitData.new()
	u2.id = "test_b"
	u2.stats = UnitStats.new()
	u2.stats.attack = 8
	u2.stats.max_hp = 4
	u2.ability = _CritAbility
	var e1 := deck.add_entry(u1)
	var e2 := deck.add_entry(u2)
	_assert(e1 != null and e2 != null, "entries added")
	return deck


static func _test_forge_slot_spacing() -> void:
	var cells := EnchantLayout.forge_slot_cells(Vector2i(5, 8))
	_assert(cells.size() == 3, "three forge cells")
	if cells.size() >= 3:
		_assert(cells[0].x == 0 and cells[1].x == 2 and cells[2].x == 4, "A/B/C spaced")
		_assert(cells[0].y == cells[1].y and cells[1].y == cells[2].y, "forge row aligned")


static func _test_fuse_creates_fused_enchant() -> void:
	var deck := _deck_with_two()
	var entries := deck.get_entries()
	_assert(entries.size() == 2, "two before fuse")
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	session.set_slot(&"a", entries[0].entry_id)
	session.set_slot(&"b", entries[1].entry_id)
	var result := session.try_fuse()
	_assert(result.get("ok", false), "fuse ok")
	_assert(deck.size() == 1, "one after fuse")
	var fused := deck.get_entries()[0]
	_assert(fused.is_fused_enchant(), "is fused")
	_assert(fused.get_star_display_level() == 0, "no star display")
	_assert(DeckUpgradeService.get_display_attack(fused) == 12, "fused atk sum")
	_assert(DeckUpgradeService.get_display_max_hp(fused) == 10, "fused hp sum")
	var ab := fused.get_main_ability()
	_assert(ab != null and ab.effect_specs.size() == 1, "one composed spec")
	if ab != null and not ab.effect_specs.is_empty():
		var spec: EffectSpec = ab.effect_specs[0]
		_assert(spec.trigger == CombatEvents.ON_DAMAGE_TAKEN, "trigger from A")
		_assert(ab.uses_line_attack == _CritAbility.uses_line_attack, "shell from B")


static func _test_fused_skips_triple_merge() -> void:
	var deck := DeckState.new()
	var config := DeckConfig.new()
	config.max_size = 10
	deck.configure(config)
	for _i in 3:
		var u := UnitData.new()
		u.id = FusedEnchantIds.UNIT_ID
		u.stats = UnitStats.new()
		u.ability = _HurtAbility
		deck.add_entry(u)
	_assert(deck.size() == 3, "three fused do not auto-merge")
	deck.try_auto_merge()
	_assert(deck.size() == 3, "still three after try_auto_merge")


static func _test_preview_fused_entry_panel() -> void:
	var deck := _deck_with_two()
	var entries := deck.get_entries()
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	session.set_slot(&"a", entries[0].entry_id)
	session.set_slot(&"b", entries[1].entry_id)
	var preview := session.build_preview_fused_entry()
	_assert(preview != null, "preview entry")
	if preview != null:
		_assert(DeckUpgradeService.get_display_attack(preview) == 12, "preview atk sum")
		_assert(DeckUpgradeService.get_display_max_hp(preview) == 10, "preview hp sum")
		_assert(preview.get_main_ability() != null, "preview ability")


static func _test_session_once_per_visit() -> void:
	var deck := _deck_with_two()
	var ids := deck.get_entries()
	var session := EnchantSession.new()
	session.configure(deck)
	session.begin()
	session.set_slot(&"a", ids[0].entry_id)
	session.set_slot(&"b", ids[1].entry_id)
	session.try_fuse()
	_assert(not session.can_fuse(), "cannot fuse twice")
	session.finish_after_fuse()


static func _assert(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		push_error("EnchantSessionTest: FAIL %s" % label)
