#!/usr/bin/env python3
"""
upload_to_roblox.py
Uploads generated pet images to Roblox CDN via Open Cloud Asset API.
Run: python tools/upload_to_roblox.py
Credentials are loaded from .env.petgen in the project root:
  ROBLOX_API_KEY=<your key>
  ROBLOX_USER_ID=<your user id>   (or ROBLOX_GROUP_ID for group-owned assets)
Get API key from: https://create.roblox.com/credentials (requires Asset:Write permission)
"""

import os
import json
import time
import argparse
import requests
from pathlib import Path

# ──────────────────────────────────────
# Configuration
# ──────────────────────────────────────

ASSETS_DIR = Path(__file__).parent.parent / "assets" / "pets"
ASSET_IDS_FILE = ASSETS_DIR / "pet_asset_ids.json"
ENV_FILE = Path(__file__).parent.parent / ".env.petgen"

ROBLOX_ASSET_API = "https://apis.roblox.com/assets/v1/assets"

# Rate limit: be conservative (Roblox limits vary by tier)
UPLOAD_DELAY = 2  # seconds between uploads (polling already adds ~5-15s per image)


def load_env_file() -> dict:
    """Load key=value pairs from .env.petgen, ignoring blank lines and comments."""
    env = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, _, val = line.partition("=")
                env[key.strip()] = val.strip()
    return env


def load_asset_ids() -> dict:
    """Load existing asset ID mapping."""
    if ASSET_IDS_FILE.exists():
        return json.loads(ASSET_IDS_FILE.read_text())
    return {}


def save_asset_ids(asset_ids: dict):
    """Save asset ID mapping."""
    ASSET_IDS_FILE.write_text(json.dumps(asset_ids, indent=2, sort_keys=True))


def upload_image(api_key: str, creator_id: str, creator_type: str,
                 image_path: Path, display_name: str) -> str | None:
    """
    Upload an image to Roblox CDN via Open Cloud Asset API.
    Returns the asset ID string (e.g., "rbxassetid://12345678") or None on failure.
    """
    headers = {
        "x-api-key": api_key,
    }

    # The creation request metadata
    # userId/groupId must be integers per the Open Cloud spec
    creator_id_int = int(creator_id)
    request_body = {
        "assetType": "Decal",
        "displayName": display_name[:50],  # Max 50 chars
        "description": f"Wynkpets pet image: {display_name}",
        "creationContext": {
            "creator": {
                "userId": creator_id_int if creator_type == "User" else None,
                "groupId": creator_id_int if creator_type == "Group" else None,
            }
        },
    }

    # Remove None values from creator
    request_body["creationContext"]["creator"] = {
        k: v for k, v in request_body["creationContext"]["creator"].items()
        if v is not None
    }

    try:
        with open(image_path, "rb") as f:
            files = {
                "request": (None, json.dumps(request_body), "application/json"),
                "fileContent": (image_path.name, f, "image/png"),
            }

            response = requests.post(
                ROBLOX_ASSET_API,
                headers=headers,
                files=files,
            )

        if response.status_code == 200:
            result = response.json()
            # The API returns an async Operation object with operationId.
            # We must poll it to get the real integer assetId.
            op_id = result.get("operationId") or result.get("path", "").split("/")[-1]
            if op_id and "-" in op_id:  # valid UUID
                return poll_operation(api_key, op_id)

            # Fallback: direct assetId in response (rare)
            asset_id = result.get("assetId")
            if asset_id:
                return f"rbxassetid://{asset_id}"

            print(f"  Unexpected response: {result}")
            return None

        elif response.status_code == 400:
            error = response.json()
            print(f"  Bad request: {error}")
            return None
        elif response.status_code == 429:
            print(f"  Rate limited! Waiting 60s...")
            time.sleep(60)
            return upload_image(api_key, creator_id, creator_type, image_path, display_name)
        else:
            print(f"  HTTP {response.status_code}: {response.text[:200]}")
            return None

    except Exception as e:
        print(f"  Upload error: {e}")
        return None


def poll_operation(api_key: str, operation_id: str, max_attempts: int = 30) -> str | None:
    """Poll an async operation until it completes and return the real integer asset ID."""
    headers = {"x-api-key": api_key}
    # operation_id is the UUID portion (e.g., "e6423a97-2b96-47ad-9138-8059f628b6cf")
    url = f"https://apis.roblox.com/assets/v1/operations/{operation_id}"

    for attempt in range(max_attempts):
        time.sleep(2)
        try:
            response = requests.get(url, headers=headers)
            if response.status_code == 200:
                result = response.json()
                if result.get("done"):
                    # assetId is a string like "91378944616414" in response.assetId
                    inner = result.get("response", {})
                    asset_id = inner.get("assetId")
                    if asset_id:
                        return f"rbxassetid://{asset_id}"
                    print(f"  Poll done but no assetId found: {result}")
                    return None
                # Not done yet, keep polling
            elif response.status_code == 429:
                print(f"  Poll rate limited, waiting 30s...")
                time.sleep(30)
            elif response.status_code == 404:
                print(f"  Poll 404: operation not found. Wrong URL or expired op.")
                return None
            else:
                print(f"  Poll HTTP {response.status_code}: {response.text[:100]}")
        except Exception as e:
            print(f"  Poll error: {e}")

    print(f"  Operation timed out after {max_attempts} attempts")
    return None


