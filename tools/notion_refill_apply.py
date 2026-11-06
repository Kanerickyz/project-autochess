#!/usr/bin/env python3
"""Load /tmp/invoke-fixed-*.json payloads for Notion MCP replace_content (agent-driven)."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: notion_refill_apply.py <doc-id>|--list", file=sys.stderr)
        return 2
    if sys.argv[1] == "--list":
        for p in sorted(Path("/tmp").glob("invoke-fixed-*.json")):
            doc = p.stem.replace("invoke-fixed-", "")
            d = json.loads(p.read_text(encoding="utf-8"))
            print(doc, d["page_id"], len(d.get("new_str", "")))
        return 0
    doc = sys.argv[1]
    path = Path(f"/tmp/invoke-fixed-{doc}.json")
    if not path.is_file():
        print(f"missing {path}", file=sys.stderr)
        return 1
    payload = json.loads(path.read_text(encoding="utf-8"))
    json.dump(payload, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
