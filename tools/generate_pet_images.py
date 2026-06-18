#!/usr/bin/env python3
"""
generate_pet_images.py
Generates pet images using OpenAI DALL-E 3 for all pets defined in PetConfig.luau.
Run: python tools/generate_pet_images.py
Run with --force to clear progress and regenerate ALL images from scratch.
Requires: pip install openai
Set OPENAI_API_KEY environment variable before running.
"""

import os
import re
import sys
import json
import time
import urllib.request
from pathlib import Path

# Try to import openai, give helpful error if missing
try:
    from openai import OpenAI
except ImportError:
    OpenAI = None  # will be caught at runtime in main() when not in preview mode

# ──────────────────────────────────────
# Configuration
# ──────────────────────────────────────

ASSETS_DIR = Path(__file__).parent.parent / "assets" / "pets"
PET_CONFIG_PATH = Path(__file__).parent.parent / "src" / "shared" / "Configs" / "PetConfig.luau"
PROGRESS_FILE = ASSETS_DIR / "generation_progress.json"
PET_DESCRIPTIONS_FILE = ASSETS_DIR / "pet_descriptions.json"  # GPT-4-enriched per-pet anatomy briefs

# DALL-E 3 settings
IMAGE_SIZE = "1024x1024"
IMAGE_QUALITY = "hd"   # hd ($0.08/image) — required for consistent collectible quality
MODEL = "dall-e-3"

# ═══════════════════════════════════════════════════════════════════════════════
# MASTER STYLE — the single source of truth for ALL pet icons.
#
# This header is prepended to EVERY prompt regardless of zone, rarity, or variant.
# It locks the art direction so DALL-E produces a visually unified set.
# The IconPrompt in PetConfig contributes ONLY the creature description;
# all style/format/background decisions are made here, not there.
# ═══════════════════════════════════════════════════════════════════════════════

MASTER_STYLE_HEADER = (
    # Pin the reference aesthetic so DALL-E always draws the same type of creature.
    "SUBJECT: a cute fantasy ANIMAL CREATURE — same art style as Pikachu, Axie Infinity, or Stardew Valley pets. "
    "Full-bodied adorable creature with 4 limbs (or fins/wings). "
    "Pokémon GO / Axie Infinity chibi collectible icon. Kawaii blind-box vinyl toy. "
    "Roblox game PET inventory icon. Follow every rule: "

    "BODY: chibi proportions—head 55% of total height, body round and chubby like a Pikachu or Axie, "
    "limbs short/stubby/rounded, zero sharp angles, clean silhouette readable at 32×32px. "

    "EYES (highest priority—dopamine trigger): each eye is a large perfect circle ~28% of head width. "
    "Vivid jewel-coloured iris (sapphire, emerald, ruby, amber, or violet). "
    "Dark pupil. MANDATORY: single bright white star-shaped specular highlight at 10-o'clock inside each pupil. "
    "Eyes must radiate life, warmth, curiosity. No flat/dead/asymmetric eyes. "

    "EXPRESSION: head tilted 10° toward viewer, soft happy smile or cheek-puff, gentle 3/4 angle, "
    "creature looks delighted to be collected. "

    "SURFACE: flat cel-shaded fills, NO photorealistic textures, NO fur/scale detail, "
    "looks like a premium glossy enamel pin or vinyl toy under studio light. "
    "Colours vivid and saturated (Pokémon palette). "

    "BACKGROUND: pure flat white #FFFFFF everywhere—NO gradient, NO floor, NO scenery, NO props. "
    "The 4 canvas CORNERS must be absolutely pure white—never let creature, glow, shadow, or aura "
    "reach the corners. Mandatory minimum 10% white margin at every edge. "

    "LIGHTING: soft fill from upper-left, subtle warm rim light from behind. "

    "COMPOSITION: creature centred, fills 62–68% of square canvas, equal white padding all sides, "
    "tiny soft drop shadow under feet, nothing cropped. All special effects (glow, aura, sparks) "
    "must stay within the creature\'s silhouette boundary—never flood the background white. "

    "FORMAT: square 1:1, crisp anti-aliased edges. "

    "Do NOT include: text, watermark, UI frames, multiple creatures, "
    "coloured background, photorealistic fur/scales. "
    "Roblox-safe, all ages, family-friendly. "
)

MASTER_STYLE_FOOTER = (
    " Checklist: white #FFFFFF background ✓ white highlight dot in each eye ✓ "
    "one creature only ✓ no text ✓. "
    "Displayed at 80×80px—make it IRRESISTIBLY cute and collectable at that size."
)

# ──────────────────────────────────────────────────────────────────────────────
# ZONE ACCENTS — influence creature BODY COLOURS only, not the background.
# The creature's palette should read as belonging to its zone without
# requiring the background to carry that information.
# ──────────────────────────────────────────────────────────────────────────────

