#!/usr/bin/env python3
"""
generate_pet_config.py
Expands every pet entry in PetConfig.luau with 10 new fields:
  Element, EggSource, BaseMultiplier (replaces Power),
  PassiveTrait {Name, Description} (replaces Utility string),
  PrimaryColor, SecondaryColor, SilhouetteKeywords, FXKeywords,
  ShortLore (replaces Description), IconPrompt, ArtPrompt,
  GoldenImage, RainbowImage

Run: python tools/generate_pet_config.py
"""

import re
from pathlib import Path

PET_CONFIG_PATH = Path(__file__).parent.parent / "src" / "shared" / "Configs" / "PetConfig.luau"

# ─────────────────────────────────────────────────────────────────────────────
# Zone & formula data
# ─────────────────────────────────────────────────────────────────────────────

ZONE_INFO = {
    "starter_meadow":   {"level": 1, "element": "Nature",    "pc": "#A8E6CF", "sc": "#DCEEFB"},
    "forest_grove":     {"level": 2, "element": "Nature",    "pc": "#52B788", "sc": "#B7E4C7"},
    "crystal_caves":    {"level": 3, "element": "Crystal",   "pc": "#6B5B95", "sc": "#C8B8E8"},
    "volcanic_ridge":   {"level": 4, "element": "Fire",      "pc": "#E05252", "sc": "#FFAA5A"},
    "frozen_tundra":    {"level": 5, "element": "Ice",       "pc": "#90E0EF", "sc": "#CAF0F8"},
    "celestial_garden": {"level": 6, "element": "Celestial", "pc": "#9B5DE5", "sc": "#F15BB5"},
    "shadow_realm":     {"level": 7, "element": "Shadow",    "pc": "#4A1463", "sc": "#7B2FBE"},
    "cosmic_void":      {"level": 8, "element": "Cosmic",    "pc": "#03045E", "sc": "#00B4D8"},
}

EGG_ZONE_MAP = {
    "basic_egg":        "starter_meadow",
    "spotted_egg":      "starter_meadow",
    "forest_egg":       "forest_grove",
    "enchanted_egg":    "forest_grove",
    "crystal_egg":      "crystal_caves",
    "mythic_egg":       "crystal_caves",
    "magma_egg":        "volcanic_ridge",
    "inferno_egg":      "volcanic_ridge",
    "frost_egg":        "frozen_tundra",
    "arctic_egg":       "frozen_tundra",
    "starlight_egg":    "celestial_garden",
    "cosmic_bloom_egg": "celestial_garden",
    "dusk_egg":         "shadow_realm",
    "abyss_egg":        "shadow_realm",
    "void_egg":         "cosmic_void",
    "eternity_egg":     "cosmic_void",
}

# Some eggs override the default zone element
EGG_ELEMENT_OVERRIDE = {
    "enchanted_egg": "Spirit",
}

# Pet → egg source
PET_EGG = {
    # Zone 1 – Starter Meadow
    "whiskerling": "basic_egg",   "puddlejump": "basic_egg",
    "fluffnose": "basic_egg",     "sparkletail": "basic_egg",   "glowbug": "basic_egg",
    "dottie": "spotted_egg",      "specklefoot": "spotted_egg",
    "patchwhirl": "spotted_egg",  "shimmerspot": "spotted_egg",
    "radiantdot": "spotted_egg",  "prismapaw": "spotted_egg",
    # Zone 2 – Forest Grove
    "leafling": "forest_egg",     "twigsnap": "forest_egg",
    "mosswhisker": "forest_egg",  "thornbloom": "forest_egg",   "elderoak": "forest_egg",
    "pixiepuff": "enchanted_egg", "willowisp": "enchanted_egg",
    "fernshade": "enchanted_egg", "glimmerfox": "enchanted_egg",
    "starweaver": "enchanted_egg","moonlark": "enchanted_egg",
    # Zone 3 – Crystal Caves
    "gemshard": "crystal_egg",    "quartzpaw": "crystal_egg",
    "amethystine": "crystal_egg", "sapphireclaw": "crystal_egg","diamondwing": "crystal_egg",
    "rubyflare": "mythic_egg",    "obsidianfang": "mythic_egg",
    "topazstrike": "mythic_egg",  "emeraldwyrm": "mythic_egg",  "cosmicnova": "mythic_egg",
    # Zone 4 – Volcanic Ridge
    "cinderkit": "magma_egg",     "scorchpup": "magma_egg",
    "flamefang": "magma_egg",     "magmahowl": "magma_egg",     "volcanowyrm": "magma_egg",
    "ashmote": "inferno_egg",     "blazeclaw": "inferno_egg",
    "pyronix": "inferno_egg",     "infernotitan": "inferno_egg","moltendrake": "inferno_egg",
    # Zone 5 – Frozen Tundra
    "snowpuff": "frost_egg",      "icepaw": "frost_egg",
    "frostbite": "frost_egg",     "glacierheart": "frost_egg",  "blizzardwolf": "frost_egg",
    "sleetstep": "arctic_egg",    "hailshard": "arctic_egg",
    "permafrost": "arctic_egg",   "aurorabear": "arctic_egg",   "absolutezero": "arctic_egg",
    # Zone 6 – Celestial Garden
    "petalwisp": "starlight_egg",       "moonbloom": "starlight_egg",
    "stardust": "starlight_egg",        "nebulafawn": "starlight_egg",
    "celestialunicorn": "starlight_egg",
    "astralsprout": "cosmic_bloom_egg", "galaxyvine": "cosmic_bloom_egg",
    "solarflare": "cosmic_bloom_egg",   "cosmosdragon": "cosmic_bloom_egg",
    "etherealphoenix": "cosmic_bloom_egg",
    # Zone 7 – Shadow Realm
    "shadowmite": "dusk_egg",    "nightcrawl": "dusk_egg",
    "gloomfang": "dusk_egg",     "voidhound": "dusk_egg",      "abyssalking": "dusk_egg",
    "darkwhisper": "abyss_egg",  "phantomblade": "abyss_egg",
    "dreadlord": "abyss_egg",    "oblivionserpent": "abyss_egg","shadowmonarch": "abyss_egg",
    # Zone 8 – Cosmic Void
    "voidmote": "void_egg",       "nebulawyrm": "void_egg",
    "singularity": "void_egg",    "quantumwolf": "void_egg",    "cosmicreaper": "void_egg",
    "starforger": "eternity_egg", "dimensionweaver": "eternity_egg",
    "infinitybeast": "eternity_egg","omnigod": "eternity_egg","realityshatter": "eternity_egg",
    # Secret Orb Pets
    "meadow_guardian":  "secret_orb", "forest_spirit":   "secret_orb",
    "crystal_keeper":   "secret_orb", "magma_guardian":  "secret_orb",
    "frost_sentinel":   "secret_orb", "celestial_herald":"secret_orb",
    "void_watcher":     "secret_orb", "cosmos_herald":   "secret_orb",
}

