class_name SimMetricsWriter
extends RefCounted

const DEFAULT_OUT_DIR := "/workspace/.artifacts/sim_balance/latest"
## summary.json 图表块格式；报告页与下游工具按此解析。
const REPORT_SCHEMA_VERSION := "1.0"


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

	var enriched_meta := enrich_meta(meta, runs)
	var summary := aggregate(runs, all_encounters, enriched_meta)
	_write_json("%s/runs.json" % output_dir, runs)
	_write_json("%s/encounters.json" % output_dir, all_encounters)
	_write_json("%s/summary.json" % output_dir, summary)
	return summary


static func enrich_meta(meta: Dictionary, runs: Array) -> Dictionary:
	var out := meta.duplicate()
	out["report_schema_version"] = REPORT_SCHEMA_VERSION
	out["game_version"] = read_game_version()
	out["ai_profile_id"] = _infer_profile_id(runs)
	if not out.has("generated_at_utc"):
		out["generated_at_utc"] = Time.get_datetime_string_from_system(true)
	return out


static func read_game_version() -> String:
	var v: Variant = ProjectSettings.get_setting("application/config/version", "")
	if v == null:
		return "unknown"
	var s := str(v).strip_edges()
	return s if not s.is_empty() else "unknown"


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
		b["loss_rate"] = 1.0 - float(b["win_rate"])
		floor_stats.append(b)
	floor_stats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("floor", 0)) < int(b.get("floor", 0))
	)

	var death_hist: Dictionary = {}
	var run_complete := 0
	var reached_f12 := 0
	for run in runs:
		if typeof(run) != TYPE_DICTIONARY:
			continue
		if str(run.get("outcome", "")) == "RUN_COMPLETE":
			run_complete += 1
		if str(run.get("outcome", "")) == "RUN_COMPLETE" or int(run.get("death_floor", 0)) >= 12:
			reached_f12 += 1
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

	var run_count := runs.size()
	var run_complete_rate := float(run_complete) / float(maxi(1, run_count))
	var game_version := str(meta.get("game_version", read_game_version()))

	var out := {
		"report_schema_version": REPORT_SCHEMA_VERSION,
		"game_version": game_version,
		"meta": meta,
		"run_count": run_count,
		"run_complete_count": run_complete,
		"run_complete_rate": run_complete_rate,
		"reached_f12_count": reached_f12,
		"encounter_count": encounters.size(),
		"by_floor": floor_stats,
		"death_floor_histogram": death_hist,
		"death_floor_mode": mode_floor,
		"death_floor_mode_count": mode_count,
		"kpis": _build_kpis(
			game_version, run_count, run_complete_rate, encounters.size(), mode_floor, mode_count, meta
		),
		"charts": _build_charts(floor_stats, death_hist, run_count, run_complete),
	}
	var lineups := _build_lineups(runs)
	if not lineups.is_empty():
		out["lineups"] = lineups
	return out


static func _reached_f12(run: Dictionary) -> bool:
	return str(run.get("outcome", "")) == "RUN_COMPLETE" or int(run.get("death_floor", 0)) >= 12


static func _lineup_sort(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("tier", 0)) != int(b.get("tier", 0)):
		return int(a.get("tier", 0)) > int(b.get("tier", 0))
	if int(a.get("level", 0)) != int(b.get("level", 0)):
		return int(a.get("level", 0)) > int(b.get("level", 0))
	return str(a.get("unit_id", "")) < str(b.get("unit_id", ""))


static func _lineup_member(e: Dictionary) -> Dictionary:
	return {
		"unit_id": str(e.get("unit_id", "")),
		"name": str(e.get("name", e.get("unit_id", ""))),
		"level": int(e.get("level", 1)),
		"tier": int(e.get("tier", 0)),
	}


