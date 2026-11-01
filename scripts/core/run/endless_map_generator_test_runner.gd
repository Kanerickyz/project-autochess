extends SceneTree


func _initialize() -> void:
	var ok := EndlessMapGeneratorTest.run_all()
	ok = _test_spawn_budget_extrapolation() and ok
	ok = _test_panel_floors_rise_with_f() and ok
	ok = _test_forward_tier_unlock() and ok
	ok = _test_endless_ladder_knobs() and ok
	ok = _test_endless_map_product_config() and ok
	quit(0 if ok else 1)


func _test_spawn_budget_extrapolation() -> bool:
	var cfg := SpawnBudgetConfig.new()
	cfg.floor_mid_power = [0.0, 40.0, 54.0, 68.0]
	cfg.floor_e_min = [10.0, 20.0, 30.0, 40.0]
	cfg.floor_e_max = [50.0, 60.0, 70.0, 80.0]
	cfg.p_mid_floor_growth = 0.12
	var mid3 := cfg.get_p_mid(3)
	var mid10 := cfg.get_p_mid(10)
	if mid10 <= mid3:
		push_error("SpawnBudget extrapolation: p_mid(10)=%s should exceed p_mid(3)=%s" % [mid10, mid3])
		return false
	var emin3 := cfg.get_floor_e_min(3)
	var emin15 := cfg.get_floor_e_min(15)
	if emin15 <= emin3:
		push_error("SpawnBudget extrapolation: e_min should grow past table end")
		return false
	print("SpawnBudget extrapolation: p_mid 3=%.1f 10=%.1f e_min 3=%.1f 15=%.1f" % [mid3, mid10, emin3, emin15])
	return true


func _test_panel_floors_rise_with_f() -> bool:
	## 主塔默认：层向面板下限随 F 升（无尽关闭此项，改走阶梯公式）。
	var cfg := SpawnBudgetConfig.load_or_default()
	var atk5 := cfg.get_panel_atk_floor(5)
	var atk15 := cfg.get_panel_atk_floor(15)
	var hp5 := cfg.get_panel_hp_floor(5)
	var hp15 := cfg.get_panel_hp_floor(15)
	if atk15 <= atk5 or hp15 <= hp5:
		push_error(
			"Panel floors: F15 atk/hp (%.1f/%.1f) should exceed F5 (%.1f/%.1f)"
			% [atk15, hp15, atk5, hp5]
		)
		return false
	var threat5 := 1.0 + cfg.floor_threat_growth * 4.0
	var threat15 := 1.0 + cfg.floor_threat_growth * 14.0
	if threat15 <= threat5:
		push_error("floor_threat_growth should raise E multiplier with F")
		return false
	print(
		"Panel/threat F5 atk=%.1f hp=%.1f thr=%.2f | F15 atk=%.1f hp=%.1f thr=%.2f"
		% [atk5, hp5, threat5, atk15, hp15, threat15]
	)
	return true


func _test_forward_tier_unlock() -> bool:
	if TierUnlock.get_max_unlocked_tier(9, 30, true) != 2:
		push_error("forward tier: F9 should be T2")
		return false
	if TierUnlock.get_max_unlocked_tier(10, 30, true) != 3:
		push_error("forward tier: F10 should be T3")
		return false
	## 主塔倒数逻辑：floor_count=30 → late at 25；forward 不受软顶拖累。
	if TierUnlock.get_max_unlocked_tier(15, 30, false) != 2:
		push_error("tower late-band: F15/30 should still be T2")
		return false
	print("Forward tier unlock OK")
	return true


func _test_endless_ladder_knobs() -> bool:
	if EndlessLadderBalance.enemy_count_for_floor(1) != 1:
		push_error("ladder F1 count should be 1")
		return false
	if EndlessLadderBalance.enemy_count_for_floor(10) != 10:
		push_error("ladder F10 count should be 10")
		return false
	if EndlessLadderBalance.enemy_count_for_floor(11) != 10:
		push_error("ladder F11 count should cap at 10")
		return false
	if EndlessLadderBalance.stat_for_floor(11) != 12:
		push_error("ladder F11 stat should be 12")
		return false
	if EndlessLadderBalance.stat_for_floor(15) != 20:
		push_error("ladder F15 stat should be 20")
		return false
	if EndlessLadderBalance.stat_for_floor(20) != 30:
		push_error("ladder F20 stat should be 30")
		return false
	if EndlessLadderBalance.UNIT_ID != "enemy_endless_dev":
		push_error("ladder unit id mismatch")
		return false
	print(
		"Endless ladder: F1=%d@%d F10=%d@%d F11=%d@%d"
		% [
			EndlessLadderBalance.enemy_count_for_floor(1),
			EndlessLadderBalance.stat_for_floor(1),
			EndlessLadderBalance.enemy_count_for_floor(10),
			EndlessLadderBalance.stat_for_floor(10),
			EndlessLadderBalance.enemy_count_for_floor(11),
			EndlessLadderBalance.stat_for_floor(11),
		]
	)
	return true


func _test_endless_map_product_config() -> bool:
	## 用文本断言产品节拍，避免依赖 board/enemy 贴图导入链才能 load().
	const PATH := "res://resources/runs/endless_map.tres"
	if not FileAccess.file_exists(PATH):
		push_error("missing endless_map.tres")
		return false
	var text := FileAccess.get_file_as_string(PATH)
	if text.find("endless_mode = true") < 0:
		push_error("endless_map.tres must set endless_mode = true")
		return false
	if text.find("pure_combat_floors = 0") < 0:
		push_error("endless_map pure_combat_floors should be 0")
		return false
	if text.find("shop_every_n_combats = 4") < 0:
		push_error("endless_map shop_every_n_combats should be 4")
		return false
	if text.find("spawn_budget_override") >= 0:
		push_error("endless_map should not set spawn_budget_override")
		return false
	print("Endless map product config: pure=0 every=4 no budget override")
	return true
