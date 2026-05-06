import json, re

with open("assets/pets/pet_asset_ids.json") as f:
    asset_ids = json.load(f)

with open("src/shared/Configs/PetConfig.luau") as f:
    config_text = f.read()

blocks = re.findall(
    r'Id\s*=\s*"([^"]+)".*?Image\s*=\s*"([^"]*)".*?GoldenImage\s*=\s*"([^"]*)".*?RainbowImage\s*=\s*"([^"]*)"',
    config_text, re.DOTALL
)

placeholder_in_config = []
missing_from_json = []
mismatch = []
orphan_in_json = []

for pet_id, img, gimg, rimg in blocks:
    if img == "rbxassetid://0" or gimg == "rbxassetid://0" or rimg == "rbxassetid://0":
        placeholder_in_config.append(pet_id)
        continue

    for key, val in [(pet_id, img), (pet_id+"_golden", gimg), (pet_id+"_rainbow", rimg)]:
        if key not in asset_ids:
            missing_from_json.append(f"  MISSING from JSON: {key}")
        elif asset_ids[key] != val:
            mismatch.append(f"  MISMATCH {key}:\n    PetConfig = {val}\n    JSON      = {asset_ids[key]}")

config_ids_set = {pid for pid, *_ in blocks}
for key in asset_ids:
    base = key.replace("_golden","").replace("_rainbow","")
    if base not in config_ids_set:
        orphan_in_json.append(f"  {key}")

non_placeholder = len(blocks) - len(placeholder_in_config)

print("=== PLACEHOLDERS (event-exclusive, intentional) ===")
for p in placeholder_in_config:
    print(f"  {p}")

print("\n=== MISSING FROM pet_asset_ids.json ===")
print("\n".join(missing_from_json) if missing_from_json else "  NONE — all uploaded")

print("\n=== ID MISMATCHES (PetConfig vs JSON) ===")
print("\n".join(mismatch) if mismatch else "  NONE — all IDs match exactly")

print("\n=== ORPHAN JSON ENTRIES (in JSON but no matching PetConfig entry) ===")
print("\n".join(orphan_in_json) if orphan_in_json else "  NONE")

print("\n=== SUMMARY ===")
print(f"  Total pet blocks in PetConfig  : {len(blocks)}")
print(f"  Event placeholders (no art yet): {len(placeholder_in_config)}")
print(f"  Pets with real asset IDs       : {non_placeholder}")
print(f"  JSON entries                   : {len(asset_ids)}")
print(f"  Expected JSON entries (3x)     : {non_placeholder * 3}")
ok = (len(missing_from_json) == 0 and len(mismatch) == 0)
print(f"  AUDIT RESULT: {'PASS' if ok else 'FAIL'}")
