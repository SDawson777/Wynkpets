#!/usr/bin/env python3
"""
fix_pet_images.py
Correctly injects base, golden, and rainbow asset IDs into PetConfig.luau
using a line-by-line pass that tracks the current pet Id.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent
IDS_FILE = ROOT / "assets" / "pets" / "pet_asset_ids.json"
CONFIG_FILE = ROOT / "src" / "shared" / "Configs" / "PetConfig.luau"

ids = json.loads(IDS_FILE.read_text())
lines = CONFIG_FILE.read_text().splitlines(keepends=True)

current_pet_id = None
out = []
updated = 0

for line in lines:
    # Detect current pet Id
    id_match = re.match(r'\s*Id\s*=\s*"([^"]+)"', line)
    if id_match:
        current_pet_id = id_match.group(1)

    if current_pet_id:
        # Bare Image field (not GoldenImage / RainbowImage)
        img_match = re.match(r'(\s*)Image(\s*=\s*)"rbxassetid://[0-9]*"(.*)', line)
        if img_match and not re.match(r'\s*(Golden|Rainbow)Image', line):
            new_id = ids.get(current_pet_id, "rbxassetid://0")
            line = img_match.group(1) + "Image" + img_match.group(2) + '"' + new_id + '"' + img_match.group(3) + "\n"
            updated += 1

        g_match = re.match(r'(\s*GoldenImage\s*=\s*)"rbxassetid://[0-9]*"(.*)', line)
        if g_match:
            new_id = ids.get(current_pet_id + "_golden", "rbxassetid://0")
            line = g_match.group(1) + '"' + new_id + '"' + g_match.group(2) + "\n"
            updated += 1

        r_match = re.match(r'(\s*RainbowImage\s*=\s*)"rbxassetid://[0-9]*"(.*)', line)
        if r_match:
            new_id = ids.get(current_pet_id + "_rainbow", "rbxassetid://0")
            line = r_match.group(1) + '"' + new_id + '"' + r_match.group(2) + "\n"
            updated += 1

    out.append(line)

CONFIG_FILE.write_text("".join(out))
print(f"Done — updated {updated} image fields across {updated // 3} pet entries")

# Verify
zeros = sum(1 for ln in out if 'rbxassetid://0"' in ln and re.search(r'(Image|GoldenImage|RainbowImage)', ln))
reals = sum(1 for ln in out if re.search(r'rbxassetid://[1-9]', ln))
print(f"  Zero IDs remaining: {zeros}")
print(f"  Real IDs present:   {reals}")
