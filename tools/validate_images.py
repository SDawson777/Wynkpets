#!/usr/bin/env python3
"""
validate_images.py
Scans assets/pets/*.png and flags images that:
  - Have non-white corners (background removal failed)
  - Have near-white centres (creature likely missing / fully erased by rembg)
Outputs a JSON list of pet_id/variant pairs that need regeneration.
"""
import json
import statistics
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: pip install pillow")
    sys.exit(1)

ASSETS = Path(__file__).parent.parent / "assets" / "pets"
OUT_REGEN = ASSETS / "needs_regen.json"

# Thresholds
CORNER_WHITE_MIN = 245   # below this → background not white
CENTRE_CONTENT_MAX = 238 # above this → creature too faint / missing

flagged = []
ok = 0

pngs = sorted(ASSETS.glob("*.png"))
total = len(pngs)

for i, png in enumerate(pngs):
    sys.stdout.write(f"\r  Checking [{i+1}/{total}] {png.stem:<30}")
    sys.stdout.flush()

    img = Image.open(png).convert("RGB")
    w, h = img.size

    corners = [
        img.getpixel((0, 0)),
        img.getpixel((w - 1, 0)),
        img.getpixel((0, h - 1)),
        img.getpixel((w - 1, h - 1)),
    ]
    avg_corner = statistics.mean(sum(c) / 3 for c in corners)

    # Sample centre + a small ring to catch off-centre creatures
    centre_samples = []
    for dx, dy in [(0,0),(w//4,0),(-w//4,0),(0,h//4),(0,-h//4)]:
        cx, cy = w//2 + dx, h//2 + dy
        cx = max(0, min(cx, w-1))
        cy = max(0, min(cy, h-1))
        p = img.getpixel((cx, cy))
        centre_samples.append(sum(p) / 3)
    min_centre = min(centre_samples)  # darkest sample = most likely creature

    bg_ok      = avg_corner >= CORNER_WHITE_MIN
    has_content = min_centre <= CENTRE_CONTENT_MAX

    if bg_ok and has_content:
        ok += 1
    else:
        # Decode filename → pet_id + variant
        stem = png.stem
        if stem.endswith("_golden"):
            pet_id, variant = stem[:-7], "golden"
        elif stem.endswith("_rainbow"):
            pet_id, variant = stem[:-8], "rainbow"
        else:
            pet_id, variant = stem, "base"

        reason = []
        if not bg_ok:
            reason.append(f"bg_dark(corner={int(avg_corner)})")
        if not has_content:
            reason.append(f"creature_missing(centre={int(min_centre)})")
        flagged.append({"pet_id": pet_id, "variant": variant, "reason": ", ".join(reason)})

print(f"\n\nResults: {ok}/{total} OK  |  {len(flagged)} need attention")
print()

if flagged:
    print("Flagged images:")
    for f in flagged:
        print(f"  {f['pet_id']:30s} [{f['variant']:7s}]  {f['reason']}")

    OUT_REGEN.write_text(json.dumps(flagged, indent=2))
    print(f"\nSaved to: {OUT_REGEN}")
    print()
    print("To regenerate only the flagged ones:")
    print("  python3 tools/generate_pet_images.py --regen-flagged")
