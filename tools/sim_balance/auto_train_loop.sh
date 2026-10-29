#!/usr/bin/env bash
# Iterative bandit train/eval/review/apply until F12+ or wall clock limit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export GODOT_BIN="${GODOT_BIN:-godot}"

MAX_SECONDS="${MAX_SECONDS:-1800}"
TARGET_FLOOR="${TARGET_FLOOR:-12}"
TRAIN_RUNS="${TRAIN_RUNS:-500}"
EVAL_RUNS="${EVAL_RUNS:-100}"
SEED_START="${SEED_START:-1}"
LOG="$ROOT/tools/sim_balance/reports/auto_loop.log"
mkdir -p "$ROOT/tools/sim_balance/reports" "$ROOT/tools/sim_balance/reviews"

START_TS=$(date +%s)
echo "auto_loop start $(date -u +%Y-%m-%dT%H:%M:%SZ) max_s=$MAX_SECONDS target_floor=$TARGET_FLOOR" | tee "$LOG"

ITER=0
while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TS))
  if (( ELAPSED >= MAX_SECONDS )); then
    echo "STOP: time limit ${MAX_SECONDS}s" | tee -a "$LOG"
    break
  fi

  ITER=$((ITER + 1))
  TAG=$(printf '%03d' "$ITER")
  OUT="$ROOT/tools/sim_balance/runs/iter_$TAG"
  BUNDLE="$ROOT/tools/sim_balance/reviews/iter_${TAG}_bundle.json"
  PLAN="$ROOT/tools/sim_balance/reviews/iter_${TAG}_plan.json"
  BALANCE_PLAN="$ROOT/tools/sim_balance/reviews/iter_${TAG}_plan_balance.json"
  APPLY_REPORT="$ROOT/tools/sim_balance/reports/iter_${TAG}_apply.json"

  echo "=== ITER $ITER elapsed=${ELAPSED}s ===" | tee -a "$LOG"

  ITER="$ITER" TRAIN_RUNS="$TRAIN_RUNS" EVAL_RUNS="$EVAL_RUNS" SEED_START="$SEED_START" \
    OUT_DIR="$OUT" bash "$ROOT/tools/sim_balance/train_eval_round.sh" 2>&1 | tee -a "$LOG"

  REACH12=$(python3 - <<PY
import json
b=json.load(open("$BUNDLE"))
print(b.get("reach_floor_12_rate", 0))
PY
)
  MAXF=$(python3 - <<PY
import json
b=json.load(open("$BUNDLE"))
print(b.get("max_floor_any_run", 0))
PY
)
  echo "metrics iter=$ITER reach_f12_rate=$REACH12 max_floor=$MAXF" | tee -a "$LOG"

  if python3 - <<PY
import json
b=json.load(open("$BUNDLE"))
ok = b.get("reach_floor_12_rate", 0) >= 0.05 or b.get("max_floor_any_run", 0) >= $TARGET_FLOOR
raise SystemExit(0 if ok else 1)
PY
  then
    echo "STOP: target floor $TARGET_FLOOR reached (or >=5% runs reach F12)" | tee -a "$LOG"
    break
  fi

  if [[ -f "$BALANCE_PLAN" ]]; then
    python3 "$ROOT/tools/sim_balance/apply_optimization.py" \
      --checkpoint "$ROOT/tools/sim_balance/models/active.tres" \
      --plan "$BALANCE_PLAN" \
      --report "${APPLY_REPORT%.json}_balance.json" 2>&1 | tee -a "$LOG"
  fi

  python3 "$ROOT/tools/sim_balance/apply_optimization.py" \
    --checkpoint "$ROOT/tools/sim_balance/models/active.tres" \
    --bundle "$BUNDLE" \
    --report "$APPLY_REPORT" 2>&1 | tee -a "$LOG"

  python3 - <<PY > "$PLAN"
import json
print(json.dumps(json.load(open("$APPLY_REPORT"))["plan"], ensure_ascii=False, indent=2))
PY

done

FINAL="$ROOT/tools/sim_balance/reports/final_summary.json"
python3 - <<PY > "$FINAL"
import json, glob, os
runs=sorted(glob.glob("$ROOT/tools/sim_balance/runs/iter_*/summary.json"))
last=runs[-1] if runs else None
out={"iterations": len(runs), "last_batch": last, "elapsed_s": $(($(date +%s)-START_TS))}
if last:
    s=json.load(open(last))
    out["death_floor_mode"]=s.get("death_floor_mode")
    out["run_complete_rate"]=s.get("run_complete_rate")
print(json.dumps(out, ensure_ascii=False, indent=2))
PY

echo "auto_loop done -> $FINAL" | tee -a "$LOG"