ZONE_ACCENTS = {
    "starter_meadow":   (
        "pastel lime-green primary body colour, sky-blue secondary markings, cream-white belly; "
        "cheerful and approachable palette"
    ),
    "forest_grove":     (
        "rich emerald-green primary body colour, warm golden-amber secondary markings, "
        "dark earth-brown accents on paws; enchanted woodland palette"
    ),
    "crystal_caves":    (
        "deep amethyst-purple primary body colour, icy crystalline-blue secondary markings; "
        "small gem-like spikes or horns as surface features on the creature body; prismatic palette. "
        "CRITICAL: all gem/crystal/prismatic effects stay ON the creature body — "
        "background and all 4 canvas corners remain pure white #FFFFFF"
    ),
    "volcanic_ridge":   (
        "deep crimson-red primary body colour, molten orange secondary markings; "
        "glowing ember cracks visible on skin surface; obsidian-dark highlights; volcanic palette"
    ),
    "frozen_tundra":    (
        "pale arctic ice-blue primary body colour, silver-white frost secondary markings; "
        "frost-crystal surface texture on fur or scales (integrated coat pattern, NOT separate floating snowflakes); "
        "crisp cold palette. CRITICAL: all frost/ice effects are ON the creature body surface — "
        "background and all 4 canvas corners remain pure white #FFFFFF"
    ),
    "celestial_garden": (
        "deep midnight-blue primary body colour, gold star-spot markings painted directly on body surface; "
        "soft golden rim-glow contained to the creature silhouette edge only; cosmic celestial palette. "
        "CRITICAL: all star and glow effects stay ON the creature body — "
        "background and all 4 canvas corners remain pure white #FFFFFF"
    ),
    "shadow_realm":     (
        "deep indigo primary body colour, electric violet secondary markings; "
        "wispy dark mist curling only around the creature's feet and paws (NOT spreading to background); "
        "glowing violet rune-like patterns on skin; shadow palette. "
        "CRITICAL: all dark mist/shadow effects stay within the creature boundary—"
        "the 4 canvas corners and all background edges remain pure white #FFFFFF"
    ),
    "cosmic_void":      (
        "near-black deep-space primary body colour, neon cyan and magenta energy secondary markings; "
        "tiny glowing star-dot pattern embedded INTO the body surface (not floating separately); "
        "crackling energy glow contained to silhouette edge only; cosmic void palette. "
        "CRITICAL: all star/void effects stay ON the creature body—"
        "all 4 canvas corners and background remain pure white #FFFFFF"
    ),
}

# ──────────────────────────────────────────────────────────────────────────────
# RARITY FINISHES — applied to the creature's SURFACE only.
# Rarity must be immediately legible at icon size: Common → Secret should feel
# like a clear value ladder, with each tier visually more impressive.
# ──────────────────────────────────────────────────────────────────────────────

RARITY_STYLES = {
    "Common": (
        "Flat matte vinyl surface. Clean solid colours. No special effects. "
        "Baseline tier—approachable and friendly."
    ),
    "Rare": (
        "Satin lacquer sheen. 20% more saturated colours than Common. "
        "Thin coloured glow-line traces the silhouette. Noticeably better than Common."
    ),
    "Epic": (
        "High-gloss resin surface. Deep vivid jewel-tone colours. "
        "Soft colour-matched aura glow rimming the creature silhouette only. "
        "Bright sparkle-fleck highlights embedded on body surface. "
        "Genuinely exciting to receive."
    ),
    "Legendary": (
        "Gleaming gold metallic trim on all edges and features. "
        "Warm gold radiant halo — glow stays within the creature silhouette only. "
        "Rich saturated base colours + gold contrast. "
        "Gold star-shaped highlights embedded on body surface. "
        "Showstopping — must impress any new player."
    ),
    "Mythic": (
        "Iridescent pearl body sheen shifting violet→teal→gold by angle. "
        "Star-galaxy surface PRINT integrated into the body like a tattoo — no floating stars outside the body. "
        "Aurora shimmer tones (pink, green, violet) blended into fur/scale surface texture. "
        "All colour effects are ON the creature body surface — background stays pure white. Supernatural beauty."
    ),
    "Secret": (
        "Crystalline diamond-clear body with rainbow prismatic iridescent surface. "
        "Blazing white-to-rainbow radiance as a body-edge rim-glow only. "
        "Star-pattern and iridescent shimmer integrated INTO the body surface — not separate floating elements. "
        "Full holographic colour-cycle: red→orange→yellow→green→blue→violet on body surface only. "
        "CRITICAL: all sparkle, star, and rainbow effects are ON the creature body — "
        "background and all 4 canvas corners remain pure white #FFFFFF. "
        "Maximum dopamine. Maximum FOMO. The rarest creature in existence."
    ),
}

