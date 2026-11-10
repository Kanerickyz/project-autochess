class_name PhaseGridPalettes
extends RefCounted
## 各阶段动态棋盘格双色（小丑牌式深色主题；战斗用冷铁灰抬高与暖色纸片对比）。

enum ThemeId {
	MENU,
	MAP,
	PREPARE,
	COMBAT,
	RECRUIT,
	MAP_SHOP,
	ENCHANT,
}


## 返回 { "a": Color, "b": Color }。
static func colors_for(theme_id: ThemeId) -> Dictionary:
	match theme_id:
		ThemeId.MENU:
			## 主菜单：冷灰紫（现网 As-Is）。
			return {
				"a": Color(0.07, 0.08, 0.11),
				"b": Color(0.13, 0.11, 0.15),
			}
		ThemeId.MAP:
			## 地图选路：深蓝 Ante 感。
			return {
				"a": Color(0.04, 0.07, 0.14),
				"b": Color(0.09, 0.14, 0.26),
			}
		ThemeId.PREPARE:
			## 准备站位：青灰冷静。
			return {
				"a": Color(0.05, 0.09, 0.11),
				"b": Color(0.09, 0.16, 0.18),
			}
		ThemeId.COMBAT:
			## 战斗：冷铁灰（压低饱和与格间反差，避免焦橙吃掉暖色纸片/脚下血量）。
			return {
				"a": Color(0.04, 0.05, 0.08),
				"b": Color(0.10, 0.12, 0.17),
			}
		ThemeId.RECRUIT:
			## 招募：墨绿店面感。
			return {
				"a": Color(0.03, 0.09, 0.07),
				"b": Color(0.07, 0.20, 0.14),
			}
		ThemeId.MAP_SHOP:
			## 地图商店：琥珀金。
			return {
				"a": Color(0.10, 0.07, 0.03),
				"b": Color(0.34, 0.23, 0.07),
			}
		ThemeId.ENCHANT:
			## 附魔熔炉：品红紫。
			return {
				"a": Color(0.09, 0.03, 0.11),
				"b": Color(0.28, 0.09, 0.30),
			}
		_:
			return {
				"a": Color(0.07, 0.08, 0.11),
				"b": Color(0.13, 0.11, 0.15),
			}
