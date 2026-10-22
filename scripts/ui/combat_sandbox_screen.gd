extends Control
## 主菜单「沙盒」：粘贴阵容/布局、开战观战（含录音机）；无远征统计/招募。

const MAIN_MENU_PATH := "res://scenes/main/main_menu.tscn"
const BATTLE_SCENE := preload("res://scenes/combat/realtime/realtime_battle.tscn")
const LEVEL_PATH := "res://resources/levels/board_act1.tres"
const DECK_PATH := "res://resources/deck/realtime_starter_deck.tres"

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
	_battle.half_exit_seconds = 0.0
	_battle_host.add_child(_battle)
	if not _battle.encounter_completed.is_connected(_on_encounter_completed):
		_battle.encounter_completed.connect(_on_encounter_completed)


func _start_sandbox() -> void:
	if _battle == null:
		return
	var deck := DeckState.new()
	deck.configure(load(DECK_PATH) as DeckConfig)
	deck.reset_from_config()
	var economy := RunEconomy.new()
	var level := load(LEVEL_PATH) as LevelData
	_battle.setup(deck, economy, level)
	_battle.set_combat_sandbox_mode(true)
	_battle.enter_combat_sandbox(0)


func _on_encounter_completed(_won: bool) -> void:
	## 沙盒 continue 已在控制器内重开准备；此处仅防离开中的残留信号。
	if _leaving:
		return


func _on_back_pressed() -> void:
	_leaving = true
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
