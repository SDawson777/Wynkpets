#!/usr/bin/env python3
"""
write_pet_lore.py
Uses GPT-4o to generate long-form Lore for every pet that has Lore = "".
Injects results directly into PetConfig.luau.
Run: python tools/write_pet_lore.py
"""

import os
import re
import json
import time
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("ERROR: openai package not installed. Run: pip install openai")
    exit(1)

# ─────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────
PET_CONFIG_PATH = Path(__file__).parent.parent / "src" / "shared" / "Configs" / "PetConfig.luau"
ENV_FILE = Path(__file__).parent.parent / ".env.petgen"
PROGRESS_FILE = Path(__file__).parent / "_lore_progress.json"
DELAY = 0.5  # seconds between API calls

def load_env() -> dict:
    env = {}
    for src in [ENV_FILE, Path(__file__).parent.parent / ".env"]:
        if src.exists():
            for line in src.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, _, v = line.partition("=")
                    env[k.strip()] = v.strip()
    return env

# ─────────────────────────────────────────────────────────────
# Parse all pets from PetConfig.luau that have Lore = ""
# ─────────────────────────────────────────────────────────────
def parse_pets(text: str) -> list[dict]:
    """Extract Id, Name, Rarity, ShortLore, Lore from PetConfig.luau."""
    pets = []
    # Grab each pet block (between braces after PetConfig.Pets = {)
    block_pattern = re.compile(
        r'Id = "(?P<id>[^"]+)".*?'
        r'Name = "(?P<name>[^"]+)".*?'
        r'Rarity = "(?P<rarity>[^"]+)".*?'
        r'Element = "(?P<element>[^"]+)".*?'
        r'EggSource = "(?P<egg>[^"]+)".*?'
        r'ShortLore = "(?P<short>[^"]*)".*?'
        r'Lore = "(?P<lore>[^"]*)"',
        re.DOTALL
    )
    for m in block_pattern.finditer(text):
        pets.append({
            "id": m.group("id"),
            "name": m.group("name"),
            "rarity": m.group("rarity"),
            "element": m.group("element"),
            "egg": m.group("egg"),
            "short_lore": m.group("short"),
            "lore": m.group("lore"),
        })
    return pets

# ─────────────────────────────────────────────────────────────
# Zone / egg → world description
# ─────────────────────────────────────────────────────────────
EGG_TO_ZONE = {
    "basic_egg": "Starter Meadow",
    "spotted_egg": "Starter Meadow",
    "forest_egg": "Forest Grove",
    "enchanted_egg": "Forest Grove",
    "crystal_egg": "Crystal Caves",
    "mythic_egg": "Crystal Caves",
    "magma_egg": "Volcanic Ridge",
    "inferno_egg": "Volcanic Ridge",
    "frost_egg": "Frozen Tundra",
    "arctic_egg": "Frozen Tundra",
    "starlight_egg": "Celestial Garden",
    "cosmic_bloom_egg": "Celestial Garden",
    "dusk_egg": "Shadow Realm",
    "abyss_egg": "Shadow Realm",
    "void_egg": "Cosmic Void",
    "eternity_egg": "Cosmic Void",
    "secret": "Secret Zone",
}

RARITY_DEPTH = {
    "Common": "2–3 sentences of playful, lighthearted lore.",
    "Rare": "3–4 sentences with a small mystery or charming backstory.",
    "Epic": "4–5 sentences with a compelling legend or origin myth.",
    "Legendary": "5–6 sentences describing a grand, storied history.",
    "Mythic": "6–7 sentences of epic, world-shaking mythology.",
    "Secret": "Already written — skip.",
}

SYSTEM_PROMPT = """You write short in-game creature lore for Wynkpets, a Roblox pet-collection game.
Style: whimsical, warm, imaginative — aimed at all ages. No dark or scary content.
Never break the fourth wall. Never mention Roblox, games, or players.
Write only the requested lore text, no extra commentary, no quotation marks."""

def generate_lore(client: OpenAI, pet: dict) -> str:
    zone = EGG_TO_ZONE.get(pet["egg"], "a mysterious land")
    depth = RARITY_DEPTH.get(pet["rarity"], "3-4 sentences.")
    prompt = (
        f"Write lore for {pet['name']}, a {pet['rarity']} {pet['element']}-type creature "
        f"from {zone}. Summary: {pet['short_lore']} "
        f"Length: {depth} Keep it engaging and appropriate for all ages."
    )
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
        max_tokens=300,
        temperature=0.85,
    )
    return resp.choices[0].message.content.strip()

# ─────────────────────────────────────────────────────────────
# Inject generated lore back into PetConfig.luau
# ─────────────────────────────────────────────────────────────
def inject_lore(text: str, pet_id: str, lore: str) -> str:
    """Replace Lore = "" for the given pet_id (first match after its Id = "...") with the generated lore."""
    # Escape special Lua characters in lore string
    safe = lore.replace("\\", "\\\\").replace('"', '\\"')
    # Find the id marker, then replace the immediately following Lore = ""
    pattern = re.compile(
        r'(Id = "' + re.escape(pet_id) + r'".*?Lore = )"(?P<old>[^"]*)"',
        re.DOTALL
    )
    new_text, count = pattern.subn(r'\1"' + safe + '"', text, count=1)
    if count == 0:
        print(f"  WARNING: could not find Lore field for {pet_id}")
    return new_text

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────
def main():
    env = load_env()
    api_key = os.environ.get("OPENAI_API_KEY") or env.get("OPENAI_API_KEY")
    if not api_key:
        print("ERROR: set OPENAI_API_KEY in environment or .env.petgen")
        exit(1)

    client = OpenAI(api_key=api_key)

    # Load progress (lore already generated)
    progress: dict = {}
    if PROGRESS_FILE.exists():
        progress = json.loads(PROGRESS_FILE.read_text())

    config_text = PET_CONFIG_PATH.read_text(encoding="utf-8")
    pets = parse_pets(config_text)
    print(f"Found {len(pets)} pets total")

    to_write = [p for p in pets if p["lore"] == "" and p["rarity"] != "Secret" and p["id"] not in progress]
    print(f"{len(to_write)} pets need lore\n")

    for i, pet in enumerate(to_write, 1):
        print(f"[{i}/{len(to_write)}] {pet['name']} ({pet['rarity']}) ...", end=" ", flush=True)
        try:
            lore = generate_lore(client, pet)
            progress[pet["id"]] = lore
            # Save progress after every pet
            PROGRESS_FILE.write_text(json.dumps(progress, indent=2, ensure_ascii=False))
            # Inject immediately into current config_text so subsequent regex finds are correct
            config_text = inject_lore(config_text, pet["id"], lore)
            print("✓")
        except Exception as e:
            print(f"FAILED: {e}")
        time.sleep(DELAY)

    # Also inject any previously generated (from progress file) that are still "" in current file
    for pet_id, lore in progress.items():
        if f'Lore = "{lore}"' not in config_text:
            config_text = inject_lore(config_text, pet_id, lore)

    PET_CONFIG_PATH.write_text(config_text, encoding="utf-8")
    print(f"\nDone — wrote lore for {len(progress)} pets into PetConfig.luau")

if __name__ == "__main__":
    main()
