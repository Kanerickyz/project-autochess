#!/usr/bin/env bash
# Headless batch sim (isolated from main game entry). Default: 100 runs → .artifacts/sim_balance/latest/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-godot}"
RUNS="${1:-100}"
SEED_START="${2:-1}"
OUT="${3:-$ROOT/.artifacts/sim_balance/latest}"
if [ $# -ge 3 ]; then
  shift 3
fi
CHECKPOINT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --checkpoint)
      CHECKPOINT="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done
mkdir -p "$OUT"
CMD=(--runs "$RUNS" --seed-start "$SEED_START" --out "$OUT")
if [ -n "$CHECKPOINT" ]; then
  CMD+=(--checkpoint "$CHECKPOINT")
fi
"$GODOT_BIN" --headless --path "$ROOT" --script res://scripts/sim_balance/sim_batch_runner.gd -- "${CMD[@]}"
echo "Wrote summary to $OUT/summary.json"
echo "Open tools/sim_balance/sim_report.html and load that summary.json"
