#!/usr/bin/env python3
"""
audit_brand.py
High-level brand consistency audit for all 366 pet PNGs.

Checks:
  1. COMPLETENESS  — all 366 expected files present
  2. BACKGROUND PURITY — 8 edge/corner sample points must be white
  3. ZONE-GRID SCAN — divides canvas into 7x7 grid; outer ring cells must be
     ≥94% white pixels. Catches floating props, orbs, bubbles, scene elements
     that appear outside the creature's centred silhouette.
  4. MULTI-BLOB DETECTION — counts distinct non-white regions; >1 region
     (after merging nearby pixels) usually means floating objects
  5. COLOUR SATURATION — non-greyscale check (sat > 12)
  6. RESOLUTION — must be 1024×1024

Writes:
  assets/pets/needs_regen.json   — list of {pet_id, variant, reason} to fix
  assets/pets/brand_audit.json   — full per-image results for analysis
"""
import json
import statistics
from collections import deque
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: pip install pillow"); import sys; sys.exit(1)

ASSETS = Path(__file__).parent.parent / "assets" / "pets"
NEEDS_REGEN = ASSETS / "needs_regen.json"
BRAND_AUDIT = ASSETS / "brand_audit.json"

# Thresholds
EDGE_WHITE_MIN       = 240   # 8-point corner/edge check
OUTER_CELL_WHITE_PCT = 94.0  # ≥94% of pixels in each outer grid cell must be white
SATURATION_MIN       = 12    # below this = greyscale
GRID_N               = 7     # 7×7 grid → 28 outer cells, 9 inner, 4 centre
CREATURE_DIAMETER    = 0.65  # creature should occupy at least this fraction of short dimension

def _grid_check(img: Image.Image, n: int = GRID_N) -> tuple[bool, list]:
    """
    Divide image into n×n cells. Check each outer-ring cell for non-white pixels.
    Returns (pass, list_of_failing_cells) where each item is (row, col, white_pct).
    """
    w, h = img.size
    cw, ch = w // n, h // n
    fails = []
    for row in range(n):
        for col in range(n):
            # Only check outer ring
            if row in range(1, n-1) and col in range(1, n-1):
                continue
            # Skip the very corners (already checked elsewhere) — focus on mid-edge
            x0, y0 = col * cw, row * ch
            x1, y1 = x0 + cw, y0 + ch
            region = img.crop((x0, y0, x1, y1)).convert("RGB")
            pixels = list(region.getdata())
            white = sum(1 for r,g,b in pixels if r>237 and g>237 and b>237)
            pct   = white / len(pixels) * 100
            if pct < OUTER_CELL_WHITE_PCT:
                fails.append({"row": row, "col": col, "white_pct": round(pct, 1)})
    return (len(fails) == 0, fails)


def _blob_count(img: Image.Image) -> int:
    """
    Count distinct non-white blobs using flood-fill BFS on a 64×64 downscale.
    Returns the number of separate dark regions found.
    A well-formed image has exactly 1 (the creature).
    Multiple blobs = floating props/orbs.
    """
    small = img.resize((64, 64), Image.LANCZOS).convert("RGB")
    w, h  = small.size
    visited = [[False]*w for _ in range(h)]
    blob_count = 0
    pixels = {}
    for y in range(h):
        for x in range(w):
            r, g, b = small.getpixel((x, y))
            pixels[(x, y)] = (r > 237 and g > 237 and b > 237)  # True = white

    for start_y in range(h):
        for start_x in range(w):
            if visited[start_y][start_x]:
                continue
            if pixels[(start_x, start_y)]:  # skip white
                visited[start_y][start_x] = True
                continue
            # BFS from dark pixel
            blob_count += 1
            queue = deque([(start_x, start_y)])
            visited[start_y][start_x] = True
            size = 0
            while queue:
                cx, cy = queue.popleft()
                size += 1
                for nx, ny in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1),
                               (cx-1,cy-1),(cx+1,cy-1),(cx-1,cy+1),(cx+1,cy+1)]:
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                        visited[ny][nx] = True
                        if not pixels[(nx, ny)]:
                            queue.append((nx, ny))
            # Ignore tiny noise blobs (< 4 px on 64×64 = noise)
            if size < 4:
                blob_count -= 1

    return blob_count


def stem_to_pet_variant(stem: str):
    if stem.endswith("_golden"):  return stem[:-7], "golden"
    if stem.endswith("_rainbow"): return stem[:-8], "rainbow"
    return stem, "base"