# Map pet IDs to their zone (derived from EggConfig)
PET_ZONE_MAP = {
    # Zone 1: Starter Meadow
    "whiskerling": "starter_meadow", "puddlejump": "starter_meadow",
    "fluffnose": "starter_meadow", "sparkletail": "starter_meadow",
    "glowbug": "starter_meadow", "dottie": "starter_meadow",
    "specklefoot": "starter_meadow", "patchwhirl": "starter_meadow",
    "shimmerspot": "starter_meadow", "radiantdot": "starter_meadow",
    "prismapaw": "starter_meadow",
    # Zone 2: Forest Grove
    "leafling": "forest_grove", "twigsnap": "forest_grove",
    "mosswhisker": "forest_grove", "thornbloom": "forest_grove",
    "elderoak": "forest_grove", "pixiepuff": "forest_grove",
    "willowisp": "forest_grove", "fernshade": "forest_grove",
    "glimmerfox": "forest_grove", "starweaver": "forest_grove",
    "moonlark": "forest_grove",
    # Zone 3: Crystal Caves
    "gemshard": "crystal_caves", "quartzpaw": "crystal_caves",
    "amethystine": "crystal_caves", "sapphireclaw": "crystal_caves",
    "diamondwing": "crystal_caves", "rubyflare": "crystal_caves",
    "obsidianfang": "crystal_caves", "topazstrike": "crystal_caves",
    "emeraldwyrm": "crystal_caves", "cosmicnova": "crystal_caves",
    # Zone 4: Volcanic Ridge
    "cinderkit": "volcanic_ridge", "scorchpup": "volcanic_ridge",
    "flamefang": "volcanic_ridge", "magmahowl": "volcanic_ridge",
    "volcanowyrm": "volcanic_ridge", "ashmote": "volcanic_ridge",
    "blazeclaw": "volcanic_ridge", "pyronix": "volcanic_ridge",
    "infernotitan": "volcanic_ridge", "moltendrake": "volcanic_ridge",
    # Zone 5: Frozen Tundra
    "snowpuff": "frozen_tundra", "icepaw": "frozen_tundra",
    "frostbite": "frozen_tundra", "glacierheart": "frozen_tundra",
    "blizzardwolf": "frozen_tundra", "sleetstep": "frozen_tundra",
    "hailshard": "frozen_tundra", "permafrost": "frozen_tundra",
    "aurorabear": "frozen_tundra", "absolutezero": "frozen_tundra",
    # Zone 6: Celestial Garden
    "petalwisp": "celestial_garden", "moonbloom": "celestial_garden",
    "stardust": "celestial_garden", "nebulafawn": "celestial_garden",
    "celestialunicorn": "celestial_garden", "astralsprout": "celestial_garden",
    "galaxyvine": "celestial_garden", "solarflare": "celestial_garden",
    "cosmosdragon": "celestial_garden", "etherealphoenix": "celestial_garden",
    # Zone 7: Shadow Realm
    "shadowmite": "shadow_realm", "nightcrawl": "shadow_realm",
    "gloomfang": "shadow_realm", "voidhound": "shadow_realm",
    "abyssalking": "shadow_realm", "darkwhisper": "shadow_realm",
    "phantomblade": "shadow_realm", "dreadlord": "shadow_realm",
    "oblivionserpent": "shadow_realm", "shadowmonarch": "shadow_realm",
    # Zone 8: Cosmic Void
    "voidmote": "cosmic_void", "nebulawyrm": "cosmic_void",
    "singularity": "cosmic_void", "quantumwolf": "cosmic_void",
    "cosmicreaper": "cosmic_void", "starforger": "cosmic_void",
    "dimensionweaver": "cosmic_void", "infinitybeast": "cosmic_void",
    "omnigod": "cosmic_void", "realityshatter": "cosmic_void",
    # New Zone: Forest Grove (expansion pets)
    "bunny": "forest_grove", "fox": "forest_grove", "wolf": "forest_grove",
    "mega_bunny": "forest_grove", "mega_fox": "forest_grove", "mega_wolf": "forest_grove",
    "bloom_sprite": "forest_grove", "golden_bunny": "forest_grove",
    # New Zone: Celestial Garden (expansion pets)
    "bird": "celestial_garden", "dragon": "celestial_garden", "phoenix": "celestial_garden",
    "mega_bird": "celestial_garden", "mega_dragon": "celestial_garden", "mega_phoenix": "celestial_garden",
    "storm_pup": "celestial_garden", "golden_dragon": "celestial_garden",
    # New Zone: Frozen Tundra (expansion pets)
    "seal": "frozen_tundra", "shark": "frozen_tundra", "leviathan": "frozen_tundra",
    "mega_seal": "frozen_tundra", "mega_shark": "frozen_tundra", "mega_leviathan": "frozen_tundra",
    "frost_cub": "frozen_tundra", "golden_shark": "frozen_tundra",
    # New Zone: Volcanic Ridge (expansion pets)
    "cat": "volcanic_ridge", "tiger": "volcanic_ridge", "inferno_bear": "volcanic_ridge",
    "mega_cat": "volcanic_ridge", "mega_tiger": "volcanic_ridge", "mega_inferno_bear": "volcanic_ridge",
    "ember_wisp": "volcanic_ridge", "golden_cat": "volcanic_ridge",
}

# ──────────────────────────────────────────────────────────────────────────────
# Style keywords GPT-4 embedded inside the IconPrompt field.
# We strip these so the IconPrompt contributes ONLY the creature description;
# all style/format/background decisions come from MASTER_STYLE_HEADER.
# ──────────────────────────────────────────────────────────────────────────────
_STYLE_STRIP_PHRASES = [
    "Square inventory icon", "Low-poly chubby vinyl-toy creature", "oversized shiny eyes",
    "oversized shiny", "simple matte finish", "clean pastel colours", "clean 2-3 colour palette",
    "transparent background", "centred", "premium collectible game icon", "512x512",
    "game-ready icon", "low-poly", "low poly", "chibi", "cel-shaded",
    "soft satin sheen", "jewel-bright accents", "vivid glossy", "colour aura glow",
    "gold trim accents", "radiant halo glow", "full iridescent pearl sheen",
    "crystalline finish", "rainbow prismatic", "premium and magical feeling",
    "highly readable at small sizes", "Nature element", "Fire element", "Ice element",
    "Crystal element", "Shadow element", "Cosmic element", "Celestial element",
]


