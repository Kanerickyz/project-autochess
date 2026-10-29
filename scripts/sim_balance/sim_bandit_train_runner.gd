extends SceneTree

const DEFAULT_TRAIN_RUNS := 400
const DEFAULT_SEED_START := 1
const DEFAULT_EXPLORE_RATIO := 0.6
const DEFAULT_CHECKPOINT_OUT_V1 := "res://resources/sim_balance/checkpoints/bandit_v1.tres"
const DEFAULT_CHECKPOINT_OUT_V2 := "res://resources/sim_balance/checkpoints/bandit_v2.tres"
const DEFAULT_CHECKPOINT_OUT_V4 := "res://resources/sim_balance/checkpoints/bandit_v4.tres"
const DEFAULT_PROFILE := preload("res://resources/sim_balance/default_ai_profile.tres")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	var train_runs := DEFAULT_TRAIN_RUNS
	var seed_start := DEFAULT_SEED_START
	var checkpoint_in := ""
	var reward_mode := BanditRunAI.REWARD_V1
	var checkpoint_out := DEFAULT_CHECKPOINT_OUT_V1
	var explore_ratio := DEFAULT_EXPLORE_RATIO
	var unlimited_recruit_gold := false
	var direct_pool_recruit := false
	for i in args.size():
		var a := args[i]
		if a == "--train-runs" and i + 1 < args.size():
			train_runs = maxi(1, int(args[i + 1]))
		elif a == "--seed-start" and i + 1 < args.size():
			seed_start = int(args[i + 1])
		elif a == "--checkpoint-in" and i + 1 < args.size():
			checkpoint_in = args[i + 1]
		elif a == "--checkpoint-out" and i + 1 < args.size():
			checkpoint_out = args[i + 1]
		elif a == "--reward-mode" and i + 1 < args.size():
			reward_mode = str(args[i + 1])
		elif a == "--explore-ratio" and i + 1 < args.size():
			explore_ratio = clampf(float(args[i + 1]), 0.0, 1.0)
		elif a == "--unlimited-recruit-gold":
			unlimited_recruit_gold = true
		elif a == "--direct-pool-recruit":
			direct_pool_recruit = true

	if reward_mode == BanditRunAI.REWARD_V2 and checkpoint_out == DEFAULT_CHECKPOINT_OUT_V1:
		checkpoint_out = DEFAULT_CHECKPOINT_OUT_V2
	elif reward_mode == BanditRunAI.REWARD_V4 and checkpoint_out == DEFAULT_CHECKPOINT_OUT_V1:
		checkpoint_out = DEFAULT_CHECKPOINT_OUT_V4

	var checkpoint: SimBanditCheckpoint
	if not checkpoint_in.is_empty() and ResourceLoader.exists(checkpoint_in):
		var loaded := load(checkpoint_in) as SimBanditCheckpoint
		if loaded != null:
			checkpoint = loaded.duplicate(true) as SimBanditCheckpoint
	if checkpoint == null:
		checkpoint = SimBanditCheckpoint.new()
	checkpoint.reward_mode = reward_mode
	checkpoint.policy_id = _policy_id_for_mode(reward_mode)
	checkpoint.schema_version = SimBanditCheckpoint.SCHEMA_VERSION

	var profile := DEFAULT_PROFILE.duplicate(true) as SimAIProfile
	profile.direct_pool_recruit = direct_pool_recruit

	var sim := RunMatchSimulator.new()
	sim.unlimited_recruit_gold = unlimited_recruit_gold
	sim.configure(null, null, null, null, profile, null, checkpoint, true)

	var explore_until := int(float(train_runs) * explore_ratio)
	var t0 := Time.get_ticks_msec()
	for n in train_runs:
		sim.set_bandit_explore_enabled(n < explore_until)
		sim.simulate_run(seed_start + n)
		if (n + 1) % 50 == 0 or n + 1 == train_runs:
			print("SimBanditTrain: %d / %d episodes" % [n + 1, train_runs])

	var saved := sim.export_bandit_checkpoint()
	saved.policy_id = _policy_id_for_mode(reward_mode)
	saved.reward_mode = reward_mode
	var err := ResourceSaver.save(saved, checkpoint_out)
	if err != OK:
		push_error("SimBanditTrain: save failed %s err=%s" % [checkpoint_out, err])
		quit(1)
		return
	var updates := sim.get_bandit_update_count()
	var cov: Dictionary = sim.get_bandit_coverage_summary()
	print(
		(
			"SimBanditTrain: saved policy_id=%s reward_mode=%s unlimited_gold=%s direct_pool=%s path=%s "
			+ "bandit_updates=%d keys=%d median_wl=%d pct_keys_ge5=%.1f elapsed_ms=%d"
		)
		% [
			saved.policy_id,
			saved.reward_mode,
			str(unlimited_recruit_gold),
			str(direct_pool_recruit),
			checkpoint_out,
			updates,
			int(cov.get("keys", 0)),
			int(cov.get("median_wl", 0)),
			float(cov.get("pct_keys_ge5", 0.0)),
			Time.get_ticks_msec() - t0,
		]
	)
	quit(0)


func _policy_id_for_mode(mode: String) -> String:
	match mode:
		BanditRunAI.REWARD_V4:
			return "bandit-v4"
		BanditRunAI.REWARD_V2:
			return "bandit-v2"
		_:
			return "bandit-v1"
