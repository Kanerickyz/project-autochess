extends Control
## 主菜单「附魔试验场」：全招募池入队，可滚动半场 + 拖拽熔炉。

const MAIN_MENU_PATH := "res://scenes/main/main_menu.tscn"
const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const RECRUIT_CONFIG_PATH := "res://resources/recruit/default_recruit_config.tres"
const LEVEL_PATH := "res://resources/levels/board_act1.tres"

@onready var _battle_host: Control = %BattleHost
@onready var _back_button: Button = %BackButton

var _battle: RealtimeBattleController
var _leaving: bool = false


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_spawn_battle()
	call_deferred("_start_sandbox")


func _spawn_battle() -> void:
	_battle = BATTLE_SCENE.instantiate() as RealtimeBattleController
	_battle.recruit_enter_seconds = 0.0
	_battle_host.add_child(_battle)
	var session := _battle.get_enchant_session()
	if not session.session_finished.is_connected(_on_enchant_session_finished):
		session.session_finished.connect(_on_enchant_session_finished)


func _build_deck() -> DeckState:
	var recruit := load(RECRUIT_CONFIG_PATH) as RecruitConfig
	var pool: Array = recruit.get_unit_pool() if recruit != null else []
	var deck_cfg := DeckConfig.new()
	deck_cfg.max_size = maxi(pool.size(), 8)
	deck_cfg.starting_units = []
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	for unit in pool:
		if unit is UnitData:
			deck.add_entry(unit as UnitData)
	return deck


func _start_sandbox() -> void:
	if _battle == null:
		return
	var deck := _build_deck()
	var economy := RunEconomy.new()
	var level := load(LEVEL_PATH) as LevelData
	_battle.setup(deck, economy, level)
	await _battle.enter_enchant(0.0, true)


func _on_enchant_session_finished(did_fuse: bool) -> void:
	if _leaving or _battle == null:
		return
	if not did_fuse:
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
		return
	await get_tree().process_frame
	await _battle.enter_enchant(0.0, true)


func _on_back_pressed() -> void:
	_leaving = true
	if _battle != null and _battle.get_phase() == RealtimeBattleController.Phase.ENCHANT:
		_battle.exit_enchant()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
