class_name UiKitTest
extends RefCounted
## Headless 契约烟测：Theme 变体、工厂、GamePopup 主/次按钮位序。


static func run_all() -> bool:
	var passed := true
	passed = _check("theme_variations", _test_theme_variations()) and passed
	passed = _check("factory_panels_and_buttons", _test_factory_panels_and_buttons()) and passed
	passed = _check("game_popup_button_order", _test_game_popup_button_order()) and passed
	passed = _check("stylebox_from_theme_not_private", _test_stylebox_from_theme()) and passed
	passed = _check("color_tokens", _test_color_tokens()) and passed
	return passed


static func _check(label: String, ok: bool) -> bool:
	if not ok:
		push_error("UiKitTest: %s failed" % label)
	else:
		print("UiKitTest: %s OK" % label)
	return ok


static func _test_theme_variations() -> bool:
	if not UiKit.has_required_variations():
		return false
	var theme := UiKit.shell_theme()
	# PopupPanel is a built-in — must NOT be registered as our variation base.
	if theme.get_type_variation_base(&"PopupPanel") == &"PanelContainer":
		push_error("UiKitTest: unexpected PopupPanel variation (use KitPopupPanel)")
		return false
	return theme.get_type_variation_base(UiKit.VAR_POPUP_PANEL) == &"PanelContainer"


static func _test_factory_panels_and_buttons() -> bool:
	var shell := UiKit.make_shell_panel()
	var dock := UiKit.make_dock_panel()
	var popup_panel := UiKit.make_popup_panel()
	var primary := UiKit.make_primary_button("开战")
	var secondary := UiKit.make_secondary_button("取消")
	var icon := UiKit.make_icon_button("⚙")
	var ok := (
		shell.theme_type_variation == String(UiKit.VAR_SHELL_PANEL)
		and dock.theme_type_variation == String(UiKit.VAR_DOCK_PANEL)
		and popup_panel.theme_type_variation == String(UiKit.VAR_POPUP_PANEL)
		and primary.theme_type_variation == String(UiKit.VAR_PRIMARY)
		and secondary.theme_type_variation == String(UiKit.VAR_SECONDARY)
		and icon.theme_type_variation == String(UiKit.VAR_ICON)
		and primary.custom_minimum_size.y >= 44.0
	)
	shell.free()
	dock.free()
	popup_panel.free()
	primary.free()
	secondary.free()
	icon.free()
	return ok


static func _test_game_popup_button_order() -> bool:
	var packed := load(UiKit.GAME_POPUP_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var popup := packed.instantiate() as GamePopup
	if popup == null:
		return false
	# Need to enter tree for @onready — use temporary root.
	var host := Node.new()
	host.add_child(popup)
	# Force _ready
	if not popup.is_node_ready():
		# instantiate under host already calls _ready when in tree if SceneTree exists;
		# under RefCounted tests we may need deferred — use call_deferred pattern via
		# reading unique names directly if @onready null.
		pass
	var secondary := popup.get_node_or_null("%SecondaryButton") as Button
	var primary := popup.get_node_or_null("%PrimaryButton") as Button
	var row := popup.get_node_or_null("%ButtonRow") as HBoxContainer
	var dim := popup.get_node_or_null("%Dim") as ColorRect
	if secondary == null or primary == null or row == null or dim == null:
		host.free()
		return false
	var order_ok := secondary.get_index() < primary.get_index()
	var dim_ok := dim.color.a > 0.3
	popup.configure("测试", "正文", "主操作", "次操作")
	popup.dismiss_on_dim = false
	var title := popup.get_node_or_null("%TitleLabel") as Label
	var config_ok := title != null and title.text == "测试"
	host.free()
	return order_ok and dim_ok and config_ok


static func _test_stylebox_from_theme() -> bool:
	var box := UiKit.stylebox_for(UiKit.VAR_SHELL_PANEL)
	if box == null:
		return false
	# Must be a duplicate (mutating must not change theme source).
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		var original_bg := flat.bg_color
		flat.bg_color = Color(1, 0, 0, 1)
		var again := UiKit.stylebox_for(UiKit.VAR_SHELL_PANEL) as StyleBoxFlat
		if again == null:
			return false
		var unchanged := again.bg_color.is_equal_approx(original_bg)
		return unchanged
	return true


static func _test_color_tokens() -> bool:
	# Enemy redder than ally green channel dominance; gold yellowish; dim translucent.
	if UiKit.COLOR_HP_ENEMY.r <= UiKit.COLOR_HP_ENEMY.g:
		return false
	if UiKit.COLOR_HP_ALLY.g <= UiKit.COLOR_HP_ALLY.r:
		return false
	if UiKit.COLOR_GOLD.r < 0.7 or UiKit.COLOR_GOLD.b > 0.5:
		return false
	if UiKit.COLOR_DIM.a < 0.4 or UiKit.COLOR_DIM.a > 0.9:
		return false
	return true