def extract_creature_essence(icon_prompt: str, pet_name: str) -> str:
    """Return only the creature description from an IconPrompt.

    IconPrompts were authored by GPT-4 per-pet and contain a mix of:
      - Good: creature name, physical description, personality cues
      - Bad: style instructions that conflict with or repeat MASTER_STYLE_HEADER

    Strategy: take sentences up to (but not including) the first sentence that
    is dominated by style keywords (≥2 hits).  This preserves the creature
    description while discarding the appended style boilerplate.
    """
    # Strip leading "PetName: " prefix
    text = re.sub(r'^[^:]+:\s*', '', icon_prompt).strip()
    sentences = re.split(r'(?<=[.!?])\s+', text)
    clean = []
    for sentence in sentences:
        lower = sentence.lower()
        hits = sum(1 for phrase in _STYLE_STRIP_PHRASES if phrase.lower() in lower)
        if hits >= 1:
            break  # everything from here is style boilerplate
        clean.append(sentence)
    result = " ".join(clean).strip()
    # Fallback: use only the first sentence if everything got stripped
    return result if result else (sentences[0] if sentences else f"A cute creature called {pet_name}.")


def _split_pet_blocks(content: str) -> list[str]:
    """Split Luau table content into individual pet blocks, respecting nested braces.
    Pet entries are at depth 2 (inside the outer PetConfig.Pets = { ... } array).
    """
    blocks = []
    depth = 0
    start = -1
    for i, ch in enumerate(content):
        if ch == "{":
            depth += 1
            if depth == 2:  # Individual pet blocks are depth-2 inside the outer Pets array
                start = i
        elif ch == "}":
            if depth == 2 and start >= 0:
                blocks.append(content[start : i + 1])
            depth -= 1
    return blocks


def parse_pet_config(config_path: Path) -> list[dict]:
    """Parse PetConfig.luau and extract pet data.
    Handles both legacy (Description) and new (ShortLore + IconPrompt) formats.
    Uses brace-safe block splitting so nested PassiveTrait.Description is ignored.
    """
    content = config_path.read_text()
    pets = []

    for block in _split_pet_blocks(content):
        # Use MULTILINE anchors so ^ only matches start-of-line, excluding
        # nested fields like PassiveTrait = {Name="...", Description="..."}
        id_m = re.search(r'^\s*Id\s*=\s*"([^"]+)"', block, re.MULTILINE)
        if not id_m:
            continue
        name_m = re.search(r'^\s*Name\s*=\s*"([^"]+)"', block, re.MULTILINE)
        rarity_m = re.search(r'^\s*Rarity\s*=\s*"([^"]+)"', block, re.MULTILINE)
        power_m = re.search(r'^\s*Power\s*=\s*(\d+)', block, re.MULTILINE)
        if not (name_m and rarity_m and power_m):
            continue

        # Description (legacy format) — top-level only
        desc_m = re.search(r'^\s*Description\s*=\s*"([^"]+)"', block, re.MULTILINE)
        # ShortLore fallback (new format)
        if not desc_m:
            desc_m = re.search(r'^\s*ShortLore\s*=\s*"([^"]+)"', block, re.MULTILINE)
        # IconPrompt (new format — pre-authored DALL-E prompt, preferred for generation)
        icon_prompt_m = re.search(r'^\s*IconPrompt\s*=\s*"([^"]+)"', block, re.MULTILINE)

        if not (desc_m or icon_prompt_m):
            continue

        pet_id = id_m.group(1)
        pets.append({
            "id": pet_id,
            "name": name_m.group(1),
            "rarity": rarity_m.group(1),
            "power": int(power_m.group(1)),
            "description": desc_m.group(1) if desc_m else "",
            "icon_prompt": icon_prompt_m.group(1) if icon_prompt_m else None,
            "zone": PET_ZONE_MAP.get(pet_id, "starter_meadow"),
        })

    return pets


def load_pet_descriptions() -> dict:
    """Load GPT-4-enriched per-pet anatomy descriptions from JSON."""
    if PET_DESCRIPTIONS_FILE.exists():
        return json.loads(PET_DESCRIPTIONS_FILE.read_text())
    return {}


def enrich_descriptions(pets: list[dict], client) -> dict:
    """Call GPT-4-turbo once per pet to generate a rich visual anatomy brief.

    Each brief is 2 sentences max, describes:
      - Body shape, size, and any unique anatomy (ears, tail, horn, etc.)
      - Skin/fur/scale texture and distinctive markings

    Crucially it does NOT include style, background, or format words —
    those come entirely from MASTER_STYLE_HEADER.

    Saves results to PET_DESCRIPTIONS_FILE and returns the dict.
    Cost: ~$0.002 per pet = ~$0.24 for 122 pets total.
    """
    existing = load_pet_descriptions()
    descriptions = dict(existing)  # copy so we can update incrementally

    needs_enrichment = [p for p in pets if p["id"] not in descriptions]
    if not needs_enrichment:
        print(f"All {len(pets)} pets already have enriched descriptions.")
        return descriptions

    print(f"Enriching {len(needs_enrichment)} pets via GPT-4 (~${len(needs_enrichment)*0.002:.2f})...")

    SYSTEM_PROMPT = (
        "You are a character designer for a kawaii chibi collectible game (like Pokémon or Axie Infinity). "
        "Write a visual anatomy brief for a creature icon. "
        "Rules: exactly 2 sentences. Describe only VISUAL ANATOMY: body proportions, unique physical features "
        "(ears, tail, horn, wings, markings, patterns), and any standout trait that makes it recognisable. "
        "Do NOT mention style, art direction, background, game context, or feelings. "
        "Be specific and concrete — a DALL-E artist must be able to draw the creature from your 2 sentences alone."
    )

    for i, pet in enumerate(needs_enrichment):
        # Build a context hint from available data
        name = pet["name"]
        lore = pet.get("description") or extract_creature_essence(pet.get("icon_prompt", ""), name)
        zone_hint = pet["zone"].replace("_", " ")
        rarity = pet["rarity"]

        user_msg = (
            f"Pet name: {name}\n"
            f"Rarity: {rarity}\n"
            f"Zone/theme: {zone_hint}\n"
            f"Lore hint: {lore}\n\n"
            f"Write the 2-sentence visual anatomy brief for {name}."
        )

        try:
            resp = client.chat.completions.create(
                model="gpt-4o-mini",  # cheap + fast; $0.00015/1K input tokens
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user",   "content": user_msg},
                ],
                max_tokens=120,
                temperature=0.7,
            )
            brief = resp.choices[0].message.content.strip()
            descriptions[pet["id"]] = brief
            print(f"  [{i+1}/{len(needs_enrichment)}] {name}: {brief[:80]}...")
        except Exception as exc:
            print(f"  [{i+1}/{len(needs_enrichment)}] {name}: ERROR {exc}")
            # Fall back to lore hint so this pet isn't left empty
            descriptions[pet["id"]] = lore

        # Save incrementally so progress is kept on interrupt
        PET_DESCRIPTIONS_FILE.write_text(json.dumps(descriptions, indent=2))

    print(f"\nEnrichment complete. Saved to {PET_DESCRIPTIONS_FILE.name}")
    return descriptions


