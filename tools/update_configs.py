#!/usr/bin/env python3
"""
update_configs.py
Reads pet_asset_ids.json and updates PetConfig.luau with real asset IDs.
Also adds GoldenImage and RainbowImage fields to each pet entry.
Run: python tools/update_configs.py
"""

import json
import re
from pathlib import Path

# ──────────────────────────────────────
# Configuration
# ──────────────────────────────────────

ASSETS_DIR = Path(__file__).parent.parent / "assets" / "pets"
ASSET_IDS_FILE = ASSETS_DIR / "pet_asset_ids.json"
PET_CONFIG_PATH = Path(__file__).parent.parent / "src" / "shared" / "Configs" / "PetConfig.luau"
DAILY_ROT_CONFIG_PATH = Path(__file__).parent.parent / "src" / "shared" / "Configs" / "DailyRotationConfig.luau"


def load_asset_ids() -> dict:
    """Load asset ID mapping."""
    if not ASSET_IDS_FILE.exists():
        print(f"ERROR: {ASSET_IDS_FILE} not found!")
        print("  Run upload_to_roblox.py first!")
        exit(1)
    return json.loads(ASSET_IDS_FILE.read_text())


def update_pet_config(asset_ids: dict):
    """Update PetConfig.luau with real asset IDs and variant image fields."""
    lines = PET_CONFIG_PATH.read_text().splitlines()

    updated = 0
    added_variants = 0

    out_lines: list[str] = []
    current_pet_id: str | None = None
    saw_image = False
    saw_golden = False
    saw_rainbow = False
    image_indent = "        "

    def emit_missing_variant_lines():
        nonlocal added_variants
        if not current_pet_id:
            return []

        golden_id = asset_ids.get(f"{current_pet_id}_golden", "rbxassetid://0")
        rainbow_id = asset_ids.get(f"{current_pet_id}_rainbow", "rbxassetid://0")
        add: list[str] = []
        if saw_image and (not saw_golden or not saw_rainbow):
            if not saw_golden:
                add.append(f'{image_indent}GoldenImage = "{golden_id}",')
            if not saw_rainbow:
                add.append(f'{image_indent}RainbowImage = "{rainbow_id}",')
            if add:
                added_variants += 1
        return add

    for line in lines:
        id_match = re.search(r'^\s*Id\s*=\s*"([^"]+)"\s*,\s*$', line)
        if id_match:
            current_pet_id = id_match.group(1)
            saw_image = False
            saw_golden = False
            saw_rainbow = False
            out_lines.append(line)
            continue

        if current_pet_id is not None:
            base_id = asset_ids.get(current_pet_id, "rbxassetid://0")
            golden_id = asset_ids.get(f"{current_pet_id}_golden", "rbxassetid://0")
            rainbow_id = asset_ids.get(f"{current_pet_id}_rainbow", "rbxassetid://0")

            image_match = re.match(r'^(\s*)Image\s*=\s*"[^"]*"\s*,\s*$', line)
            if image_match:
                saw_image = True
                image_indent = image_match.group(1)
                if base_id != "rbxassetid://0":
                    out_lines.append(f'{image_indent}Image = "{base_id}",')
                    updated += 1
                else:
                    out_lines.append(line)
                continue

            golden_match = re.match(r'^(\s*)GoldenImage\s*=\s*"[^"]*"\s*,\s*$', line)
            if golden_match:
                saw_golden = True
                out_lines.append(f'{golden_match.group(1)}GoldenImage = "{golden_id}",')
                continue

            rainbow_match = re.match(r'^(\s*)RainbowImage\s*=\s*"[^"]*"\s*,\s*$', line)
            if rainbow_match:
                saw_rainbow = True
                out_lines.append(f'{rainbow_match.group(1)}RainbowImage = "{rainbow_id}",')
                continue

            # End of a top-level pet block
            if re.match(r'^\s*\},\s*$', line):
                out_lines.extend(emit_missing_variant_lines())
                current_pet_id = None

        out_lines.append(line)

    PET_CONFIG_PATH.write_text("\n".join(out_lines) + "\n")

    print(f"Updated {updated} base image IDs")
    print(f"Added variant fields to {added_variants} pets")
    print(f"Written to: {PET_CONFIG_PATH}")


def update_mutation_config(asset_ids: dict):
    """Update DailyRotationConfig.luau mutation Image fields from pet_asset_ids.json."""
    content = DAILY_ROT_CONFIG_PATH.read_text()

    # Match each mutation entry: { BasePetId = "...", MutationId = "id", ..., Image = "..." }
    # We replace Image = "rbxassetid://..." with the uploaded ID keyed by MutationId
    pattern = re.compile(
        r'(\{\s*BasePetId\s*=\s*"[^"]+",\s*MutationId\s*=\s*"([^"]+)".*?'
        r'Image\s*=\s*")([^"]*?)(")',
        re.DOTALL,
    )

    updated = 0

    def replacer(m):
        nonlocal updated
        mutation_id = m.group(2)
        new_id = asset_ids.get(mutation_id)
        if new_id and new_id != "rbxassetid://0":
            updated += 1
            return m.group(1) + new_id + m.group(4)
        return m.group(0)

    new_content = pattern.sub(replacer, content)
    DAILY_ROT_CONFIG_PATH.write_text(new_content)
    print(f"Updated {updated} mutation Image IDs in DailyRotationConfig.luau")


def main():
    asset_ids = load_asset_ids()
    total_ids = len(asset_ids)

    base_count = sum(1 for k in asset_ids if not k.endswith("_golden") and not k.endswith("_rainbow"))
    golden_count = sum(1 for k in asset_ids if k.endswith("_golden"))
    rainbow_count = sum(1 for k in asset_ids if k.endswith("_rainbow"))

    print(f"Loaded {total_ids} asset IDs:")
    print(f"  Base/mutation: {base_count}, Golden: {golden_count}, Rainbow: {rainbow_count}")
    print()

    update_pet_config(asset_ids)
    print()
    update_mutation_config(asset_ids)
    print()
    print("Done! PetConfig.luau and DailyRotationConfig.luau updated.")


if __name__ == "__main__":
    main()
