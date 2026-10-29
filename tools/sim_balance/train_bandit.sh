#!/usr/bin/env bash
# Train contextual bandit checkpoint (encounter win/loss only). Default 400 episodes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-godot}"
exec "$GODOT_BIN" --headless --path "$ROOT" --script res://scripts/sim_balance/sim_bandit_train_runner.gd -- "$@"
