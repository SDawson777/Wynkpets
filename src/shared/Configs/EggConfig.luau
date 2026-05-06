--[[
    EggConfig.luau
    All egg definitions with hatch tables
    16 eggs across 8 zones
]]

local EggConfig = {}

EggConfig.Eggs = {
    -- ═══════════════════════════════════════
    -- ZONE 1: STARTER MEADOW
    -- ═══════════════════════════════════════
    {
        Id = "basic_egg",
        Name = "Basic Egg",
        Zone = "starter_meadow",
        Cost = 25,
        Currency = "Coins",
        HatchTime = 1.5,
        Image = "rbxassetid://71530578168493",
        Pets = {
            { PetId = "whiskerling",  Weight = 40 },  -- Common 40%
            { PetId = "puddlejump",   Weight = 30 },  -- Common 30%
            { PetId = "fluffnose",    Weight = 20 },  -- Rare 20%
            { PetId = "sparkletail",  Weight = 8 },   -- Epic 8%
            { PetId = "glowbug",      Weight = 2 },   -- Legendary 2%
        },
    },
    {
        Id = "spotted_egg",
        Name = "Spotted Egg",
        Zone = "starter_meadow",
        Cost = 120,
        Currency = "Coins",
        HatchTime = 2.0,
        Image = "rbxassetid://107793415303146",
        Pets = {
            { PetId = "dottie",       Weight = 35 },  -- Common 35%
            { PetId = "specklefoot",  Weight = 25 },  -- Common 25%
            { PetId = "patchwhirl",   Weight = 20 },  -- Rare 20%
            { PetId = "shimmerspot",  Weight = 12 },  -- Epic 12%
            { PetId = "radiantdot",   Weight = 6 },   -- Legendary 6%
            { PetId = "prismapaw",    Weight = 2 },   -- Mythic 2%
        },
    },

    -- ═══════════════════════════════════════
    -- ZONE 2: FOREST GROVE
    -- ═══════════════════════════════════════
    {
        Id = "forest_egg",
        Name = "Forest Egg",
        Zone = "forest_grove",
        Cost = 500,
        Currency = "Coins",
        HatchTime = 2.5,
        Image = "rbxassetid://138135608847486",
        Pets = {
            { PetId = "leafling",     Weight = 35 },
            { PetId = "twigsnap",     Weight = 30 },
            { PetId = "mosswhisker",  Weight = 20 },
            { PetId = "thornbloom",   Weight = 10 },
            { PetId = "elderoak",     Weight = 5 },
        },
    },
    {
        Id = "enchanted_egg",
        Name = "Enchanted Egg",
        Zone = "forest_grove",
        Cost = 2500,
        Currency = "Coins",
        HatchTime = 3.0,
        Image = "rbxassetid://79266939756243",
        Pets = {
            { PetId = "pixiepuff",    Weight = 30 },
            { PetId = "willowisp",    Weight = 22 },
            { PetId = "fernshade",    Weight = 20 },
            { PetId = "glimmerfox",   Weight = 15 },
            { PetId = "starweaver",   Weight = 10 },
            { PetId = "moonlark",     Weight = 3 },
        },
    },

    -- ═══════════════════════════════════════
    -- ZONE 3: CRYSTAL CAVES
    -- ═══════════════════════════════════════
    {
        Id = "crystal_egg",
        Name = "Crystal Egg",
        Zone = "crystal_caves",
        Cost = 8000,
        Currency = "Coins",
        HatchTime = 3.5,
        Image = "rbxassetid://124181350534279",
        Pets = {
            { PetId = "gemshard",      Weight = 35 },
            { PetId = "quartzpaw",     Weight = 25 },
            { PetId = "amethystine",   Weight = 20 },
            { PetId = "sapphireclaw",  Weight = 15 },
            { PetId = "diamondwing",   Weight = 5 },
        },
    },
    {
        Id = "mythic_egg",
        Name = "Mythic Egg",
        Zone = "crystal_caves",
        Cost = 40000,
        Currency = "Coins",
        HatchTime = 4.0,
        Image = "rbxassetid://118573179077470",
        Pets = {
            { PetId = "rubyflare",     Weight = 35 },
            { PetId = "obsidianfang",  Weight = 28 },
            { PetId = "topazstrike",   Weight = 20 },
            { PetId = "emeraldwyrm",   Weight = 12 },
            { PetId = "cosmicnova",    Weight = 5 },
        },
    },

    -- ═══════════════════════════════════════
    -- ZONE 4: VOLCANIC RIDGE
    -- ═══════════════════════════════════════
    {
        Id = "magma_egg",
        Name = "Magma Egg",
        Zone = "volcanic_ridge",
        Cost = 150000,
        Currency = "Coins",
        HatchTime = 4.0,
        Image = "rbxassetid://116319066477642",
        Pets = {
            { PetId = "cinderkit",     Weight = 35 },
            { PetId = "scorchpup",     Weight = 28 },
            { PetId = "flamefang",     Weight = 20 },
            { PetId = "magmahowl",     Weight = 12 },
            { PetId = "volcanowyrm",   Weight = 5 },
        },
    },
    {
        Id = "inferno_egg",
        Name = "Inferno Egg",
        Zone = "volcanic_ridge",
        Cost = 600000,
        Currency = "Coins",
        HatchTime = 4.5,
        Image = "rbxassetid://134190647448034",
        Pets = {
            { PetId = "ashmote",       Weight = 30 },
            { PetId = "blazeclaw",     Weight = 25 },
            { PetId = "pyronix",       Weight = 22 },
            { PetId = "infernotitan",  Weight = 15 },
            { PetId = "moltendrake",   Weight = 8 },
        },
    },

    -- ═══════════════════════════════════════
    -- ZONE 5: FROZEN TUNDRA
    -- ═══════════════════════════════════════
    {
        Id = "frost_egg",
        Name = "Frost Egg",
        Zone = "frozen_tundra",
        Cost = 1500000,
        Currency = "Coins",
        HatchTime = 5.0,
        Image = "rbxassetid://92851289431171",
        Pets = {
            { PetId = "snowpuff",      Weight = 35 },
            { PetId = "icepaw",        Weight = 28 },
            { PetId = "frostbite",     Weight = 20 },
            { PetId = "glacierheart",  Weight = 12 },
            { PetId = "blizzardwolf",  Weight = 5 },
        },
    },
    {
        Id = "arctic_egg",
        Name = "Arctic Egg",
        Zone = "frozen_tundra",
        Cost = 6000000,
        Currency = "Coins",
        HatchTime = 5.5,
        Image = "rbxassetid://99383115331176",
        Pets = {
            { PetId = "sleetstep",     Weight = 30 },
            { PetId = "hailshard",     Weight = 25 },
            { PetId = "permafrost",    Weight = 22 },
            { PetId = "aurorabear",    Weight = 15 },
            { PetId = "absolutezero",  Weight = 8 },
        },
    },

    -- ═══════════════════════════════════════
    -- ZONE 6: CELESTIAL GARDEN
    -- ═══════════════════════════════════════
    {
        Id = "starlight_egg",
        Name = "Starlight Egg",
        Zone = "celestial_garden",
        Cost = 20000000,
        Currency = "Coins",
        HatchTime = 5.5,
        Image = "rbxassetid://94643370466870",
        Pets = {
            { PetId = "petalwisp",         Weight = 35 },
            { PetId = "moonbloom",         Weight = 28 },
            { PetId = "stardust",          Weight = 20 },
            { PetId = "nebulafawn",        Weight = 12 },
            { PetId = "celestialunicorn",  Weight = 5 },
        },
    },
    {
        Id = "cosmic_bloom_egg",
        Name = "Cosmic Bloom Egg",
        Zone = "celestial_garden",
        Cost = 75000000,
        Currency = "Coins",
        HatchTime = 6.0,
        Image = "rbxassetid://126467663965792",
        Pets = {
            { PetId = "astralsprout",      Weight = 30 },
            { PetId = "galaxyvine",        Weight = 25 },
            { PetId = "solarflare",        Weight = 22 },
            { PetId = "cosmosdragon",      Weight = 15 },
            { PetId = "etherealphoenix",   Weight = 8 },
        },
    },

    -- ═══════════════════════════════════════
    -- ZONE 7: SHADOW REALM
    -- ═══════════════════════════════════════
    {
        Id = "dusk_egg",
        Name = "Dusk Egg",
        Zone = "shadow_realm",
        Cost = 250000000,
        Currency = "Coins",
        HatchTime = 6.0,
        Image = "rbxassetid://101221483541198",
        Pets = {
            { PetId = "shadowmite",    Weight = 35 },
            { PetId = "nightcrawl",    Weight = 28 },
            { PetId = "gloomfang",     Weight = 20 },
            { PetId = "voidhound",     Weight = 12 },
            { PetId = "abyssalking",   Weight = 5 },
        },
    },
    {
        Id = "abyss_egg",
        Name = "Abyss Egg",
        Zone = "shadow_realm",
        Cost = 1000000000,
        Currency = "Coins",
        HatchTime = 6.5,
        Image = "rbxassetid://118466343085609",
        Pets = {
            { PetId = "darkwhisper",       Weight = 30 },
            { PetId = "phantomblade",      Weight = 25 },
            { PetId = "dreadlord",         Weight = 22 },
            { PetId = "oblivionserpent",   Weight = 15 },
            { PetId = "shadowmonarch",     Weight = 8 },
        },
    },

    -- ═══════════════════════════════════════
    -- ZONE 8: COSMIC VOID
    -- ═══════════════════════════════════════
    {
        Id = "void_egg",
        Name = "Void Egg",
        Zone = "cosmic_void",
        Cost = 5000000000,
        Currency = "Coins",
        HatchTime = 7.0,
        Image = "rbxassetid://122446887186873",
        Pets = {
            { PetId = "voidmote",      Weight = 35 },
            { PetId = "nebulawyrm",    Weight = 28 },
            { PetId = "singularity",   Weight = 20 },
            { PetId = "quantumwolf",   Weight = 12 },
            { PetId = "cosmicreaper",  Weight = 5 },
        },
    },
    {
        Id = "eternity_egg",
        Name = "Eternity Egg",
        Zone = "cosmic_void",
        Cost = 25000000000,
        Currency = "Coins",
        HatchTime = 7.5,
        Image = "rbxassetid://114904294170841",
        Pets = {
            { PetId = "starforger",        Weight = 30 },
            { PetId = "dimensionweaver",   Weight = 25 },
            { PetId = "infinitybeast",     Weight = 22 },
            { PetId = "omnigod",           Weight = 15 },
            { PetId = "realityshatter",    Weight = 8 },
        },
    },
}

-- Build lookup
EggConfig.EggById = {}
for _, egg in ipairs(EggConfig.Eggs) do
    EggConfig.EggById[egg.Id] = egg
end

function EggConfig.GetEgg(eggId: string)
    return EggConfig.EggById[eggId]
end

function EggConfig.GetEggsByZone(zoneId: string)
    local eggs = {}
    for _, egg in ipairs(EggConfig.Eggs) do
        if egg.Zone == zoneId then
            table.insert(eggs, egg)
        end
    end
    return eggs
end

return EggConfig
