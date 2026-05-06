#!/usr/bin/env python3
"""
upload_ui_icons.py
Uploads gamepass and dev-product icon PNGs to Roblox, then patches the Icon
fields in GamepassConfig.luau and DevProductConfig.luau.

Folder layout expected:
    assets/ui/gamepasses/<Id>.png       — one file per gamepass Id
    assets/ui/dev_products/<Id>.png     — one file per dev product Id
    assets/ui/subscriptions/<Id>.png    — basic.png and vip.png

Icon files are matched to config entries by filename stem matching the Id field.
Results are stored in assets/ui/ui_asset_ids.json.

Run: python tools/upload_ui_icons.py
Credentials loaded from .env.petgen (same as upload_to_roblox.py):
    ROBLOX_API_KEY=<key>
    ROBLOX_USER_ID=<id>  or  ROBLOX_GROUP_ID=<id>
"""

import json
import os
import re
import time
import requests
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────
ROOT            = Path(__file__).parent.parent
UI_DIR          = ROOT / "assets" / "ui"
GAMEPASS_DIR      = UI_DIR / "gamepasses"
DEVPRODUCT_DIR    = UI_DIR / "dev_products"
SUBSCRIPTION_DIR  = UI_DIR / "subscriptions"
ASSET_IDS_FILE    = UI_DIR / "ui_asset_ids.json"
ENV_FILE          = ROOT / ".env.petgen"

GAMEPASS_CONFIG      = ROOT / "src" / "shared" / "Configs" / "GamepassConfig.luau"
DEVPRODUCT_CONFIG    = ROOT / "src" / "shared" / "Configs" / "DevProductConfig.luau"
SUBSCRIPTION_CONFIG  = ROOT / "src" / "shared" / "Configs" / "SubscriptionConfig.luau"

ROBLOX_ASSET_API = "https://apis.roblox.com/assets/v1/assets"
UPLOAD_DELAY = 2  # seconds between uploads


# ── Credentials ──────────────────────────────────────────────────────────────

def load_env() -> dict:
    env = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip()
    return env


# ── Asset ID tracking ────────────────────────────────────────────────────────

def load_asset_ids() -> dict:
    if ASSET_IDS_FILE.exists():
        return json.loads(ASSET_IDS_FILE.read_text())
    return {}


def save_asset_ids(ids: dict):
    ASSET_IDS_FILE.write_text(json.dumps(ids, indent=2, sort_keys=True))


def is_valid_id(val: str) -> bool:
    if not val:
        return False
    numeric = val.replace("rbxassetid://", "")
    return numeric.isdigit() and numeric != "0"


# ── Roblox upload helpers (same logic as upload_to_roblox.py) ────────────────

def poll_operation(api_key: str, operation_id: str, max_attempts: int = 30) -> "str | None":
    headers = {"x-api-key": api_key}
    url = f"https://apis.roblox.com/assets/v1/operations/{operation_id}"
    for _ in range(max_attempts):
        time.sleep(2)
        try:
            r = requests.get(url, headers=headers)
            if r.status_code == 200:
                result = r.json()
                if result.get("done"):
                    asset_id = result.get("response", {}).get("assetId")
                    if asset_id:
                        return f"rbxassetid://{asset_id}"
                    return None
            elif r.status_code == 429:
                time.sleep(30)
            elif r.status_code == 404:
                return None
        except Exception as e:
            print(f"  Poll error: {e}")
    return None