def main():
    parser = argparse.ArgumentParser(description="Upload pet PNGs to Roblox assets")
    parser.add_argument(
        "--force-all",
        action="store_true",
        help="Re-upload every PNG and overwrite existing IDs",
    )
    parser.add_argument(
        "--force-keys",
        nargs="*",
        default=[],
        help="Re-upload only these PNG stems (e.g. bunny bunny_golden)",
    )
    args = parser.parse_args()

    # Load credentials from .env.petgen (falls back to environment variables)
    env = load_env_file()
    api_key = env.get("ROBLOX_API_KEY") or os.environ.get("ROBLOX_API_KEY")
    if not api_key:
        print("ERROR: ROBLOX_API_KEY not found.")
        print(f"  Add it to {ENV_FILE}:")
        print("    ROBLOX_API_KEY=your_key_here")
        print("  Get a key from: https://create.roblox.com/credentials")
        print("  Required permission: Asset:Write")
        exit(1)

    group_id  = env.get("ROBLOX_GROUP_ID")  or os.environ.get("ROBLOX_GROUP_ID")
    user_id   = env.get("ROBLOX_USER_ID")   or os.environ.get("ROBLOX_USER_ID")
    creator_id   = group_id or user_id
    creator_type = "Group" if group_id else "User"
    if not creator_id:
        print("ERROR: ROBLOX_USER_ID or ROBLOX_GROUP_ID not found.")
        print(f"  Add to {ENV_FILE}:")
        print("    ROBLOX_USER_ID=your_numeric_id")
        exit(1)

    # Find all PNG files to upload
    if not ASSETS_DIR.exists():
        print(f"ERROR: Assets directory not found: {ASSETS_DIR}")
        print("  Run generate_pet_images.py first!")
        exit(1)

    png_files = sorted(ASSETS_DIR.glob("*.png"))
    if not png_files:
        print("No PNG files found to upload!")
        exit(1)

    # Load existing mappings
    asset_ids = load_asset_ids()

    # Filter to only files that haven't been uploaded successfully yet.
    # A valid entry has no hyphens (integer ID) and is not the placeholder "0".
    def is_valid_id(val: str) -> bool:
        if not val:
            return False
        numeric = val.replace("rbxassetid://", "")
        return numeric.isdigit() and numeric != "0"

    force_key_set = {k.strip() for k in args.force_keys if k and k.strip()}
    to_upload = []
    for png in png_files:
        key = png.stem  # e.g., "whiskerling", "whiskerling_golden"
        if args.force_all:
            to_upload.append(png)
        elif force_key_set:
            if key in force_key_set:
                to_upload.append(png)
        elif not is_valid_id(asset_ids.get(key, "")):
            to_upload.append(png)

    if force_key_set:
        available = {p.stem for p in png_files}
        unknown = sorted(force_key_set - available)
        if unknown:
            print("WARNING: force keys not found as PNG files:")
            for k in unknown:
                print(f"  - {k}")

    mode = "normal"
    if args.force_all:
        mode = "force-all"
    elif force_key_set:
        mode = f"force-keys ({len(force_key_set)})"

    print(f"Found {len(png_files)} PNG files, {len(to_upload)} queued for upload [{mode}]")

    if not to_upload:
        print("All images already uploaded!")
        return

    estimated_time = len(to_upload) * UPLOAD_DELAY
    print(f"Estimated time: ~{estimated_time // 60}m {estimated_time % 60}s")
    print(f"Starting upload of {len(to_upload)} images...")

    uploaded = 0
    errors = 0

    for i, png in enumerate(to_upload):
        key = png.stem
        display_name = key.replace("_", " ").title()

        print(f"[{i + 1}/{len(to_upload)}] Uploading {key}...")

        asset_id = upload_image(api_key, creator_id, creator_type, png, display_name)

        if asset_id:
            asset_ids[key] = asset_id
            save_asset_ids(asset_ids)
            uploaded += 1
            print(f"  -> {asset_id}")
        else:
            errors += 1
            print(f"  -> FAILED")

        time.sleep(UPLOAD_DELAY)

    print()
    print(f"Done! Uploaded: {uploaded}, Errors: {errors}")
    print(f"Asset IDs saved to: {ASSET_IDS_FILE}")


if __name__ == "__main__":
    main()
