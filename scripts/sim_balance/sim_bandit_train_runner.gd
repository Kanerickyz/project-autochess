extends SceneTree

const DEFAULT_TRAIN_RUNS := 400
const DEFAULT_SEED_START := 1
const DEFAULT_CHECKPOINT_OUT := "res://resources/sim_balance/checkpoints/bandit_v1.tres"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	var train_runs := DEFAULT_TRAIN_RUNS
	var seed_start := DEFAULT_SEED_START
	var checkpoint_in := ""
	var checkpoint_out := DEFAULT_CHECKPOINT_OUT
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

	var checkpoint: SimBanditCheckpoint
	if not checkpoint_in.is_empty() and ResourceLoader.exists(checkpoint_in):
		checkpoint = load(checkpoint_in) as SimBanditCheckpoint
	if checkpoint == null:
		checkpoint = SimBanditCheckpoint.new()

	var sim := RunMatchSimulator.new()
	sim.configure(null, null, null, null, null, null, checkpoint, true)

	var t0 := Time.get_ticks_msec()
	for n in train_runs:
		sim.simulate_run(seed_start + n)
		if (n + 1) % 50 == 0 or n + 1 == train_runs:
			print("SimBanditTrain: %d / %d episodes" % [n + 1, train_runs])

	var saved := sim.export_bandit_checkpoint()
	saved.policy_id = checkpoint.policy_id
	var err := ResourceSaver.save(saved, checkpoint_out)
	if err != OK:
		push_error("SimBanditTrain: save failed %s err=%s" % [checkpoint_out, err])
		quit(1)
		return
	var updates := sim.get_bandit_update_count()
	print(
		"SimBanditTrain: saved policy_id=%s path=%s bandit_updates=%d elapsed_ms=%d"
		% [saved.policy_id, checkpoint_out, updates, Time.get_ticks_msec() - t0]
	)
	quit(0)
