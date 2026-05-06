#!/usr/bin/env python3
"""
generate_art_assets.py
Generates and uploads three types of art assets via DALL-E 3:
  1. Egg art (16 eggs)
  2. Rarity card backgrounds (6 tiers: Common, Rare, Epic, Legendary, Mythic, Secret)
  3. Marketing thumbnail pets (3 hero shots)

Images saved to:
  assets/eggs/         → EggConfig.luau Image fields updated
  assets/ui/rarity/    → JSON sidecar written
  assets/marketing/    → JSON sidecar written

All assets uploaded to Roblox via Open Cloud Asset API.
Run: python tools/generate_art_assets.py
"""

import os
import re
import json
import time
import base64
import requests
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not installed. Run: pip install openai")
    exit(1)

# ─────────────────────────────────────────────────────────────
# Paths & config
# ─────────────────────────────────────────────────────────────
ROOT = Path(__file__).parent.parent
EGGS_DIR       = ROOT / "assets" / "eggs"
RARITY_DIR     = ROOT / "assets" / "ui" / "rarity"
MARKETING_DIR  = ROOT / "assets" / "marketing"
EGG_CONFIG     = ROOT / "src" / "shared" / "Configs" / "EggConfig.luau"
ENV_FILE       = ROOT / ".env.petgen"
PROGRESS_FILE  = Path(__file__).parent / "_art_progress.json"

ROBLOX_ASSET_API = "https://apis.roblox.com/assets/v1/assets"
UPLOAD_DELAY = 2  # seconds between uploads

IMAGE_SIZE    = "1024x1024"
IMAGE_QUALITY = "standard"
MODEL         = "dall-e-3"

