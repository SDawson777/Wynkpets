-- MiningConfig.luau
-- Configuration for mining tools, rocks, and zones

local MiningConfig = {}

-- ─── Mining Tools ─────────────────────────────────────────────────────────────
-- Each tool has a damage value and a purchase price (coins)
MiningConfig.Tools = {
    {
        id          = "wooden_pickaxe",
        name        = "Wooden Pickaxe",
        damage      = 1,
        price       = 0,       -- starting tool, free
        currency    = "Coins",
    },
    {
        id          = "stone_pickaxe",
        name        = "Stone Pickaxe",
        damage      = 5,
        price       = 500,
        currency    = "Coins",
    },
    {
        id          = "iron_pickaxe",
        name        = "Iron Pickaxe",
        damage      = 15,
        price       = 5000,
        currency    = "Coins",
    },
    {
        id          = "gold_pickaxe",
        name        = "Gold Pickaxe",
        damage      = 50,
        price       = 50000,
        currency    = "Coins",
    },
    {
        id          = "diamond_pickaxe",
        name        = "Diamond Pickaxe",
        damage      = 150,
        price       = 500000,
        currency    = "Coins",
    },
    {
        id          = "crystal_pickaxe",
        name        = "Crystal Pickaxe",
        damage      = 500,
        price       = 5000000,
        currency    = "Coins",
    },
    {
        id          = "void_pickaxe",
        name        = "Void Pickaxe",
        damage      = 2000,
        price       = 50000000,
        currency    = "Coins",
    },
    {
        id          = "stellar_pickaxe",
        name        = "Stellar Pickaxe",
        damage      = 10000,
        price       = 500,
        currency    = "Gems",
    },
}

-- ─── Rock / Node Config ────────────────────────────────────────────────────────
-- hp: hits required to break at base damage=1
-- oreTable: weighted loot table {ore, weight}
MiningConfig.Rocks = {
    -- World 1: Starter Mine
    {
        id       = "coal_rock",
        name     = "Coal Rock",
        hp       = 5,
        world    = 1,
        oreTable = {
            { ore = "Coal",   weight = 80 },
            { ore = "Copper", weight = 20 },
        },
    },
    {
        id       = "copper_rock",
        name     = "Copper Rock",
        hp       = 15,
        world    = 1,
        oreTable = {
            { ore = "Copper", weight = 70 },
            { ore = "Iron",   weight = 30 },
        },
    },
    -- World 2: Crystal Caverns
    {
        id       = "silver_rock",
        name     = "Silver Rock",
        hp       = 50,
        world    = 2,
        oreTable = {
            { ore = "Silver",  weight = 60 },
            { ore = "Gold",    weight = 30 },
            { ore = "Diamond", weight = 10 },
        },
    },
    {
        id       = "gemstone_rock",
        name     = "Gemstone Rock",
        hp       = 150,
        world    = 2,
        oreTable = {
            { ore = "Diamond", weight = 50 },
            { ore = "Emerald", weight = 30 },
            { ore = "Ruby",    weight = 20 },
        },
    },
    -- World 3: Starstone Abyss
    {
        id       = "crystal_rock",
        name     = "Crystal Rock",
        hp       = 500,
        world    = 3,
        oreTable = {
            { ore = "Crystal",   weight = 55 },
            { ore = "Amethyst",  weight = 30 },
            { ore = "Obsidian",  weight = 15 },
        },
    },
    {
        id       = "starstone_rock",
        name     = "Starstone Rock",
        hp       = 2000,
        world    = 3,
        oreTable = {
            { ore = "Starstone", weight = 40 },
            { ore = "Crystal",   weight = 40 },
            { ore = "Sapphire",  weight = 20 },
        },
    },
}

-- ─── Click / Swing Cooldown ────────────────────────────────────────────────────
MiningConfig.BaseMineInterval = 0.5  -- seconds between swings (base)
MiningConfig.MinMineInterval  = 0.1  -- fastest possible swing (with speed boosts)

-- ─── Auto-Mine Gamepass Config ────────────────────────────────────────────────
MiningConfig.AutoMineInterval = 1.0  -- seconds between auto-swings

return MiningConfig
