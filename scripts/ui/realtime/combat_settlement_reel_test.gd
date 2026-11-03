class_name CombatSettlementReelTest
extends RefCounted


static var _failures: int = 0


static func run_all(host: Node = null) -> bool:
	_failures = 0
	_check("info_card_reel_shake", _test_info_card_reel_shake(host))
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
