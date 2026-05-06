#!/usr/bin/env python3
"""
audit_deep.py
Multi-dimensional quality audit of all pet PNGs:
  1. File count completeness (all 366 expected files present)
  2. File size sanity (tiny = blank, huge = complex scene)
  3. 8-point edge/corner whiteness (strict background check)
  4. Colour saturation (catches greyscale/monochrome renders)
  5. Aspect ratio check (must be 1:1 square)
  6. Resolution check (must be 1024x1024)

Outputs a summary and writes audit_results.json.
"""
import json
import statistics
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: pip install pillow")
    import sys; sys.exit(1)

ASSETS = Path(__file__).parent.parent / "assets" / "pets"
OUT = ASSETS / "audit_results.json"

pngs = sorted(ASSETS.glob("*.png"))
total = len(pngs)
print(f"Images found: {total}/366\n")

# ── Build expected filename set from generation_progress.json ─────────────────
progress_file = ASSETS / "generation_progress.json"
if progress_file.exists():
    progress = json.loads(progress_file.read_text())
    expected_keys = set(progress.keys())
    def key_to_filename(k):
        parts = k.rsplit("_", 1)
        if len(parts) == 2 and parts[1] in ("golden", "rainbow"):
            return k + ".png"
        return k + "_base.png"  # shouldn't happen with our naming

    # Re-derive expected filenames
    expected_files = set()
    for k in expected_keys:
        if k.endswith("_golden"):
            expected_files.add(k + ".png")
        elif k.endswith("_rainbow"):
            expected_files.add(k + ".png")
        else:
            # Base variants: progress key is "petid_base" → file is "petid.png"
            base_id = k[:-5] if k.endswith("_base") else k
            expected_files.add(base_id + ".png")
    on_disk = set(p.name for p in pngs)
    missing = expected_files - on_disk
    extra = on_disk - expected_files
    if missing:
        print(f"MISSING FILES ({len(missing)}):")
        for f in sorted(missing):
            print(f"  {f}")
    else:
        print("Completeness: all expected files present ✓")
    if extra:
        print(f"Unexpected extra files: {sorted(extra)}")
    print()

# ── File size audit ────────────────────────────────────────────────────────────
sizes = [p.stat().st_size for p in pngs]
print(f"File sizes: min={min(sizes)//1024}KB  max={max(sizes)//1024}KB  median={int(statistics.median(sizes))//1024}KB")
tiny  = [(p.name, p.stat().st_size) for p in pngs if p.stat().st_size < 50_000]
huge  = [(p.name, p.stat().st_size) for p in pngs if p.stat().st_size > 1_500_000]
if tiny:
    print(f"  TINY (<50KB) — likely blank/corrupt:")
    for n, s in tiny:
        print(f"    {n}: {s//1024}KB")
if huge:
    print(f"  LARGE (>1.5MB) — may have complex scene:")
    for n, s in huge:
        print(f"    {n}: {s//1024}KB")
print()

# ── Per-image checks ──────────────────────────────────────────────────────────
bg_fails       = []
grey_suspects  = []
resolution_bad = []
results        = []

for i, png in enumerate(pngs):
    print(f"\r  Checking [{i+1}/{total}] {png.stem:<35}", end="", flush=True)
    img = Image.open(png).convert("RGB")
    w, h = img.size

    # Resolution
    if w != 1024 or h != 1024:
        resolution_bad.append((png.name, w, h))

    # 8-point edge whiteness
    pts = [
        (0, 0), (w-1, 0), (0, h-1), (w-1, h-1),
        (w//2, 0), (w//2, h-1), (0, h//2), (w-1, h//2),
    ]
    edge_vals = [sum(img.getpixel(p)) / 3 for p in pts]
    edge_min  = min(edge_vals)
    edge_avg  = statistics.mean(edge_vals)
    bg_ok     = edge_min >= 240

    if not bg_ok:
        bg_fails.append((png.name, int(edge_min)))

    # Colour saturation (on downscaled 32x32)
    small   = img.resize((32, 32), Image.LANCZOS)
    pixels  = list(small.getdata())
    coloured = [(r, g, b) for r, g, b in pixels if not (r > 240 and g > 240 and b > 240)]
    if not coloured:
        sat = 0
    else:
        sat = statistics.mean(max(r, g, b) - min(r, g, b) for r, g, b in coloured)

    is_grey = sat < 15
    if is_grey:
        grey_suspects.append((png.name, int(sat)))

    results.append({
        "file": png.name,
        "size_kb": png.stat().st_size // 1024,
        "resolution": f"{w}x{h}",
        "edge_min": int(edge_min),
        "saturation": int(sat),
        "bg_ok": bg_ok,
        "colour_ok": not is_grey,
    })

print(f"\n\n{'='*60}")
print(f"AUDIT COMPLETE — {total} images")
print(f"{'='*60}")
print(f"Background (8-pt edge) ✓: {total - len(bg_fails)}/{total}")
print(f"Colour saturation      ✓: {total - len(grey_suspects)}/{total}")
print(f"Resolution 1024x1024   ✓: {total - len(resolution_bad)}/{total}")
print()

flag_count = len(set([x[0] for x in bg_fails] + [x[0] for x in grey_suspects] + [x[0] for x in resolution_bad]))
print(f"Total images needing attention: {flag_count}")

if bg_fails:
    print(f"\nBackground fails ({len(bg_fails)}):")
    for n, v in sorted(bg_fails, key=lambda x: x[1]):
        print(f"  {n}  edge_min={v}")

if grey_suspects:
    print(f"\nGreyscale/low-colour suspects ({len(grey_suspects)}):")
    for n, s in sorted(grey_suspects, key=lambda x: x[1]):
        print(f"  {n}  sat={s}")

if resolution_bad:
    print(f"\nWrong resolution ({len(resolution_bad)}):")
    for n, w, h in resolution_bad:
        print(f"  {n}  {w}x{h}")

# Save full results
OUT.write_text(json.dumps(results, indent=2))
print(f"\nFull results saved to: {OUT.name}")
