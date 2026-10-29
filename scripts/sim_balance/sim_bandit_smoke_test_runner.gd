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
	print("SimBanditSmoke: OK updates=%d eval_outcome=%s" % [updates, record.get("outcome")])
	quit(0)
