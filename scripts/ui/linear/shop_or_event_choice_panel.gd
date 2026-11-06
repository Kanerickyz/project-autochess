class_name ShopOrEventChoicePanel
extends RefCounted
## 战后商店或事件二选一（主模式线性远征）。
## 选项画在 Arena 上半场卡片上（AllyBoard 常驻底部），不再弹 GamePopup。

signal choice_made(choice: StringName)

const CHOICE_SHOP := &"shop"
const CHOICE_EVENT := &"event"

var _battle: RealtimeBattleController
var _active: bool = false


func bind_battle(battle: RealtimeBattleController) -> void:
	if _battle == battle:
		return
	if _battle != null and _battle.stage_choice_picked.is_connected(_on_stage_picked):
		_battle.stage_choice_picked.disconnect(_on_stage_picked)
	_battle = battle
	if _battle != null and not _battle.stage_choice_picked.is_connected(_on_stage_picked):
		_battle.stage_choice_picked.connect(_on_stage_picked)


func show_choice() -> void:
	_active = true
	if _battle == null:
		push_error("ShopOrEventChoicePanel: battle not bound")
		## 无战场时默认商店，避免卡死。
		choice_made.emit(CHOICE_SHOP)
		_active = false
		return
	var cards: Array = [
		{"id": CHOICE_SHOP, "label": "商店", "summary": "消耗品 / 装备"},
		{"id": CHOICE_EVENT, "label": "事件", "summary": "远征圣物等"},
	]
	_battle.enter_stage_choice("战后选择", cards, 0.0)


func hide_choice() -> void:
	_active = false
	if _battle != null and _battle.get_phase() == RealtimeBattleController.Phase.STAGE_CHOICE:
		_battle.exit_stage_choice()


func _on_stage_picked(choice_id: StringName, _index: int) -> void:
	if not _active:
		return
	if choice_id != CHOICE_SHOP and choice_id != CHOICE_EVENT:
		return
	_active = false
	if _battle != null:
		_battle.exit_stage_choice()
	choice_made.emit(choice_id)
