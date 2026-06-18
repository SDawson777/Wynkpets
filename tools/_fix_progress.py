#!/usr/bin/env python3
"""One-off: clean progress.json to only keep entries with actual PNG files on disk."""
import json
from pathlib import Path

ASSETS = Path(__file__).parent.parent / "assets" / "pets"
progress_path = ASSETS / "generation_progress.json"

p = json.loads(progress_path.read_text())

cleaned = {}
for key, val in p.items():
    if not val:
        continue
    if key.endswith("_base"):
        fname = key[:-5] + ".png"
    elif key.endswith("_golden"):
        fname = key[:-7] + "_golden.png"
    elif key.endswith("_rainbow"):
        fname = key[:-8] + "_rainbow.png"
    else:
        fname = key + ".png"

    if (ASSETS / fname).exists():
        cleaned[key] = True

orig = sum(1 for v in p.values() if v)
print(f"Original done: {orig}")
print(f"Cleaned done:  {len(cleaned)}")
print(f"Will regenerate: {orig - len(cleaned)} orphaned entries removed")

progress_path.write_text(json.dumps(cleaned, indent=2))
print("Progress file saved.")
