-- EggConfig.luau
-- Egg definitions, hatch pools, and pricing

local EggConfig = {}

-- ─── Egg Definitions ─────────────────────────────────────────────────────────
-- Each egg has an id, display name, cost, a pool of pet ids it can produce,
-- and optional constraints (world required, rebirth required, limited).
EggConfig.Eggs = {
    -- ── Egg 1: Starter Egg ────────────────────────────────────────────────────
    {
        id             = "starter_egg",
        name           = "Starter Egg",
        description    = "A humble egg found in the Starter Mine.",
        coinCost       = 500,
        gemCost        = 0,
        worldRequired  = 1,
        rebirthRequired= 0,
        isLimited      = false,
        pool = {
            { petId = "rock_pup",     weight = 50 },
            { petId = "coal_cub",     weight = 30 },
            { petId = "pebble_bunny", weight = 15 },
            { petId = "dusty_cat",    weight = 4  },
            { petId = "copper_dog",   weight = 1  },
        },
    },

    -- ── Egg 2: Mine Egg ───────────────────────────────────────────────────────
    {
        id             = "mine_egg",
        name           = "Mine Egg",
        description    = "Forged from deep rock — better pets lurk inside.",
        coinCost       = 5000,
        gemCost        = 0,
        worldRequired  = 1,
        rebirthRequired= 0,
        isLimited      = false,
        pool = {
            { petId = "ore_turtle",   weight = 40 },
            { petId = "gravel_fox",   weight = 30 },
            { petId = "copper_dog",   weight = 15 },
            { petId = "iron_owl",     weight = 10 },
            { petId = "silver_wolf",  weight = 4  },
            { petId = "gold_lion",    weight = 1  },
        },
    },

    -- ── Egg 3: Crystal Egg ────────────────────────────────────────────────────
    {
        id             = "crystal_egg",
        name           = "Crystal Egg",
        description    = "Shimmers with crystalline energy.",
        coinCost       = 100000,
        gemCost        = 0,
        worldRequired  = 2,
        rebirthRequired= 1,
        isLimited      = false,
        pool = {
            { petId = "bronze_bear",     weight = 35 },
            { petId = "gem_mouse",       weight = 25 },
            { petId = "gold_lion",       weight = 20 },
            { petId = "diamond_hawk",    weight = 10 },
            { petId = "emerald_frog",    weight = 6  },
            { petId = "amethyst_dragon", weight = 3  },
            { petId = "crystal_phoenix", weight = 1  },
        },
    },

    -- ── Egg 4: Gem Egg ────────────────────────────────────────────────────────
    {
        id             = "gem_egg",
        name           = "Gem Egg",
        description    = "Packed with gemstone energy. Worth every coin.",
        coinCost       = 1000000,
        gemCost        = 0,
        worldRequired  = 2,
        rebirthRequired= 1,
        isLimited      = false,
        pool = {
            { petId = "ruby_tiger",      weight = 30 },
            { petId = "sapphire_fish",   weight = 25 },
            { petId = "obsidian_wolf",   weight = 20 },
            { petId = "void_panther",    weight = 12 },
            { petId = "storm_eagle",     weight = 8  },
            { petId = "celestial_cat",   weight = 4  },
            { petId = "golden_dragon",   weight = 1  },
        },
    },

    -- ── Egg 5: Void Egg ───────────────────────────────────────────────────────
    {
        id             = "void_egg",
        name           = "Void Egg",
        description    = "Pulled from the Starstone Abyss.",
        coinCost       = 0,
        gemCost        = 100,
        worldRequired  = 3,
        rebirthRequired= 3,
        isLimited      = false,
        pool = {
            { petId = "meteor_wolf",     weight = 30 },
            { petId = "starbound_bear",  weight = 25 },
            { petId = "nebula_serpent",  weight = 20 },
            { petId = "void_titan",      weight = 15 },
            { petId = "cosmos_fox",      weight = 8  },
            { petId = "eternal_phoenix", weight = 2  },
        },
    },

    -- ── Egg 6: Premium Egg ────────────────────────────────────────────────────
    {
        id             = "premium_egg",
        name           = "Premium Egg",
        description    = "Only the finest pets wait inside.",
        coinCost       = 0,
        gemCost        = 250,
        worldRequired  = 1,
        rebirthRequired= 0,
        isLimited      = false,
        pool = {
            { petId = "gold_lion",       weight = 25 },
            { petId = "diamond_hawk",    weight = 20 },
            { petId = "celestial_cat",   weight = 18 },
            { petId = "golden_dragon",   weight = 15 },
            { petId = "nebula_serpent",  weight = 10 },
            { petId = "cosmos_fox",      weight = 7  },
            { petId = "eternal_phoenix", weight = 4  },
            { petId = "crystal_overlord",weight = 1  },
        },
    },

    -- ── Egg 7: Event Egg (placeholder – seasonal) ─────────────────────────────
    {
        id             = "event_egg",
        name           = "Event Egg",
        description    = "A mysterious egg from a limited-time event!",
        coinCost       = 0,
        gemCost        = 0,
        worldRequired  = 1,
        rebirthRequired= 0,
        isLimited      = true,
        eventCurrency  = "EventTokens",
        eventCost      = 50,
        pool = {
            { petId = "cosmos_fox",       weight = 40 },
            { petId = "eternal_phoenix",  weight = 35 },
            { petId = "crystal_overlord", weight = 25 },
        },
    },

    -- ── Egg 8: Mythic Egg ─────────────────────────────────────────────────────
    {
        id             = "mythic_egg",
        name           = "Mythic Egg",
        description    = "Rumored to contain the rarest pets in existence.",
        coinCost       = 0,
        gemCost        = 500,
        worldRequired  = 3,
        rebirthRequired= 5,
        isLimited      = false,
        pool = {
            { petId = "nebula_serpent",  weight = 30 },
            { petId = "void_titan",      weight = 25 },
            { petId = "cosmos_fox",      weight = 20 },
            { petId = "eternal_phoenix", weight = 15 },
            { petId = "crystal_overlord",weight = 10 },
        },
    },
}

-- ─── Auto-Hatch Gamepass ──────────────────────────────────────────────────────
EggConfig.AutoHatchInterval = 3.0  -- seconds between auto-hatches

-- Build lookup by id
local eggById = {}
for _, egg in ipairs(EggConfig.Eggs) do
    eggById[egg.id] = egg
end
EggConfig.ById = eggById

return EggConfig
