extends Control
## 实时战斗演示：独立构造牌库/经济/关卡，循环打 resources/encounters/realtime/ 下的遇敌。
## 命令行用户参数（`--` 之后）：
##   --autoplay   自动投放前 3 张手牌、开战并在战斗中补人，结算后自动继续
##   --once       autoplay 下打完一场即退出（退出码 0）
##   --speed=X    战斗推进倍速（默认 1）
##   --seed=N     固定种子

const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const ECONOMY_PATH := "res://resources/economy/default_economy.tres"
const ENCOUNTER_PATHS: PackedStringArray = [
	"res://resources/encounters/realtime/rt_combat_01.tres",
	"res://resources/encounters/realtime/rt_combat_02.tres",
	"res://resources/encounters/realtime/rt_combat_03.tres",
	"res://resources/encounters/realtime/rt_elite_01.tres",
	"res://resources/encounters/realtime/rt_combat_04.tres",
	"res://resources/encounters/realtime/rt_combat_05.tres",
	"res://resources/encounters/realtime/rt_boss_01.tres",
]
const AUTO_DEPLOY_INTERVAL := 0.6
const AUTO_CONTINUE_DELAY := 1.5

var _deck := DeckState.new()
var _economy := RunEconomy.new()
var _level: LevelData
var _encounters: Array[EncounterData] = []
var _encounter_index: int = 0
var _autoplay: bool = false
var _autoplay_once: bool = false
var _auto_timer: float = 0.0
var _auto_rng := RandomNumberGenerator.new()

@onready var _battle: RealtimeBattleController = $RealtimeBattle


func _ready() -> void:
	_parse_args()
	_deck.configure(_load_deck_config())
	_deck.reset_from_config()
	var economy_config: EconomyConfig = null
	if ResourceLoader.exists(ECONOMY_PATH):
		economy_config = load(ECONOMY_PATH) as EconomyConfig
	_economy.configure(economy_config if economy_config != null else EconomyConfig.new())
	_economy.reset()
	_level = _load_level()
	_encounters = _load_encounters()
	_battle.setup(_deck, _economy, _level)
	_battle.encounter_completed.connect(_on_encounter_completed)
	_battle.combat_resolved.connect(_on_combat_resolved)
	_start_next.call_deferred()


func _process(delta: float) -> void:
	if not _autoplay:
		return
	_auto_timer -= delta
	if _auto_timer > 0.0:
		return
	match _battle.get_phase():
		RealtimeBattleController.Phase.PREPARE:
			_auto_prepare()
		RealtimeBattleController.Phase.COMBAT:
			_auto_timer = AUTO_DEPLOY_INTERVAL
			_auto_reinforce()
		RealtimeBattleController.Phase.RESULT:
			if _autoplay_once:
				get_tree().quit(0)
				return
			_battle.continue_after_result()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			_autoplay = true
		elif arg == "--once":
			_autoplay_once = true
		elif arg.begins_with("--speed="):
			_battle.time_scale = clampf(arg.trim_prefix("--speed=").to_float(), 0.25, 8.0)
		elif arg.begins_with("--seed="):
			_battle.rng_seed = arg.trim_prefix("--seed=").to_int()
	_auto_rng.seed = _battle.rng_seed if _battle.rng_seed != 0 else 12345


func _start_next() -> void:
	var encounter := _encounters[_encounter_index % _encounters.size()]
	var tier_index := _encounter_index
	_encounter_index += 1
	_battle.start_encounter(encounter, tier_index)
	_auto_timer = 0.5


func _on_combat_resolved(won: bool) -> void:
	print("RealtimeBattleDemo: result won=%s gold=%d" % [won, _economy.gold])
	_auto_timer = AUTO_CONTINUE_DELAY


func _on_encounter_completed(_won: bool) -> void:
	_start_next.call_deferred()


func _auto_prepare() -> void:
	var size := _battle.get_board_size()
	var row := size.y - 6
	var columns: Array[int] = [int(size.x * 0.25), int(size.x * 0.5), int(size.x * 0.75)]
	var hand := _battle.get_hand()
	for i in mini(3, hand.size()):
		_battle.try_deploy(hand[i].entry_id, Vector2i(columns[i], row))
	if not _battle.try_start_combat():
		push_warning("RealtimeBattleDemo: autoplay could not start combat")
	_auto_timer = AUTO_DEPLOY_INTERVAL


