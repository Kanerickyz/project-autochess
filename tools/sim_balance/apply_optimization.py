#!/usr/bin/env python3
"""Apply structured recruit-policy patches to a bandit checkpoint (tools/ only)."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from checkpoint_stats import load_checkpoint, save_checkpoint


def _compound_key(state_key: str, action_key: str) -> str:
    return f"{state_key}|{action_key}"


def _action_suffix(key: str) -> str:
    if "|" not in key:
        return ""
    return key.rsplit("|", 1)[-1]


def apply_plan(stats: dict, plan: dict) -> dict:
    """Mutates and returns stats."""
    boosts = plan.get("boost_units") or []
    penalize = plan.get("penalize_units") or []
    floor_boosts = plan.get("floor_unit_boosts") or []

    for item in boosts:
        uid = str(item.get("unit_id", ""))
        w_add = int(item.get("w_add", 1))
        if not uid:
            continue
        suffix = f"|{uid}"
        for key, row in list(stats.items()):
            if _action_suffix(key) != uid and not key.endswith(suffix):
                continue
            stats[key] = {
                "w": int(row.get("w", 0)) + w_add,
                "l": int(row.get("l", 0)),
            }

    for item in penalize:
        uid = str(item.get("unit_id", ""))
        l_add = int(item.get("l_add", 1))
        if not uid:
            continue
        for key, row in list(stats.items()):
            if _action_suffix(key) != uid:
                continue
            stats[key] = {
                "w": int(row.get("w", 0)),
                "l": int(row.get("l", 0)) + l_add,
            }

    for item in floor_boosts:
        floor = int(item.get("floor", 0))
        uid = str(item.get("unit_id", ""))
        w_add = int(item.get("w_add", 2))
        if floor <= 0 or not uid:
            continue
        needle = f"|f{floor}|"
        for key, row in list(stats.items()):
            if needle not in key or _action_suffix(key) != uid:
                continue
            stats[key] = {
                "w": int(row.get("w", 0)) + w_add,
                "l": int(row.get("l", 0)),
            }

    seed_rows = plan.get("seed_rows") or []
    for row in seed_rows:
        sk = str(row.get("state_key", ""))
        ak = str(row.get("action_key", ""))
        if not sk or not ak:
            continue
        k = _compound_key(sk, ak)
        prev = stats.get(k, {"w": 0, "l": 0})
        stats[k] = {
            "w": int(prev.get("w", 0)) + int(row.get("w_add", 1)),
            "l": int(prev.get("l", 0)) + int(row.get("l_add", 0)),
        }

    return stats


def heuristic_plan_from_bundle(bundle: dict) -> dict:
    """Fallback reviewer when no LLM subagent output exists."""
    boost_units = []
    penalize_units = []
    floor_unit_boosts = []

    deep = {uid for uid, _ in bundle.get("units_in_deep_runs", [])[:6]}
    shallow = {uid for uid, _ in bundle.get("units_in_shallow_runs", [])[:6]}
    for uid in deep - shallow:
        boost_units.append({"unit_id": uid, "w_add": 2})
    for uid in shallow - deep:
        penalize_units.append({"unit_id": uid, "l_add": 1})

    for wf in bundle.get("weak_encounter_floors", [])[:4]:
        fl = int(wf.get("floor", 0))
        picks = bundle.get("recruit_picks_by_floor", {}).get(str(fl), {})
        if not isinstance(picks, dict):
            continue
        for uid in list(picks.keys())[:2]:
            if uid in deep:
                floor_unit_boosts.append({"floor": fl, "unit_id": uid, "w_add": 2})

    top = [u for u, _ in bundle.get("top_quartile_unit_freq", [])[:4]]
    for uid in top:
        if uid not in deep:
            boost_units.append({"unit_id": uid, "w_add": 1})

    return {
        "source": "heuristic",
        "boost_units": boost_units,
        "penalize_units": penalize_units,
        "floor_unit_boosts": floor_unit_boosts,
        "notes": [
            "v4 bandit 按 unit_id + team/shop state 学招募；选路仍为启发式最短路 Boss。",
            "批跑内仍受金币与席位规则约束；席位扩展示意见 HeuristicRunAI 买旗帜（F4 前未必有钱）。",
            "优化通过增减 checkpoint 中 (state, unit_id) 的 w/l 偏置集成，不改游戏资源。",
        ],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", type=Path, required=True)
    ap.add_argument("--plan", type=Path, help="JSON optimization plan")
    ap.add_argument("--bundle", type=Path, help="Build heuristic plan from review bundle")
    ap.add_argument("--report", type=Path, required=True)
    args = ap.parse_args()

    if args.plan:
        plan = json.loads(args.plan.read_text(encoding="utf-8"))
    elif args.bundle:
        bundle = json.loads(args.bundle.read_text(encoding="utf-8"))
        plan = heuristic_plan_from_bundle(bundle)
    else:
        raise SystemExit("need --plan or --bundle")

    tres_text, stats = load_checkpoint(args.checkpoint)
    before_keys = len(stats)
    stats = apply_plan(stats, plan)
    save_checkpoint(args.checkpoint, tres_text, stats)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(
            {
                "plan": plan,
                "checkpoint": str(args.checkpoint),
                "stats_keys_before": before_keys,
                "stats_keys_after": len(stats),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"ok": True, "keys": len(stats), "source": plan.get("source", "file")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
