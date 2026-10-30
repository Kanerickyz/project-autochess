extends SceneTree
## 轻量：bandit 训练 8 局 + 冻结 eval 1 局；不写入 resources。

const TMP_CKPT := "/tmp/sim_bandit_smoke_ckpt.tres"


func _initialize() -> void:
	var checkpoint := SimBanditCheckpoint.new()
	checkpoint.policy_id = "bandit-smoke"
	var sim_train := RunMatchSimulator.new()
	sim_train.configure(null, null, null, null, null, null, checkpoint, true)
	for seed in range(8):
		sim_train.simulate_run(9000 + seed)
	var saved := sim_train.export_bandit_checkpoint()
	var err := ResourceSaver.save(saved, TMP_CKPT)
	if err != OK:
		push_error("BanditSmoke: save tmp failed")
		quit(1)
		return
	var updates := sim_train.get_bandit_update_count()
	if updates <= 0:
		push_error("BanditSmoke: expected bandit updates > 0 got %d" % updates)
		quit(1)
		return

	var loaded := load(TMP_CKPT) as SimBanditCheckpoint
	var sim_eval := RunMatchSimulator.new()
	sim_eval.configure(null, null, null, null, null, null, loaded, false)
	var before := sim_eval.get_bandit_update_count()
	var record: Dictionary = sim_eval.simulate_run(42)
	var after := sim_eval.get_bandit_update_count()
	if after != before:
		push_error("BanditSmoke: eval run must not update table")
		quit(1)
		return
	if record.get("profile_id") != "bandit-smoke":
		push_error("BanditSmoke: profile_id mismatch")
		quit(1)
		return
	if not _direct_pick_smoke():
		quit(1)
		return
	print("SimBanditSmoke: OK updates=%d eval_outcome=%s" % [updates, record.get("outcome")])
	quit(0)


func _direct_pick_smoke() -> bool:
	var ckpt := SimBanditCheckpoint.new()
	ckpt.policy_id = "bandit-v5-smoke"
	ckpt.reward_mode = BanditRunAI.REWARD_V5
	var sim := RunMatchSimulator.new()
	sim.configure(null, null, null, null, null, null, ckpt, true)
	sim.direct_pick = true
	var record: Dictionary = {}
	for seed in range(2):
		record = sim.simulate_run(9100 + seed)
	var picks: Array = record.get("recruit_picks", [])
	if picks.is_empty() or not bool(record.get("direct_pick", false)):
		push_error("BanditSmoke: direct-pick run must log recruit_picks")
		return false
	var counts: Dictionary = {}
	for p in picks:
		var uid := str((p as Dictionary).get("unit_id", ""))
		counts[uid] = int(counts.get(uid, 0)) + 1
		if int(counts[uid]) > RecruitSession.COPIES_PER_CHARACTER:
			push_error("BanditSmoke: direct-pick exceeded copies for %s" % uid)
			return false
	if sim.get_bandit_update_count() <= 0:
		push_error("BanditSmoke: v5 direct-pick expected bandit updates > 0")
		return false
	print("SimBanditSmoke: direct-pick v5 OK picks=%d outcome=%s" % [picks.size(), record.get("outcome")])
	return true
