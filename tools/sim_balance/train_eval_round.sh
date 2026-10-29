#!/usr/bin/env bash
# One train (500) + eval (100) round; checkpoints under tools/sim_balance/models/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-godot}"
TRAIN_RUNS="${TRAIN_RUNS:-500}"
EVAL_RUNS="${EVAL_RUNS:-100}"
SEED_START="${SEED_START:-1}"
ITER="${ITER:-1}"
OUT_DIR="${OUT_DIR:-$ROOT/tools/sim_balance/runs/iter_$(printf '%03d' "$ITER")}"
CKPT="${CKPT:-res://tools/sim_balance/models/active.tres}"
CKPT_FS="$ROOT/tools/sim_balance/models/active.tres"

mkdir -p "$OUT_DIR" "$(dirname "$CKPT_FS")"

if [[ ! -f "$CKPT_FS" ]]; then
  echo "==> init checkpoint from template"
  python3 "$ROOT/tools/sim_balance/checkpoint_stats.py" init \
    --template "$ROOT/tools/sim_balance/models/checkpoint_template.tres" \
    --out "$CKPT_FS" \
    --policy-id bandit-v4-cursor
fi

EXTRA_TRAIN=()
if [[ -n "${CHECKPOINT_IN:-}" ]]; then
  EXTRA_TRAIN+=(--checkpoint-in "$CHECKPOINT_IN")
elif [[ -f "$CKPT_FS" ]]; then
  EXTRA_TRAIN+=(--checkpoint-in "$CKPT")
fi

echo "==> train bandit v4 runs=$TRAIN_RUNS seed=$SEED_START out=$CKPT"
bash "$ROOT/tools/sim_balance/train_bandit.sh" \
  --reward-mode v4 \
  --train-runs "$TRAIN_RUNS" \
  --seed-start "$SEED_START" \
  --checkpoint-out "$CKPT" \
  "${EXTRA_TRAIN[@]}"

echo "==> eval frozen checkpoint runs=$EVAL_RUNS -> $OUT_DIR"
bash "$ROOT/tools/sim_balance/run_batch.sh" "$EVAL_RUNS" "$SEED_START" "$OUT_DIR" --checkpoint "$CKPT"

python3 "$ROOT/tools/sim_balance/analyze_for_review.py" "$OUT_DIR" \
  -o "$ROOT/tools/sim_balance/reviews/iter_$(printf '%03d' "$ITER")_bundle.json"

echo "==> round complete: $OUT_DIR"
