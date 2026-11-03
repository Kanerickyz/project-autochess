class_name ThemeBondServiceTest
extends RefCounted
## 主题羁绊：双计、备战/随从不计、threshold 成形。


static func run_all() -> bool:
	var ok := true
	ok = _test_dual_count_and_threshold() and ok
	ok = _test_bench_and_summon_excluded() and ok
	ok = _test_apply_injects_placeholder_ability() and ok
	ok = _test_unit_theme_helpers() and ok
	return ok


static func _make_unit(
	unit_id: String,
	primary: StringName,
	secondary: StringName = &"",
	is_summon: bool = false,
) -> UnitInstance:
	var data := UnitData.new()
	data.id = unit_id
	data.display_name = unit_id
	data.theme_primary = primary
	data.theme_secondary = secondary
	data.stats = UnitStats.new()
	data.stats.max_hp = 10
	data.stats.attack = 1
	var unit := UnitInstance.from_unit_data(data, Vector2i.ZERO, UnitInstance.Team.PLAYER)
	unit.is_combat_summon = is_summon
	return unit


static func _catalog_threshold(threshold: int = 3) -> ThemeBondCatalog:
	var cat := ThemeBondCatalog.new()
	for theme_id in UnitTheme.ALL_IDS:
		var bond := ThemeBondDef.new()
		bond.theme_id = theme_id
		bond.threshold = threshold
		var act := EffectAction.new()
		act.stat_name = &"attack"
		act.value = 1
		var spec := EffectSpec.new()
		spec.trigger = &"OnCombatStart"
		spec.target_selector = EffectSpec.TargetSelector.ALL_ALLIES
		var acts: Array[EffectAction] = [act]
		spec.actions = acts
		var specs: Array[EffectSpec] = [spec]
		bond.effect_specs = specs
		cat.bonds.append(bond)
	return cat


static func _test_dual_count_and_threshold() -> bool:
	## 帑卫(护卫+佣兵) + 盾卫 + 刺盾 → 护卫 3 成形；佣兵 1 未成形。
	var deployed: Array = [
		_make_unit("coffer", UnitTheme.GUARD, UnitTheme.MERCENARY),
		_make_unit("knight", UnitTheme.GUARD),
		_make_unit("spike", UnitTheme.GUARD),
	]
	var counts := ThemeBondService.count_themes(deployed)
	if int(counts.get(UnitTheme.GUARD, 0)) != 3:
		push_error(
			"ThemeBondServiceTest dual: guard count=%s want 3"
			% str(counts.get(UnitTheme.GUARD, 0))
		)
		return false
	if int(counts.get(UnitTheme.MERCENARY, 0)) != 1:
		push_error(
			"ThemeBondServiceTest dual: mercenary count=%s want 1"
			% str(counts.get(UnitTheme.MERCENARY, 0))
		)
		return false
	var formed := ThemeBondService.list_formed_themes(deployed, _catalog_threshold(3))
	var expect_guard: Array[StringName] = [UnitTheme.GUARD]
	if formed != expect_guard:
		push_error("ThemeBondServiceTest dual: formed=%s want [guard]" % str(formed))
		return false
	return true


static func _test_bench_and_summon_excluded() -> bool:
	## 上场仅 2 护卫；备战第三护卫与随从不传入 / 随从过滤 → 未成形。
	var on_board: Array = [
		_make_unit("a", UnitTheme.GUARD),
		_make_unit("b", UnitTheme.GUARD),
	]
	var bench := _make_unit("bench", UnitTheme.GUARD)
	var summon := _make_unit("summon", UnitTheme.GUARD, &"", true)
	## 备战不计入：调用方只传上场名单。
	var formed_board := ThemeBondService.list_formed_themes(on_board, _catalog_threshold(3))
	if not formed_board.is_empty():
		push_error("ThemeBondServiceTest bench: board-only should not form, got %s" % str(formed_board))
		return false
	## 即使误把备战塞进列表也会抬人数——规格要求调用方只传上场；随从必须滤掉。
	var with_summon: Array = on_board + [summon]
	var counts := ThemeBondService.count_themes(with_summon)
	if int(counts.get(UnitTheme.GUARD, 0)) != 2:
		push_error(
			"ThemeBondServiceTest summon: guard count=%s want 2 (summon excluded)"
			% str(counts.get(UnitTheme.GUARD, 0))
		)
		return false
	## 把备战算上才达门槛——证明备战若被传入会抬表；本测试记录调用约定。
	var with_bench: Array = on_board + [bench]
	var formed_with_bench := ThemeBondService.list_formed_themes(with_bench, _catalog_threshold(3))
	var expect_guard: Array[StringName] = [UnitTheme.GUARD]
	if formed_with_bench != expect_guard:
		push_error(
			"ThemeBondServiceTest bench convention: with bench should form, got %s"
			% str(formed_with_bench)
		)
		return false
	return true


static func _test_apply_injects_placeholder_ability() -> bool:
	var deployed: Array = [
		_make_unit("g1", UnitTheme.GUARD),
		_make_unit("g2", UnitTheme.GUARD),
		_make_unit("g3", UnitTheme.GUARD),
	]
	var formed := ThemeBondService.apply_formed_bonds_to_player_units(
		deployed, _catalog_threshold(3)
	)
	var expect_guard: Array[StringName] = [UnitTheme.GUARD]
	if formed != expect_guard:
		push_error("ThemeBondServiceTest apply: formed=%s" % str(formed))
		return false
	var carrier: UnitInstance = deployed[0]
	var found := false
	for ab in carrier.attached_abilities:
		if ab != null and String(ab.id).begins_with("theme_bond_placeholder_"):
			found = true
			if ab.effect_specs.is_empty():
				push_error("ThemeBondServiceTest apply: placeholder ability has no specs")
				return false
			break
	if not found:
		push_error("ThemeBondServiceTest apply: missing placeholder attached ability")
		return false
	return true


static func _test_unit_theme_helpers() -> bool:
	var data := UnitData.new()
	data.theme_primary = UnitTheme.UNDEAD
	data.theme_secondary = UnitTheme.ARCANE
	var ids := data.get_theme_ids()
	if ids.size() != 2 or ids[0] != UnitTheme.UNDEAD or ids[1] != UnitTheme.ARCANE:
		push_error("ThemeBondServiceTest helpers: get_theme_ids=%s" % str(ids))
		return false
	var line := UnitInfoText.get_theme_line_from_unit_data(data)
	if line != "主题：亡灵 / 秘术":
		push_error("ThemeBondServiceTest helpers: theme line='%s'" % line)
		return false
	if not UnitTheme.is_valid_id(UnitTheme.BAND):
		push_error("ThemeBondServiceTest helpers: BAND should be valid")
		return false
	if UnitTheme.display_name(UnitTheme.KNIGHT_ORDER) != "骑士团":
		push_error("ThemeBondServiceTest helpers: knight_order display")
		return false
	return true
