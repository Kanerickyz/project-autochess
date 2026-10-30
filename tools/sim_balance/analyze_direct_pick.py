#!/usr/bin/env python3
"""Analyze direct-pick sim runs.json: F12 reach, death histogram, per-floor win rate, pick stats.

Usage: python3 tools/sim_balance/analyze_direct_pick.py <runs.json|dir> [--out analysis.json]
"""
import argparse
import json
import os
from collections import Counter, defaultdict

TARGET_FLOOR = 12
EARLY_DEATH_MAX = 6


def segment(floor: int) -> str:
    if floor <= 3:
        return "F1-3"
    if floor <= 9:
        return "F4-9"
    if floor <= 12:
        return "F10-12"
    return "F13+"


def reached_f12(run: dict) -> bool:
    return run.get("outcome") == "RUN_COMPLETE" or int(run.get("death_floor", 0)) >= TARGET_FLOOR


def max_floor(run: dict) -> int:
    floors = [int(e.get("floor", 0)) for e in run.get("encounters", [])]
    return max(floors) if floors else 0


def pick_freq(runs: list) -> Counter:
    c = Counter()
    for r in runs:
        for p in r.get("recruit_picks", []):
            c[p.get("unit_id", "")] += 1
    return c


def analyze(runs: list) -> dict:
    n = len(runs)
    f12 = [r for r in runs if reached_f12(r)]
    early = [r for r in runs if r.get("outcome") == "RUN_DEFEAT" and int(r.get("death_floor", 0)) <= EARLY_DEATH_MAX]
    if not early:
        early = [r for r in runs if not reached_f12(r)]
        early_def = "not reached F12 (no death<=%d)" % EARLY_DEATH_MAX
    else:
        early_def = f"death_floor<={EARLY_DEATH_MAX}"
    complete = sum(1 for r in runs if r.get("outcome") == "RUN_COMPLETE")
    f4_plus = sum(1 for r in runs if r.get("outcome") == "RUN_COMPLETE" or int(r.get("death_floor", 0)) >= 4)

    death_hist = Counter()
    for r in runs:
        if r.get("outcome") == "RUN_DEFEAT":
            death_hist[int(r.get("death_floor", 0))] += 1

    by_floor = defaultdict(lambda: {"attempts": 0, "wins": 0})
    for r in runs:
        for e in r.get("encounters", []):
            b = by_floor[int(e.get("floor", 0))]
            b["attempts"] += 1
            b["wins"] += 1 if e.get("won") else 0
    floor_wr = {
        str(f): {**b, "win_rate": round(b["wins"] / max(1, b["attempts"]), 3)}
        for f, b in sorted(by_floor.items())
    }

    seg_picks = defaultdict(Counter)
    for r in runs:
        for p in r.get("recruit_picks", []):
            seg_picks[segment(int(p.get("floor", 0)))][p.get("unit_id", "")] += 1
    top_by_segment = {s: c.most_common(20) for s, c in sorted(seg_picks.items())}

    f12_freq = pick_freq(f12)
    early_freq = pick_freq(early)
    f12_tot = max(1, sum(f12_freq.values()))
    early_tot = max(1, sum(early_freq.values()))
    diff = []
    for uid in set(f12_freq) | set(early_freq):
        a = f12_freq[uid] / f12_tot
        b = early_freq[uid] / early_tot
        diff.append((uid, round(a - b, 4), round(a, 4), round(b, 4)))
    diff.sort(key=lambda x: x[1], reverse=True)

    roster_units = Counter()
    roster_roles = Counter()
    level_sum = 0
    tier_sum = 0
    roster_count = 0
    seat_cap_sum = 0
    seated_healers = 0
    seated_level_sum = 0
    seated_count = 0
    max_level_seen = 0
    for r in runs:
        roster = r.get("final_roster", [])
        seat_cap_sum += int(r.get("final_seat_cap", 0))
        for e in roster:
            roster_units[e.get("unit_id", "")] += 1
            for role in e.get("roles", []):
                roster_roles[role] += 1
            level_sum += int(e.get("level", 1))
            max_level_seen = max(max_level_seen, int(e.get("level", 1)))
            if e.get("seated"):
                seated_count += 1
                seated_level_sum += int(e.get("level", 1))
                if "healer" in e.get("roles", []):
                    seated_healers += 1
            tier_sum += int(e.get("tier", 1))
            roster_count += 1
    avg_roster = {
        "avg_size": round(roster_count / max(1, n), 2),
        "avg_level": round(level_sum / max(1, roster_count), 2),
        "avg_tier": round(tier_sum / max(1, roster_count), 2),
        "avg_seat_cap": round(seat_cap_sum / max(1, n), 2),
        "avg_seated_level": round(seated_level_sum / max(1, seated_count), 2),
        "avg_seated_healers": round(seated_healers / max(1, n), 2),
        "max_level_seen": max_level_seen,
        "avg_role_counts": {k: round(v / max(1, n), 2) for k, v in roster_roles.most_common()},
        "top_units": roster_units.most_common(15),
    }

    return {
        "runs": n,
        "reached_f12": len(f12),
        "run_complete": complete,
        "f4_plus_ratio": round(f4_plus / max(1, n), 3),
        "avg_max_floor": round(sum(max_floor(r) for r in runs) / max(1, n), 2),
        "death_floor_histogram": {str(k): v for k, v in sorted(death_hist.items())},
        "floor_win_rate": floor_wr,
        "top_picks_by_segment": top_by_segment,
        "f12_vs_early_pick_diff": {
            "f12_runs": len(f12),
            "early_runs": len(early),
            "early_def": early_def,
            "more_in_f12": diff[:10],
            "more_in_early": diff[-10:][::-1],
        },
        "avg_final_roster": avg_roster,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    path = args.path
    if os.path.isdir(path):
        path = os.path.join(path, "runs.json")
    with open(path, encoding="utf-8") as f:
        runs = json.load(f)
    result = analyze(runs)
    out = args.out or os.path.join(os.path.dirname(path), "analysis.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"runs={result['runs']} reached_f12={result['reached_f12']} complete={result['run_complete']} "
          f"f4_plus={result['f4_plus_ratio']} avg_max_floor={result['avg_max_floor']}")
    print("death_floor_histogram:", result["death_floor_histogram"])
    print("floor_win_rate:", {k: f"{v['wins']}/{v['attempts']}={v['win_rate']}" for k, v in result["floor_win_rate"].items()})
    for seg, top in result["top_picks_by_segment"].items():
        print(f"top_picks {seg}:", ", ".join(f"{u}:{c}" for u, c in top[:10]))
    d = result["f12_vs_early_pick_diff"]
    print(f"f12 vs early [{d['early_def']}] ({d['f12_runs']} vs {d['early_runs']}): more_in_f12=", d["more_in_f12"][:5])
    print("  more_in_early=", d["more_in_early"][:5])
    print("avg_final_roster:", {k: v for k, v in result["avg_final_roster"].items() if k != "top_units"})
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
