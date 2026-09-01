#!/usr/bin/env python3
"""Print CHANGELOG release notes for a version (from ### headings through section end)."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def extract(changelog: str, version: str) -> str:
    lines = changelog.splitlines()
    section_open = False
    notes: list[str] = []

    header = re.compile(rf"^## \[{re.escape(version)}\]")
    next_release = re.compile(r"^## \[")

    for line in lines:
        if header.match(line):
            section_open = True
            continue
        if section_open and next_release.match(line):
            break
        if not section_open:
            continue
        if line.startswith("###"):
            notes.append(line)
        elif notes:
            notes.append(line)

    return "\n".join(notes).strip()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: extract-release-notes.py <version>", file=sys.stderr)
        return 2

    version = sys.argv[1].removeprefix("v")
    changelog_path = Path(__file__).resolve().parents[1] / "CHANGELOG.md"
    text = extract(changelog_path.read_text(encoding="utf-8"), version)
    if not text:
        print(f"no changelog section found for {version}", file=sys.stderr)
        return 1

    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
