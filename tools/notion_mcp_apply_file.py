#!/usr/bin/env python3
"""Emit notion-update-page arguments JSON (one line) for agent CallDynamicTool."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: notion_mcp_apply_file.py <path-to-args.json>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    payload = json.loads(path.read_text(encoding="utf-8"))
    json.dump(payload, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
