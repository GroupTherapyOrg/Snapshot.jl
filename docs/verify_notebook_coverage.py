#!/usr/bin/env python3
"""Fail a docs deployment if featured-notebook interactivity regresses."""

import json
import sys
from pathlib import Path


index_path = Path(sys.argv[1] if len(sys.argv) > 1 else "docs/notebooks-static/index.json")
entries = json.loads(index_path.read_text())

interactive = sum(entry.get("cells_interactive", 0) for entry in entries)
fallback = sum(entry.get("cells_fallback", 0) for entry in entries)
total = sum(entry.get("cells_total", 0) for entry in entries)

# The diagnostic showcase deliberately contains one unsupported cell. Every
# other bound cell in the featured corpus is a release gate.
intentional = {"wasm_diagnostics": 1}
unexpected = {
    entry.get("slug", "<missing>"): entry.get("cells_fallback", 0)
    for entry in entries
    if entry.get("cells_fallback", 0) != intentional.get(entry.get("slug"), 0)
}

expected_total = 106
if total != expected_total or fallback != 1 or interactive != total - fallback or unexpected:
    raise SystemExit(
        "featured-notebook coverage regression: "
        f"{interactive}/{total} interactive, {fallback} fallback, "
        f"unexpected={unexpected}; expected 105/106 with only "
        "wasm_diagnostics carrying one intentional fallback"
    )

print(
    f"featured-notebook coverage certified: {interactive}/{total} interactive; "
    "only wasm_diagnostics has the intentional fallback"
)
