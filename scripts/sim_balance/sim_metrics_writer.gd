class_name SimMetricsWriter
extends RefCounted

const DEFAULT_OUT_DIR := "/workspace/.artifacts/sim_balance/latest"


static func write_batch(output_dir: String, runs: Array, meta: Dictionary = {}) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var all_encounters: Array = []
	for run in runs:
		if typeof(run) != TYPE_DICTIONARY:
			continue
		var seed_val: int = int(run.get("seed", 0))
		for enc in run.get("encounters", []):
			if typeof(enc) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = enc.duplicate()
			row["seed"] = seed_val
			all_encounters.append(row)

	var summary := aggregate(runs, all_encounters, meta)
	_write_json("%s/runs.json" % output_dir, runs)
	_write_json("%s/encounters.json" % output_dir, all_encounters)
	_write_json("%s/summary.json" % output_dir, summary)
	return summary


static func aggregate(runs: Array, encounters: Array, meta: Dictionary = {}) -> Dictionary:
	var by_floor: Dictionary = {}
	for enc in encounters:
		if typeof(enc) != TYPE_DICTIONARY:
			continue
		var floor_key := str(int(enc.get("floor", 0)))
		if not by_floor.has(floor_key):
			by_floor[floor_key] = {"floor": int(enc.get("floor", 0)), "attempts": 0, "wins": 0}
		var bucket: Dictionary = by_floor[floor_key]
		bucket["attempts"] = int(bucket["attempts"]) + 1
		if bool(enc.get("won", false)):
			bucket["wins"] = int(bucket["wins"]) + 1

	var floor_stats: Array = []
	for key in by_floor.keys():
		var b: Dictionary = by_floor[key]
		var attempts := int(b.get("attempts", 0))
		var wins := int(b.get("wins", 0))
		b["win_rate"] = float(wins) / float(maxi(1, attempts))
		floor_stats.append(b)
	floor_stats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("floor", 0)) < int(b.get("floor", 0))
	)

	var death_hist: Dictionary = {}
	var run_complete := 0
	for run in runs:
		if typeof(run) != TYPE_DICTIONARY:
			continue
		if str(run.get("outcome", "")) == "RUN_COMPLETE":
			run_complete += 1
		if str(run.get("outcome", "")) != "RUN_DEFEAT":
			continue
		var df := str(int(run.get("death_floor", 0)))
		death_hist[df] = int(death_hist.get(df, 0)) + 1

	var mode_floor := 0
	var mode_count := 0
	for k in death_hist.keys():
		var c := int(death_hist[k])
		if c > mode_count:
			mode_count = c
			mode_floor = int(k)

	var out := {
		"meta": meta,
		"run_count": runs.size(),
		"run_complete_count": run_complete,
		"run_complete_rate": float(run_complete) / float(maxi(1, runs.size())),
		"encounter_count": encounters.size(),
		"by_floor": floor_stats,
		"death_floor_histogram": death_hist,
		"death_floor_mode": mode_floor,
		"death_floor_mode_count": mode_count,
	}
	return out


static func _write_json(path: String, data: Variant) -> void:
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SimMetricsWriter: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()