## 直选池等带 final_roster 的批跑：每局最终上场/备战阵容 + 角色上场统计（按是否到达 F12 拆分）。
static func _build_lineups(runs: Array) -> Dictionary:
	var rows: Array = []
	var usage: Dictionary = {}
	var reached_runs := 0
	var other_runs := 0
	for run in runs:
		if typeof(run) != TYPE_DICTIONARY or not run.has("final_roster"):
			continue
		var reached := _reached_f12(run)
		if reached:
			reached_runs += 1
		else:
			other_runs += 1
		var seated: Array = []
		var bench: Array = []
		var seen_in_run: Dictionary = {}
		for e in run.get("final_roster", []):
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var m := _lineup_member(e)
			if bool(e.get("seated", false)):
				seated.append(m)
				var uid: String = m["unit_id"]
				if not usage.has(uid):
					usage[uid] = {
						"unit_id": uid,
						"name": m["name"],
						"tier": m["tier"],
						"copies_seated": 0,
						"level_sum": 0,
						"runs_reached_f12": 0,
						"runs_other": 0,
					}
				var u: Dictionary = usage[uid]
				u["copies_seated"] = int(u["copies_seated"]) + 1
				u["level_sum"] = int(u["level_sum"]) + int(m["level"])
				if not seen_in_run.has(uid):
					seen_in_run[uid] = true
					var key := "runs_reached_f12" if reached else "runs_other"
					u[key] = int(u[key]) + 1
			else:
				bench.append(m)
		seated.sort_custom(_lineup_sort)
		bench.sort_custom(_lineup_sort)
		rows.append({
			"seed": int(run.get("seed", 0)),
			"outcome": str(run.get("outcome", "")),
			"death_floor": int(run.get("death_floor", 0)),
			"reached_f12": reached,
			"seat_cap": int(run.get("final_seat_cap", seated.size())),
			"seated": seated,
			"bench": bench,
		})
	if rows.is_empty():
		return {}
	var unit_usage: Array = []
	for uid in usage.keys():
		var u: Dictionary = usage[uid]
		var copies := maxi(1, int(u["copies_seated"]))
		u["avg_level"] = float(u["level_sum"]) / float(copies)
		u.erase("level_sum")
		u["rate_reached_f12"] = float(u["runs_reached_f12"]) / float(maxi(1, reached_runs))
		u["rate_other"] = float(u["runs_other"]) / float(maxi(1, other_runs))
		unit_usage.append(u)
	unit_usage.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := int(a["runs_reached_f12"]) + int(a["runs_other"])
		var tb := int(b["runs_reached_f12"]) + int(b["runs_other"])
		if ta != tb:
			return ta > tb
		return str(a["unit_id"]) < str(b["unit_id"])
	)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := 99 if a["outcome"] == "RUN_COMPLETE" else int(a["death_floor"])
		var db := 99 if b["outcome"] == "RUN_COMPLETE" else int(b["death_floor"])
		if da != db:
			return da > db
		return int(a["seed"]) < int(b["seed"])
	)
	return {
		"description": "每局结束时（通关或阵亡时刻）的队伍快照；上场=已入座。角色统计按局去重计「上场局数」。",
		"runs_reached_f12": reached_runs,
		"runs_other": other_runs,
		"unit_usage": unit_usage,
		"runs": rows,
	}


static func _infer_profile_id(runs: Array) -> String:
	for run in runs:
		if typeof(run) != TYPE_DICTIONARY:
			continue
		var pid := str(run.get("profile_id", ""))
		if not pid.is_empty():
			return pid
	return "default"


static func _build_kpis(
	game_version: String,
	run_count: int,
	run_complete_rate: float,
	encounter_count: int,
	death_mode: int,
	death_mode_count: int,
	meta: Dictionary,
) -> Array:
	return [
		{"id": "game_version", "label": "游戏版本", "value": game_version, "format": "semver"},
		{"id": "run_count", "label": "模拟 Run 数", "value": run_count, "format": "integer"},
		{
			"id": "run_complete_rate",
			"label": "Boss 通关率",
			"value": run_complete_rate,
			"format": "percent",
		},
		{"id": "encounter_count", "label": "战斗遭遇次数", "value": encounter_count, "format": "integer"},
		{
			"id": "death_floor_mode",
			"label": "败局众数层",
			"value": death_mode,
			"format": "floor",
			"note": "%d 次" % death_mode_count if death_mode_count > 0 else "",
		},
		{
			"id": "ai_profile_id",
			"label": "Sim AI Profile",
			"value": str(meta.get("ai_profile_id", "default")),
			"format": "string",
		},
		{
			"id": "report_schema_version",
			"label": "报告 Schema",
			"value": REPORT_SCHEMA_VERSION,
			"format": "string",
		},
	]