# For secret orb pets, which zone they belong to
SECRET_ORB_ZONE = {
    "meadow_guardian":  "starter_meadow",
    "forest_spirit":    "forest_grove",
    "crystal_keeper":   "crystal_caves",
    "magma_guardian":   "volcanic_ridge",
    "frost_sentinel":   "frozen_tundra",
    "celestial_herald": "celestial_garden",
    "void_watcher":     "shadow_realm",
    "cosmos_herald":    "cosmic_void",
}

# BaseMultiplier = RARITY_BASE[rarity] * ZONE_SCALE[zone_level]
RARITY_BASE = {
    "Common": 1.1, "Rare": 1.5, "Epic": 2.5,
    "Legendary": 5.0, "Mythic": 15.0, "Secret": 100.0,
}
ZONE_SCALE = {
    1: 1.0, 2: 2.0, 3: 4.0, 4: 8.0,
    5: 16.0, 6: 35.0, 7: 80.0, 8: 200.0,
}

ELEMENT_FX = {
    "Nature":    ["leaf", "petal", "sparkle"],
    "Spirit":    ["sparkle", "wisp", "shimmer"],
    "Crystal":   ["crystal_shard", "shimmer", "refraction"],
    "Fire":      ["ember", "flame_particle", "smoke"],
    "Ice":       ["snowflake", "frost_crystal", "cold_mist"],
    "Celestial": ["stardust", "starfield_glow", "cosmic_shimmer"],
    "Shadow":    ["dark_smoke", "void_particle", "shadow_wisp"],
    "Cosmic":    ["nebula_dust", "warp_shimmer", "plasma_arc"],
}
RARITY_FX_EXTRA = {
    "Common": [],
    "Rare": ["soft_aura"],
    "Epic": ["aura", "glow"],
    "Legendary": ["strong_aura", "particle_trail"],
    "Mythic": ["prismatic_aura", "heavy_emission"],
    "Secret": ["prismatic_aura", "heavy_emission", "reality_distortion"],
}

# ─────────────────────────────────────────────────────────────────────────────
# Original Power values (preserved for backward-compat with existing services)
# BaseMultiplier is the NEW decimal multiplier; Power is the original stat.
# ─────────────────────────────────────────────────────────────────────────────
PET_POWER = {
    # Zone 1
    "whiskerling": 1,      "puddlejump": 2,      "fluffnose": 5,
    "sparkletail": 12,     "glowbug": 30,
    "dottie": 3,           "specklefoot": 4,      "patchwhirl": 8,
    "shimmerspot": 18,     "radiantdot": 45,      "prismapaw": 120,
    # Zone 2
    "leafling": 10,        "twigsnap": 12,        "mosswhisker": 25,
    "thornbloom": 55,      "elderoak": 140,
    "pixiepuff": 15,       "willowisp": 30,       "fernshade": 35,
    "glimmerfox": 70,      "starweaver": 180,     "moonlark": 450,
    # Zone 3
    "gemshard": 40,        "quartzpaw": 80,       "amethystine": 180,
    "sapphireclaw": 450,   "diamondwing": 1200,
    "rubyflare": 100,      "obsidianfang": 250,   "topazstrike": 600,
    "emeraldwyrm": 1500,   "cosmicnova": 5000,
    # Zone 4
    "cinderkit": 100,      "scorchpup": 120,      "flamefang": 250,
    "magmahowl": 550,      "volcanowyrm": 1400,
    "ashmote": 150,        "blazeclaw": 320,      "pyronix": 700,
    "infernotitan": 1800,  "moltendrake": 4500,
    # Zone 5
    "snowpuff": 300,       "icepaw": 350,         "frostbite": 700,
    "glacierheart": 1600,  "blizzardwolf": 4000,
    "sleetstep": 400,      "hailshard": 900,      "permafrost": 2000,
    "aurorabear": 5000,    "absolutezero": 13000,
    # Zone 6
    "petalwisp": 900,      "moonbloom": 1100,     "stardust": 2200,
    "nebulafawn": 5000,    "celestialunicorn": 12000,
    "astralsprout": 1200,  "galaxyvine": 2800,    "solarflare": 6500,
    "cosmosdragon": 16000, "etherealphoenix": 40000,
    # Zone 7
    "shadowmite": 3000,    "nightcrawl": 3500,    "gloomfang": 7000,
    "voidhound": 16000,    "abyssalking": 40000,
    "darkwhisper": 4000,   "phantomblade": 9000,  "dreadlord": 20000,
    "oblivionserpent": 50000, "shadowmonarch": 125000,
    # Zone 8
    "voidmote": 10000,     "nebulawyrm": 12000,   "singularity": 25000,
    "quantumwolf": 55000,  "cosmicreaper": 140000,
    "starforger": 30000,   "dimensionweaver": 70000, "infinitybeast": 180000,
    "omnigod": 500000,     "realityshatter": 1500000,
    # Secret Orbs
    "meadow_guardian": 8000,    "forest_spirit": 16000,
    "crystal_keeper": 32000,    "magma_guardian": 80000,
    "frost_sentinel": 200000,   "celestial_herald": 500000,
    "void_watcher": 1200000,    "cosmos_herald": 3000000,
}

