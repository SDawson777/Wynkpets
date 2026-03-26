--[[
    PetConfig.luau
    All pet definitions with stats and rarity
    MVP: 31 pets across 6 eggs and 3 zones
]]

local PetConfig = {}

PetConfig.Pets = {
    -- ═══════════════════════════════════════
    -- ZONE 1: STARTER MEADOW
    -- ═══════════════════════════════════════

    -- Basic Egg Pets
    {
        Id = "whiskerling",
        Name = "Whiskerling",
        Rarity = "Common",
        Power = 1,
        Image = "rbxassetid://0",
        Description = "A tiny critter with twitchy whiskers.",
    },
    {
        Id = "puddlejump",
        Name = "Puddlejump",
        Rarity = "Common",
        Power = 2,
        Image = "rbxassetid://0",
        Description = "Loves to splash in puddles!",
    },
    {
        Id = "fluffnose",
        Name = "Fluffnose",
        Rarity = "Rare",
        Power = 5,
        Image = "rbxassetid://0",
        Description = "So fluffy it can barely see.",
    },
    {
        Id = "sparkletail",
        Name = "Sparkletail",
        Rarity = "Epic",
        Power = 12,
        Image = "rbxassetid://0",
        Description = "Its tail glows when it's happy.",
    },
    {
        Id = "glowbug",
        Name = "Glowbug",
        Rarity = "Legendary",
        Power = 30,
        Image = "rbxassetid://0",
        Description = "A luminous bug from the meadow depths.",
    },

    -- Spotted Egg Pets
    {
        Id = "dottie",
        Name = "Dottie",
        Rarity = "Common",
        Power = 3,
        Image = "rbxassetid://0",
        Description = "Covered head to toe in spots.",
    },
    {
        Id = "specklefoot",
        Name = "Specklefoot",
        Rarity = "Common",
        Power = 4,
        Image = "rbxassetid://0",
        Description = "Leaves spotted footprints wherever it goes.",
    },
    {
        Id = "patchwhirl",
        Name = "Patchwhirl",
        Rarity = "Rare",
        Power = 8,
        Image = "rbxassetid://0",
        Description = "Spins around showing off its patches.",
    },
    {
        Id = "shimmerspot",
        Name = "Shimmerspot",
        Rarity = "Epic",
        Power = 18,
        Image = "rbxassetid://0",
        Description = "Its spots shimmer with magical light.",
    },
    {
        Id = "radiantdot",
        Name = "Radiantdot",
        Rarity = "Legendary",
        Power = 45,
        Image = "rbxassetid://0",
        Description = "A single radiant dot powers its whole body.",
    },
    {
        Id = "prismapaw",
        Name = "Prismapaw",
        Rarity = "Mythic",
        Power = 120,
        Image = "rbxassetid://0",
        Description = "Refracts light into rainbows with each step.",
    },

    -- ═══════════════════════════════════════
    -- ZONE 2: FOREST GROVE
    -- ═══════════════════════════════════════

    -- Forest Egg Pets
    {
        Id = "leafling",
        Name = "Leafling",
        Rarity = "Common",
        Power = 10,
        Image = "rbxassetid://0",
        Description = "A tiny spirit made of fallen leaves.",
    },
    {
        Id = "twigsnap",
        Name = "Twigsnap",
        Rarity = "Common",
        Power = 12,
        Image = "rbxassetid://0",
        Description = "Snaps twigs with its tiny claws.",
    },
    {
        Id = "mosswhisker",
        Name = "Mosswhisker",
        Rarity = "Rare",
        Power = 25,
        Image = "rbxassetid://0",
        Description = "Moss grows on its long whiskers.",
    },
    {
        Id = "thornbloom",
        Name = "Thornbloom",
        Rarity = "Epic",
        Power = 55,
        Image = "rbxassetid://0",
        Description = "Beautiful but watch out for the thorns!",
    },
    {
        Id = "elderoak",
        Name = "Elderoak",
        Rarity = "Legendary",
        Power = 140,
        Image = "rbxassetid://0",
        Description = "Ancient as the forest itself.",
    },

    -- Enchanted Egg Pets
    {
        Id = "pixiepuff",
        Name = "Pixiepuff",
        Rarity = "Common",
        Power = 15,
        Image = "rbxassetid://0",
        Description = "A puffy little pixie creature.",
    },
    {
        Id = "willowisp",
        Name = "Willowisp",
        Rarity = "Rare",
        Power = 30,
        Image = "rbxassetid://0",
        Description = "Floats gently like a willow in wind.",
    },
    {
        Id = "fernshade",
        Name = "Fernshade",
        Rarity = "Rare",
        Power = 35,
        Image = "rbxassetid://0",
        Description = "Hides in the shade of giant ferns.",
    },
    {
        Id = "glimmerfox",
        Name = "Glimmerfox",
        Rarity = "Epic",
        Power = 70,
        Image = "rbxassetid://0",
        Description = "A fox that glimmers with enchanted light.",
    },
    {
        Id = "starweaver",
        Name = "Starweaver",
        Rarity = "Legendary",
        Power = 180,
        Image = "rbxassetid://0",
        Description = "Weaves starlight into magical threads.",
    },
    {
        Id = "moonlark",
        Name = "Moonlark",
        Rarity = "Mythic",
        Power = 450,
        Image = "rbxassetid://0",
        Description = "Sings only under the light of the moon.",
    },

    -- ═══════════════════════════════════════
    -- ZONE 3: CRYSTAL CAVES
    -- ═══════════════════════════════════════

    -- Crystal Egg Pets
    {
        Id = "gemshard",
        Name = "Gemshard",
        Rarity = "Common",
        Power = 40,
        Image = "rbxassetid://0",
        Description = "A living shard of crystal energy.",
    },
    {
        Id = "quartzpaw",
        Name = "Quartzpaw",
        Rarity = "Rare",
        Power = 80,
        Image = "rbxassetid://0",
        Description = "Paws made of polished quartz.",
    },
    {
        Id = "amethystine",
        Name = "Amethystine",
        Rarity = "Epic",
        Power = 180,
        Image = "rbxassetid://0",
        Description = "A regal creature born from amethyst.",
    },
    {
        Id = "sapphireclaw",
        Name = "Sapphireclaw",
        Rarity = "Legendary",
        Power = 450,
        Image = "rbxassetid://0",
        Description = "Claws sharper than any sapphire.",
    },
    {
        Id = "diamondwing",
        Name = "Diamondwing",
        Rarity = "Mythic",
        Power = 1200,
        Image = "rbxassetid://0",
        Description = "Wings of pure diamond cut through the air.",
    },

    -- Mythic Egg Pets
    {
        Id = "rubyflare",
        Name = "Rubyflare",
        Rarity = "Rare",
        Power = 100,
        Image = "rbxassetid://0",
        Description = "Burns with the fire of a thousand rubies.",
    },
    {
        Id = "obsidianfang",
        Name = "Obsidianfang",
        Rarity = "Epic",
        Power = 250,
        Image = "rbxassetid://0",
        Description = "Fangs forged in volcanic obsidian.",
    },
    {
        Id = "topazstrike",
        Name = "Topazstrike",
        Rarity = "Legendary",
        Power = 600,
        Image = "rbxassetid://0",
        Description = "Strikes with electrified topaz energy.",
    },
    {
        Id = "emeraldwyrm",
        Name = "Emeraldwyrm",
        Rarity = "Mythic",
        Power = 1500,
        Image = "rbxassetid://0",
        Description = "An ancient wyrm made of living emerald.",
    },
    {
        Id = "cosmicnova",
        Name = "Cosmicnova",
        Rarity = "Secret",
        Power = 5000,
        Image = "rbxassetid://0",
        Description = "Born from the explosion of a dying star.",
    },
}

-- Build lookup table
PetConfig.PetById = {}
for _, pet in ipairs(PetConfig.Pets) do
    PetConfig.PetById[pet.Id] = pet
end

function PetConfig.GetPet(petId: string)
    return PetConfig.PetById[petId]
end

return PetConfig