for d in [EGGS_DIR, RARITY_DIR, MARKETING_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ─────────────────────────────────────────────────────────────
# Egg definitions
# ─────────────────────────────────────────────────────────────
EGGS = [
    {
        "id": "basic_egg",
        "name": "Basic Egg",
        "zone": "starter_meadow",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Round, slightly lumpy shape. Soft lime-green and sky-blue pastel shell "
            "with tiny leaf and flower petal patterns etched into it. "
            "Gentle golden glow emanating from cracks. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "spotted_egg",
        "name": "Spotted Egg",
        "zone": "starter_meadow",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Cream-white shell covered in colourful polka dots of coral, lavender, and mint. "
            "Glossy, slightly iridescent surface. Subtle sparkle effect. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "forest_egg",
        "name": "Forest Egg",
        "zone": "forest_grove",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Deep oak-brown shell with moss-green patches, tiny mushrooms and acorns embossed on the surface. "
            "Glowing golden runes faintly etched. Mossy forest-floor atmosphere. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "enchanted_egg",
        "name": "Enchanted Egg",
        "zone": "forest_grove",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Emerald and teal shell with swirling magical sigils glowing in soft gold. "
            "Wisps of glittering fairy-dust light float around it. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "crystal_egg",
        "name": "Crystal Egg",
        "zone": "crystal_caves",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Faceted amethyst-purple and ice-blue crystal surface, like a cut gemstone. "
            "Prismatic rainbow light refracts from every facet. Inner glow pulses softly. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "mythic_egg",
        "name": "Mythic Egg",
        "zone": "crystal_caves",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Deep obsidian-black shell with veins of glowing ruby-red and molten gold. "
            "The veins pulse like a heartbeat, crackling with arcane energy. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "magma_egg",
        "name": "Magma Egg",
        "zone": "volcanic_ridge",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Rough volcanic rock exterior with rivers of glowing orange-red lava running through cracks. "
            "Steam wisps rising from surface, ember particles floating around. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "inferno_egg",
        "name": "Inferno Egg",
        "zone": "volcanic_ridge",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Blackened obsidian shell with white-hot cracks burning at the seams. "
            "Intense flame coronas erupt from the top. Radiates heat shimmer. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "frost_egg",
        "name": "Frost Egg",
        "zone": "frozen_tundra",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Smooth arctic-white shell with intricate snowflake patterns etched in pale blue. "
            "Frosted surface with delicate ice crystals growing from it. Soft cold inner glow. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "arctic_egg",
        "name": "Arctic Egg",
        "zone": "frozen_tundra",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Translucent ice-blue shell with aurora-borealis colours swirling inside it. "
            "Thick frost coating on the outside, miniature icicles hanging from the base. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "starlight_egg",
        "name": "Starlight Egg",
        "zone": "celestial_garden",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Midnight-blue shell dusted with gold star-map constellations. "
            "Subtle starlight shimmer glowing from within. Tiny shooting stars circle the shell. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "cosmic_bloom_egg",
        "name": "Cosmic Bloom Egg",
        "zone": "celestial_garden",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Celestial shell blending deep violet and rose-gold, with a blooming cosmic flower design embossed on the surface. "
            "Glowing nebula wisps spiral around it. Radiates warm heavenly light. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "dusk_egg",
        "name": "Dusk Egg",
        "zone": "shadow_realm",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Dark indigo shell with wisps of electric violet shadow mist flowing around it. "
            "Faintly glowing arcane symbols visible through the translucent shell. Mysterious and alluring. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "abyss_egg",
        "name": "Abyss Egg",
        "zone": "shadow_realm",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Near-black egg with bands of deep purple and silver shadow energy crackling around it. "
            "Void tendrils curl outward. Unsettling yet beautiful. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "void_egg",
        "name": "Void Egg",
        "zone": "cosmic_void",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Jet-black shell with swirling neon-cyan and magenta cosmic energy inside, visible through cracks. "
            "Warps light around it slightly. Intense cosmic power feeling. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
    {
        "id": "eternity_egg",
        "name": "Eternity Egg",
        "zone": "cosmic_void",
        "prompt": (
            "A single charming collectible egg for a pet game. "
            "Transcendent egg: pure white blending into black, infinity spiral symbol on the surface. "
            "Reality-warping aura with rainbow fractal energy. The ultimate collectible egg. "
            "Clean white background, centred, 3D render, premium game asset, 1024x1024."
        ),
    },
]

# ─────────────────────────────────────────────────────────────
# Rarity background cards
# ─────────────────────────────────────────────────────────────
RARITY_CARDS = [
    {
        "id": "rarity_common",
        "rarity": "Common",
        "prompt": (
            "A decorative card background for a collectible card game. "
            "Clean, soft grey and white gradient. Subtle brushed-metal texture. "
            "Simple leaf and petal motifs in the corners. Professional game UI feel. "
            "No text, no characters. 1024x1024, portrait orientation."
        ),
    },
    {
        "id": "rarity_rare",
        "rarity": "Rare",
        "prompt": (
            "A decorative card background for a collectible card game. "
            "Deep sapphire-blue gradient with silver filigree patterns. "
            "Subtle diamond shimmer across the surface. Crystal motifs in corners. "
            "No text, no characters. 1024x1024, portrait orientation."
        ),
    },
    {
        "id": "rarity_epic",
        "rarity": "Epic",
        "prompt": (
            "A decorative card background for a collectible card game. "
            "Rich purple-to-violet gradient with glowing arcane runes etched along the border. "
            "Magical aura glow effect around edges. Ornate jewelled corner decorations. "
            "No text, no characters. 1024x1024, portrait orientation."
        ),
    },
    {
        "id": "rarity_legendary",
        "rarity": "Legendary",
        "prompt": (
            "A decorative card background for a collectible card game. "
            "Premium gold and warm amber gradient. Radiant sunburst pattern emanating from centre. "
            "Intricate golden scrollwork border. Rich, opulent premium feel. "
            "No text, no characters. 1024x1024, portrait orientation."
        ),
    },
    {
        "id": "rarity_mythic",
        "rarity": "Mythic",
        "prompt": (
            "A decorative card background for a collectible card game. "
            "Crimson-red and deep rose gradient with shifting holographic rainbow shimmer overlay. "
            "Dragon-scale texture in the background. Epic mythological energy. "
            "No text, no characters. 1024x1024, portrait orientation."
        ),
    },
    {
        "id": "rarity_secret",
        "rarity": "Secret",
        "prompt": (
            "A decorative card background for a collectible card game. "
            "Mysterious galaxy background: deep space black with swirling neon pink and cyan nebula. "
            "Question mark made of stars subtly visible. Reality-fracture cracks along the border. "
            "Unknown, powerful, transcendent energy. No text, no characters. 1024x1024, portrait orientation."
        ),
    },
]

# ─────────────────────────────────────────────────────────────
# Marketing thumbnails
# ─────────────────────────────────────────────────────────────
MARKETING_PETS = [
    {
        "id": "marketing_glowbug",
        "label": "Glowbug Hero",
        "prompt": (
            "Epic marketing hero image for a Roblox pet game. "
            "A luminous firefly-like creature called Glowbug, Legendary Nature type. "
            "Large, glowing, adorable — low-poly vinyl-toy style with oversized jewel eyes. "
            "Surrounded by floating golden light particles and soft green meadow glow. "
            "Dynamic upward-facing pose, arms wide, radiating pure joy. "
            "Cinematic, vibrant, perfect for a game thumbnail. Clean gradient background. "
            "Wynkpets logo space at bottom. 1024x1024."
        ),
    },
    {
        "id": "marketing_cosmicreaper",
        "label": "Cosmic Reaper Hero",
        "prompt": (
            "Epic marketing hero image for a Roblox pet game. "
            "A majestic cosmic entity called Cosmic Reaper, Legendary Cosmic type. "
            "Tall, skeletal-yet-cute vinyl-toy design with glowing star-filled eyes and a flowing nebula cape. "
            "Neon cyan and magenta cosmic energy crackling around it, stars orbiting. "
            "Heroic dramatic pose against a deep space backdrop. "
            "Cinematic, vibrant, perfect for a game thumbnail. Clean dark gradient background. "
            "Wynkpets logo space at bottom. 1024x1024."
        ),
    },
    {
        "id": "marketing_realityshatter",
        "label": "Reality Shatter Hero",
        "prompt": (
            "Epic marketing hero image for a Roblox pet game. "
            "A legendary secret creature called Reality Shatter, the rarest pet in existence. "
            "Ethereal, semi-transparent body made of fracturing reality and kaleidoscopic light. "
            "Reality cracks around it like broken glass revealing rainbow dimensions beneath. "
            "All six rarity-glow colours radiate from its silhouette. "
            "Surrounded by shocked cute pet creatures staring in awe. "
            "Cinematic, vibrant, perfect for a game thumbnail. White-to-black radial gradient background. "
            "Wynkpets logo space at bottom. 1024x1024."
        ),
    },
]

# ─────────────────────────────────────────────────────────────
# Helpers – shared with upload_to_roblox.py pattern
# ─────────────────────────────────────────────────────────────
def load_env() -> dict:
    env = {}
    for src in [ENV_FILE, ROOT / ".env"]:
        if src.exists():
            for line in src.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, _, v = line.partition("=")
                    env[k.strip()] = v.strip()
    return env

def poll_operation(api_key: str, op_id: str, max_attempts: int = 30) -> str | None:
    headers = {"x-api-key": api_key}
    url = f"https://apis.roblox.com/assets/v1/operations/{op_id}"
    for _ in range(max_attempts):
        time.sleep(2)
        try:
            r = requests.get(url, headers=headers)
            if r.status_code == 200:
                data = r.json()
                if data.get("done"):
                    asset_id = data.get("response", {}).get("assetId")
                    if asset_id:
                        return f"rbxassetid://{asset_id}"
                    return None
            elif r.status_code == 429:
                time.sleep(30)
        except Exception as e:
            print(f"    poll error: {e}")
    return None

def upload_image(api_key: str, creator_id: str, creator_type: str,
                 image_path: Path, display_name: str) -> str | None:
    headers = {"x-api-key": api_key}
    creator_id_int = int(creator_id)
    request_body = {
        "assetType": "Decal",
        "displayName": display_name[:50],
        "description": f"Wynkpets asset: {display_name}",
        "creationContext": {
            "creator": {
                "userId": creator_id_int if creator_type == "User" else None,
                "groupId": creator_id_int if creator_type == "Group" else None,
            }
        },
    }
    request_body["creationContext"]["creator"] = {
        k: v for k, v in request_body["creationContext"]["creator"].items() if v is not None
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
            print(f"    Unexpected: {result}")
            return None
        elif r.status_code == 429:
            print("    Rate limited, waiting 60s...")
            time.sleep(60)
            return upload_image(api_key, creator_id, creator_type, image_path, display_name)
        else:
            print(f"    HTTP {r.status_code}: {r.text[:200]}")
            return None
    except Exception as e:
        print(f"    Upload error: {e}")
        return None

def generate_image_b64(client: OpenAI, prompt: str) -> bytes | None:
    """Generate image via DALL-E 3 and return PNG bytes."""
    try:
        response = client.images.generate(
            model=MODEL,
            prompt=prompt,
            size=IMAGE_SIZE,
            quality=IMAGE_QUALITY,
            response_format="b64_json",
            n=1,
        )
        b64 = response.data[0].b64_json
        return base64.b64decode(b64)
    except Exception as e:
        print(f"    DALL-E error: {e}")
        return None

# ─────────────────────────────────────────────────────────────
# EggConfig updater
# ─────────────────────────────────────────────────────────────
def update_egg_config(egg_id: str, asset_id: str):
    """Update Image field for the given egg in EggConfig.luau."""
    text = EGG_CONFIG.read_text(encoding="utf-8")
    pattern = re.compile(
        r'(Id = "' + re.escape(egg_id) + r'".*?Image = )"rbxassetid://\d*"',
        re.DOTALL
    )
    new_text, n = pattern.subn(r'\g<1>"' + asset_id + '"', text, count=1)
    if n == 0:
        print(f"    WARNING: could not find Image field for egg {egg_id}")
    else:
        EGG_CONFIG.write_text(new_text, encoding="utf-8")

# ─────────────────────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────────────────────
def process_batch(label: str, items: list[dict], out_dir: Path,
                  client: OpenAI, api_key: str, creator_id: str, creator_type: str,
                  progress: dict, sidecar_file: Path | None = None,
                  egg_config_update: bool = False):
    print(f"\n{'='*60}")
    print(f" {label} ({len(items)} items)")
    print(f"{'='*60}")

    sidecar: dict = {}
    if sidecar_file and sidecar_file.exists():
        sidecar = json.loads(sidecar_file.read_text())

    for i, item in enumerate(items, 1):
        item_id = item["id"]
        print(f"\n[{i}/{len(items)}] {item.get('name', item.get('label', item_id))}")

        # Already in progress?
        if item_id in progress:
            print(f"  ✓ already done ({progress[item_id]})")
            if egg_config_update and progress[item_id] != "rbxassetid://0":
                update_egg_config(item_id, progress[item_id])
            continue

        img_path = out_dir / f"{item_id}.png"

        # Generate image if not already on disk
        if not img_path.exists():
            print("  Generating image...", end=" ", flush=True)
            png = generate_image_b64(client, item["prompt"])
            if png is None:
                print("FAILED - skipping")
                continue
            img_path.write_bytes(png)
            print("✓")
        else:
            print("  Image already on disk, uploading...")

        # Upload
        print("  Uploading to Roblox...", end=" ", flush=True)
        display_name = item.get("name") or item.get("label") or item_id
        asset_id = upload_image(api_key, creator_id, creator_type, img_path, display_name)

        if asset_id:
            print(f"✓ {asset_id}")
            progress[item_id] = asset_id
            PROGRESS_FILE.write_text(json.dumps(progress, indent=2))
            if egg_config_update:
                update_egg_config(item_id, asset_id)
            # Update sidecar
            sidecar[item_id] = {
                "name": display_name,
                "rarity": item.get("rarity"),
                "assetId": asset_id,
            }
            if sidecar_file:
                sidecar_file.write_text(json.dumps(sidecar, indent=2))
        else:
            print("UPLOAD FAILED")

        time.sleep(UPLOAD_DELAY)

def main():
    env = load_env()
    api_key_openai = os.environ.get("OPENAI_API_KEY") or env.get("OPENAI_API_KEY")
    api_key_roblox = os.environ.get("ROBLOX_API_KEY") or env.get("ROBLOX_API_KEY")
    creator_id = os.environ.get("ROBLOX_USER_ID") or env.get("ROBLOX_USER_ID") or \
                 os.environ.get("ROBLOX_GROUP_ID") or env.get("ROBLOX_GROUP_ID")
    creator_type = "Group" if (env.get("ROBLOX_GROUP_ID") or os.environ.get("ROBLOX_GROUP_ID")) else "User"

    if not api_key_openai:
        print("ERROR: set OPENAI_API_KEY in environment or .env.petgen")
        exit(1)
    if not api_key_roblox or not creator_id:
        print("ERROR: set ROBLOX_API_KEY and ROBLOX_USER_ID (or ROBLOX_GROUP_ID) in .env.petgen")
        exit(1)

    client = OpenAI(api_key=api_key_openai)

    # Load global progress
    progress: dict = {}
    if PROGRESS_FILE.exists():
        progress = json.loads(PROGRESS_FILE.read_text())

    # ── 1. Egg art ───────────────────────────────────────────
    process_batch(
        label="EGG ART",
        items=EGGS,
        out_dir=EGGS_DIR,
        client=client,
        api_key=api_key_roblox,
        creator_id=creator_id,
        creator_type=creator_type,
        progress=progress,
        sidecar_file=EGGS_DIR / "egg_asset_ids.json",
        egg_config_update=True,
    )

    # ── 2. Rarity card backgrounds ───────────────────────────
    process_batch(
        label="RARITY CARD BACKGROUNDS",
        items=RARITY_CARDS,
        out_dir=RARITY_DIR,
        client=client,
        api_key=api_key_roblox,
        creator_id=creator_id,
        creator_type=creator_type,
        progress=progress,
        sidecar_file=RARITY_DIR / "rarity_asset_ids.json",
    )

    # ── 3. Marketing thumbnails ──────────────────────────────
    process_batch(
        label="MARKETING THUMBNAIL PETS",
        items=MARKETING_PETS,
        out_dir=MARKETING_DIR,
        client=client,
        api_key=api_key_roblox,
        creator_id=creator_id,
        creator_type=creator_type,
        progress=progress,
        sidecar_file=MARKETING_DIR / "marketing_asset_ids.json",
    )

    print("\n" + "="*60)
    print("ALL DONE")
    print(f"  Egg images:           {EGGS_DIR}")
    print(f"  Rarity backgrounds:   {RARITY_DIR}")
    print(f"  Marketing thumbnails: {MARKETING_DIR}")
    print(f"  EggConfig.luau updated with new Image fields")
    print("="*60)

if __name__ == "__main__":
    main()
