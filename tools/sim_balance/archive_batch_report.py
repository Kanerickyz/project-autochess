#!/usr/bin/env python3
"""Archive sim batch summary under docs/balancereport/runs/ and update manifest.json."""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


MANIFEST_SCHEMA = "1.0"


def slug_version(version: str) -> str:
    s = re.sub(r"[^0-9A-Za-z._-]+", "-", version.strip())
    return s or "unknown"


def make_run_id(summary: dict, github_sha: str) -> str:
    meta = summary.get("meta") or {}
    generated = str(meta.get("generated_at_utc") or "")
    if generated:
        ts = generated.replace(":", "-").replace(" ", "T")
        if not ts.endswith("Z") and "+" not in ts:
            ts = ts + "Z"
    else:
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    run_count = int(summary.get("run_count") or 0)
    game_version = slug_version(str(summary.get("game_version") or "unknown"))
    sha7 = (github_sha or "local")[:7]
    return f"{ts}_{run_count}runs_v{game_version}_{sha7}"


def load_manifest(path: Path) -> dict:
    if path.is_file():
        with path.open(encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            return data
    return {
        "manifest_schema_version": MANIFEST_SCHEMA,
        "latest_run_id": None,
        "runs": [],
    }


def manifest_entry(run_id: str, summary: dict) -> dict:
    meta = summary.get("meta") or {}
    return {
        "id": run_id,
        "path": f"runs/{run_id}/summary.json",
        "generated_at_utc": meta.get("generated_at_utc")
        or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "game_version": str(summary.get("game_version") or "unknown"),
        "run_count": int(summary.get("run_count") or 0),
        "git_ref": meta.get("git_ref"),
        "github_sha": meta.get("github_sha"),
        "ai_profile_id": meta.get("ai_profile_id") or summary.get("profile_id"),
    }


def enrich_summary(summary_path: Path) -> dict:
    with summary_path.open(encoding="utf-8") as f:
        summary = json.load(f)
    meta = summary.setdefault("meta", {})
    if os.environ.get("GITHUB_REF_NAME"):
        meta["git_ref"] = os.environ["GITHUB_REF_NAME"]
    if os.environ.get("GITHUB_SHA"):
        meta["github_sha"] = os.environ["GITHUB_SHA"][:7]
    if not meta.get("generated_at_utc"):
        meta["generated_at_utc"] = datetime.now(timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
    with summary_path.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    return summary


def archive_batch(batch_dir: Path, repo_root: Path) -> str:
    summary_path = batch_dir / "summary.json"
    if not summary_path.is_file():
        raise SystemExit(f"missing {summary_path}")

    enrich_summary(summary_path)
    with summary_path.open(encoding="utf-8") as f:
        summary = json.load(f)

    run_id = make_run_id(summary, os.environ.get("GITHUB_SHA", ""))
    report_root = repo_root / "docs" / "balancereport"
    run_dir = report_root / "runs" / run_id
    run_dir.mkdir(parents=True, exist_ok=True)

    archived = run_dir / "summary.json"
    archived.write_text(summary_path.read_text(encoding="utf-8"), encoding="utf-8")

    latest_mirror = report_root / "summary.json"
    latest_mirror.write_text(archived.read_text(encoding="utf-8"), encoding="utf-8")

    manifest_path = report_root / "manifest.json"
    manifest = load_manifest(manifest_path)
    manifest["manifest_schema_version"] = MANIFEST_SCHEMA
    entry = manifest_entry(run_id, summary)
    runs: list = manifest.setdefault("runs", [])
    runs = [r for r in runs if r.get("id") != run_id]
    runs.insert(0, entry)
    manifest["runs"] = runs
    manifest["latest_run_id"] = run_id

    with manifest_path.open("w", encoding="utf-8") as f:
        json.dump(manifest, f, indent="\t", ensure_ascii=False)
        f.write("\n")

    return run_id


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("usage: archive_batch_report.py <batch_out_dir> [repo_root]")
    batch_dir = Path(sys.argv[1]).resolve()
    repo_root = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else Path.cwd().resolve()
    run_id = archive_batch(batch_dir, repo_root)
    print(run_id)


if __name__ == "__main__":
    main()