# ─────────────────────────────────────────────────────────────────────────────
# Per-pet colour overrides  (primary, secondary)
# ─────────────────────────────────────────────────────────────────────────────
PET_COLORS = {
    # Zone 1
    "whiskerling":       ("#F7C59F", "#A8D8EA"),
    "puddlejump":        ("#86C98E", "#FFFDB3"),
    "fluffnose":         ("#E8C3E8", "#FFFFFF"),
    "sparkletail":       ("#FFD700", "#FFF4B3"),
    "glowbug":           ("#90EE90", "#FFFFE0"),
    "dottie":            ("#F7C6C7", "#FFFFFF"),
    "specklefoot":       ("#C4A882", "#F5DEB3"),
    "patchwhirl":        ("#DDA0DD", "#9370DB"),
    "shimmerspot":       ("#E8E4FF", "#B8A9FF"),
    "radiantdot":        ("#FFE066", "#FFFFFF"),
    "prismapaw":         ("#E8F4FF", "#FFB3DE"),
    # Zone 2
    "leafling":          ("#4DAE7A", "#A8D5B5"),
    "twigsnap":          ("#8B6914", "#C4A052"),
    "mosswhisker":       ("#5E8C3A", "#9DC88D"),
    "thornbloom":        ("#C53B8C", "#4DAE7A"),
    "elderoak":          ("#5C4033", "#A67C52"),
    "pixiepuff":         ("#FF9FF3", "#FFEAA7"),
    "willowisp":         ("#74B9FF", "#DFFEFF"),
    "fernshade":         ("#00B894", "#55EFC4"),
    "glimmerfox":        ("#FDCB6E", "#E17055"),
    "starweaver":        ("#A29BFE", "#DFEAFF"),
    "moonlark":          ("#2C3E50", "#74B9FF"),
    # Zone 3
    "gemshard":          ("#8FE3CF", "#DFF9FB"),
    "quartzpaw":         ("#F8EFBA", "#FFFFFF"),
    "amethystine":       ("#9B59B6", "#DDB6F2"),
    "sapphireclaw":      ("#2471A3", "#85C1E9"),
    "diamondwing":       ("#E8F4F8", "#FFFFFF"),
    "rubyflare":         ("#E74C3C", "#FF8787"),
    "obsidianfang":      ("#2C3E50", "#7F8C8D"),
    "topazstrike":       ("#F1C40F", "#F7DC6F"),
    "emeraldwyrm":       ("#27AE60", "#58D68D"),
    "cosmicnova":        ("#1B2A6B", "#85C1E9"),
    # Zone 4
    "cinderkit":         ("#5D4037", "#BCAAA4"),
    "scorchpup":         ("#E64A19", "#E57373"),
    "flamefang":         ("#FF6D00", "#FFAB40"),
    "magmahowl":         ("#B71C1C", "#E57373"),
    "volcanowyrm":       ("#4E342E", "#EF9A9A"),
    "ashmote":           ("#9E9E9E", "#F5F5F5"),
    "blazeclaw":         ("#FF6F00", "#FFECB3"),
    "pyronix":           ("#F44336", "#FF8A80"),
    "infernotitan":      ("#880E4F", "#EF9A9A"),
    "moltendrake":       ("#DD2C00", "#FF5722"),
    # Zone 5
    "snowpuff":          ("#ECEFF1", "#90CAF9"),
    "icepaw":            ("#B3E5FC", "#FFFFFF"),
    "frostbite":         ("#26C6DA", "#B2EBF2"),
    "glacierheart":      ("#0288D1", "#81D4FA"),
    "blizzardwolf":      ("#37474F", "#B0BEC5"),
    "sleetstep":         ("#4DD0E1", "#E0F7FA"),
    "hailshard":         ("#78909C", "#CFD8DC"),
    "permafrost":        ("#0D47A1", "#90CAF9"),
    "aurorabear":        ("#7E57C2", "#26C6DA"),
    "absolutezero":      ("#E0F7FA", "#FFFFFF"),
    # Zone 6
    "petalwisp":         ("#F48FB1", "#FCE4EC"),
    "moonbloom":         ("#CE93D8", "#FFEEFF"),
    "stardust":          ("#FFD54F", "#FFF9C4"),
    "nebulafawn":        ("#7C4DFF", "#EDE7F6"),
    "celestialunicorn":  ("#FFFFFF", "#FFD700"),
    "astralsprout":      ("#69F0AE", "#E8F5E9"),
    "galaxyvine":        ("#BA68C8", "#E1BEE7"),
    "solarflare":        ("#FF6D00", "#FFF9C4"),
    "cosmosdragon":      ("#3949AB", "#9FA8DA"),
    "etherealphoenix":   ("#F06292", "#F8BBD9"),
    # Zone 7
    "shadowmite":        ("#37003C", "#7B1FA2"),
    "nightcrawl":        ("#212121", "#424242"),
    "gloomfang":         ("#4A148C", "#9C27B0"),
    "voidhound":         ("#1A1A2E", "#533483"),
    "abyssalking":       ("#12002F", "#4A0080"),
    "darkwhisper":       ("#263238", "#546E7A"),
    "phantomblade":      ("#311B92", "#7E57C2"),
    "dreadlord":         ("#B71C1C", "#311B92"),
    "oblivionserpent":   ("#1B5E20", "#4A148C"),
    "shadowmonarch":     ("#000000", "#7B1FA2"),
    # Zone 8
    "voidmote":          ("#0D0D2B", "#00E5FF"),
    "nebulawyrm":        ("#1A0533", "#7C4DFF"),
    "singularity":       ("#000000", "#FFFFFF"),
    "quantumwolf":       ("#1A1A2E", "#00B0FF"),
    "cosmicreaper":      ("#1A0000", "#FF1744"),
    "starforger":        ("#FF8F00", "#FFFF00"),
    "dimensionweaver":   ("#7C4DFF", "#1DE9B6"),
    "infinitybeast":     ("#4A148C", "#CE93D8"),
    "omnigod":           ("#FFD700", "#FFFFFF"),
    "realityshatter":    ("#FF1744", "#FFD700"),
    # Secret Orb
    "meadow_guardian":   ("#A8E6CF", "#FFD700"),
    "forest_spirit":     ("#1B5E20", "#FFD700"),
    "crystal_keeper":    ("#00B0FF", "#FFD700"),
    "magma_guardian":    ("#FF3D00", "#FFD700"),
    "frost_sentinel":    ("#E0F7FA", "#FFD700"),
    "celestial_herald":  ("#9C27B0", "#FFD700"),
    "void_watcher":      ("#1A1A2E", "#FFD700"),
    "cosmos_herald":     ("#FF1744", "#FFD700"),
}

