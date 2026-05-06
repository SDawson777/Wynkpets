#!/usr/bin/env python3
"""
audit_smart.py
Detects genuinely broken images by looking for:
  1. Disconnected floating blobs (orbiting sparkles, props, text fragments
     that rembg kept because they were too large/close to remove)
  2. File-size outliers (>1.1MB often = backdrop that partially survived rembg)
  3. Creature occupies too small a fraction of canvas (creature got erased or is tiny)

Writes flagged list to needs_regen.json with specific reasons.
"""
import json
from pathlib import Path

import numpy as np
from scipy import ndimage

try:
    from PIL import Image
except ImportError:
    print("pip install pillow"); import sys; sys.exit(1)

ASSETS = Path(__file__).parent.parent / "assets" / "pets"
OUT    = ASSETS / "needs_regen.json"
pngs   = sorted(ASSETS.glob("*.png"))
total  = len(pngs)

# ── Tuneable thresholds ──────────────────────────────────────────────────────
BLOB_THRESHOLD      = 200    # pixels darker than this (0-255) are "non-white"
MIN_BLOB_PIXELS     = 400    # ignore blobs smaller than this (anti-aliasing noise)
FLOAT_DIST_PCT      = 0.14   # blob centre must be >14% canvas-width from main blob
FLOAT_TOTAL_PX_MIN  = 8000   # total floating pixel mass must exceed this to flag
FILE_SIZE_WARN_KB   = 1100   # >1.1 MB = likely background element survived rembg
CREATURE_MIN_PCT    = 0.04   # creature must cover ≥4% of canvas

def find_blobs(img_gray_array, threshold=BLOB_THRESHOLD, min_pixels=MIN_BLOB_PIXELS):
    """Fast connected-component labeling using scipy — single scan over the array."""
    mask = img_gray_array < threshold          # True = non-white pixel
    labeled, num_features = ndimage.label(mask)
    if num_features == 0:
        return []

    all_ids = np.arange(1, num_features + 1)

    # Area (pixel count) per label — O(W×H) single pass
    areas = np.bincount(labeled.ravel())[1:]   # index 0 = background

    # Keep only blobs big enough
    large_ids = all_ids[areas >= min_pixels]
    if len(large_ids) == 0:
        return []

    large_areas = areas[large_ids - 1]

    # Centers of mass for large blobs — one pass per kept label (usually few)
    centers = ndimage.center_of_mass(mask, labeled, large_ids)

    # Bounding boxes via find_objects (fast, C-side)
    slices = ndimage.find_objects(labeled)     # list of (yslice, xslice) per label

    blobs = []
    for i, label_id in enumerate(large_ids):
        sl = slices[label_id - 1]
        if sl is None:
            continue
        cy, cx = centers[i]
        blobs.append({
            "count":  int(large_areas[i]),
            "cx":     float(cx),
            "cy":     float(cy),
            "x_min":  sl[1].start, "x_max": sl[1].stop - 1,
            "y_min":  sl[0].start, "y_max": sl[0].stop - 1,
        })
    return blobs

flagged = []
ok = 0

for i, png in enumerate(pngs):
    print(f"\r  [{i+1}/{total}] {png.stem:<35}", end="", flush=True)

    stem = png.stem
    if   stem.endswith("_golden"):  pet_id, variant = stem[:-7], "golden"
    elif stem.endswith("_rainbow"): pet_id, variant = stem[:-8], "rainbow"
    else:                           pet_id, variant = stem,       "base"

    size_kb = png.stat().st_size // 1024
    img     = Image.open(png).convert("RGB")
    w, h    = img.size
    gray_arr = np.array(img.convert("L"))   # numpy array for fast blob detection

    reasons = []

    # ── File size check ──────────────────────────────────────────────────────
    if size_kb > FILE_SIZE_WARN_KB:
        reasons.append(f"large_file({size_kb}KB)")

    # ── Blob analysis ────────────────────────────────────────────────────────
    blobs = find_blobs(gray_arr)

    if not blobs:
        reasons.append("creature_missing")
    else:
        # Main blob = largest by pixel count
        main = max(blobs, key=lambda b: b["count"])
        canvas_area = w * h
        creature_pct = main["count"] / canvas_area

        if creature_pct < CREATURE_MIN_PCT:
            reasons.append(f"creature_tiny({creature_pct*100:.1f}%)")

        # Floating blob check: blobs whose centre is far from main blob centre
        float_blobs = []
        for b in blobs:
            if b is main:
                continue
            dist = ((b["cx"] - main["cx"])**2 + (b["cy"] - main["cy"])**2) ** 0.5
            dist_pct = dist / w
            if dist_pct > FLOAT_DIST_PCT:
                float_blobs.append((b["count"], dist_pct))

        total_float_px = sum(c for c, _ in float_blobs)
        if float_blobs and total_float_px > FLOAT_TOTAL_PX_MIN:
            reasons.append(f"floating_props(n={len(float_blobs)},px={total_float_px})")

    if reasons:
        flagged.append({
            "pet_id":  pet_id,
            "variant": variant,
            "reason":  ", ".join(reasons),
            "size_kb": size_kb,
        })
    else:
        ok += 1

print(f"\n\n{'='*60}")
print(f"SMART AUDIT — {total} images")
print(f"{'='*60}")
print(f"PASS: {ok}/{total}")
print(f"FLAG: {len(flagged)}/{total}")
print()

# Break down by reason type
from collections import Counter
reason_counts = Counter()
for f in flagged:
    for tag in f["reason"].split(","):
        reason_counts[tag.strip().split("(")[0]] += 1
for reason, cnt in reason_counts.most_common():
    print(f"  {reason}: {cnt}")

print()
print("Flagged images:")
for f in sorted(flagged, key=lambda x: x["reason"]):
    print(f"  {f['pet_id']:<30} [{f['variant']:<7}]  {f['reason']}")

OUT.write_text(json.dumps(flagged, indent=2))
print(f"\nWrote: {OUT.name}  ({len(flagged)} entries)")
print(f"Estimated regen cost: ${len(flagged) * 0.08:.2f}")
