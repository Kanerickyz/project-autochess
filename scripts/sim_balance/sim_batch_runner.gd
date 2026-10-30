extends SceneTree

const DEFAULT_RUNS := 100
const DEFAULT_SEED_START := 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	var runs := DEFAULT_RUNS
	var seed_start := DEFAULT_SEED_START
	var out_dir := SimMetricsWriter.DEFAULT_OUT_DIR
	var checkpoint_path := ""
	var direct_pick := false
	for i in args.size():
		var a := args[i]
		if a == "--runs" and i + 1 < args.size():
			runs = maxi(1, int(args[i + 1]))
		elif a == "--seed-start" and i + 1 < args.size():
			seed_start = int(args[i + 1])
		elif a == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
		elif a == "--checkpoint" and i + 1 < args.size():
			checkpoint_path = args[i + 1]
		elif a == "--direct-pick":
			direct_pick = true

	var checkpoint: SimBanditCheckpoint = null
	if not checkpoint_path.is_empty() and ResourceLoader.exists(checkpoint_path):
		checkpoint = load(checkpoint_path) as SimBanditCheckpoint

	var sim := RunMatchSimulator.new()
	if checkpoint != null:
		sim.configure(null, null, null, null, null, null, checkpoint, false)
	else:
		sim.configure()
	sim.direct_pick = direct_pick
	var batch: Array = []
	var t0 := Time.get_ticks_msec()
	for n in runs:
		var seed_val := seed_start + n
		var record: Dictionary = sim.simulate_run(seed_val)
		batch.append(record)
		if (n + 1) % 10 == 0 or n + 1 == runs:
			print("SimBatchRunner: %d / %d runs" % [n + 1, runs])
	var elapsed_ms := Time.get_ticks_msec() - t0
	var summary := SimMetricsWriter.write_batch(
		out_dir,
		batch,
		{
			"runs_requested": runs,
			"seed_start": seed_start,
			"elapsed_ms": elapsed_ms,
			"direct_pick": direct_pick,
			"checkpoint": checkpoint_path,
			"generated_at_utc": Time.get_datetime_string_from_system(true),
		},
	)
	print(
		"SimBatchRunner: done runs=%d complete_rate=%.3f death_mode_floor=%s out=%s"
		% [
			summary.get("run_count", 0),
			float(summary.get("run_complete_rate", 0.0)),
			str(summary.get("death_floor_mode", 0)),
			out_dir,
		]
	)
	quit(0)
