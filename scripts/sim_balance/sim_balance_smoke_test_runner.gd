extends SceneTree


func _initialize() -> void:
	var ok := true
	var sim := RunMatchSimulator.new()
	sim.configure()
	var record: Dictionary = sim.simulate_run(42)
	if record.is_empty():
		push_error("SimBalanceSmoke: empty run record")
		ok = false
	var enc: Array = record.get("encounters", [])
	if enc.is_empty() and str(record.get("outcome", "")) == "RUN_COMPLETE":
		push_error("SimBalanceSmoke: completed run with no encounters")
		ok = false
	var tmp_dir := "/workspace/.artifacts/sim_balance/smoke"
	var summary := SimMetricsWriter.write_batch(tmp_dir, [record], {"smoke": true})
	if summary.get("encounter_count", 0) <= 0:
		push_error("SimBalanceSmoke: summary missing encounters")
		ok = false
	if not summary.has("charts") or (summary.get("charts") as Array).size() < 5:
		push_error("SimBalanceSmoke: summary.charts incomplete")
		ok = false
	if str(summary.get("game_version", "")).is_empty() or summary.get("game_version") == "unknown":
		push_warning("SimBalanceSmoke: game_version missing (import project?)")
	if ok:
		print("SimBalanceSmoke: OK outcome=%s encounters=%d" % [record.get("outcome"), enc.size()])
	quit(0 if ok else 1)
