class_name ShopOrEventChoicePanelTest
extends RefCounted
## 战后店|事|跳过选项卡契约。


static func run_all() -> bool:
	var passed := true
	passed = _test_build_cards_include_skip() and passed
	passed = _test_is_valid_choice() and passed
	if passed:
		print("ShopOrEventChoicePanelTest: all passed")
	else:
		push_error("ShopOrEventChoicePanelTest: failures detected")
	return passed


static func _test_build_cards_include_skip() -> bool:
	var cards := ShopOrEventChoicePanel.build_choice_cards()
	if cards.size() != 3:
		push_error(
			"ShopOrEventChoicePanelTest: expect 3 cards (shop/event/skip), got %d"
			% cards.size()
		)
		return false
	var ids: Dictionary = {}
	for card in cards:
		if not (card is Dictionary):
			push_error("ShopOrEventChoicePanelTest: card must be Dictionary")
			return false
		var id: StringName = (card as Dictionary).get("id", &"")
		ids[id] = true
		if String((card as Dictionary).get("label", "")).is_empty():
			push_error("ShopOrEventChoicePanelTest: card label empty for %s" % String(id))
			return false
	if not ids.has(ShopOrEventChoicePanel.CHOICE_SHOP):
		push_error("ShopOrEventChoicePanelTest: missing shop card")
		return false
	if not ids.has(ShopOrEventChoicePanel.CHOICE_EVENT):
		push_error("ShopOrEventChoicePanelTest: missing event card")
		return false
	if not ids.has(ShopOrEventChoicePanel.CHOICE_SKIP):
		push_error("ShopOrEventChoicePanelTest: missing skip card")
		return false
	return true


static func _test_is_valid_choice() -> bool:
	if not ShopOrEventChoicePanel.is_valid_choice(ShopOrEventChoicePanel.CHOICE_SKIP):
		push_error("ShopOrEventChoicePanelTest: skip must be valid")
		return false
	if ShopOrEventChoicePanel.is_valid_choice(&"bogus"):
		push_error("ShopOrEventChoicePanelTest: bogus id must be invalid")
		return false
	return true