def build_prompt(pet: dict, variant: str = "base", enriched: dict | None = None) -> str:
    """Build a DALL-E HD prompt using the locked MASTER_STYLE.

    Priority for creature description (best → fallback):
      1. GPT-4-enriched anatomy brief from pet_descriptions.json
      2. IconPrompt with style boilerplate stripped
      3. Raw description / name fallback

    MASTER_STYLE_HEADER owns ALL style decisions (body shape, eyes, background,
    materials, lighting, composition). The creature description block contributes
    ONLY unique anatomy that differentiates this pet from others.
    """
    # ── Pull enriched descriptions dict if provided ───────────────────────────
    if enriched is None:
        enriched = load_pet_descriptions()

    # ── Creature description (priority order) ────────────────────────────────
    if pet["id"] in enriched:
        creature_desc = enriched[pet["id"]]
    elif pet.get("icon_prompt"):
        creature_desc = extract_creature_essence(pet["icon_prompt"], pet["name"])
    else:
        # Legacy pets without IconPrompt: build from name + description truncated to 2 sentences
        raw = pet.get("description", f"A creature called {pet['name']}.")
        sentences = re.split(r'(?<=[.!?])\s+', raw)
        creature_desc = " ".join(sentences[:2])

    zone_accent  = ZONE_ACCENTS.get(pet["zone"], "vibrant fantasy colours")
    rarity_style = RARITY_STYLES.get(pet["rarity"], "clean matte finish")

    prompt = (
        MASTER_STYLE_HEADER
        + f"CREATURE DESCRIPTION: {creature_desc} "
        + f"COLOUR PALETTE: {zone_accent}. "
        + f"RARITY FINISH: {rarity_style}. "
        + MASTER_STYLE_FOOTER
    )

    # ── Variant overrides ─────────────────────────────────────────────────────
    if variant == "golden":
        prompt += (
            " GOLDEN VARIANT: Replace the creature's entire body colour with gleaming polished gold. "
            "Warm amber metallic sheen, bright gold specular reflections, small golden sparkles "
            "floating around it. The eyes remain their original vivid colour with the white highlight dot. "
            "Body retains its shape and expression — only the material changes to gold."
        )
    elif variant == "rainbow":
        prompt += (
            " RAINBOW VARIANT: The creature's body shimmers with a continuously shifting prismatic rainbow. "
            "Iridescent holographic colour cycling through red, orange, yellow, green, blue, violet across "
            "the surface. Ethereal rainbow glow radiating outward. Eyes are especially brilliant and glowing. "
            "Body retains its shape and expression — only the material becomes holographic rainbow."
        )

    return prompt


def load_progress() -> dict:
    """Load generation progress to enable resuming."""
    if PROGRESS_FILE.exists():
        return json.loads(PROGRESS_FILE.read_text())
    return {}


def save_progress(progress: dict):
    """Save generation progress."""
    PROGRESS_FILE.write_text(json.dumps(progress, indent=2))


# ──────────────────────────────────────────────────────────────────────────────
# POST-PROCESSING — enforces white background and consistent canvas on EVERY
# image after download.  DALL-E 3 cannot produce transparent PNGs; it invents
# a background every time.  This strips whatever background was generated and
# composites the creature onto pure #FFFFFF, giving 100% consistent output.
# ──────────────────────────────────────────────────────────────────────────────

def _has_pillow() -> bool:
    try:
        import PIL  # noqa: F401
        return True
    except ImportError:
        return False


