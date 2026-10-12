#!/usr/bin/env bash
# Light acceptance: project load / “compile” smoke only (no full runner suite, no GUI).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$ROOT"

echo "==> import (best-effort)"
"$GODOT_BIN" --headless --path . --import || true

echo "==> project load smoke"
"$GODOT_BIN" --headless --path . --script res://scripts/core/project_load_smoke_test_runner.gd

echo "light verify: OK"
