#!/usr/bin/env python3
"""Deprecated: animal / legacy roster generator.

Main-path unit content is hand-authored at:
  Documents/Content/UNITS_ROSTER.md

This script no longer writes Documents/UNITS_ROSTER.md.
"""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "generate_units_roster.py is deprecated.\n"
        "Edit Documents/Content/UNITS_ROSTER.md for the realtime unit roster.\n"
        "No file was written.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
