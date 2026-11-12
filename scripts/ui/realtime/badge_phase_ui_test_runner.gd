extends SceneTree
## Headless：徽章阶段 UI 进入、跳过回 IDLE、选择写入、持有条节点存在。

const BATTLE_SCENE := "res://scenes/combat/realtime/realtime_battle.tscn"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_enter_badge_skip()
	await _test_enter_badge_pick()
	await _test_pick_long_press_info_when_owned_empty()
	if _failures == 0:
		print("BadgePhaseUiTest: all passed")
	quit(0 if _failures == 0 else 1)


func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  PASS %s" % label)
	else:
		_failures += 1
		push_error("BadgePhaseUiTest: FAIL %s" % label)


func _make_battle() -> RealtimeBattleController:
	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = 10
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	var economy := RunEconomy.new()
	economy.configure(load(ECONOMY_PATH) as EconomyConfig)
	economy.reset()
	var battle := (load(BATTLE_SCENE) as PackedScene).instantiate() as RealtimeBattleController
	battle.half_exit_seconds = 0.0
	battle.recruit_enter_seconds = 0.0
	root.add_child(battle)
	battle.setup(deck, economy, load(LEVEL_PATH) as LevelData)
	return battle


func _test_enter_badge_skip() -> void:
	var battle := _make_battle()
	await process_frame
	var run := RunState.new()
	var session := BadgeSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	session.configure(run, rng)
	session.begin(1, 15, false)
	_expect(session.get_candidates().size() == BadgeSession.OFFER_COUNT, "skip path has 3 candidates")
	var finished: Array = []
	battle.badge_finished.connect(func(picked: bool) -> void: finished.append(picked))
	battle.enter_badge(session)
	await process_frame
	_expect(battle.get_phase() == RealtimeBattleController.Phase.BADGE, "phase BADGE")
	var overlay := battle.get_node_or_null("BadgePickOverlay") as BadgePickOverlay
	_expect(overlay != null and overlay.visible, "pick overlay visible")
	## 全屏钉死：避免尺寸 0 导致候选挤左上且看不见。
	_expect(overlay.size.x > 100.0 and overlay.size.y > 100.0, "pick overlay non-zero size")
	var slot0 := overlay.find_child("BadgeSlot0", true, false) as Control
	_expect(slot0 != null and slot0.visible, "circular slot0 visible")
	overlay.badge_skipped.emit()
	await process_frame
	_expect(finished.size() == 1 and finished[0] == false, "skip emits picked=false")
	_expect(battle.get_phase() == RealtimeBattleController.Phase.IDLE, "phase IDLE after skip")
	_expect(run.get_owned_badge_count() == 0, "skip keeps empty owned")
	battle.queue_free()
	await process_frame


func _test_enter_badge_pick() -> void:
	var battle := _make_battle()
	await process_frame
	var run := RunState.new()
	var session := BadgeSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	session.configure(run, rng)
	session.begin(4, 15, false)
	_expect(not session.get_candidates().is_empty(), "has candidates")
	var want_id := session.get_candidate(0).id
	var finished: Array = []
	battle.badge_finished.connect(func(picked: bool) -> void: finished.append(picked))
	battle.enter_badge(session)
	await process_frame
	var overlay := battle.get_node_or_null("BadgePickOverlay") as BadgePickOverlay
	overlay.badge_picked.emit(0)
	await process_frame
	_expect(finished.size() == 1 and finished[0] == true, "pick emits picked=true")
	_expect(run.has_badge(want_id), "run_state has picked id")
	_expect(battle.get_owned_badge_ids().has(want_id), "battle owned synced")
	var bar := battle.get_node_or_null("BadgeOwnedBar") as BadgeOwnedBar
	_expect(bar != null, "owned bar exists")
	## 持有条在准备/招募/战斗显示；IDLE 过渡可隐藏。强制进准备刷新底栏。
	battle.set_owned_badge_ids(run.get_owned_badge_ids())
	battle.call("_set_phase", RealtimeBattleController.Phase.PREPARE)
	await process_frame
	_expect(bar.visible, "owned bar visible in PREPARE with badges")
	battle.queue_free()
	await process_frame


func _test_pick_long_press_info_when_owned_empty() -> void:
	## 首胜三选一：持有为空时长按候选仍须出说明卡（在 PickOverlay 上）。
	var battle := _make_battle()
	await process_frame
	var run := RunState.new()
	var session := BadgeSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	session.configure(run, rng)
	session.begin(3, 15, false)
	battle.enter_badge(session)
	await process_frame
	var overlay := battle.get_node_or_null("BadgePickOverlay") as BadgePickOverlay
	_expect(overlay != null and overlay.visible, "pick overlay up")
	var cand := session.get_candidate(0)
	_expect(cand != null, "candidate0")
	overlay.show_info_for(cand)
	await process_frame
	var info := overlay.get_node_or_null("PickInfoCard") as CanvasItem
	_expect(info != null and info.visible, "pick info card visible with empty owned")
	var bar := battle.get_node_or_null("BadgeOwnedBar") as BadgeOwnedBar
	if bar != null:
		bar.show_info_for(cand)
		_expect(bar.visible, "owned bar forced visible for info fallback")
	battle.queue_free()
	await process_frame