# ─────────────────────────────────────────────────────────────────────────────
# Per-pet silhouette keywords (for future 3-D model generation hints)
# ─────────────────────────────────────────────────────────────────────────────
PET_SILHOUETTE = {
    # Zone 1
    "whiskerling":      ["cat", "round", "fluffy", "small"],
    "puddlejump":       ["frog", "chubby", "round", "smooth"],
    "fluffnose":        ["round", "very_fluffy", "tiny", "amorphous"],
    "sparkletail":      ["small_mammal", "glowing_tail", "round_body"],
    "glowbug":          ["insect", "round", "luminous", "tiny"],
    "dottie":           ["round", "spotted", "small_mammal"],
    "specklefoot":      ["quadruped", "small", "spotted_paws"],
    "patchwhirl":       ["round", "spinning", "patchy"],
    "shimmerspot":      ["smooth", "round", "glowing_spots"],
    "radiantdot":       ["round", "floating_core", "glowing"],
    "prismapaw":        ["crystalline_paws", "prismatic", "small_mammal"],
    # Zone 2
    "leafling":         ["leaf_body", "tiny", "round", "organic"],
    "twigsnap":         ["stick_limbs", "angular", "small"],
    "mosswhisker":      ["cat", "fluffy", "long_whiskers", "mossy"],
    "thornbloom":       ["flower_body", "thorny", "beautiful"],
    "elderoak":         ["tree_like", "bark_skin", "ancient", "large"],
    "pixiepuff":        ["tiny_humanoid", "round", "puffy", "winged"],
    "willowisp":        ["floating", "glowing", "round", "ethereal"],
    "fernshade":        ["leaf_patterned", "flat", "camouflaged"],
    "glimmerfox":       ["fox", "pointy_ears", "bushy_tail", "glowing"],
    "starweaver":       ["many_limbs", "star_pattern", "weaver"],
    "moonlark":         ["bird", "dark_feathers", "lunar_marks"],
    # Zone 3
    "gemshard":         ["crystalline", "faceted", "small", "angular"],
    "quartzpaw":        ["quadruped", "crystal_paws", "translucent"],
    "amethystine":      ["regal", "upright", "crystalline", "crown"],
    "sapphireclaw":     ["large_claws", "quadruped", "gem_body"],
    "diamondwing":      ["winged", "crystalline", "translucent", "large"],
    "rubyflare":        ["bird_like", "glowing_red", "fiery"],
    "obsidianfang":     ["dark", "sharp_fangs", "angular"],
    "topazstrike":      ["sleek", "fast", "yellow_glow"],
    "emeraldwyrm":      ["serpentine", "long", "green_scales"],
    "cosmicnova":       ["round", "explosive_glow", "cosmic"],
    # Zone 4
    "cinderkit":        ["small", "ashy", "round", "cat_like"],
    "scorchpup":        ["puppy", "smoky_paws", "energetic"],
    "flamefang":        ["predator", "flaming_fangs", "lean"],
    "magmahowl":        ["wolf", "magma_streaks", "large"],
    "volcanowyrm":      ["large_dragon", "serpentine", "armored"],
    "ashmote":          ["tiny", "floating", "ash_particle"],
    "blazeclaw":        ["large_claws", "white_fire", "feline"],
    "pyronix":          ["bird", "glass_feathers", "fiery"],
    "infernotitan":     ["giant", "armored", "upright"],
    "moltendrake":      ["dragon", "lava_body", "flowing"],
    # Zone 5
    "snowpuff":         ["tiny", "round", "snowball", "fluffy"],
    "icepaw":           ["small_mammal", "ice_paws", "cool"],
    "frostbite":        ["predator", "sharp_teeth", "icy"],
    "glacierheart":     ["large", "ice_core_visible", "cold"],
    "blizzardwolf":     ["wolf", "stormy_fur", "powerful"],
    "sleetstep":        ["graceful", "lean", "sleek", "deer_like"],
    "hailshard":        ["collective", "jagged", "floating_shards"],
    "permafrost":       ["amorphous", "ice_encrusted", "ancient"],
    "aurorabear":       ["bear", "shimmering_fur", "large"],
    "absolutezero":     ["crystalline", "barely_visible", "pure"],
    # Zone 6
    "petalwisp":        ["tiny", "flower_petal", "floating"],
    "moonbloom":        ["flower", "luminous", "closed_bud"],
    "stardust":         ["glittering", "small", "particle_form"],
    "nebulafawn":       ["deer_fawn", "cosmic_coat", "large_eyes"],
    "celestialunicorn": ["unicorn", "white", "shining_horn"],
    "astralsprout":     ["plant", "tiny", "sprouting", "cosmic"],
    "galaxyvine":       ["vine", "spiraling", "cosmic_purple"],
    "solarflare":       ["bird", "solar_wings", "intense_glow"],
    "cosmosdragon":     ["dragon", "constellation_breath", "large"],
    "etherealphoenix":  ["phoenix", "translucent", "light_form"],
    # Zone 7
    "shadowmite":       ["tiny", "shadow_form", "barely_visible"],
    "nightcrawl":       ["low_profile", "shadow_elongated", "stealthy"],
    "gloomfang":        ["dark", "large_fangs", "shadow_mist"],
    "voidhound":        ["hound", "ethereal", "dark_thin"],
    "abyssalking":      ["regal", "massive", "crystallized_darkness"],
    "darkwhisper":      ["invisible_outline", "ghostly", "small"],
    "phantomblade":     ["sharp_limbs", "negative_space", "angular"],
    "dreadlord":        ["tall", "imposing", "crimson_dark"],
    "oblivionserpent":  ["serpentine", "massive", "void_dark"],
    "shadowmonarch":    ["tall", "crown_of_shadows", "pure_black"],
    # Zone 8
    "voidmote":         ["tiny", "anti_matter", "round"],
    "nebulawyrm":       ["serpentine", "cosmic_fins", "large"],
    "singularity":      ["extremely_dense", "circular", "black"],
    "quantumwolf":      ["wolf", "quantum_blur", "multioutline"],
    "cosmicreaper":     ["tall", "scythe", "dark_cosmic"],
    "starforger":       ["muscular_upright", "forge_hands", "ember_glow"],
    "dimensionweaver":  ["complex_limbs", "web_pattern", "floating"],
    "infinitybeast":    ["massive", "amorphous", "infinite_dark"],
    "omnigod":          ["divine", "golden_radiant", "formless"],
    "realityshatter":   ["fragmented", "neon_cracks", "angular"],
    # Secret Orb
    "meadow_guardian":  ["guardian", "nature_armor", "large"],
    "forest_spirit":    ["tall", "root_tendrils", "ancient"],
    "crystal_keeper":   ["crystalline_humanoid", "faceted", "upright"],
    "magma_guardian":   ["fire_giant", "lava_armor", "massive"],
    "frost_sentinel":   ["armored", "ice_spikes", "upright"],
    "celestial_herald": ["winged_divine", "celestial_glow", "upright"],
    "void_watcher":     ["multiple_eyes", "shadow_form", "floating"],
    "cosmos_herald":    ["cosmic_divine", "radiant", "edge_of_reality"],
}

