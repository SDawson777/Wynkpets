-- PetConfig.luau
-- All pet definitions, rarities, and stat multipliers

local PetConfig = {}

-- ─── Rarity Tiers ─────────────────────────────────────────────────────────────
PetConfig.Rarities = {
    { id = "Common",    color = Color3.fromRGB(200, 200, 200), glowColor = Color3.fromRGB(180,180,180), weight = 5000 },
    { id = "Uncommon",  color = Color3.fromRGB(80, 200, 80),   glowColor = Color3.fromRGB(60,220,60),   weight = 2500 },
    { id = "Rare",      color = Color3.fromRGB(60, 120, 240),  glowColor = Color3.fromRGB(40,100,255),  weight = 1000 },
    { id = "Epic",      color = Color3.fromRGB(160, 60, 240),  glowColor = Color3.fromRGB(140,40,255),  weight = 400  },
    { id = "Legendary", color = Color3.fromRGB(255, 180, 0),   glowColor = Color3.fromRGB(255,200,0),   weight = 100  },
    { id = "Mythic",    color = Color3.fromRGB(255, 60, 60),   glowColor = Color3.fromRGB(255,0,0),     weight = 25   },
    { id = "Divine",    color = Color3.fromRGB(255, 255, 100), glowColor = Color3.fromRGB(255,255,0),   weight = 5    },
    { id = "Secret",    color = Color3.fromRGB(0, 255, 200),   glowColor = Color3.fromRGB(0,255,180),   weight = 1    },
}

-- Total weight = 9031. Approximate probability of each (values are rounded):
--   Common    ~55.4%  |  Uncommon ~27.7%  |  Rare  ~11.1%  |  Epic   ~4.4%
--   Legendary ~1.1%   |  Mythic    ~0.28% |  Divine ~0.055% | Secret ~0.011%

-- ─── Pet Stat Multipliers per Rarity ──────────────────────────────────────────
-- coinMult: additive bonus to coin gain multiplier
-- mineMult: additive bonus to mining power multiplier
PetConfig.RarityMultipliers = {
    Common    = { coinMult = 0.05,   mineMult = 0.05   },
    Uncommon  = { coinMult = 0.12,   mineMult = 0.12   },
    Rare      = { coinMult = 0.30,   mineMult = 0.30   },
    Epic      = { coinMult = 0.75,   mineMult = 0.75   },
    Legendary = { coinMult = 2.00,   mineMult = 2.00   },
    Mythic    = { coinMult = 5.00,   mineMult = 5.00   },
    Divine    = { coinMult = 15.00,  mineMult = 15.00  },
    Secret    = { coinMult = 50.00,  mineMult = 50.00  },
}

