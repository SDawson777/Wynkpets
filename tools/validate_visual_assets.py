#!/usr/bin/env python3
"""Validate pet/egg image coverage across config + asset maps.

This script is intentionally read-only and produces a launch-audit summary.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PET_CONFIG = ROOT / "src/shared/Configs/PetConfig.luau"
EGG_CONFIG = ROOT / "src/shared/Configs/EggConfig.luau"
PET_MAP = ROOT / "assets/pets/pet_asset_ids.json"
EGG_MAP = ROOT / "assets/eggs/egg_asset_ids.json"

INVALID_ID = "rbxassetid://0"


def is_valid_asset_id(value: str | None) -> bool:
    if not isinstance(value, str):
        return False
    value = value.strip()
    if not value or value == INVALID_ID:
        return False
    return re.search(r"\d+", value) is not None


def parse_pet_config(text: str) -> list[dict[str, str | None]]:
    pets: list[dict[str, str | None]] = []
    current: dict[str, str | None] | None = None

    for line in text.splitlines():
        match_id = re.search(r'\bId\s*=\s*"([^"]+)"', line)
        if match_id:
            if current:
                pets.append(current)
            current = {
                "Id": match_id.group(1),
                "Image": None,
                "GoldenImage": None,
                "RainbowImage": None,
            }
            continue

        if not current:
            continue

        for field in ("Image", "GoldenImage", "RainbowImage"):
            match_field = re.search(rf'\b{field}\s*=\s*"([^"]*)"', line)
            if match_field:
                current[field] = match_field.group(1)

    if current:
        pets.append(current)

    return [
        pet
        for pet in pets
        if pet["Id"] not in {"GetPet", "GetPetsByEgg", "GetPetsByRarity"}
    ]


def parse_egg_config(text: str) -> list[dict[str, str | None]]:
    eggs: list[dict[str, str | None]] = []
    current: dict[str, str | None] | None = None

    for line in text.splitlines():
        match_id = re.search(r'\bId\s*=\s*"([^"]+)"', line)
        if match_id:
            if current:
                eggs.append(current)
            current = {"Id": match_id.group(1), "Image": None}
            continue

        if not current:
            continue

        match_image = re.search(r'\bImage\s*=\s*"([^"]*)"', line)
        if match_image:
            current["Image"] = match_image.group(1)

    if current:
        eggs.append(current)

    return [egg for egg in eggs if egg["Id"] not in {"GetEgg", "GetEggsByZone"}]


def main() -> int:
    pet_entries = parse_pet_config(PET_CONFIG.read_text())
    egg_entries = parse_egg_config(EGG_CONFIG.read_text())

    pet_map = json.loads(PET_MAP.read_text())
    egg_map = json.loads(EGG_MAP.read_text())

    pet_total = len(pet_entries)
    egg_total = len(egg_entries)

    base_cfg_valid = sum(is_valid_asset_id(pet["Image"]) for pet in pet_entries)
    golden_cfg_valid = sum(is_valid_asset_id(pet["GoldenImage"]) for pet in pet_entries)
    rainbow_cfg_valid = sum(is_valid_asset_id(pet["RainbowImage"]) for pet in pet_entries)

    base_resolved = sum(
        is_valid_asset_id(pet["Image"]) or is_valid_asset_id(pet_map.get(pet["Id"]))
        for pet in pet_entries
    )
    golden_resolved = sum(
        is_valid_asset_id(pet["GoldenImage"])
        or is_valid_asset_id(pet_map.get(f'{pet["Id"]}_golden'))
        or is_valid_asset_id(pet["Image"])
        or is_valid_asset_id(pet_map.get(pet["Id"]))
        for pet in pet_entries
    )
    rainbow_resolved = sum(
        is_valid_asset_id(pet["RainbowImage"])
        or is_valid_asset_id(pet_map.get(f'{pet["Id"]}_rainbow'))
        or is_valid_asset_id(pet["Image"])
        or is_valid_asset_id(pet_map.get(pet["Id"]))
        for pet in pet_entries
    )

    egg_cfg_valid = sum(is_valid_asset_id(egg["Image"]) for egg in egg_entries)
    egg_resolved = sum(
        is_valid_asset_id(egg["Image"])
        or is_valid_asset_id((egg_map.get(egg["Id"]) or {}).get("assetId"))
        for egg in egg_entries
    )

    missing_base = [
        pet["Id"]
        for pet in pet_entries
        if not (is_valid_asset_id(pet["Image"]) or is_valid_asset_id(pet_map.get(pet["Id"])))
    ]
    missing_golden = [
        pet["Id"]
        for pet in pet_entries
        if not (
            is_valid_asset_id(pet["GoldenImage"])
            or is_valid_asset_id(pet_map.get(f'{pet["Id"]}_golden'))
            or is_valid_asset_id(pet["Image"])
            or is_valid_asset_id(pet_map.get(pet["Id"]))
        )
    ]
    missing_rainbow = [
        pet["Id"]
        for pet in pet_entries
        if not (
            is_valid_asset_id(pet["RainbowImage"])
            or is_valid_asset_id(pet_map.get(f'{pet["Id"]}_rainbow'))
            or is_valid_asset_id(pet["Image"])
            or is_valid_asset_id(pet_map.get(pet["Id"]))
        )
    ]
    missing_eggs = [
        egg["Id"]
        for egg in egg_entries
        if not (
            is_valid_asset_id(egg["Image"])
            or is_valid_asset_id((egg_map.get(egg["Id"]) or {}).get("assetId"))
        )
    ]

    print("=== Visual Asset Coverage ===")
    print(f"Pets total: {pet_total}")
    print(f"Pets base config valid: {base_cfg_valid}/{pet_total}")
    print(f"Pets golden config valid: {golden_cfg_valid}/{pet_total}")
    print(f"Pets rainbow config valid: {rainbow_cfg_valid}/{pet_total}")
    print(f"Pets base resolved (config+map): {base_resolved}/{pet_total}")
    print(f"Pets golden resolved (config+map+base fallback): {golden_resolved}/{pet_total}")
    print(f"Pets rainbow resolved (config+map+base fallback): {rainbow_resolved}/{pet_total}")
    print(f"Eggs total: {egg_total}")
    print(f"Eggs config valid: {egg_cfg_valid}/{egg_total}")
    print(f"Eggs resolved (config+map): {egg_resolved}/{egg_total}")
    missing_base_ids = [pet_id for pet_id in missing_base if pet_id is not None]
    missing_golden_ids = [pet_id for pet_id in missing_golden if pet_id is not None]
    missing_rainbow_ids = [pet_id for pet_id in missing_rainbow if pet_id is not None]
    missing_egg_ids = [egg_id for egg_id in missing_eggs if egg_id is not None]

    print("Missing base pet IDs:", ", ".join(missing_base_ids) if missing_base_ids else "none")
    print("Missing golden pet IDs:", ", ".join(missing_golden_ids) if missing_golden_ids else "none")
    print("Missing rainbow pet IDs:", ", ".join(missing_rainbow_ids) if missing_rainbow_ids else "none")
    print("Missing egg IDs:", ", ".join(missing_egg_ids) if missing_egg_ids else "none")

    # ── Rule: no rbxthumb:// in any pet/egg image field ───────────────────────
    # rbxthumb renders 3D cube previews for Decal assets and returns Pending
    # thumbnails for recently uploaded assets. Direct rbxassetid:// must be used.
    rbxthumb_pets = [
        f"{pet['Id']}.{field}={pet[field]}"
        for pet in pet_entries
        for field in ("Image", "GoldenImage", "RainbowImage")
        if isinstance(pet.get(field), str) and "rbxthumb://" in pet[field]
    ]
    rbxthumb_eggs = [
        f"{egg['Id']}.Image={egg['Image']}"
        for egg in egg_entries
        if isinstance(egg.get("Image"), str) and "rbxthumb://" in egg["Image"]
    ]
    if rbxthumb_pets or rbxthumb_eggs:
        print("\n[FAIL] rbxthumb:// detected in image fields (must use rbxassetid:// directly):")
        for x in rbxthumb_pets:
            print(f"  PET {x}")
        for x in rbxthumb_eggs:
            print(f"  EGG {x}")
    else:
        print("rbxthumb:// check: PASS — no rbxthumb in pet/egg configs")

    # ── Rule: no rbxassetid://0 while a direct asset ID exists in the map ─────
    zero_but_have_map = [
        f"{pet['Id']} (map has {pet_map[pet['Id']]})"
        for pet in pet_entries
        if (not is_valid_asset_id(pet.get("Image"))) and is_valid_asset_id(pet_map.get(pet["Id"]))
    ]
    zero_eggs_but_have_map = [
        f"{egg['Id']} (map has {(egg_map.get(egg['Id']) or {}).get('assetId','')})"
        for egg in egg_entries
        if (not is_valid_asset_id(egg.get("Image")))
        and is_valid_asset_id((egg_map.get(egg["Id"]) or {}).get("assetId"))
    ]
    if zero_but_have_map or zero_eggs_but_have_map:
        print("\n[WARN] Config has rbxassetid://0 but asset map has a valid ID (run update_configs.py):")
        for x in zero_but_have_map:
            print(f"  PET {x}")
        for x in zero_eggs_but_have_map:
            print(f"  EGG {x}")
    else:
        print("Zero-ID stale check: PASS — no config zeros where map ID exists")

    failed = bool(
        missing_base_ids or missing_golden_ids or missing_rainbow_ids
        or missing_egg_ids or rbxthumb_pets or rbxthumb_eggs
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