# ─────────────────────────────────────────────────────────────────────────────
# Fallback / patch data for pets missing Lore or Utility in the source file,
# plus full definitions for the 8 Secret Orb pets not in the committed source.
# ─────────────────────────────────────────────────────────────────────────────

PET_FALLBACK = {
    "realityshatter": {
        "ShortLore": "Breaks the fabric of reality with its mere existence.",
        "Lore": (
            "Reality Shatters are what remain after a reality ends. When a universe collapses — "
            "not just stars dying, but the fundamental physical laws ceasing to apply — the final "
            "echo of that reality sometimes survives as a Reality Shatter. It carries the ghost of "
            "different physics, contradicting the rules of the universe it now inhabits just by "
            "breathing. Scientists call it an 'ontological impossibility.' Collectors simply call "
            "it the rarest treasure in existence."
        ),
        "Utility": "Reality Override: All rules bend — coin and gem gains are tripled for 2 minutes on equip. 10-minute cooldown.",
    },
}

# Full definitions for the 8 Secret Orb pets (not in the committed source file)
SECRET_ORB_PETS_DATA = [
    {
        "Id": "meadow_guardian",   "Name": "Meadow Guardian",   "Rarity": "Secret",
        "Power": 8000,
        "ShortLore": "The hidden spirit of the Starter Meadow.",
        "Lore": (
            "The Meadow Guardian has slept beneath the green hillsides since before the first "
            "explorer arrived. The three lime-green orbs scattered across the meadow are fragments "
            "of its dreaming consciousness, separated by an ancient enchantment so that only a "
            "worthy collector who finds all three can call it forth. When all pieces are gathered, "
            "the Guardian awakens with a chime like grass in wind."
        ),
        "Utility": "Meadow Keeper: Reveals all hidden orb locations in the current zone for 2 minutes.",
        "OrbSet": "starter_meadow",
    },
    {
        "Id": "forest_spirit",   "Name": "Forest Spirit",   "Rarity": "Secret",
        "Power": 16000,
        "ShortLore": "The ancient soul bound to Forest Grove.",
        "Lore": (
            "The Forest Spirit is the grove's oldest secret, a consciousness woven from the very "
            "first roots that ever grew in the soil. The three deep-green orbs hidden throughout "
            "the forest are sap-tears it shed when it became formless, crystallized by centuries "
            "of magical energy. Reuniting them breaks the sap-crystal shell and the Spirit rises, "
            "smelling of pine and petrichor."
        ),
        "Utility": "Grove Bond: All forest-type pets gain +20% Power when Forest Spirit is in the party.",
        "OrbSet": "forest_grove",
    },
    {
        "Id": "crystal_keeper",   "Name": "Crystal Keeper",   "Rarity": "Secret",
        "Power": 32000,
        "ShortLore": "The guardian born from perfect crystal geometry.",
        "Lore": (
            "The Crystal Keeper was formed when the three most perfectly faceted crystals in the "
            "cave network rolled together at the precise geometric angle that achieves resonance. "
            "The resulting tone shattered impurities throughout the entire cave system and a "
            "consciousness crystallized at the epicenter. The three cyan orbs are its shed "
            "crystalline tears, each containing a note of that original resonant chord."
        ),
        "Utility": "Resonant Form: Boosts all crystal zone coin drops by 30% and halves the respawn time of hidden cave collectibles.",
        "OrbSet": "crystal_caves",
    },
    {
        "Id": "magma_guardian",   "Name": "Magma Guardian",   "Rarity": "Secret",
        "Power": 80000,
        "ShortLore": "The living embodiment of volcanic force.",
        "Lore": (
            "The Magma Guardian was the Volcanic Ridge before the ridge had a name. Eons of "
            "pressure, heat, and eruption eventually produced a self-aware entity that stepped "
            "out of the volcano's caldera on a night when three moons aligned. Its three "
            "orange-red orbs are solidified cinders from that first emergence, each still "
            "holding the heat of a sleeping volcano inside."
        ),
        "Utility": "Volcanic Might: All fire-type pets in the team gain +35% Power. Volcanic Ridge coin drops increase by 25%.",
        "OrbSet": "volcanic_ridge",
    },
    {
        "Id": "frost_sentinel",   "Name": "Frost Sentinel",   "Rarity": "Secret",
        "Power": 200000,
        "ShortLore": "The ancient watcher frozen into three shards.",
        "Lore": (
            "The Frost Sentinel guarded the tundra's most sacred glacier until a betrayal long "
            "ago froze its power into three arctic-blue orbs that scattered across the ice fields. "
            "In that fragmented state it has stood watch for ten thousand years, its consciousness "
            "split but never quieted. Reuniting the orbs is not just collection — it is the "
            "healing of a wound the tundra has carried for millennia."
        ),
        "Utility": "Sentinel's Watch: Slows all coin despawn timers by 50% in Frozen Tundra. Blizzard events grant double collectibles.",
        "OrbSet": "frozen_tundra",
    },
    {
        "Id": "celestial_herald",   "Name": "Celestial Herald",   "Rarity": "Secret",
        "Power": 500000,
        "ShortLore": "The herald of the stars made manifest.",
        "Lore": (
            "Celestial Heralds are the messengers of the stars themselves, sent to mortal realms "
            "when the constellations have news of cosmic importance. This one has been waiting in "
            "the Celestial Garden since its message was split across three violet orbs by a rogue "
            "comet. When the collector reunites the orbs, the Herald delivers its message — "
            "silently, directly into the mind, in a language older than words."
        ),
        "Utility": "Star Message: All gem rewards are doubled for 5 minutes after collecting a set. Celestial Garden coin drops permanently +30%.",
        "OrbSet": "celestial_garden",
    },
    {
        "Id": "void_watcher",   "Name": "Void Watcher",   "Rarity": "Secret",
        "Power": 1200000,
        "ShortLore": "The eternal observer of all shadow.",
        "Lore": (
            "The Void Watcher has existed since the first shadow was cast in the universe. It "
            "does not create darkness — it observes it, cataloguing every instance of shadow ever "
            "formed. The three dark-purple orbs hidden in the Shadow Realm are its eyes, separated "
            "by an ancient enemy to blind it briefly. Returning the eyes ends its blinded vigil. "
            "It remembers everything it missed, in an instant."
        ),
        "Utility": "Shadow Omniscience: All hidden collectibles in shadow zones are revealed permanently. Shadow-type pets gain +40% Power.",
        "OrbSet": "shadow_realm",
    },
    {
        "Id": "cosmos_herald",   "Name": "Cosmos Herald",   "Rarity": "Secret",
        "Power": 3000000,
        "ShortLore": "Born at the edge of all existence.",
        "Lore": (
            "The Cosmos Herald stands at the absolute boundary of the universe, where space itself "
            "ends and nothing begins. It appeared at that edge the moment the universe first "
            "expanded far enough to have an edge to stand at. Its three neon-pink orbs are "
            "fragments of the cosmic horizon itself, brought inward when the edge briefly folded. "
            "Possessing a Cosmos Herald means owning a piece of the literal edge of everything."
        ),
        "Utility": "Edge of Everything: All pets gain +50% Power permanently while Cosmos Herald is equipped. Max coin multiplier cap is doubled.",
        "OrbSet": "cosmic_void",
    },
]



