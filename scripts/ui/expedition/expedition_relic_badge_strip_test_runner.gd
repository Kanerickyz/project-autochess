extends SceneTree
## godot --headless --path . --script res://scripts/ui/expedition/expedition_relic_badge_strip_test_runner.gd

const StripTest := preload("res://scripts/ui/expedition/expedition_relic_badge_strip_test.gd")
const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not StripTest.run():
		_failures += 1
	await _test_battle_hud_wiring()
	if _failures == 0:
		print("ExpeditionRelicBadgeStripTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("ExpeditionRelicBadgeStripTest: FAIL %s" % label)


func _test_battle_hud_wiring() -> void:
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	root.add_child(battle)
	await process_frame
	var strip := battle.get_relic_badge_strip()
	_expect(strip != null, "battle: RelicBadgeStrip present")
	if strip == null:
		battle.queue_free()
		await process_frame
		return
	_expect(strip.get_slot_count() == 6, "battle: strip has 6 slots when bag null")
	_expect(strip.get_occupied_count() == 0, "battle: empty bag shows 0 occupied")
	var bag := ExpeditionRelicBag.new()
	var relic := ExpeditionRelicData.new()
	relic.id = "relic_hud_test"
	relic.display_name = "税秤"
	relic.description = "HUD 接线测试"
	relic.tier = 2
	bag.try_add(relic)
	battle.set_relic_bag(bag)
	await process_frame
	_expect(strip.get_bag() == bag, "battle: set_relic_bag configures strip")
	_expect(strip.get_occupied_count() == 1, "battle: occupied slot visible after set_relic_bag")
	var badge := strip.get_badge(0)
	_expect(badge != null and badge.is_occupied(), "battle: slot 0 occupied")
	_expect(badge != null and badge.glyph_text() == "税", "battle: glyph from display_name")
	_expect(strip.get_badge(5) != null and not strip.get_badge(5).is_occupied(), "battle: empty trailing slot")
	var gold := battle.get_node_or_null("%GoldLabel") as Label
	_expect(gold != null, "battle: GoldLabel in player info row")
	var player_row := battle.get_node_or_null("%PlayerInfoRow") as HBoxContainer
	_expect(player_row != null, "battle: PlayerInfoRow exists")
	if player_row != null and gold != null and strip != null:
		_expect(gold.get_parent() == player_row, "battle: gold in PlayerInfoRow")
		_expect(strip.get_parent() == player_row, "battle: strip in PlayerInfoRow")
	battle.queue_free()
	await process_frame
