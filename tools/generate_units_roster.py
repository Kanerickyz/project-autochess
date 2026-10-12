#!/usr/bin/env python3
"""Generate Documents/UNITS_ROSTER.md from UnitData .tres resources."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNITS_DIR = ROOT / "resources" / "units"
ABILITIES_DIR = ROOT / "resources" / "abilities"
SHOP_POOL = ROOT / "resources" / "shop" / "dev_shop_pool.tres"
OUTPUT = ROOT / "Documents" / "UNITS_ROSTER.md"

# 手工覆盖（优先于自动推断）
ARCHETYPE_OVERRIDES: dict[str, str] = {}

ARCHETYPE_ORDER: list[str] = [
    "召唤",
    "受伤",
    "地图",
    "商店",
    "开战",
    "死亡",
    "友亡",
    "击倒",
    "其他",
]

ARCHETYPE_BLURB: dict[str, str] = {
    "召唤": "友方召唤、被召唤、死亡/友亡生成 token",
    "受伤": "受伤时触发（含反伤、自 buff、友伤计数）",
    "地图": "格子燃烧等地形效果",
    "商店": "购买 / 出售 / 升级等商店阶段联动",
    "开战": "战斗开始时的伤害或 buff",
    "死亡": "自身死亡时 buff 队友或全场伤害（非召唤）",
    "友亡": "友方死亡时自身成长（非召唤）",
    "击倒": "击杀敌人时触发",
    "其他": "未归类或复合机制",
}


@dataclass
class UnitInfo:
    unit_id: str
    display_name: str
    tier: int
    cost: int
    attack: int
    max_hp: int
    ability_summary: str
    ability_id: str
    archetype: str
    path: str
    in_shop: bool


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _field(text: str, name: str, default: str = "") -> str:
    m = re.search(rf'^{name} = (?:"([^"]*)"|(\d+))', text, re.MULTILINE)
    if not m:
        return default
    return m.group(1) if m.group(1) is not None else m.group(2)


# 对齐 scripts/data/unit_stats.gd 默认值
STATS_DEFAULTS: dict[str, int] = {
    "attack": 3,
    "max_hp": 10,
    "attack_range": 1,
    "crit_rate_percent": 5,
}


def _parse_unit_stats(text: str) -> dict[str, int]:
    stats: dict[str, int] = dict(STATS_DEFAULTS)
    block_match = re.search(
        r'\[sub_resource type="Resource" id="UnitStats[^\]]*\](.*?)(?=\n\[sub_resource|\n\[resource\])',
        text,
        re.DOTALL,
    )
    if not block_match:
        return stats
    block = block_match.group(1)
    for key in STATS_DEFAULTS:
        value = _field(block, key, "")
        if value != "":
            stats[key] = int(value)
    return stats


TRIGGER_MAP: dict[str, str] = {
    "OnCombatStart": "开战时",
    "OnFriendSummoned": "友方召唤时",
    "OnSummoned": "被召唤时",
    "OnFriendDeath": "友方死亡时",
    "OnRoundStart": "回合开始时",
    "OnDamageTaken": "受伤时",
    "OnDeath": "死亡时",
    "OnMove": "移动时",
    "OnBuy": "购买时",
    "OnSell": "出售时",
    "OnLevelUp": "升级时",
    "OnCrit": "造成暴击时",
    "OnAttackHit": "受击前",
    "OnLineAttack": "直线攻击时",
}


def _shop_unit_ids() -> set[str]:
    if not SHOP_POOL.is_file():
        return set()
    text = _read(SHOP_POOL)
    ids: set[str] = set()
    for m in re.finditer(r'path="res://resources/units/([^"/]+)\.tres"', text):
        ids.add(m.group(1))
    return ids


def _ability_summary(unit_text: str) -> tuple[str, str]:
    m = re.search(
        r'path="res://resources/abilities/([^"]+\.tres)"',
        unit_text,
    )
    if not m:
        return "", ""
    ability_path = ABILITIES_DIR / m.group(1)
    if not ability_path.is_file():
        return "", m.group(1).replace(".tres", "")
    ability_text = _read(ability_path)
    ability_id = _field(ability_text, "id", ability_path.stem)
    display = _field(ability_text, "display_name")
    triggers = re.findall(r'trigger = &"([^"]+)"', ability_text)
    trigger_label = triggers[0] if triggers else ""
    if display:
        return display, ability_id
    if trigger_label in TRIGGER_MAP:
        return TRIGGER_MAP[trigger_label], ability_id
    return ability_id, ability_id


def _infer_archetype(unit_id: str, ability_text: str) -> str:
    if unit_id in ARCHETYPE_OVERRIDES:
        return ARCHETYPE_OVERRIDES[unit_id]
    if not ability_text:
        return "其他"

    if re.search(r"action_type = 9\b", ability_text):
        return "地图"

    triggers = re.findall(r'trigger = &"([^"]+)"', ability_text)
    trigger = triggers[0] if triggers else ""
    has_spawn = bool(re.search(r"action_type = 2\b", ability_text))

    if trigger in ("OnFriendSummoned", "OnSummoned"):
        return "召唤"
    if trigger == "OnDeath" and has_spawn:
        return "召唤"
    if trigger == "OnFriendDeath" and has_spawn:
        return "召唤"
    if trigger == "OnDamageTaken":
        return "受伤"
    if trigger in ("OnBuy", "OnSell", "OnLevelUp"):
        return "商店"
    if trigger == "OnCombatStart":
        return "开战"
    if trigger == "OnKill":
        return "击倒"
    if trigger == "OnFriendDeath":
        return "友亡"
    if trigger == "OnDeath":
        return "死亡"
    return "其他"


def _ability_text_for_unit(unit_text: str) -> str:
    m = re.search(
        r'path="res://resources/abilities/([^"]+\.tres)"',
        unit_text,
    )
    if not m:
        return ""
    ability_path = ABILITIES_DIR / m.group(1)
    return _read(ability_path) if ability_path.is_file() else ""


def _parse_unit(path: Path, shop_ids: set[str]) -> UnitInfo:
    text = _read(path)
    unit_id = _field(text, "id", path.stem)
    display_name = _field(text, "display_name", unit_id)
    tier = int(_field(text, "tier", "1") or "1")
    cost = int(_field(text, "cost", str(tier)) or str(tier))
    stats = _parse_unit_stats(text)
    attack = stats["attack"]
    max_hp = stats["max_hp"]
    summary, ability_id = _ability_summary(text)
    ability_text = _ability_text_for_unit(text)
    archetype = _infer_archetype(unit_id, ability_text)
    return UnitInfo(
        unit_id=unit_id,
        display_name=display_name,
        tier=tier,
        cost=cost,
        attack=attack,
        max_hp=max_hp,
        ability_summary=summary,
        ability_id=ability_id,
        archetype=archetype,
        path=str(path.relative_to(ROOT)).replace("\\", "/"),
        in_shop=unit_id in shop_ids,
    )


def _render(units: list[UnitInfo]) -> str:
    shop = sorted([u for u in units if u.in_shop and "tokens" not in u.path], key=lambda u: (u.tier, u.unit_id))
    tokens = sorted([u for u in units if "tokens" in u.path], key=lambda u: u.unit_id)
    other = sorted(
        [u for u in units if not u.in_shop and "tokens" not in u.path],
        key=lambda u: u.unit_id,
    )

    lines: list[str] = [
        "# 角色汇总（UNITS_ROSTER）",
        "",
        "> 由 `tools/generate_units_roster.py` 生成；流派按技能主触发/机制自动推断，可在脚本 `ARCHETYPE_OVERRIDES` 手工覆盖。",
        "> **功能规格**（友方角色 / 敌方角色 / 生成的代理角色；生命、攻击、移动）见 [Features/UNITS.md](./Features/UNITS.md)；本文是角色内容一览。",
        "",
        "## 说明",
        "",
        "- **Tier / cost**：商店角色 `cost` 通常等于 `tier`；高 Tier 需多次进入商店解锁。",
        "- **商店池**：`resources/shop/dev_shop_pool.tres` 的 `character_pool`；token 与占位敌人不入池。",
        "- **流派标签**：召唤 / 受伤 / 地图 / 商店 / 开战 / 死亡 / 友亡 / 击倒；设计向分类，未写入 `.tres`。",
        "",
        "## 流派索引",
        "",
    ]

    by_archetype: dict[str, list[UnitInfo]] = {key: [] for key in ARCHETYPE_ORDER}
    for u in shop:
        bucket = u.archetype if u.archetype in by_archetype else "其他"
        by_archetype[bucket].append(u)

    for key in ARCHETYPE_ORDER:
        group = sorted(by_archetype[key], key=lambda u: (u.tier, u.unit_id))
        if not group:
            continue
        blurb = ARCHETYPE_BLURB.get(key, "")
        names = "、".join(f"{u.display_name}（T{u.tier}）" for u in group)
        lines.append(f"### {key}（{len(group)}）")
        if blurb:
            lines.append(f"- {blurb}")
        lines.append(f"- {names}")
        lines.append("")

    lines.extend(
        [
            f"## 可购角色（{len(shop)}）",
            "",
            "| id | 中文 | Tier | cost | 攻/血 | 技能摘要 | 流派 |",
            "|----|------|------|------|-------|----------|------|",
        ]
    )
    for u in shop:
        lines.append(
            f"| `{u.unit_id}` | {u.display_name} | {u.tier} | {u.cost} | "
            f"{u.attack}/{u.max_hp} | {u.ability_summary} | {u.archetype} |"
        )

    lines.extend(
        [
            "",
            f"## Token / 召唤物（{len(tokens)}）",
            "",
            "| id | 中文 | 攻/血 | 技能摘要 | 来源 | 流派 |",
            "|----|------|-------|----------|------|------|",
        ]
    )
    token_sources = {
        "ram": "绵羊 / 母羊",
        "chick": "公鸡",
        "bus": "鹿",
        "zombie_fly": "苍蝇",
    }
    token_archetype = {
        "ram": "召唤",
        "chick": "召唤",
        "bus": "召唤",
        "zombie_fly": "召唤",
    }
    for u in tokens:
        lines.append(
            f"| `{u.unit_id}` | {u.display_name} | {u.attack}/{u.max_hp} | "
            f"{u.ability_summary or '—'} | {token_sources.get(u.unit_id, '—')} | {token_archetype.get(u.unit_id, '—')} |"
        )

    lines.extend(
        [
            "",
            f"## 非商店单位（{len(other)}）",
            "",
            "| id | 中文 | 攻/血 | 说明 | 流派 |",
            "|----|------|-------|------|------|",
        ]
    )
    notes = {
        "zombie_cricket": "蟋蟀死亡召唤",
        "spider_hatchling": "蜘蛛死亡召唤",
        "enemy_placeholder": "波次敌人占位",
    }
    for u in other:
        archetype = u.archetype
        if u.unit_id in ("spider_hatchling", "zombie_cricket"):
            archetype = "召唤"
        elif u.unit_id == "enemy_placeholder":
            archetype = "—"
        lines.append(
            f"| `{u.unit_id}` | {u.display_name} | {u.attack}/{u.max_hp} | "
            f"{notes.get(u.unit_id, u.ability_summary or '—')} | {archetype} |"
        )

    lines.extend(
        [
            "",
            "## 维护约定",
            "",
            "1. 新增/修改 `resources/units/*.tres` 后运行 `py tools/generate_units_roster.py`。",
            "2. 同步更新 [ABILITIES.md](./ABILITIES.md) §1.2。",
            "3. 调整 Tier 前先运行 `py tools/suggest_unit_tier.py` 对照建议分。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    shop_ids = _shop_unit_ids()
    units: list[UnitInfo] = []
    for tres in sorted(UNITS_DIR.rglob("*.tres")):
        units.append(_parse_unit(tres, shop_ids))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(_render(units), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({len(units)} units)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
