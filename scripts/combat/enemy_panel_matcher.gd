class_name EnemyPanelMatcher
extends RefCounted
## 敌方面板跟队：名单与星级锁死后，按队均展示攻/血缩放本场实例。
## Boss 节点与首领标记单位跳过。不改 .tres 底模、不回写抽阵 U。


## 对已生成的敌方 UnitInstance 就地缩放攻血。返回是否执行了缩放。
static func apply_to_units(
	units: Array,
	team_entries: Array,
	floor_index: int,
	node_type: MapNodeType.Type,
	config: SpawnBudgetConfig,
) -> bool:
	if config == null or not config.panel_match_enabled:
		return false
	if node_type == MapNodeType.Type.BOSS:
		return false
	var targets: Array[UnitInstance] = []
	for item in units:
		var unit: UnitInstance = null
		if item is UnitInstance:
			unit = item as UnitInstance
		elif item is Dictionary:
			unit = (item as Dictionary).get("unit") as UnitInstance
		if unit == null or unit.stats == null:
			continue
		if unit.is_boss_leader():
			continue
		targets.append(unit)
	if targets.is_empty():
		return false

	var avg := team_average_display_stats(team_entries)
	var mult := config.get_panel_mult(node_type)
	var floor_atk := config.get_panel_atk_floor(floor_index)
	var floor_hp := config.get_panel_hp_floor(floor_index)
	var target_atk := maxf(avg.x * mult, floor_atk)
	var target_hp := maxf(avg.y * mult, floor_hp)

	var sum_atk := 0.0
	var sum_hp := 0.0
	for unit in targets:
		sum_atk += float(maxi(1, unit.stats.attack))
		sum_hp += float(maxi(1, unit.stats.max_hp))
	var mean_atk := sum_atk / float(targets.size())
	var mean_hp := sum_hp / float(targets.size())
	var factor_atk := target_atk / maxf(1.0, mean_atk)
	var factor_hp := target_hp / maxf(1.0, mean_hp)

	var flat_atk := config.get_floor_flat_atk_bonus(floor_index)
	var flat_hp := config.get_floor_flat_hp_bonus(floor_index)
	for unit in targets:
		unit.stats.attack = maxi(1, int(round(float(unit.stats.attack) * factor_atk)) + flat_atk)
		unit.stats.max_hp = maxi(1, int(round(float(unit.stats.max_hp) * factor_hp)) + flat_hp)
		unit.current_hp = unit.stats.max_hp
	return true


## 返回 Vector2(队均展示攻击, 队均展示生命)；空队为 (0, 0)。
static func team_average_display_stats(team_entries: Array) -> Vector2:
	var sum_atk := 0.0
	var sum_hp := 0.0
	var n := 0
	for entry in team_entries:
		if not (entry is DeckEntry):
			continue
		var de := entry as DeckEntry
		if de.unit == null or de.unit.stats == null:
			continue
		sum_atk += float(DeckUpgradeService.get_display_attack(de))
		sum_hp += float(DeckUpgradeService.get_display_max_hp(de))
		n += 1
	if n <= 0:
		return Vector2.ZERO
	return Vector2(sum_atk / float(n), sum_hp / float(n))
