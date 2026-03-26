--[[
    PetConfig.luau
    All pet definitions with stats and rarity
    80+ pets across 16 eggs and 8 zones
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

    -- ═══════════════════════════════════════
    -- ZONE 4: VOLCANIC RIDGE
    -- ═══════════════════════════════════════

    -- Magma Egg Pets
    {
        Id = "cinderkit",
        Name = "Cinderkit",
        Rarity = "Common",
        Power = 100,
        Image = "rbxassetid://0",
        Description = "A small creature born from cooling embers.",
    },
    {
        Id = "scorchpup",
        Name = "Scorchpup",
        Rarity = "Common",
        Power = 120,
        Image = "rbxassetid://0",
        Description = "Leaves tiny scorch marks wherever it walks.",
    },
    {
        Id = "flamefang",
        Name = "Flamefang",
        Rarity = "Rare",
        Power = 250,
        Image = "rbxassetid://0",
        Description = "Fangs that burn with an eternal flame.",
    },
    {
        Id = "magmahowl",
        Name = "Magmahowl",
        Rarity = "Epic",
        Power = 550,
        Image = "rbxassetid://0",
        Description = "Its howl makes the ground tremble and crack.",
    },
    {
        Id = "volcanowyrm",
        Name = "Volcanowyrm",
        Rarity = "Legendary",
        Power = 1400,
        Image = "rbxassetid://0",
        Description = "Sleeps inside active volcanoes.",
    },

    -- Inferno Egg Pets
    {
        Id = "ashmote",
        Name = "Ashmote",
        Rarity = "Common",
        Power = 150,
        Image = "rbxassetid://0",
        Description = "A floating speck of sentient ash.",
    },
    {
        Id = "blazeclaw",
        Name = "Blazeclaw",
        Rarity = "Rare",
        Power = 320,
        Image = "rbxassetid://0",
        Description = "Claws wreathed in white-hot fire.",
    },
    {
        Id = "pyronix",
        Name = "Pyronix",
        Rarity = "Epic",
        Power = 700,
        Image = "rbxassetid://0",
        Description = "A phoenix reborn from volcanic glass.",
    },
    {
        Id = "infernotitan",
        Name = "Infernotitan",
        Rarity = "Legendary",
        Power = 1800,
        Image = "rbxassetid://0",
        Description = "An ancient titan forged in the planet's core.",
    },
    {
        Id = "moltendrake",
        Name = "Moltendrake",
        Rarity = "Mythic",
        Power = 4500,
        Image = "rbxassetid://0",
        Description = "A dragon made entirely of flowing lava.",
    },

    -- ═══════════════════════════════════════
    -- ZONE 5: FROZEN TUNDRA
    -- ═══════════════════════════════════════

    -- Frost Egg Pets
    {
        Id = "snowpuff",
        Name = "Snowpuff",
        Rarity = "Common",
        Power = 300,
        Image = "rbxassetid://0",
        Description = "A tiny ball of living snow.",
    },
    {
        Id = "icepaw",
        Name = "Icepaw",
        Rarity = "Common",
        Power = 350,
        Image = "rbxassetid://0",
        Description = "Leaves frozen footprints that never melt.",
    },
    {
        Id = "frostbite",
        Name = "Frostbite",
        Rarity = "Rare",
        Power = 700,
        Image = "rbxassetid://0",
        Description = "Its bite can freeze anything solid.",
    },
    {
        Id = "glacierheart",
        Name = "Glacierheart",
        Rarity = "Epic",
        Power = 1600,
        Image = "rbxassetid://0",
        Description = "A heart of pure glacier ice beats within.",
    },
    {
        Id = "blizzardwolf",
        Name = "Blizzardwolf",
        Rarity = "Legendary",
        Power = 4000,
        Image = "rbxassetid://0",
        Description = "Commands blizzards with a single howl.",
    },

    -- Arctic Egg Pets
    {
        Id = "sleetstep",
        Name = "Sleetstep",
        Rarity = "Common",
        Power = 400,
        Image = "rbxassetid://0",
        Description = "Dances gracefully across frozen lakes.",
    },
    {
        Id = "hailshard",
        Name = "Hailshard",
        Rarity = "Rare",
        Power = 900,
        Image = "rbxassetid://0",
        Description = "Made of countless tiny hailstones.",
    },
    {
        Id = "permafrost",
        Name = "Permafrost",
        Rarity = "Epic",
        Power = 2000,
        Image = "rbxassetid://0",
        Description = "As old as the ice age itself.",
    },
    {
        Id = "aurorabear",
        Name = "Aurorabear",
        Rarity = "Legendary",
        Power = 5000,
        Image = "rbxassetid://0",
        Description = "Its fur shimmers with the northern lights.",
    },
    {
        Id = "absolutezero",
        Name = "Absolutezero",
        Rarity = "Mythic",
        Power = 13000,
        Image = "rbxassetid://0",
        Description = "Exists at the coldest possible temperature.",
    },

    -- ═══════════════════════════════════════
    -- ZONE 6: CELESTIAL GARDEN
    -- ═══════════════════════════════════════

    -- Starlight Egg Pets
    {
        Id = "petalwisp",
        Name = "Petalwisp",
        Rarity = "Common",
        Power = 900,
        Image = "rbxassetid://0",
        Description = "A flower petal that floats on starlight.",
    },
    {
        Id = "moonbloom",
        Name = "Moonbloom",
        Rarity = "Common",
        Power = 1100,
        Image = "rbxassetid://0",
        Description = "Blooms only under celestial moonlight.",
    },
    {
        Id = "stardust",
        Name = "Stardust",
        Rarity = "Rare",
        Power = 2200,
        Image = "rbxassetid://0",
        Description = "Sprinkles glittering stardust wherever it goes.",
    },
    {
        Id = "nebulafawn",
        Name = "Nebulafawn",
        Rarity = "Epic",
        Power = 5000,
        Image = "rbxassetid://0",
        Description = "A fawn born within a colorful nebula.",
    },
    {
        Id = "celestialunicorn",
        Name = "Celestial Unicorn",
        Rarity = "Legendary",
        Power = 12000,
        Image = "rbxassetid://0",
        Description = "A unicorn that gallops across the heavens.",
    },

    -- Cosmic Bloom Egg Pets
    {
        Id = "astralsprout",
        Name = "Astralsprout",
        Rarity = "Common",
        Power = 1200,
        Image = "rbxassetid://0",
        Description = "A tiny sprout growing from a shooting star.",
    },
    {
        Id = "galaxyvine",
        Name = "Galaxyvine",
        Rarity = "Rare",
        Power = 2800,
        Image = "rbxassetid://0",
        Description = "Its vines stretch across galaxies.",
    },
    {
        Id = "solarflare",
        Name = "Solarflare",
        Rarity = "Epic",
        Power = 6500,
        Image = "rbxassetid://0",
        Description = "Burns with the intensity of a solar eruption.",
    },
    {
        Id = "cosmosdragon",
        Name = "Cosmos Dragon",
        Rarity = "Legendary",
        Power = 16000,
        Image = "rbxassetid://0",
        Description = "A dragon that breathes constellations.",
    },
    {
        Id = "etherealphoenix",
        Name = "Ethereal Phoenix",
        Rarity = "Mythic",
        Power = 40000,
        Image = "rbxassetid://0",
        Description = "Reborn from the light of a dying galaxy.",
    },

    -- ═══════════════════════════════════════
    -- ZONE 7: SHADOW REALM
    -- ═══════════════════════════════════════

    -- Dusk Egg Pets
    {
        Id = "shadowmite",
        Name = "Shadowmite",
        Rarity = "Common",
        Power = 3000,
        Image = "rbxassetid://0",
        Description = "A tiny mite made of living shadow.",
    },
    {
        Id = "nightcrawl",
        Name = "Nightcrawl",
        Rarity = "Common",
        Power = 3500,
        Image = "rbxassetid://0",
        Description = "Crawls silently through the darkest places.",
    },
    {
        Id = "gloomfang",
        Name = "Gloomfang",
        Rarity = "Rare",
        Power = 7000,
        Image = "rbxassetid://0",
        Description = "Its fangs drip with distilled darkness.",
    },
    {
        Id = "voidhound",
        Name = "Voidhound",
        Rarity = "Epic",
        Power = 16000,
        Image = "rbxassetid://0",
        Description = "Hunts through the spaces between dimensions.",
    },
    {
        Id = "abyssalking",
        Name = "Abyssal King",
        Rarity = "Legendary",
        Power = 40000,
        Image = "rbxassetid://0",
        Description = "Rules over the deepest darkness.",
    },

    -- Abyss Egg Pets
    {
        Id = "darkwhisper",
        Name = "Darkwhisper",
        Rarity = "Common",
        Power = 4000,
        Image = "rbxassetid://0",
        Description = "You can hear it, but never see it.",
    },
    {
        Id = "phantomblade",
        Name = "Phantomblade",
        Rarity = "Rare",
        Power = 9000,
        Image = "rbxassetid://0",
        Description = "Cuts through reality with spectral blades.",
    },
    {
        Id = "dreadlord",
        Name = "Dreadlord",
        Rarity = "Epic",
        Power = 20000,
        Image = "rbxassetid://0",
        Description = "Inspires pure dread in all who see it.",
    },
    {
        Id = "oblivionserpent",
        Name = "Oblivion Serpent",
        Rarity = "Legendary",
        Power = 50000,
        Image = "rbxassetid://0",
        Description = "A serpent that devours forgotten memories.",
    },
    {
        Id = "shadowmonarch",
        Name = "Shadow Monarch",
        Rarity = "Mythic",
        Power = 125000,
        Image = "rbxassetid://0",
        Description = "The supreme ruler of all shadows.",
    },

    -- ═══════════════════════════════════════
    -- ZONE 8: COSMIC VOID
    -- ═══════════════════════════════════════

    -- Void Egg Pets
    {
        Id = "voidmote",
        Name = "Voidmote",
        Rarity = "Common",
        Power = 10000,
        Image = "rbxassetid://0",
        Description = "A mote of anti-matter given sentience.",
    },
    {
        Id = "nebulawyrm",
        Name = "Nebulawyrm",
        Rarity = "Common",
        Power = 12000,
        Image = "rbxassetid://0",
        Description = "Swims through nebulae like a cosmic fish.",
    },
    {
        Id = "singularity",
        Name = "Singularity",
        Rarity = "Rare",
        Power = 25000,
        Image = "rbxassetid://0",
        Description = "An impossibly dense point that bends light.",
    },
    {
        Id = "quantumwolf",
        Name = "Quantumwolf",
        Rarity = "Epic",
        Power = 55000,
        Image = "rbxassetid://0",
        Description = "Exists in all places simultaneously.",
    },
    {
        Id = "cosmicreaper",
        Name = "Cosmic Reaper",
        Rarity = "Legendary",
        Power = 140000,
        Image = "rbxassetid://0",
        Description = "Harvests the energy of dying stars.",
    },

    -- Eternity Egg Pets
    {
        Id = "starforger",
        Name = "Starforger",
        Rarity = "Rare",
        Power = 30000,
        Image = "rbxassetid://0",
        Description = "Forges new stars from raw cosmic energy.",
    },
    {
        Id = "dimensionweaver",
        Name = "Dimensionweaver",
        Rarity = "Epic",
        Power = 70000,
        Image = "rbxassetid://0",
        Description = "Weaves new dimensions into existence.",
    },
    {
        Id = "infinitybeast",
        Name = "Infinity Beast",
        Rarity = "Legendary",
        Power = 180000,
        Image = "rbxassetid://0",
        Description = "A creature without beginning or end.",
    },
    {
        Id = "omnigod",
        Name = "Omnigod",
        Rarity = "Mythic",
        Power = 500000,
        Image = "rbxassetid://0",
        Description = "The ultimate being that transcends all.",
    },
    {
        Id = "realityshatter",
        Name = "Reality Shatter",
        Rarity = "Secret",
        Power = 1500000,
        Image = "rbxassetid://0",
        Description = "Breaks the fabric of reality with its mere existence.",
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
