#!/usr/bin/env python3
"""Fix pet image filenames: case, typos, strays."""
import os, shutil

assets_dir = "assets/pets"
old_dir = os.path.join(assets_dir, "old_images")
fixes = 0
deletes = 0

# 1. Delete stray screenshot
stray = os.path.join(assets_dir, "OpenAI Playground 2026-04-13 at 13.40.10.png")
if os.path.exists(stray):
    os.remove(stray)
    print("DELETED: stray screenshot")
    deletes += 1

# 2. Delete typo duplicate
typo = os.path.join(assets_dir, "storm_pup_gloden.png")
if os.path.exists(typo):
    os.remove(typo)
    print("DELETED: storm_pup_gloden.png (typo)")
    deletes += 1

# 3. Fix leading space
space_file = os.path.join(assets_dir, " tiger_rainbow.png")
if os.path.exists(space_file):
    target = os.path.join(assets_dir, "tiger_rainbow.png")
    if os.path.exists(target):
        os.remove(space_file)
        print("DELETED: ' tiger_rainbow.png' (dup with leading space)")
        deletes += 1
    else:
        os.rename(space_file, target)
        print("RENAMED: ' tiger_rainbow.png' -> tiger_rainbow.png")
        fixes += 1

# 4. Fix patchwhirl_Rainbow
bad_case = os.path.join(assets_dir, "patchwhirl_Rainbow.png")
if os.path.exists(bad_case):
    tmp = bad_case + ".tmp"
    target = os.path.join(assets_dir, "patchwhirl_rainbow.png")
    os.rename(bad_case, tmp)
    os.rename(tmp, target)
    print("RENAMED: patchwhirl_Rainbow.png -> patchwhirl_rainbow.png")
    fixes += 1

# 5. Move -2 duplicates
for f in sorted(os.listdir(assets_dir)):
    if "-2" in f and f.lower().endswith(".png"):
        src = os.path.join(assets_dir, f)
        dst = os.path.join(old_dir, f)
        shutil.move(src, dst)
        print(f"MOVED to old_images: {f}")
        fixes += 1

# 6. Rename .PNG -> .png (two-step for macOS case-insensitive FS)
for f in sorted(os.listdir(assets_dir)):
    if f.endswith(".PNG"):
        src = os.path.join(assets_dir, f)
        tmp = src + ".tmp"
        target = os.path.join(assets_dir, f[:-4] + ".png")
        os.rename(src, tmp)
        os.rename(tmp, target)
        fixes += 1

print(f"\nDone: {fixes} fixes, {deletes} deletes")
pngs = [f for f in os.listdir(assets_dir) if f.endswith(".png")]
PNG_upper = [f for f in os.listdir(assets_dir) if f.endswith(".PNG")]
print(f"Now: {len(pngs)} .png files, {len(PNG_upper)} .PNG remaining")