ZONE_SETTINGS_PROMPT = {
    "starter_meadow":   "rolling green meadows with wildflowers and soft morning light",
    "forest_grove":     "enchanted forest with glowing moss and towering ancient trees",
    "crystal_caves":    "sparkling crystal caverns with gem-lit stalactites",
    "volcanic_ridge":   "dramatic volcanic landscape with flowing lava and ember clouds",
    "frozen_tundra":    "sweeping arctic tundra under shimmering northern lights",
    "celestial_garden": "magical celestial garden floating in star-lit space",
    "shadow_realm":     "dark ethereal dimension of living shadow and violet mist",
    "cosmic_void":      "vast cosmic void with swirling nebulae and quantum energy",
}

RARITY_FINISH = {
    "Common":    "simple matte finish, clean pastel colours",
    "Rare":      "soft satin sheen, jewel-bright accents",
    "Epic":      "vivid glossy with colour aura glow",
    "Legendary": "gold trim accents, radiant halo glow",
    "Mythic":    "iridescent pearl finish, prismatic shimmer",
    "Secret":    "full rainbow prismatic crystalline shimmer, reality-bending highlights",
}


def make_icon_prompt(name: str, rarity: str, element: str, short_lore: str) -> str:
    return (
        f"{name}: {short_lore} "
        f"Square inventory icon. Low-poly chubby vinyl-toy creature, oversized shiny eyes, "
        f"{element} element, {RARITY_FINISH[rarity]}, clean 2-3 colour palette, "
        f"transparent background, centred, premium collectible game icon, 512x512."
    )