-- ─── Pet Definitions ─────────────────────────────────────────────────────────
-- 30 pets across rarities (MVP target: 25–40)
PetConfig.Pets = {
    -- Common (6)
    { id = "rock_pup",      name = "Rock Pup",      rarity = "Common",    mesh = "RockPup",      coinBonus = 0,    mineBonus = 0   },
    { id = "coal_cub",      name = "Coal Cub",      rarity = "Common",    mesh = "CoalCub",      coinBonus = 0,    mineBonus = 0   },
    { id = "pebble_bunny",  name = "Pebble Bunny",  rarity = "Common",    mesh = "PebbleBunny",  coinBonus = 0,    mineBonus = 0   },
    { id = "dusty_cat",     name = "Dusty Cat",     rarity = "Common",    mesh = "DustyCat",     coinBonus = 0,    mineBonus = 0   },
    { id = "ore_turtle",    name = "Ore Turtle",    rarity = "Common",    mesh = "OreTurtle",    coinBonus = 0,    mineBonus = 0   },
    { id = "gravel_fox",    name = "Gravel Fox",    rarity = "Common",    mesh = "GravelFox",    coinBonus = 0,    mineBonus = 0   },

    -- Uncommon (5)
    { id = "copper_dog",    name = "Copper Dog",    rarity = "Uncommon",  mesh = "CopperDog",    coinBonus = 0,    mineBonus = 0   },
    { id = "iron_owl",      name = "Iron Owl",      rarity = "Uncommon",  mesh = "IronOwl",      coinBonus = 0,    mineBonus = 0   },
    { id = "silver_wolf",   name = "Silver Wolf",   rarity = "Uncommon",  mesh = "SilverWolf",   coinBonus = 0,    mineBonus = 0   },
    { id = "bronze_bear",   name = "Bronze Bear",   rarity = "Uncommon",  mesh = "BronzeBear",   coinBonus = 0,    mineBonus = 0   },
    { id = "gem_mouse",     name = "Gem Mouse",     rarity = "Uncommon",  mesh = "GemMouse",     coinBonus = 0,    mineBonus = 0   },

    -- Rare (5)
    { id = "gold_lion",     name = "Gold Lion",     rarity = "Rare",      mesh = "GoldLion",     coinBonus = 0,    mineBonus = 0   },
    { id = "diamond_hawk",  name = "Diamond Hawk",  rarity = "Rare",      mesh = "DiamondHawk",  coinBonus = 0,    mineBonus = 0   },
    { id = "emerald_frog",  name = "Emerald Frog",  rarity = "Rare",      mesh = "EmeraldFrog",  coinBonus = 0,    mineBonus = 0   },
    { id = "ruby_tiger",    name = "Ruby Tiger",    rarity = "Rare",      mesh = "RubyTiger",    coinBonus = 0,    mineBonus = 0   },
    { id = "sapphire_fish", name = "Sapphire Fish", rarity = "Rare",      mesh = "SapphireFish", coinBonus = 0,    mineBonus = 0   },

    -- Epic (5)
    { id = "amethyst_dragon",  name = "Amethyst Dragon",  rarity = "Epic", mesh = "AmethystDragon",  coinBonus = 0, mineBonus = 0 },
    { id = "obsidian_wolf",    name = "Obsidian Wolf",    rarity = "Epic", mesh = "ObsidianWolf",    coinBonus = 0, mineBonus = 0 },
    { id = "crystal_phoenix",  name = "Crystal Phoenix",  rarity = "Epic", mesh = "CrystalPhoenix",  coinBonus = 0, mineBonus = 0 },
    { id = "void_panther",     name = "Void Panther",     rarity = "Epic", mesh = "VoidPanther",     coinBonus = 0, mineBonus = 0 },
    { id = "storm_eagle",      name = "Storm Eagle",      rarity = "Epic", mesh = "StormEagle",      coinBonus = 0, mineBonus = 0 },

    -- Legendary (4)
    { id = "celestial_cat",   name = "Celestial Cat",   rarity = "Legendary", mesh = "CelestialCat",   coinBonus = 0, mineBonus = 0 },
    { id = "golden_dragon",   name = "Golden Dragon",   rarity = "Legendary", mesh = "GoldenDragon",   coinBonus = 0, mineBonus = 0 },
    { id = "meteor_wolf",     name = "Meteor Wolf",     rarity = "Legendary", mesh = "MeteorWolf",     coinBonus = 0, mineBonus = 0 },
    { id = "starbound_bear",  name = "Starbound Bear",  rarity = "Legendary", mesh = "StarboundBear",  coinBonus = 0, mineBonus = 0 },

    -- Mythic (2)
    { id = "nebula_serpent",  name = "Nebula Serpent",  rarity = "Mythic", mesh = "NebulaSerpent",  coinBonus = 0, mineBonus = 0 },
    { id = "void_titan",      name = "Void Titan",      rarity = "Mythic", mesh = "VoidTitan",      coinBonus = 0, mineBonus = 0 },

    -- Divine (2)
    { id = "cosmos_fox",      name = "Cosmos Fox",      rarity = "Divine", mesh = "CosmosFox",      coinBonus = 0, mineBonus = 0 },
    { id = "eternal_phoenix", name = "Eternal Phoenix", rarity = "Divine", mesh = "EternalPhoenix", coinBonus = 0, mineBonus = 0 },

    -- Secret (1)
    { id = "crystal_overlord", name = "Crystal Overlord", rarity = "Secret", mesh = "CrystalOverlord", coinBonus = 0, mineBonus = 0 },
}

-- ─── Equipped Pet Slots ───────────────────────────────────────────────────────
PetConfig.BaseEquipSlots     = 3     -- all players get 3 slots
PetConfig.GamepassEquipSlots = 3     -- +3 slots from "Extra Slots" gamepass
PetConfig.MaxEquipSlots      = 6     -- absolute maximum

-- ─── Pet Limit per Player ────────────────────────────────────────────────────
PetConfig.MaxInventorySize   = 250

-- Build lookup by id for O(1) access
local petById = {}
for _, pet in ipairs(PetConfig.Pets) do
    petById[pet.id] = pet
end
PetConfig.ById = petById

-- Build rarity lookup by id for O(1) access
local rarityById = {}
for _, rarity in ipairs(PetConfig.Rarities) do
    rarityById[rarity.id] = rarity
end
PetConfig.RarityById = rarityById

return PetConfig