static func _build_charts(
	floor_stats: Array,
	death_hist: Dictionary,
	run_count: int,
	run_complete: int,
) -> Array:
	var floor_labels: Array = []
	var win_rates: Array = []
	var loss_rates: Array = []
	var attempts_series: Array = []
	for row in floor_stats:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var f := int(row.get("floor", 0))
		floor_labels.append("F%d" % f)
		win_rates.append(roundf(float(row.get("win_rate", 0.0)) * 1000.0) / 10.0)
		loss_rates.append(roundf(float(row.get("loss_rate", 0.0)) * 1000.0) / 10.0)
		attempts_series.append(int(row.get("attempts", 0)))

	var death_labels: Array = []
	var death_values: Array = []
	var death_keys := death_hist.keys()
	death_keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in death_keys:
		death_labels.append("F%s" % str(k))
		death_values.append(int(death_hist[k]))

	var run_defeat := run_count - run_complete

	return [
		{
			"id": "encounter_win_rate_by_floor",
			"title": "按地图层 · 遭遇胜率",
			"chart_type": "bar",
			"x_label": "地图层号",
			"y_label": "胜率 (%)",
			"description": "该层所有战斗节点（COMBAT/ELITE/BOSS）尝试中 won=true 的占比。",
			"labels": floor_labels,
			"datasets": [
				{"series_id": "win_rate_pct", "label": "遭遇胜率 %", "values": win_rates},
			],
		},
		{
			"id": "encounter_loss_rate_by_floor",
			"title": "按地图层 · 遭遇失败率",
			"chart_type": "line",
			"x_label": "地图层号",
			"y_label": "失败率 (%)",
			"description": "1 − 遭遇胜率；用于观察难度爬升曲线。",
			"labels": floor_labels,
			"datasets": [
				{"series_id": "loss_rate_pct", "label": "遭遇失败率 %", "values": loss_rates},
			],
		},
		{
			"id": "encounter_attempts_by_floor",
			"title": "按地图层 · 遭遇样本量",
			"chart_type": "bar",
			"x_label": "地图层号",
			"y_label": "尝试次数",
			"description": "该层被模拟打到的战斗节点总次数（多 Run 累计）。",
			"labels": floor_labels,
			"datasets": [
				{"series_id": "attempts", "label": "尝试次数", "values": attempts_series},
			],
		},
		{
			"id": "death_floor_histogram",
			"title": "败局 · 死亡地图层分布",
			"chart_type": "bar",
			"x_label": "死亡时地图层号",
			"y_label": "Run 次数",
			"description": "整局失败（RUN_DEFEAT）时 defeat_reached_floor 的直方图。",
			"labels": death_labels,
			"datasets": [
				{"series_id": "defeat_runs", "label": "败局 Run 数", "values": death_values},
			],
		},
		{
			"id": "run_outcome",
			"title": "Run 结局分布",
			"chart_type": "doughnut",
			"x_label": "结局",
			"y_label": "Run 数",
			"description": "Boss 通关（RUN_COMPLETE）与中途失败（RUN_DEFEAT）占比。",
			"labels": ["通关", "失败"],
			"datasets": [
				{
					"series_id": "outcomes",
					"label": "Run 数",
					"values": [run_complete, run_defeat],
				},
			],
		},
	]


static func _write_json(path: String, data: Variant) -> void:
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SimMetricsWriter: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()
