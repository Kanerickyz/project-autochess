#!/usr/bin/env bash
# Headless batch sim (isolated from main game entry). Default: 100 runs → .artifacts/sim_balance/latest/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-godot}"
RUNS="${1:-100}"
SEED_START="${2:-1}"
OUT="${3:-$ROOT/.artifacts/sim_balance/latest}"
mkdir -p "$OUT"
"$GODOT_BIN" --headless --path "$ROOT" --script res://scripts/sim_balance/sim_batch_runner.gd -- \
  --runs "$RUNS" --seed-start "$SEED_START" --out "$OUT"
echo "Wrote summary to $OUT/summary.json"
echo "Open tools/sim_balance/sim_report.html and load that summary.json"
