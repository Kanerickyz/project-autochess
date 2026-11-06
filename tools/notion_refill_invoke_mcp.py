#!/usr/bin/env python3
"""Print Notion MCP notion-update-page arguments JSON for a doc id (agent pipes to MCP)."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: notion_refill_invoke_mcp.py <doc-id>", file=sys.stderr)
        return 2
    doc = sys.argv[1]
    path = Path(f"/tmp/mcp-payload-{doc}.json")
    if not path.is_file():
        print(f"missing {path}", file=sys.stderr)
        return 1
    payload = json.loads(path.read_text(encoding="utf-8"))
    json.dump(payload, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