# ── Main ──────────────────────────────────────────────────────────────────────
pngs  = sorted(ASSETS.glob("*.png"))
total = len(pngs)
print(f"Images found: {total}/366")

# Completeness check
progress_file = ASSETS / "generation_progress.json"
if progress_file.exists():
    progress = json.loads(progress_file.read_text())
    expected_files = set()
    for k in progress:
        if k.endswith("_golden"):
            expected_files.add(k + ".png")
        elif k.endswith("_rainbow"):
            expected_files.add(k + ".png")
        else:
            expected_files.add((k[:-5] if k.endswith("_base") else k) + ".png")
    on_disk = set(p.name for p in pngs)
    missing = expected_files - on_disk
    if missing:
        print(f"MISSING FILES ({len(missing)}): {sorted(missing)}")
    else:
        print("Completeness ✓ — all expected files present\n")

flagged  = []
results  = []
pass_cnt = 0

for i, png in enumerate(pngs):
    print(f"\r  Auditing [{i+1}/{total}] {png.stem:<38}", end="", flush=True)

    pet_id, variant = stem_to_pet_variant(png.stem)
    img = Image.open(png).convert("RGB")
    w, h = img.size
    issues = []

    # 1. Resolution
    if w != 1024 or h != 1024:
        issues.append(f"resolution({w}x{h})")

    # 2. 8-point edge whiteness
    pts = [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(w//2,h-1),(0,h//2),(w-1,h//2)]
    edge_vals = [sum(img.getpixel(p))/3 for p in pts]
    if min(edge_vals) < EDGE_WHITE_MIN:
        issues.append(f"edge_dark(min={int(min(edge_vals))})")

    # 3. Zone-grid outer-ring scan
    bg_ok, grid_fails = _grid_check(img)
    if not bg_ok:
        worst = min(grid_fails, key=lambda x: x["white_pct"])
        issues.append(f"bg_element(cell={worst['row']},{worst['col']},white={worst['white_pct']}%,n={len(grid_fails)}cells)")

    # 4. Blob count
    blobs = _blob_count(img)
    if blobs > 2:  # allow 2 (creature may have a detached tail/wing)
        issues.append(f"multi_blob({blobs})")

    # 5. Saturation
    small   = img.resize((32,32), Image.LANCZOS)
    pixels  = list(small.getdata())
    coloured = [(r,g,b) for r,g,b in pixels if not (r>240 and g>240 and b>240)]
    sat = statistics.mean(max(r,g,b)-min(r,g,b) for r,g,b in coloured) if coloured else 0
    if sat < SATURATION_MIN:
        issues.append(f"greyscale(sat={int(sat)})")
    if not coloured:
        issues.append("blank(no_creature)")

    ok = len(issues) == 0
    if ok:
        pass_cnt += 1
    else:
        reason = ", ".join(issues)
        flagged.append({"pet_id": pet_id, "variant": variant, "reason": reason})

    results.append({
        "file": png.name, "pet_id": pet_id, "variant": variant,
        "resolution": f"{w}x{h}", "blobs": blobs,
        "edge_min": int(min(edge_vals)), "saturation": int(sat),
        "grid_failing_cells": len(grid_fails) if not bg_ok else 0,
        "issues": issues, "pass": ok,
    })

print(f"\n\n{'='*65}")
print(f"BRAND AUDIT COMPLETE — {total} images analysed")
print(f"{'='*65}")
print(f"  PASS  : {pass_cnt}/{total}")
print(f"  FLAG  : {len(flagged)}/{total}")
print()

# Group by issue type for overview
from collections import Counter
issue_types = Counter()
for r in results:
    for iss in r["issues"]:
        key = iss.split("(")[0]
        issue_types[key] += 1
if issue_types:
    print("Issue breakdown:")
    for k, v in issue_types.most_common():
        print(f"  {k:<25} : {v} images")
    print()

if flagged:
    print(f"Flagged images ({len(flagged)}):")
    for f in flagged:
        print(f"  {f['pet_id']:<30} [{f['variant']:<7}]  {f['reason']}")
    print()
    NEEDS_REGEN.write_text(json.dumps(flagged, indent=2))
    print(f"Written to: {NEEDS_REGEN.name}")
    print(f"\nFix with: python3 tools/generate_pet_images.py --regen-flagged")
else:
    print("All images pass brand audit ✓")
    if NEEDS_REGEN.exists():
        NEEDS_REGEN.unlink()

BRAND_AUDIT.write_text(json.dumps(results, indent=2))
print(f"Full results: {BRAND_AUDIT.name}")