def _remove_bg_numpy(img):
    """
    Background removal using corner-sampled colour threshold.
    Samples 8×8 pixel regions at all four corners to estimate the background
    colour, then marks any pixel within 40 RGB units of that colour as
    transparent.  Works well for the uniform/near-uniform backgrounds DALL-E 3
    typically generates.
    Requires: numpy, Pillow
    """
    import numpy as np
    from PIL import Image

    rgba = np.array(img.convert("RGBA"), dtype=np.uint16)  # uint16 to avoid overflow
    h, w = rgba.shape[:2]
    pad = min(12, h // 8, w // 8)

    # Sample corners — average RGB in each corner block
    corners = [
        rgba[0:pad,       0:pad,       :3].reshape(-1, 3).mean(axis=0),
        rgba[0:pad,       w-pad:w,     :3].reshape(-1, 3).mean(axis=0),
        rgba[h-pad:h,     0:pad,       :3].reshape(-1, 3).mean(axis=0),
        rgba[h-pad:h,     w-pad:w,     :3].reshape(-1, 3).mean(axis=0),
    ]
    bg = np.mean(corners, axis=0)  # estimated background RGB (float)

    # Max channel distance from background colour per pixel
    diff = np.abs(rgba[:, :, :3].astype(np.float32) - bg).max(axis=2)

    # Pixels within threshold → fully transparent
    # Pixels near threshold → soft edge (linear fade)
    HARD   = 30
    SOFT   = 50
    alpha  = rgba[:, :, 3].astype(np.float32)
    alpha[diff < HARD] = 0
    fade   = (diff >= HARD) & (diff < SOFT)
    alpha[fade] = alpha[fade] * ((diff[fade] - HARD) / (SOFT - HARD))
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint16)

    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def post_process_image(image_path: Path) -> bool:
    """
    Enforce visual consistency on a generated image:
      1. Remove background (rembg AI model if installed, otherwise numpy corner-threshold)
      2. Crop tight to creature bounding box
      3. Scale creature to 88% of canvas (6% white padding every side — Pokémon-card standard)
      4. Centre on pure white #FFFFFF 1024×1024 canvas
      5. Save as RGB PNG (no alpha — Roblox Decal-ready)
    Guaranteed white corners regardless of creature colour or zone.
    Returns True on success, False if Pillow is not installed (image left unchanged).
    """
    if not _has_pillow():
        return False
    try:
        from PIL import Image

        img = Image.open(image_path).convert("RGBA")
        canvas_w, canvas_h = img.size  # 1024×1024

        # ── Step 1: background removal ────────────────────────────────────────
        try:
            from rembg import remove as rembg_remove
            foreground = rembg_remove(img)
        except ImportError:
            foreground = _remove_bg_numpy(img)

        # ── Step 2: crop to tight creature bounding box (strips transparent border) ──
        bbox = foreground.getbbox()  # (left, upper, right, lower) of non-transparent pixels
        if bbox:
            creature = foreground.crop(bbox)
        else:
            creature = foreground  # fully transparent — skip (will appear blank)

        # ── Step 3: scale creature to fit within 88% of canvas (6% padding each side) ──
        # This is the key Pokémon-card rule: subject never bleeds to canvas edges.
        # Guarantees all 4 corners are pure white regardless of creature colour.
        PAD = 0.06  # 6% each side → 88% usable area
        max_dim = int(min(canvas_w, canvas_h) * (1.0 - 2 * PAD))
        cw, ch = creature.size
        scale = min(max_dim / cw, max_dim / ch, 1.0)  # never upscale
        new_w = max(1, int(cw * scale))
        new_h = max(1, int(ch * scale))
        if (new_w, new_h) != (cw, ch):
            creature = creature.resize((new_w, new_h), Image.LANCZOS)

        # ── Step 4: composite centred on pure white canvas ────────────────────
        canvas = Image.new("RGBA", (canvas_w, canvas_h), (255, 255, 255, 255))
        paste_x = (canvas_w - new_w) // 2
        paste_y = (canvas_h - new_h) // 2
        canvas.paste(creature, (paste_x, paste_y), mask=creature.split()[3])

        # ── Step 5: save as RGB PNG ───────────────────────────────────────────
        canvas.convert("RGB").save(image_path, "PNG", optimize=True)
        return True

    except Exception as exc:
        print(f"  post-process warning ({image_path.name}): {exc}")
        return False


def _build_fallback_prompt(pet: dict, variant: str) -> str:
    """Ultra-safe minimal prompt used when the full prompt triggers a content policy flag.
    Strips all zone/rarity/description detail — just enough to get a name-accurate chibi icon."""
    # Some pet names trip safety filters even though they're harmless game creatures.
    # Use a neutral alias for those names.
    SAFE_ALIASES = {
        "blazeclaw":   "Firepaws",
        "fox":         "Forest Kitsune",
        "mega_fox":    "Great Forest Spirit",
        "mega_shark":  "Colossus Fish",
        "aurorabear":  "Northern Lights Bear",
        "absolutezero": "Frostpeak",
        "cat":         "Ember Kitten",
        "celestial_herald": "Starwatcher",
        "cosmicnova":  "Starburst Pup",
        "cosmos_herald": "Galactic Scout",
    }
    raw_name = pet.get("name", pet["id"])
    name = SAFE_ALIASES.get(pet.get("id", ""), raw_name)
    variant_suffix = ""
    if variant == "golden":
        variant_suffix = "with a warm golden sheen, gold sparkles"
    elif variant == "rainbow":
        variant_suffix = "with holographic rainbow iridescent colour-shifting surface"
    return (
        f"Cute chibi cartoon fantasy collectible creature called '{name}' {variant_suffix}. "
        "Full-bodied adorable magical animal with 4 limbs, similar to Pikachu or Axie Infinity. "
        "Big sparkling round eyes with tiny white highlight dots. Happy expression. "
        "Round chubby body, short stubby limbs. "
        "Pokémon GO / Axie Infinity icon art style, cel-shaded, vivid colours. "
        "Displayed at icon size 80x80px — maximally cute and collectable. "
        "Pure flat white background #FFFFFF. No text. Family-friendly. Square 1:1."
    )