def upload_image(api_key: str, creator_id: str, creator_type: str,
                 image_path: Path, display_name: str) -> "str | None":
    headers = {"x-api-key": api_key}
    creator_id_int = int(creator_id)
    creator_dict = {}
    if creator_type == "Group":
        creator_dict["groupId"] = creator_id_int
    else:
        creator_dict["userId"] = creator_id_int

    request_body = {
        "assetType": "Decal",
        "displayName": display_name[:50],
        "description": f"Wynkpets UI icon: {display_name}",
        "creationContext": {"creator": creator_dict},
    }

    try:
        with open(image_path, "rb") as f:
            files = {
                "request": (None, json.dumps(request_body), "application/json"),
                "fileContent": (image_path.name, f, "image/png"),
            }
            r = requests.post(ROBLOX_ASSET_API, headers=headers, files=files)

        if r.status_code == 200:
            result = r.json()
            op_id = result.get("operationId") or result.get("path", "").split("/")[-1]
            if op_id and "-" in op_id:
                return poll_operation(api_key, op_id)
            asset_id = result.get("assetId")
            if asset_id:
                return f"rbxassetid://{asset_id}"
            print(f"  Unexpected response: {result}")
            return None
        elif r.status_code == 429:
            print("  Rate limited! Waiting 60s...")
            time.sleep(60)
            return upload_image(api_key, creator_id, creator_type, image_path, display_name)
        else:
            print(f"  HTTP {r.status_code}: {r.text[:200]}")
            return None
    except Exception as e:
        print(f"  Upload error: {e}")
        return None


# ── Config patchers ──────────────────────────────────────────────────────────

def patch_icon_field(config_path: Path, id_value: str, new_icon: str) -> bool:
    """
    Replace Icon = "rbxassetid://..." inside the entry block that contains
    Id = "<id_value>" with new_icon.  Returns True if a replacement was made.
    """
    content = config_path.read_text()

    # Find the entry block for this Id
    pattern = re.compile(
        r'(Id\s*=\s*"' + re.escape(id_value) + r'".*?'
        r'Icon\s*=\s*"[^"]*")',
        re.DOTALL,
    )

    def replacer(m):
        return re.sub(r'Icon\s*=\s*"[^"]*"', f'Icon = "{new_icon}"', m.group(0))

    new_content, count = pattern.subn(replacer, content)
    if count > 0:
        config_path.write_text(new_content)
        return True
    return False


def update_config(config_path: Path, asset_ids: dict, prefix: str):
    """Update all Icon fields in a config file using asset_ids keyed by prefix_<Id>."""
    updated = 0
    content = config_path.read_text()
    # Extract every Id = "..." to know which entries exist
    ids_in_config = re.findall(r'Id\s*=\s*"([^"]+)"', content)
    for entry_id in ids_in_config:
        key = f"{prefix}_{entry_id}"
        icon_id = asset_ids.get(key)
        if icon_id and is_valid_id(icon_id):
            if patch_icon_field(config_path, entry_id, icon_id):
                print(f"  {entry_id} → {icon_id}")
                updated += 1
    return updated


def patch_icon_image_field(config_path: Path, id_value: str, new_icon: str) -> bool:
    """
    Replace IconImage = "rbxassetid://..." inside the entry block that contains
    Id = "<id_value>".  Used for SubscriptionConfig which uses IconImage, not Icon.
    """
    content = config_path.read_text()
    pattern = re.compile(
        r'(Id\s*=\s*"' + re.escape(id_value) + r'".*?'
        r'IconImage\s*=\s*"[^"]*")',
        re.DOTALL,
    )

    def replacer(m):
        return re.sub(r'IconImage\s*=\s*"[^"]*"', f'IconImage = "{new_icon}"', m.group(0))

    new_content, count = pattern.subn(replacer, content)
    if count > 0:
        config_path.write_text(new_content)
        return True
    return False


def update_subscription_config(asset_ids: dict):
    """Update IconImage fields in SubscriptionConfig.luau."""
    updated = 0
    for tier_id in ("basic", "vip"):
        key = f"subscription_{tier_id}"
        icon_id = asset_ids.get(key)
        if icon_id and is_valid_id(icon_id):
            if patch_icon_image_field(SUBSCRIPTION_CONFIG, tier_id, icon_id):
                print(f"  {tier_id} → {icon_id}")
                updated += 1
    return updated


