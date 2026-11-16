class_name RecruitTwoStageTest
extends RefCounted

## 胜后招募两段：Session 层仍一次 roll 候选；UI 由 RealtimeBattleController 分 ITEMS → ROSTER。


static var _failures: int = 0


static func run_all() -> bool:
	_failures = 0
	_test_post_victory_session_flag()
	_test_opening_session_flag()
	if _failures == 0:
		print("RecruitTwoStageTest: all tests passed")
	else:
		push_error("RecruitTwoStageTest: %d failure(s)" % _failures)
	return _failures == 0


static func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("RecruitTwoStageTest FAIL: %s" % message)


static func _make_economy(gold: int) -> RunEconomy:
	var economy := RunEconomy.new()
	economy.configure(null)
	economy.grant(gold)
	return economy


static func _test_post_victory_session_flag() -> void:
	var session := RecruitSession.new()
	var deck := DeckState.new()
	var deck_config := DeckConfig.new()
	deck_config.max_size = 5
	deck.configure(deck_config)
	var econ := _make_economy(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	session.configure(load("res://resources/recruit/default_recruit_config.tres") as RecruitConfig, deck, econ, rng)
	session.require_nonempty_roster = false
	session.begin(0.5, 4, 20)
	_assert(not session.require_nonempty_roster, "post-victory: two-stage in UI")
	_assert(session.get_candidates().size() > 0, "candidates pre-rolled")


static func _test_opening_session_flag() -> void:
	var session := RecruitSession.new()
	var deck := DeckState.new()
	var deck_config := DeckConfig.new()
	deck_config.max_size = 5
	deck.configure(deck_config)
	var econ := _make_economy(20)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	session.configure(load("res://resources/recruit/default_recruit_config.tres") as RecruitConfig, deck, econ, rng)
	session.require_nonempty_roster = true
	session.begin(0.0, 1, 20)
	_assert(session.require_nonempty_roster, "opening: single combined screen")