func _auto_reinforce() -> void:
	if _battle.get_player_unit_count() >= _battle.get_max_board_units():
		return
	var size := _battle.get_board_size()
	var mid := BoardHalf.midline_row(size.y)
	for entry in _battle.get_hand():
		if _battle.is_entry_on_field(entry.entry_id):
			continue
		var cell := Vector2i(_auto_rng.randi_range(1, size.x - 2), _auto_rng.randi_range(mid + 3, size.y - 2))
		if _battle.try_deploy(entry.entry_id, cell).is_empty():
			return


func _load_deck_config() -> DeckConfig:
	if ResourceLoader.exists(DECK_PATH):
		var config := load(DECK_PATH) as DeckConfig
		if config != null:
			return config
	push_warning("RealtimeBattleDemo: %s missing, using fallback deck" % DECK_PATH)
	var fallback := DeckConfig.new()
	fallback.starting_units = _fallback_units()
	fallback.max_board_units = 5
	fallback.draw_count = 5
	return fallback


func _load_level() -> LevelData:
	if ResourceLoader.exists(LEVEL_PATH):
		var level := load(LEVEL_PATH) as LevelData
		if level != null:
			return level
	push_warning("RealtimeBattleDemo: %s missing, using fallback 18x32 level" % LEVEL_PATH)
	var fallback := LevelData.new()
	fallback.board_width = 18
	fallback.board_height = 32
	fallback.enemy_pool = _fallback_units()
	return fallback


func _load_encounters() -> Array[EncounterData]:
	var result: Array[EncounterData] = []
	for path in ENCOUNTER_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var encounter := load(path) as EncounterData
		if encounter != null and encounter.wave != null:
			result.append(encounter)
	if result.is_empty():
		push_warning("RealtimeBattleDemo: no realtime encounters found, using fallback")
		var wave := WaveData.new()
		wave.spawn_count = 3
		var encounter := EncounterData.new()
		encounter.id = "rt_demo_fallback"
		encounter.display_name = "演示遭遇"
		encounter.wave = wave
		result.append(encounter)
	return result


static func _fallback_units() -> Array[UnitData]:
	## 仅在牌库/关卡资源缺失时使用；命名对齐 Content 基础兵种。
	var units: Array[UnitData] = []
	units.append(_make_unit("demo_shield", "盾兵", 600, 70, 1.0, 0.5, 0.0, 0.0, 0.7, 0.9, 1.15))
	units.append(_make_unit("demo_archer", "弓箭手", 250, 60, 1.0, 5.0, 10.0, 0.0, 0.5, 0.55, 0.7))
	units.append(_make_unit("demo_flail", "链枷兵", 800, 90, 1.0, 0.5, 0.0, 1.0, 0.7, 0.9, 1.15))
	units.append(_make_unit("demo_light", "轻步兵", 160, 50, 2.0, 0.5, 0.0, 0.0, 0.5, 0.55, 0.68))
	units.append(_make_unit("demo_rider", "骑士", 320, 155, 2.2, 0.6, 0.0, 0.0, 0.72, 0.95, 1.2))
	return units


static func _make_unit(
	id: String, display_name: String, hp: int, attack: int, speed: float,
	reach: float, projectile_speed: float, splash: float, radius: float,
	visual_half_width: float = 0.0, visual_half_height: float = 0.0,
) -> UnitData:
	var stats := UnitStats.new()
	stats.max_hp = hp
	stats.attack = attack
	stats.crit_rate_percent = 0
	stats.move_speed = speed
	stats.attack_reach = reach
	stats.projectile_speed = projectile_speed
	stats.splash_radius = splash
	stats.body_radius = radius
	stats.visual_half_width = visual_half_width
	stats.visual_half_height = visual_half_height
	var data := UnitData.new()
	data.id = id
	data.display_name = display_name
	data.tier = 1
	data.stats = stats
	return data