# ── Upload runner ────────────────────────────────────────────────────────────

def upload_folder(folder: Path, prefix: str, api_key: str,
                  creator_id: str, creator_type: str, asset_ids: dict) -> int:
    pngs = sorted(folder.glob("*.png"))
    if not pngs:
        print(f"  No PNG files found in {folder.relative_to(ROOT)}")
        return 0

    to_upload = [p for p in pngs if not is_valid_id(asset_ids.get(f"{prefix}_{p.stem}", ""))]
    print(f"  {len(pngs)} files found, {len(to_upload)} need uploading")

    uploaded = 0
    for i, png in enumerate(to_upload):
        key = f"{prefix}_{png.stem}"
        display = png.stem.replace("_", " ").title()
        print(f"  [{i+1}/{len(to_upload)}] {png.stem}...", end=" ", flush=True)
        asset_id = upload_image(api_key, creator_id, creator_type, png, display)
        if asset_id:
            asset_ids[key] = asset_id
            save_asset_ids(asset_ids)
            print(f"→ {asset_id}")
            uploaded += 1
        else:
            print("→ FAILED")
        time.sleep(UPLOAD_DELAY)

    return uploaded


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    env = load_env()
    api_key = env.get("ROBLOX_API_KEY") or os.environ.get("ROBLOX_API_KEY")
    if not api_key:
        print(f"ERROR: ROBLOX_API_KEY not found in {ENV_FILE}")
        exit(1)

    group_id  = env.get("ROBLOX_GROUP_ID") or os.environ.get("ROBLOX_GROUP_ID")
    user_id   = env.get("ROBLOX_USER_ID")  or os.environ.get("ROBLOX_USER_ID")
    creator_id   = group_id or user_id
    creator_type = "Group" if group_id else "User"
    if not creator_id:
        print(f"ERROR: ROBLOX_USER_ID or ROBLOX_GROUP_ID not found in {ENV_FILE}")
        exit(1)

    asset_ids = load_asset_ids()

    # ── Gamepasses ──────────────────────────────────────────────────────────
    print("\n── Gamepasses ─────────────────────────────────────────────────────")
    gp_uploaded = upload_folder(GAMEPASS_DIR, "gamepass", api_key, creator_id, creator_type, asset_ids)

    # ── Dev Products ────────────────────────────────────────────────────────
    print("\n── Dev Products ───────────────────────────────────────────────────")
    dp_uploaded = upload_folder(DEVPRODUCT_DIR, "devproduct", api_key, creator_id, creator_type, asset_ids)

    # ── Subscriptions ───────────────────────────────────────────────────────
    print("\n── Subscriptions ──────────────────────────────────────────────────")
    sub_uploaded = upload_folder(SUBSCRIPTION_DIR, "subscription", api_key, creator_id, creator_type, asset_ids)

    total = gp_uploaded + dp_uploaded + sub_uploaded
    print(f"\nUploaded {total} icon(s).")

    if total == 0 and not any(is_valid_id(v) for v in asset_ids.values()):
        print("No icons uploaded and no existing IDs — configs not patched.")
        return

    # ── Patch configs ────────────────────────────────────────────────────────
    print("\n── Patching GamepassConfig.luau ───────────────────────────────────")
    gp_count = update_config(GAMEPASS_CONFIG, asset_ids, "gamepass")
    print(f"  Updated {gp_count} gamepass icon(s).")

    print("\n── Patching DevProductConfig.luau ─────────────────────────────────")
    dp_count = update_config(DEVPRODUCT_CONFIG, asset_ids, "devproduct")
    print(f"  Updated {dp_count} dev product icon(s).")

    print("\n── Patching SubscriptionConfig.luau ───────────────────────────────")
    sub_count = update_subscription_config(asset_ids)
    print(f"  Updated {sub_count} subscription icon(s).")

    print(f"\nDone! IDs saved to {ASSET_IDS_FILE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
