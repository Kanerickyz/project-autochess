class_name ShopOrEventChoicePanel
extends RefCounted
## 战后商店 / 事件 / 跳过（主模式线性远征）。
## 选项画在 Arena 上半场卡片上（AllyBoard 常驻底部），不再弹 GamePopup。

signal choice_made(choice: StringName)

const CHOICE_SHOP := &"shop"
const CHOICE_EVENT := &"event"
const CHOICE_SKIP := &"skip"


static func is_valid_choice(choice_id: StringName) -> bool:
	return (
		choice_id == CHOICE_SHOP
		or choice_id == CHOICE_EVENT
		or choice_id == CHOICE_SKIP
	)


static func build_choice_cards() -> Array:
	return [
		{
			"id": CHOICE_SHOP,
			"label": "商店",
			"summary": "消耗品 / 装备",
			"detail": "进入地图商店：上半场货架购买消耗品与装备，下半场队伍常驻可换座。离开后进入短名单招募。",
			"kind_label": "去向",
		},
		{
			"id": CHOICE_EVENT,
			"label": "事件",
			"summary": "远征圣物等",
			"detail": "进入远征圣物三选一：点选上半场圣物卡片，长按可看完整效果；可跳过或换下旧件。结束后进入短名单招募。",
			"kind_label": "去向",
		},
		{
			"id": CHOICE_SKIP,
			"label": "跳过",
			"summary": "直接招募",
			"detail": "本层不进商店也不进事件，直接进入短名单招募。本层拿不到新圣物，也不改商店库存。",
			"kind_label": "去向",
		},
	]


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
	_battle.enter_stage_choice("战后选择", build_choice_cards(), 0.0)


func hide_choice() -> void:
	_active = false
	if _battle != null and _battle.get_phase() == RealtimeBattleController.Phase.STAGE_CHOICE:
		_battle.exit_stage_choice()


func _on_stage_picked(choice_id: StringName, _index: int) -> void:
	if not _active:
		return
	if not is_valid_choice(choice_id):
		return
	_active = false
	if _battle != null:
		_battle.exit_stage_choice()
	choice_made.emit(choice_id)