def generate_image(client: OpenAI, prompt: str, output_path: Path, pet: dict = None, variant: str = "base") -> bool:
    """Generate a single image with DALL-E 3, save to disk, and post-process.
    On content_policy_violation, automatically retries once with a guaranteed-safe minimal prompt."""
    def _call(p: str) -> bool:
        response = client.images.generate(
            model=MODEL,
            prompt=p,
            size=IMAGE_SIZE,
            quality=IMAGE_QUALITY,
            n=1,
        )
        image_url = response.data[0].url
        urllib.request.urlretrieve(image_url, str(output_path))
        post_process_image(output_path)
        print(f"  Saved: {output_path.name}")
        return True

    try:
        return _call(prompt)
    except Exception as e:
        err = str(e)
        # Transient server error — retry once after a short wait
        if "server_error" in err or '"type": "server_error"' in err or "500" in err:
            print(f"  Server error — retrying in 10s...")
            time.sleep(10)
            try:
                return _call(prompt)
            except Exception as e_retry:
                print(f"  ERROR (server retry): {e_retry}")
                return False
        if "content_policy_violation" in err and pet is not None:
            fallback = _build_fallback_prompt(pet, variant)
            print(f"  Policy flag — retrying with safe fallback prompt...")
            try:
                time.sleep(5)
                return _call(fallback)
            except Exception as e2:
                err2 = str(e2)
                if "content_policy_violation" in err2:
                    # Pet name itself may be triggering the filter — strip it
                    zone_colours = {
                        "frozen_tundra": "arctic ice-blue and silver-white",
                        "volcanic_ridge": "crimson red and molten orange",
                        "starter_meadow": "lime-green and sky-blue",
                        "forest_grove": "emerald-green and golden-amber",
                        "crystal_caves": "amethyst-purple and icy crystal-blue",
                        "celestial_garden": "midnight-blue and gold",
                        "shadow_realm": "deep indigo and electric violet",
                        "cosmic_void": "black and neon cyan",
                        "ocean_depths": "ocean-blue and seafoam",
                        "sky_realm": "sky-blue and cloud-white",
                    }
                    zone = pet.get("zone", "")
                    colours = zone_colours.get(zone, "vibrant fantasy colours")
                    variant_sfx = (
                        "with warm golden sheen" if variant == "golden" else
                        "with holographic rainbow iridescent surface" if variant == "rainbow" else ""
                    )
                    safe2 = (
                        f"Cute chibi cartoon fantasy tiny magical collectible creature {variant_sfx}, "
                        f"coloured in {colours}. "
                        "Full-bodied adorable fantasy animal with 4 limbs, similar to Pikachu or an Axie. "
                        "Big round eyes. Happy expression. Round chubby body, stubby limbs. "
                        "Pokémon GO / Axie Infinity icon art style, cel-shaded. "
                        "Pure flat white background. Family-friendly. Square 1:1."
                    )
                    print(f"  Policy flag again — retrying with fully anonymous prompt...")
                    try:
                        time.sleep(5)
                        return _call(safe2)
                    except Exception as e3:
                        print(f"  ERROR (3rd attempt): {e3}")
                        return False
                print(f"  ERROR (retry): {e2}")
                return False
        print(f"  ERROR: {e}")
        return False


