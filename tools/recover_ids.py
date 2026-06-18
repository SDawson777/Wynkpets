#!/usr/bin/env python3
"""
recover_ids.py
Extracts integer asset IDs from the upload log and merges them into pet_asset_ids.json.
Removes any UUID-format (invalid) entries from the JSON.
"""

import re
import json
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
LOG_FILES = [
    Path("/tmp/roblox_clean.log"),
    Path("/tmp/roblox2.log"),
    Path("/tmp/roblox_upload.log"),
    Path("/tmp/roblox_upload_final.log"),
]
JSON_FILE = REPO_ROOT / "assets" / "pets" / "pet_asset_ids.json"


def extract_from_log(log_path: Path) -> dict:
    """Parse upload log to extract integer asset IDs."""
    if not log_path.exists():
        return {}
    entries = {}
    pending_name = None
    for line in log_path.read_text().splitlines():
        m = re.match(r"\[\d+/\d+\] Uploading (\S+)\.\.\.", line.strip())
        if m:
            pending_name = m.group(1)
            continue
        if pending_name:
            m2 = re.match(r"\s*-> rbxassetid://(\d+)\s*$", line)
            if m2:
                entries[pending_name] = f"rbxassetid://{m2.group(1)}"
                pending_name = None
    return entries


def is_valid(val: str) -> bool:
    numeric = val.replace("rbxassetid://", "")
    return numeric.isdigit() and numeric != "0"


def main():
    # Extract from all log files
    all_entries = {}
    for log in LOG_FILES:
        extracted = extract_from_log(log)
        if extracted:
            print(f"  {log.name}: {len(extracted)} integer IDs")
        all_entries.update(extracted)

    print(f"Total integer IDs from all logs: {len(all_entries)}")

    # Load current JSON
    current = json.loads(JSON_FILE.read_text()) if JSON_FILE.exists() else {}
    print(f"Current JSON entries: {len(current)}")

    # Merge: log IDs override JSON (logs are ground truth)
    current.update(all_entries)

    # Remove UUID-format entries
    before = len(current)
    current = {k: v for k, v in current.items() if is_valid(v)}
    removed = before - len(current)
    if removed:
        print(f"Removed {removed} UUID/invalid entries")

    JSON_FILE.write_text(json.dumps(current, indent=2, sort_keys=True))
    print(f"JSON now has {len(current)} valid integer entries ({270 - len(current)} still need uploading)")


if __name__ == "__main__":
    main()
