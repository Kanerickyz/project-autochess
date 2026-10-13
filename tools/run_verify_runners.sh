#!/usr/bin/env bash
# Aggregate Godot SceneTree runners for local / CI verification.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
cd "$ROOT"

runners=(
  "res://scripts/combat/effect_resolver_faint_test_runner.gd"
  "res://scripts/combat/effect_resolver_bomber_test_runner.gd"
  "res://scripts/combat/grid_movement_test_runner.gd"
  "res://scripts/combat/attack_range_preview_test_runner.gd"
  "res://scripts/combat/combat_movement_tests_runner.gd"
  "res://scripts/combat/combat_bus_lifecycle_test_runner.gd"
  "res://scripts/combat/realtime/realtime_combat_sim_test_runner.gd"
  "res://scripts/combat/realtime/realtime_ability_effect_test_runner.gd"
  "res://scripts/ui/realtime/realtime_battle_flow_test_runner.gd"
  "res://scripts/core/board_grid_distance_test_runner.gd"
  "res://scripts/core/draw_service_test_runner.gd"
  "res://scripts/core/run/map_generator_test_runner.gd"
  "res://scripts/core/run/sacrifice_service_test_runner.gd"
  "res://scripts/core/wfc/wfc_generator_test_runner.gd"
)

failed=0
for script in "${runners[@]}"; do
  echo "==> $script"
  if ! "$GODOT_BIN" --headless --path . --script "$script"; then
    echo "FAIL $script"
    failed=1
  else
    echo "OK   $script"
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "verify runners: FAILED"
  exit 1
fi
echo "verify runners: OK"
