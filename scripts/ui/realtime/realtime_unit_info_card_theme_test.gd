class_name RealtimeUnitInfoCardThemeTest
extends RefCounted
## 介绍卡侧栏主题类名（COMBAT_FEEDBACK §7.2）：有主题追加；NONE 省略；道具不加主题。


static var _failures: int = 0


static func run_all(host: Node = null) -> bool:
	_failures = 0
	_check("ally_warrior_side_shows_theme", _test_ally_warrior_side(host))
	_check("enemy_theme_side", _test_enemy_theme_side(host))
	_check("none_omits_unset_label", _test_none_omits_unset(host))
	_check("item_ignores_theme_label", _test_item_ignores_theme(host))
	_check("attachment_ignores_theme_label", _test_attachment_ignores_theme(host))
	_check("arena_info_from_unit_data_theme", _test_arena_info_theme_label(host))
	if _failures == 0:
		print("RealtimeUnitInfoCardThemeTest: all passed")
	else:
		push_error("RealtimeUnitInfoCardThemeTest: %d failure(s)" % _failures)
	return _failures == 0


static func _check(name: String, ok: bool) -> void:
	if ok:
		print("  PASS %s" % name)
	else:
		_failures += 1
		push_error("RealtimeUnitInfoCardThemeTest FAIL: %s" % name)


static func _show_and_side(host: Node, info: Dictionary) -> String:
	if host == null:
		return ""
	var card := RealtimeUnitInfoCard.new()
	host.add_child(card)
	card.show_info(info, Vector2(120, 80), Vector2(120, 140), Rect2(0, 0, 400, 600))
	var side := ""
	if card._side_label != null:
		side = card._side_label.text
	card.free()
	return side


static func _test_ally_warrior_side(host: Node) -> bool:
	var side := _show_and_side(
		host,
		{
			"name": "蛮族",
			"side_player": true,
			"tier": 2,
			"theme_label": "战士",
			"attack": 3,
			"hp": 5,
			"skills": "测试",
		}
	)
	return side == "我方 · T2 · 战士"


static func _test_enemy_theme_side(host: Node) -> bool:
	var side := _show_and_side(
		host,
		{
			"name": "亡灵兵",
			"side_player": false,
			"tier": 1,
			"theme_label": "亡灵",
			"attack": 2,
			"hp": 4,
			"skills": "测试",
		}
	)
	return side == "敌方 · T1 · 亡灵"


static func _test_none_omits_unset(host: Node) -> bool:
	var side_empty := _show_and_side(
		host,
		{
			"name": "无主题",
			"side_player": true,
			"tier": 3,
			"theme_label": "",
			"attack": 1,
			"hp": 1,
			"skills": "测试",
		}
	)
	var side_bond_none := _show_and_side(
		host,
		{
			"name": "无主题枚举",
			"side_player": true,
			"tier": 3,
			"theme_bond": UnitData.ThemeBond.NONE,
			"attack": 1,
			"hp": 1,
			"skills": "测试",
		}
	)
	return (
		side_empty == "我方 · T3"
		and side_bond_none == "我方 · T3"
		and not side_empty.contains("未定")
		and not side_bond_none.contains("未定")
	)


static func _test_item_ignores_theme(host: Node) -> bool:
	var side := _show_and_side(
		host,
		{
			"name": "血瓶",
			"side_player": true,
			"is_item": true,
			"kind_label": "消耗品",
			"cost": 3,
			"theme_label": "战士",
			"attack": 0,
			"hp": 0,
			"skills": "道具",
		}
	)
	return side == "消耗品 · 3金" and not side.contains("战士")


static func _test_attachment_ignores_theme(host: Node) -> bool:
	var side := _show_and_side(
		host,
		{
			"name": "皮甲",
			"is_attachment": true,
			"attachment_kind_label": "装备",
			"theme_label": "战士",
			"skills": "护甲",
		}
	)
	return side == "装备" and not side.contains("战士")


static func _test_arena_info_theme_label(host: Node) -> bool:
	if host == null:
		return false
	var arena := RealtimeArenaView.new()
	host.add_child(arena)
	var warrior := UnitData.new()
	warrior.id = "theme_test_warrior"
	warrior.display_name = "测战士"
	warrior.tier = 2
	warrior.theme_bond = UnitData.ThemeBond.WARRIOR
	warrior.stats = UnitStats.new()
	warrior.stats.attack = 2
	warrior.stats.max_hp = 4
	var with_theme: Dictionary = arena._info_from_unit_data(warrior, Vector2.ZERO, "theme:w")
	var none_unit := UnitData.new()
	none_unit.id = "theme_test_none"
	none_unit.display_name = "测无"
	none_unit.tier = 1
	none_unit.theme_bond = UnitData.ThemeBond.NONE
	none_unit.stats = UnitStats.new()
	none_unit.stats.attack = 1
	none_unit.stats.max_hp = 1
	var without: Dictionary = arena._info_from_unit_data(none_unit, Vector2.ZERO, "theme:n")
	var barb := load("res://resources/units/realtime/barbarian.tres") as UnitData
	var barb_info: Dictionary = {}
	if barb != null:
		barb_info = arena._info_from_unit_data(barb, Vector2.ZERO, "theme:barb")
	arena.free()
	var ok_warrior := String(with_theme.get("theme_label", "")) == "战士"
	var ok_none := String(without.get("theme_label", "")) == ""
	var ok_barb := barb == null or String(barb_info.get("theme_label", "")) == "战士"
	return ok_warrior and ok_none and ok_barb
