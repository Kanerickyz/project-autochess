class_name CombatSettlementReelTest
extends RefCounted


static var _failures: int = 0


static func run_all(host: Node = null) -> bool:
	_failures = 0
	_check("info_card_reel_shake", _test_info_card_reel_shake(host))
	_check("combat_compact_shorter_than_detail", _test_combat_compact_shorter_than_detail(host))
	if _failures == 0:
		print("CombatSettlementReelTest: all passed")
	else:
		push_error("CombatSettlementReelTest: %d failure(s)" % _failures)
	return _failures == 0


static func _check(name: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		push_error("CombatSettlementReelTest FAIL: %s" % name)


static func _test_info_card_reel_shake(host: Node) -> bool:
	if host == null:
		return false
	var card := RealtimeUnitInfoCard.new()
	host.add_child(card)
	var info := {
		"name": "测试",
		"side_player": true,
		"tier": 1,
		"attack": 2,
		"hp": 3,
		"skills": "开战时 对自身 获得 +2 金",
	}
	card.show_info(info, Vector2(120, 80), Vector2(120, 140), Rect2(0, 0, 400, 600))
	card.play_settlement_reel_shake(1.0)
	var ok := card.visible and card.is_inside_tree()
	card.queue_free()
	return ok


## 缩卡可见且高度/宽度明显短于同文案详卡（COMBAT_FEEDBACK §5.2.1）。
static func _test_combat_compact_shorter_than_detail(host: Node) -> bool:
	if host == null:
		return false
	var detail := RealtimeUnitInfoCard.new()
	var compact := RealtimeUnitInfoCard.new()
	host.add_child(detail)
	host.add_child(compact)
	var long_skills := "敌方死亡时 持有者周围一格友方本场攻击与生命上限各 +1（三合一后 +3）"
	var info := {
		"name": "弩手",
		"side_player": true,
		"tier": 2,
		"attack": 4,
		"hp": 5,
		"skills": long_skills,
	}
	var bounds := Rect2(0, 0, 400, 700)
	var foot := Vector2(200, 500)
	detail.show_info_combat_below_unit(info, foot, bounds)
	compact.show_info_combat_compact(
		{
			"name": "弩手",
			"side_player": true,
			"tier": 2,
			"attack": 4,
			"hp": 5,
			"skills": "敌方死亡时 周围友方攻血+1",
		},
		foot,
		bounds,
	)
	var ok := (
		compact.visible
		and detail.visible
		and compact.is_compact_mode()
		and not detail.is_compact_mode()
		and compact.size.x < detail.size.x - 20.0
		and compact.size.y < detail.size.y - 10.0
	)
	detail.queue_free()
	compact.queue_free()
	return ok