def main():
    args = sys.argv[1:]
    force_all       = "--force"         in args or "--force-all" in args
    preview         = "--preview"       in args
    reprocess       = "--reprocess"     in args  # fix backgrounds on existing PNGs, no API calls
    regen_flagged   = "--regen-flagged" in args  # regenerate only needs_regen.json entries
    enrich          = "--enrich"         in args  # call GPT-4o-mini to write per-pet anatomy briefs

    # ── --reprocess: apply post-processing to all existing PNGs for free ──────
    if reprocess:
        pngs = sorted(ASSETS_DIR.glob("*.png"))
        if not pngs:
            print("No PNGs found in", ASSETS_DIR)
            print("Run without --reprocess to generate images first.")
            return
        print(f"Re-processing {len(pngs)} images (no API calls)...")
        if not _has_pillow():
            print("ERROR: Pillow not installed. Run: pip install pillow")
            return
        ok = err = 0
        for i, png in enumerate(pngs):
            sys.stdout.write(f"  [{i+1}/{len(pngs)}] {png.name}\r")
            sys.stdout.flush()
            if post_process_image(png):
                ok += 1
            else:
                err += 1
        print(f"\nDone — {ok} processed, {err} errors.")
        print("Tip: for even cleaner background removal install rembg:")
        print("  pip install rembg onnxruntime")
        return

    # ── --enrich: call GPT-4o-mini to write per-pet visual anatomy briefs ──────
    if enrich:
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            env_file = Path(__file__).parent.parent / ".env.petgen"
            if env_file.exists():
                for line in env_file.read_text().splitlines():
                    if line.startswith("OPENAI_API_KEY="):
                        api_key = line.split("=", 1)[1].strip()
                        break
        if not api_key:
            print("ERROR: Set OPENAI_API_KEY"); exit(1)
        if OpenAI is None:
            print("ERROR: pip install openai"); exit(1)
        client = OpenAI(api_key=api_key)
        ASSETS_DIR.mkdir(parents=True, exist_ok=True)
        pets = parse_pet_config(PET_CONFIG_PATH)
        enrich_descriptions(pets, client)
        print("\nNext: python3 tools/generate_pet_images.py --force")
        return

    # ── API key ───────────────────────────────────────────────────────────────
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        env_file = Path(__file__).parent.parent / ".env.petgen"
        if env_file.exists():
            for line in env_file.read_text().splitlines():
                if line.startswith("OPENAI_API_KEY="):
                    api_key = line.split("=", 1)[1].strip()
                    break
    if not api_key and not preview:
        print("ERROR: Set OPENAI_API_KEY environment variable")
        print("  export OPENAI_API_KEY='sk-...'")
        exit(1)

    if not preview and OpenAI is None:
        print("ERROR: openai package not installed. Run: pip install openai")
        exit(1)

    # ── Output directory ──────────────────────────────────────────────────────
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    # ── Parse pet config ──────────────────────────────────────────────────────
    pets = parse_pet_config(PET_CONFIG_PATH)
    pets_by_id = {p["id"]: p for p in pets}
    print(f"Found {len(pets)} pets in PetConfig.luau")

    # ── --regen-flagged: regenerate only images listed in needs_regen.json ────
    if regen_flagged:
        regen_file = ASSETS_DIR / "needs_regen.json"
        if not regen_file.exists():
            print("No needs_regen.json found. Run: python3 tools/validate_images.py first.")
            return
        flagged = json.loads(regen_file.read_text())
        if not flagged:
            print("needs_regen.json is empty — nothing to regenerate.")
            return

        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            env_file = Path(__file__).parent.parent / ".env.petgen"
            if env_file.exists():
                for line in env_file.read_text().splitlines():
                    if line.startswith("OPENAI_API_KEY="):
                        api_key = line.split("=", 1)[1].strip()
                        break
        if not api_key:
            print("ERROR: Set OPENAI_API_KEY"); exit(1)

        client = OpenAI(api_key=api_key)
        cost = len(flagged) * 0.08
        print(f"Regenerating {len(flagged)} flagged images (~${cost:.2f})...")
        generated = errors = 0
        enriched = load_pet_descriptions()
        for entry in flagged:
            pet_id  = entry["pet_id"]
            variant = entry["variant"]
            pet     = pets_by_id.get(pet_id)
            if not pet:
                print(f"  SKIP (not in PetConfig): {pet_id}")
                continue
            filename    = f"{pet_id}.png" if variant == "base" else f"{pet_id}_{variant}.png"
            output_path = ASSETS_DIR / filename
            print(f"  [{generated+errors+1}/{len(flagged)}] {pet['name']} ({variant})  reason: {entry.get('reason','')}")
            prompt  = build_prompt(pet, variant, enriched=enriched)
            success = generate_image(client, prompt, output_path, pet=pet, variant=variant)
            if success:
                generated += 1
            else:
                errors += 1
            time.sleep(9)
        print(f"\nDone — generated: {generated}, errors: {errors}")
        if errors == 0:
            regen_file.unlink()  # clear the list when all succeed
        return

    # ── --force: backup old progress so all images regenerate ─────────────────
    if force_all:
        print("--force: backing up progress file and resetting — all images will regenerate.")
        if PROGRESS_FILE.exists():
            backup = PROGRESS_FILE.with_suffix(".backup.json")
            PROGRESS_FILE.rename(backup)
            print(f"  Old progress backed up to: {backup.name}")
        progress = {}
    else:
        progress = load_progress()

    # ── --preview: print prompts only, do not call API ────────────────────────
    if preview:
        print("\n── PROMPT PREVIEW (first 3 pets, base variant) ──\n")
        for pet in pets[:3]:
            p = build_prompt(pet, "base")
            print(f"--- {pet['name']} ({pet['rarity']}, {pet['zone']}) ---")
            print(p)
            print()
        return

    # ── Generation planning ───────────────────────────────────────────────────
    client = OpenAI(api_key=api_key)

    variants = ["base", "golden", "rainbow"]
    # HD quality: $0.08/image (1024×1024 dall-e-3 hd)
    COST_PER_IMAGE = 0.08

    total = len(pets) * len(variants)
    done = sum(1 for p in pets for v in variants if progress.get(f"{p['id']}_{v}"))
    remaining = total - done
    estimated_cost = remaining * COST_PER_IMAGE

    print(f"Quality   : {IMAGE_QUALITY} (${COST_PER_IMAGE:.2f}/image)")
    print(f"Progress  : {done}/{total} already done")
    print(f"Remaining : {remaining} images (~${estimated_cost:.2f})")
    print()

    if remaining == 0:
        print("All images already generated! Use --force to regenerate.")
        return

    print(f"Starting generation of {remaining} images (~${estimated_cost:.2f})...")

    generated = 0
    errors = 0
    enriched = load_pet_descriptions()

    for pet in pets:
        for variant in variants:
            key = f"{pet['id']}_{variant}"

            if progress.get(key):
                continue

            filename = f"{pet['id']}.png" if variant == "base" else f"{pet['id']}_{variant}.png"
            output_path = ASSETS_DIR / filename

            # File already on disk but progress not recorded — mark and skip
            if output_path.exists() and not force_all:
                progress[key] = True
                save_progress(progress)
                continue

            print(f"[{generated + errors + 1}/{remaining}] {pet['name']} ({variant}, {pet['rarity']})...")

            prompt = build_prompt(pet, variant, enriched=enriched)
            success = generate_image(client, prompt, output_path, pet=pet, variant=variant)

            if success:
                progress[key] = True
                save_progress(progress)
                generated += 1
            else:
                errors += 1

            # Rate limiting: DALL-E 3 HD allows ~7 req/min on Tier 1 → 9 s gap
            time.sleep(9)

    print()
    print(f"Done! Generated: {generated}, Errors: {errors}")
    print(f"Images saved in: {ASSETS_DIR}")
    if errors:
        print("Re-run the script (without --force) to retry failed images.")


if __name__ == "__main__":
    main()
