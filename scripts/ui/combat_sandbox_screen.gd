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
var _status: Label


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_ensure_status_label()
	_spawn_battle()
	call_deferred("_start_sandbox")


func _ensure_status_label() -> void:
	if _status != null and is_instance_valid(_status):
		return
	_status = Label.new()
	_status.name = "SandboxStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.offset_top = 56.0
	_status.offset_left = 12.0
	_status.offset_right = -12.0
	_status.offset_bottom = 104.0
	## 挂在 TopLayer，避免与 Margin 内返回按钮抢同一布局槽。
	$TopLayer.add_child(_status)


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
	var deck_cfg := load(DECK_PATH) as DeckConfig
	var level := load(LEVEL_PATH) as LevelData
	if deck_cfg == null or level == null:
		if _status != null:
			_status.text = "沙盒资源加载失败，请返回主菜单"
		push_error("CombatSandbox: missing deck or level")
		return
	var deck := DeckState.new()
	deck.configure(deck_cfg)
	## 空队进沙盒：避免开局队掩盖「粘贴无效果」；靠粘贴/默认弱敌开战。
	var economy := RunEconomy.new()
	_battle.setup(deck, economy, level)
	_battle.set_combat_sandbox_mode(true)
	_battle.enter_combat_sandbox(0)
	if _battle.get_phase() != RealtimeBattleController.Phase.PREPARE:
		if _status != null:
			_status.text = "沙盒未能进入准备阶段"
		return
	if _status != null:
		_status.text = "点「粘贴布局」贴入阵容，再开战"


func _on_encounter_completed(_won: bool) -> void:
	## 沙盒 continue 已在控制器内重开准备；此处仅防离开中的残留信号。
	if _leaving:
		return


func _on_back_pressed() -> void:
	_leaving = true
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
