#!/usr/bin/env python3
"""Build a compact review bundle from sim batch output (tools/sim_balance only)."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean
from typing import Any


def _load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _max_floor_in_run(run: dict) -> int:
    mx = 0
    for enc in run.get("encounters", []) or []:
        if isinstance(enc, dict):
            mx = max(mx, int(enc.get("floor", 0)))
    if str(run.get("outcome", "")) == "RUN_COMPLETE":
        mx = max(mx, 999)
    df = int(run.get("death_floor", 0))
    if df > 0:
        mx = max(mx, df)
    return mx


def build_bundle(batch_dir: Path) -> dict:
    summary = _load(batch_dir / "summary.json")
    runs = _load(batch_dir / "runs.json")

    death_floors = [int(r.get("death_floor", 0)) for r in runs if r.get("outcome") == "RUN_DEFEAT"]
    completes = sum(1 for r in runs if r.get("outcome") == "RUN_COMPLETE")
    reach_ge = Counter()
    for r in runs:
        mx = _max_floor_in_run(r)
        for f in range(1, 16):
            if mx >= f:
                reach_ge[f] += 1

    f4_plus = sum(
        1
        for r in runs
        if str(r.get("outcome", "")) == "RUN_COMPLETE"
        or int(r.get("death_floor", 0)) >= 4
    )

    pick_by_floor: dict[str, Counter] = defaultdict(Counter)
    pick_success: Counter = Counter()
    pick_fail: Counter = Counter()
    for r in runs:
        depth = int(r.get("death_floor", 0))
        if str(r.get("outcome", "")) == "RUN_COMPLETE":
            depth = 99
        for pick in r.get("recruit_picks", []) or []:
            if not isinstance(pick, dict):
                continue
            uid = str(pick.get("unit_id", ""))
            fl = int(pick.get("floor", 0))
            if not uid:
                continue
            pick_by_floor[str(fl)][uid] += 1
            if depth >= 8:
                pick_success[uid] += 1
            elif depth <= 3:
                pick_fail[uid] += 1

    weak_floors = []
    for row in summary.get("by_floor", []) or []:
        if not isinstance(row, dict):
            continue
        fl = int(row.get("floor", 0))
        att = int(row.get("attempts", 0))
        wr = float(row.get("win_rate", 0.0))
        if att >= 3 and wr < 0.45:
            weak_floors.append({"floor": fl, "win_rate": wr, "attempts": att})

    ranked_runs = sorted(
        runs,
        key=lambda r: (
            1 if str(r.get("outcome", "")) == "RUN_COMPLETE" else 0,
            _max_floor_in_run(r),
        ),
        reverse=True,
    )
    top = ranked_runs[: max(1, len(ranked_runs) // 4)]
    bottom = ranked_runs[-max(1, len(ranked_runs) // 4) :]

    def roster_sig(run: dict) -> list[str]:
        picks = run.get("recruit_picks", []) or []
        return sorted({str(p.get("unit_id", "")) for p in picks if isinstance(p, dict) and p.get("unit_id")})

    top_units = Counter()
    bottom_units = Counter()
    for r in top:
        for uid in roster_sig(r):
            top_units[uid] += 1
    for r in bottom:
        for uid in roster_sig(r):
            bottom_units[uid] += 1

    return {
        "batch_dir": str(batch_dir),
        "run_count": len(runs),
        "run_complete_rate": summary.get("run_complete_rate"),
        "death_floor_mode": summary.get("death_floor_mode"),
        "death_floor_mean": mean(death_floors) if death_floors else 0.0,
        "f4_plus_rate": f4_plus / max(1, len(runs)),
        "reach_floor_rate": {str(k): v / max(1, len(runs)) for k, v in sorted(reach_ge.items())},
        "reach_floor_12_rate": reach_ge.get(12, 0) / max(1, len(runs)),
        "max_floor_any_run": max((_max_floor_in_run(r) for r in runs), default=0),
        "weak_encounter_floors": weak_floors,
        "recruit_picks_by_floor": {k: dict(v.most_common(8)) for k, v in sorted(pick_by_floor.items())},
        "units_in_deep_runs": pick_success.most_common(12),
        "units_in_shallow_runs": pick_fail.most_common(12),
        "top_quartile_unit_freq": top_units.most_common(12),
        "bottom_quartile_unit_freq": bottom_units.most_common(12),
        "meta": summary.get("meta", {}),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("batch_dir", type=Path)
    ap.add_argument("-o", "--out", type=Path, required=True)
    args = ap.parse_args()
    bundle = build_bundle(args.batch_dir)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"ok": True, "out": str(args.out), "reach_floor_12_rate": bundle["reach_floor_12_rate"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
