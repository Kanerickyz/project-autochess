#!/usr/bin/env python3
"""Read/write SimBanditCheckpoint stats_json inside a .tres (tools/ only)."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def _unescape_tres_string(raw: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(raw):
        ch = raw[i]
        if ch == "\\" and i + 1 < len(raw):
            nxt = raw[i + 1]
            if nxt == "n":
                out.append("\n")
                i += 2
                continue
            if nxt == "t":
                out.append("\t")
                i += 2
                continue
            if nxt == '"':
                out.append('"')
                i += 2
                continue
            if nxt == "\\":
                out.append("\\")
                i += 2
                continue
            out.append(nxt)
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def _escape_for_tres(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def extract_stats_json(tres_text: str) -> dict:
    marker = 'stats_json = "'
    start = tres_text.find(marker)
    if start < 0:
        raise ValueError("stats_json field not found in .tres")
    start += len(marker)
    i = start
    chunks: list[str] = []
    while i < len(tres_text):
        ch = tres_text[i]
        if ch == "\\" and i + 1 < len(tres_text):
            chunks.append(tres_text[i : i + 2])
            i += 2
            continue
        if ch == '"':
            break
        chunks.append(ch)
        i += 1
    raw = "".join(chunks)
    inner = _unescape_tres_string(raw)
    parsed = json.loads(inner)
    if not isinstance(parsed, dict):
        raise ValueError("stats_json is not a JSON object")
    return parsed


def inject_stats_json(tres_text: str, stats: dict) -> str:
    marker = 'stats_json = "'
    start = tres_text.find(marker)
    if start < 0:
        raise ValueError("stats_json field not found in .tres")
    start += len(marker)
    end = start
    while end < len(tres_text):
        ch = tres_text[end]
        if ch == "\\" and end + 1 < len(tres_text):
            end += 2
            continue
        if ch == '"':
            break
        end += 1
    if end >= len(tres_text):
        raise ValueError("unterminated stats_json string")
    pretty = json.dumps(stats, ensure_ascii=False, indent="\t")
    escaped = _escape_for_tres(pretty)
    return tres_text[:start] + escaped + tres_text[end:]


def load_checkpoint(path: Path) -> tuple[str, dict]:
    text = path.read_text(encoding="utf-8")
    return text, extract_stats_json(text)


def save_checkpoint(path: Path, tres_text: str, stats: dict) -> None:
    new_text = inject_stats_json(tres_text, stats)
    path.write_text(new_text, encoding="utf-8")


def cmd_get(args: argparse.Namespace) -> int:
    _, stats = load_checkpoint(Path(args.checkpoint))
    json.dump(stats, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def cmd_set(args: argparse.Namespace) -> int:
    cp = Path(args.checkpoint)
    tres_text, _ = load_checkpoint(cp)
    stats = json.loads(Path(args.stats_json).read_text(encoding="utf-8"))
    if not isinstance(stats, dict):
        raise SystemExit("stats file must be a JSON object")
    save_checkpoint(cp, tres_text, stats)
    return 0


def cmd_init_from_template(args: argparse.Namespace) -> int:
    template = Path(args.template)
    out = Path(args.out)
    stats_src = Path(args.stats_json) if args.stats_json else None
    text = template.read_text(encoding="utf-8")
    if stats_src:
        stats = json.loads(stats_src.read_text(encoding="utf-8"))
    else:
        stats = {}
    if args.policy_id:
        text = re.sub(
            r'^policy_id = ".*"$',
            f'policy_id = "{args.policy_id}"',
            text,
            count=1,
            flags=re.MULTILINE,
        )
    save_checkpoint(out, text, stats)
    return 0


def main() -> int:
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("get")
    g.add_argument("checkpoint")
    g.set_defaults(func=cmd_get)

    s = sub.add_parser("set")
    s.add_argument("checkpoint")
    s.add_argument("stats_json")
    s.set_defaults(func=cmd_set)

    i = sub.add_parser("init")
    i.add_argument("--template", required=True)
    i.add_argument("--out", required=True)
    i.add_argument("--stats-json", default="")
    i.add_argument("--policy-id", default="bandit-v4-cursor")
    i.set_defaults(func=cmd_init_from_template)

    args = p.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