def make_art_prompt(name: str, rarity: str, zone: str, element: str, short_lore: str) -> str:
    return (
        f"Full-body concept art of {name}, a {rarity} {element}-type collectible creature. "
        f"{short_lore} "
        f"Setting: {ZONE_SETTINGS_PROMPT.get(zone, 'magical realm')}. "
        f"Dynamic hero pose, low-poly vinyl-toy proportions, oversized expressive eyes, "
        f"magical particle effects, {RARITY_FINISH[rarity]}, cinematic lighting."
    )


# ─────────────────────────────────────────────────────────────────────────────
# Lua helpers
# ─────────────────────────────────────────────────────────────────────────────

def lua_str(s: str) -> str:
    """Escape a Python string for use inside a Lua double-quoted string."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def lua_list(items: list) -> str:
    """Convert Python list → Lua table literal of strings."""
    return "{" + ", ".join(f'"{x}"' for x in items) + "}"


def parse_utility(utility: str) -> tuple[str, str]:
    """'Trait Name: Description text.' → ('Trait Name', 'Description text.')"""
    if ": " in utility:
        idx = utility.index(": ")
        return utility[:idx].strip(), utility[idx + 2:].strip()
    return "Passive Trait", utility.strip()


def get_str_field(block: str, field: str) -> str:
    """Extract the value of a Lua string field from a block string.
    Uses word-boundary anchors to avoid e.g. 'Lore' matching 'ShortLore'.
    """
    m = re.search(rf'(?<!\w){re.escape(field)}\s*=\s*"((?:[^"\\]|\\.)*)"', block)
    return m.group(1) if m else ""


# ─────────────────────────────────────────────────────────────────────────────
# Block transformer
# ─────────────────────────────────────────────────────────────────────────────

def transform_block(block_inner: str, pet_id: str) -> str:
    """
    Given the inner text of a pet block (lines between opening { and closing }),
    return the full replacement block string (including the outer { and },).
    """
    # Extract existing fields (with fallback for incomplete committed entries)
    fallback = PET_FALLBACK.get(pet_id, {})
    name       = get_str_field(block_inner, "Name")
    rarity     = get_str_field(block_inner, "Rarity")
    short_lore = get_str_field(block_inner, "Description") or fallback.get("ShortLore", "")
    lore       = get_str_field(block_inner, "Lore")       or fallback.get("Lore", "")
    utility    = get_str_field(block_inner, "Utility")    or fallback.get("Utility", "Passive: See ShortLore.")
    orb_set    = get_str_field(block_inner, "OrbSet")

    # Resolve zone
    egg = PET_EGG.get(pet_id, "basic_egg")
    if egg == "secret_orb":
        zone = SECRET_ORB_ZONE.get(pet_id, "starter_meadow")
    else:
        zone = EGG_ZONE_MAP.get(egg, "starter_meadow")

    zinfo   = ZONE_INFO[zone]
    level   = zinfo["level"]
    element = EGG_ELEMENT_OVERRIDE.get(egg, zinfo["element"])
    rarity  = rarity or "Common"

    # Compute derived fields
    mult = round(RARITY_BASE.get(rarity, 1.1) * ZONE_SCALE.get(level, 1.0), 1)
    pc, sc = PET_COLORS.get(pet_id, (zinfo["pc"], zinfo["sc"]))
    silh = PET_SILHOUETTE.get(pet_id, ["round", "small"])
    fx   = ELEMENT_FX.get(element, []) + RARITY_FX_EXTRA.get(rarity, [])

    trait_name, trait_desc = parse_utility(utility)
    icon_p = make_icon_prompt(name, rarity, element, short_lore)
    art_p  = make_art_prompt(name, rarity, zone, element, short_lore)

    power = PET_POWER.get(pet_id, 1)

    # Build new block lines
    lines = [
        f'    {{',
        f'        Id = "{pet_id}",',
        f'        Name = "{lua_str(name)}",',
        f'        Rarity = "{rarity}",',
        f'        Element = "{element}",',
        f'        EggSource = "{egg}",',
        f'        Power = {power},',
        f'        BaseMultiplier = {mult},',
        f'        PassiveTrait = {{Name = "{lua_str(trait_name)}", Description = "{lua_str(trait_desc)}"}},',
        f'        PrimaryColor = "{pc}",',
        f'        SecondaryColor = "{sc}",',
        f'        SilhouetteKeywords = {lua_list(silh)},',
        f'        FXKeywords = {lua_list(fx)},',
        f'        ShortLore = "{lua_str(short_lore)}",',
        f'        Lore = "{lua_str(lore)}",',
        f'        IconPrompt = "{lua_str(icon_p)}",',
        f'        ArtPrompt = "{lua_str(art_p)}",',
        f'        Image = "rbxassetid://0",',
        f'        GoldenImage = "rbxassetid://0",',
        f'        RainbowImage = "rbxassetid://0",',
    ]
    if orb_set:
        lines.append(f'        OrbSet = "{orb_set}",')
    lines.append(f'    }},')

    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    content = PET_CONFIG_PATH.read_text(encoding="utf-8")

    # Safety: abort if file already has the new schema (prevents double-transformation)
    if "BaseMultiplier" in content:
        print("ERROR: PetConfig.luau already contains BaseMultiplier — already expanded!")
        print("  Restore the original file before re-running (e.g. git checkout).")
        raise SystemExit(1)

    # Match each 4-space-indented pet block: "    {\n...\n    },"
    # Uses a non-greedy DOTALL match between 4-space { and 4-space },
    pattern = re.compile(r"    \{\n(.*?)    \},", re.DOTALL)

    count = 0

    def replacer(m: re.Match) -> str:
        nonlocal count
        block_inner = m.group(1)
        id_match = re.search(r'Id\s*=\s*"([^"]+)"', block_inner)
        if not id_match:
            return m.group(0)   # not a pet block (e.g., HatchTable entry)
        pet_id = id_match.group(1)
        # Skip entries that look like egg hatch entries (have PetId, Weight)
        if "Weight" in block_inner or "PetId" in block_inner:
            return m.group(0)
        count += 1
        return transform_block(block_inner, pet_id)

    new_content = pattern.sub(replacer, content)

    # ── Inject Secret Orb pets ───────────────────────────────────────────────
    # Build orb pet blocks from SECRET_ORB_PETS_DATA and insert them before
    # the closing table brace of PetConfig.Pets (or before the lookup code).
    orb_blocks = []
    for orb in SECRET_ORB_PETS_DATA:
        pet_id  = orb["Id"]
        name    = orb["Name"]
        rarity  = orb["Rarity"]
        power   = orb["Power"]
        zone    = SECRET_ORB_ZONE[pet_id]
        egg     = "secret_orb"
        zinfo   = ZONE_INFO[zone]
        level   = zinfo["level"]
        element = zinfo["element"]
        mult    = round(RARITY_BASE.get(rarity, 100.0) * ZONE_SCALE.get(level, 1.0), 1)
        pc, sc  = PET_COLORS.get(pet_id, (zinfo["pc"], zinfo["sc"]))
        silh    = PET_SILHOUETTE.get(pet_id, ["round", "large"])
        fx      = ELEMENT_FX.get(element, []) + RARITY_FX_EXTRA.get(rarity, [])
        short   = orb["ShortLore"]
        lore    = orb["Lore"]
        utility = orb["Utility"]
        orb_set = orb["OrbSet"]
        trait_name, trait_desc = parse_utility(utility)
        icon_p = make_icon_prompt(name, rarity, element, short)
        art_p  = make_art_prompt(name, rarity, zone, element, short)
        lines = [
            f"    {{",
            f'        Id = "{pet_id}",',
            f'        Name = "{lua_str(name)}",',
            f'        Rarity = "{rarity}",',
            f'        Element = "{element}",',
            f'        EggSource = "{egg}",',
            f'        Power = {power},',
            f'        BaseMultiplier = {mult},',
            f'        PassiveTrait = {{Name = "{lua_str(trait_name)}", Description = "{lua_str(trait_desc)}"}},',
            f'        PrimaryColor = "{pc}",',
            f'        SecondaryColor = "{sc}",',
            f'        SilhouetteKeywords = {lua_list(silh)},',
            f'        FXKeywords = {lua_list(fx)},',
            f'        ShortLore = "{lua_str(short)}",',
            f'        Lore = "{lua_str(lore)}",',
            f'        IconPrompt = "{lua_str(icon_p)}",',
            f'        ArtPrompt = "{lua_str(art_p)}",',
            f'        Image = "rbxassetid://0",',
            f'        GoldenImage = "rbxassetid://0",',
            f'        RainbowImage = "rbxassetid://0",',
            f'        OrbSet = "{orb_set}",',
            f"    }},",
        ]
        orb_blocks.append("\n".join(lines))

    orb_section = (
        "\n\n"
        "    -- ═══════════════════════════════════════\n"
        "    -- SECRET ORB SET PETS\n"
        "    -- Earned exclusively by completing all 3 orbs in a zone\n"
        "    -- ═══════════════════════════════════════\n\n"
        + "\n".join(orb_blocks)
        + "\n"
    )

    # Insert before the closing `}` of PetConfig.Pets (which precedes the
    # lookup-table code or the return statement).
    # We look for the pattern: standalone `}\n\n-- Build lookup` or `}\n\nreturn`
    insert_marker = re.compile(r'\n\}\n\n-- Build lookup table', re.MULTILINE)
    m = insert_marker.search(new_content)
    if m:
        new_content = new_content[:m.start()] + orb_section + new_content[m.start():]
    else:
        # Fallback: append before final return
        new_content = re.sub(r'\nreturn PetConfig\s*$',
                             orb_section + "\nreturn PetConfig",
                             new_content)

    PET_CONFIG_PATH.write_text(new_content, encoding="utf-8")
    print(f"✓ Expanded {count} regular pet entries with 15-field schema.")
    print(f"✓ Injected {len(SECRET_ORB_PETS_DATA)} Secret Orb pets.")
    print(f"  Wrote → {PET_CONFIG_PATH}")


if __name__ == "__main__":
    main()
