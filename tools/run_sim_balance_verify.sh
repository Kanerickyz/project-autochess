#!/usr/bin/env bash
# Sim balance harness: smoke (default) or optional local batch.
# Isolated from run_game; see tools/sim_balance/README.md
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$ROOT"

"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

echo "==> sim_balance smoke"
"$GODOT_BIN" --headless --path . --script res://scripts/sim_balance/sim_balance_smoke_test_runner.gd

if [[ "${SIM_BALANCE_BATCH:-0}" == "1" ]]; then
  RUNS="${SIM_BALANCE_RUNS:-100}"
  SEED="${SIM_BALANCE_SEED_START:-1}"
  OUT="${SIM_BALANCE_OUT:-$ROOT/.artifacts/sim_balance/latest}"
  echo "==> sim_balance batch runs=$RUNS seed_start=$SEED"
  bash "$ROOT/tools/sim_balance/run_batch.sh" "$RUNS" "$SEED" "$OUT"
fi

echo "sim_balance verify: OK"
