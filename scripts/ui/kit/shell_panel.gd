class_name ShellPanel
extends PanelContainer
## 壳内常驻块（HeroPanel / BoardFrame / Dock 等）的基类。
## 非模态；样式来自 Theme type variation，勿在子类 StyleBoxFlat.new()。
##
## 用法：场景根挂本脚本，或代码 `UiKit.make_shell_panel()`；
## 需要 Dock / Hero 外观时设 `panel_kind`。

enum Kind {
	SHELL,
	DOCK,
	HERO,
	FLOATING,
}

@export var panel_kind: Kind = Kind.SHELL


func _ready() -> void:
	UiKit.apply_shell_theme(self)
	match panel_kind:
		Kind.SHELL:
			theme_type_variation = String(UiKit.VAR_SHELL_PANEL)
		Kind.DOCK:
			theme_type_variation = String(UiKit.VAR_DOCK_PANEL)
		Kind.HERO:
			theme_type_variation = String(UiKit.VAR_HERO_PANEL)
		Kind.FLOATING:
			theme_type_variation = String(UiKit.VAR_FLOATING_PANEL)
		_:
			push_error("ShellPanel: unhandled panel_kind %s" % panel_kind)
			theme_type_variation = String(UiKit.VAR_SHELL_PANEL)
