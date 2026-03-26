--[[
    EggConfig.luau
    All egg definitions with hatch tables
    MVP: 6 eggs across 3 zones
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
        Cost = 100,
        Currency = "Coins",
        HatchTime = 2.0,
        Image = "rbxassetid://0",
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
        Cost = 500,
        Currency = "Coins",
        HatchTime = 3.0,
        Image = "rbxassetid://0",
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
        Cost = 2500,
        Currency = "Coins",
        HatchTime = 3.5,
        Image = "rbxassetid://0",
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
        Cost = 10000,
        Currency = "Coins",
        HatchTime = 4.0,
        Image = "rbxassetid://0",
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
        Cost = 50000,
        Currency = "Coins",
        HatchTime = 5.0,
        Image = "rbxassetid://0",
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
        Cost = 250000,
        Currency = "Coins",
        HatchTime = 6.0,
        Image = "rbxassetid://0",
        Pets = {
            { PetId = "rubyflare",     Weight = 35 },
            { PetId = "obsidianfang",  Weight = 28 },
            { PetId = "topazstrike",   Weight = 20 },
            { PetId = "emeraldwyrm",   Weight = 12 },
            { PetId = "cosmicnova",    Weight = 5 },
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
