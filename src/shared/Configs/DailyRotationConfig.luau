--[[
    DailyRotationConfig.luau
    Themes, special eggs, and mutation pool for the daily rotation system.
    Content rotates deterministically each day to keep games fresh.
]]

local DailyRotationConfig = {}

-- Daily themes that affect gameplay and visuals
DailyRotationConfig.Themes = {
    {
        Id = "golden_hour",
        Name = "Golden Hour",
        TintColor = Color3.fromRGB(255, 200, 100),
        BoostType = "Coins",
        BoostMultiplier = 2,
        Description = "Everything glows golden! 2x Coins all day!",
    },
    {
        Id = "shadow_night",
        Name = "Shadow Night",
        TintColor = Color3.fromRGB(80, 20, 120),
        BoostType = "Luck",
        BoostMultiplier = 2,
        Description = "Dark forces boost rare drops! 2x Luck!",
    },
    {
        Id = "crystal_dawn",
        Name = "Crystal Dawn",
        TintColor = Color3.fromRGB(150, 220, 255),
        BoostType = "Coins",
        BoostMultiplier = 1.5,
        Description = "Crystal energy fills the air! 1.5x Coins!",
    },
    {
        Id = "blazing_noon",
        Name = "Blazing Noon",
        TintColor = Color3.fromRGB(255, 120, 50),
        BoostType = "XP",
        BoostMultiplier = 2,
        Description = "Scorching energy powers your pets! 2x XP!",
    },
    {
        Id = "rainbow_surge",
        Name = "Rainbow Surge",
        TintColor = Color3.fromRGB(255, 100, 255),
        BoostType = "Luck",
        BoostMultiplier = 3,
        Description = "Rainbow energy everywhere! 3x Luck for rare pets!",
    },
    {
        Id = "frost_realm",
        Name = "Frost Realm",
        TintColor = Color3.fromRGB(180, 230, 255),
        BoostType = "HatchSpeed",
        BoostMultiplier = 2,
        Description = "Frozen winds speed up hatching! 2x Hatch Speed!",
    },
    {
        Id = "emerald_tide",
        Name = "Emerald Tide",
        TintColor = Color3.fromRGB(50, 220, 120),
        BoostType = "Coins",
        BoostMultiplier = 2.5,
        Description = "Emerald waves of wealth! 2.5x Coins!",
    },
    {
        Id = "void_eclipse",
        Name = "Void Eclipse",
        TintColor = Color3.fromRGB(40, 10, 60),
        BoostType = "Luck",
        BoostMultiplier = 2.5,
        Description = "The void calls! 2.5x Luck for cosmic pets!",
    },
    {
        Id = "star_shower",
        Name = "Star Shower",
        TintColor = Color3.fromRGB(255, 255, 180),
        BoostType = "XP",
        BoostMultiplier = 3,
        Description = "Stars rain down! 3x XP for all pets!",
    },
    {
        Id = "gem_rush",
        Name = "Gem Rush",
        TintColor = Color3.fromRGB(100, 200, 255),
        BoostType = "Gems",
        BoostMultiplier = 2,
        Description = "Gems sparkle everywhere! 2x Gem drops!",
    },
}

-- Special eggs that rotate into the shop daily
DailyRotationConfig.SpecialEggs = {
    {
        Id = "mystery_egg",
        Name = "Mystery Egg",
        Cost = 500,
        Currency = "Gems",
        HatchTime = 3,
        Pets = {
            { PetId = "glimmer_kitten", Weight = 30 },
            { PetId = "ember_fox", Weight = 25 },
            { PetId = "crystal_wolf", Weight = 15 },
            { PetId = "nova_phoenix", Weight = 10 },
            { PetId = "void_dragon", Weight = 5 },
        },
    },
    {
        Id = "mega_egg",
        Name = "Mega Egg",
        Cost = 1000,
        Currency = "Gems",
        HatchTime = 5,
        Pets = {
            { PetId = "crystal_wolf", Weight = 25 },
            { PetId = "lava_serpent", Weight = 20 },
            { PetId = "nova_phoenix", Weight = 15 },
            { PetId = "astral_unicorn", Weight = 10 },
            { PetId = "void_dragon", Weight = 8 },
        },
    },
    {
        Id = "lucky_egg",
        Name = "Lucky Egg",
        Cost = 750,
        Currency = "Gems",
        HatchTime = 4,
        Pets = {
            { PetId = "frost_bunny", Weight = 30 },
            { PetId = "shadow_panther", Weight = 20 },
            { PetId = "celestial_stag", Weight = 15 },
            { PetId = "nebula_serpent", Weight = 10 },
            { PetId = "cosmic_leviathan", Weight = 5 },
        },
    },
    {
        Id = "elite_egg",
        Name = "Elite Egg",
        Cost = 2000,
        Currency = "Gems",
        HatchTime = 6,
        Pets = {
            { PetId = "nova_phoenix", Weight = 20 },
            { PetId = "astral_unicorn", Weight = 15 },
            { PetId = "void_dragon", Weight = 12 },
            { PetId = "nebula_serpent", Weight = 10 },
            { PetId = "cosmic_leviathan", Weight = 8 },
        },
    },
    {
        Id = "celestial_egg",
        Name = "Celestial Egg",
        Cost = 1500,
        Currency = "Gems",
        HatchTime = 5,
        Pets = {
            { PetId = "celestial_stag", Weight = 25 },
            { PetId = "star_weaver", Weight = 20 },
            { PetId = "aurora_moth", Weight = 15 },
            { PetId = "galactic_whale", Weight = 10 },
            { PetId = "cosmic_leviathan", Weight = 5 },
        },
    },
}

-- Pre-defined mutation variants (AI-generated offline images)
-- When fusing 3 of the same pet, small chance to get a mutation
DailyRotationConfig.MutationPool = {
    { BasePetId = "whiskerling", MutationId = "frost_whiskerling", MutationName = "Frost Whiskerling", PowerMultiplier = 1.5, Image = "rbxassetid://119535416476730" },
    { BasePetId = "whiskerling", MutationId = "shadow_whiskerling", MutationName = "Shadow Whiskerling", PowerMultiplier = 1.5, Image = "rbxassetid://136259687528478" },
    { BasePetId = "glimmer_kitten", MutationId = "fire_glimmer_kitten", MutationName = "Fire Glimmer Kitten", PowerMultiplier = 1.5, Image = "rbxassetid://105704221480146" },
    { BasePetId = "ember_fox", MutationId = "ice_ember_fox", MutationName = "Ice Ember Fox", PowerMultiplier = 1.5, Image = "rbxassetid://76318407552835" },
    { BasePetId = "ember_fox", MutationId = "void_ember_fox", MutationName = "Void Ember Fox", PowerMultiplier = 1.8, Image = "rbxassetid://134360655666953" },
    { BasePetId = "crystal_wolf", MutationId = "lava_crystal_wolf", MutationName = "Lava Crystal Wolf", PowerMultiplier = 1.5, Image = "rbxassetid://76529827964479" },
    { BasePetId = "lava_serpent", MutationId = "frost_lava_serpent", MutationName = "Frost Lava Serpent", PowerMultiplier = 1.5, Image = "rbxassetid://121021137966728" },
    { BasePetId = "shadow_panther", MutationId = "golden_shadow_panther", MutationName = "Golden Shadow Panther", PowerMultiplier = 1.8, Image = "rbxassetid://104207916657597" },
    { BasePetId = "nova_phoenix", MutationId = "void_nova_phoenix", MutationName = "Void Nova Phoenix", PowerMultiplier = 2.0, Image = "rbxassetid://71680113575367" },
    { BasePetId = "void_dragon", MutationId = "celestial_void_dragon", MutationName = "Celestial Void Dragon", PowerMultiplier = 2.0, Image = "rbxassetid://104984857859549" },
    { BasePetId = "frost_bunny", MutationId = "blazing_frost_bunny", MutationName = "Blazing Frost Bunny", PowerMultiplier = 1.5, Image = "rbxassetid://106915617744964" },
    { BasePetId = "celestial_stag", MutationId = "shadow_celestial_stag", MutationName = "Shadow Celestial Stag", PowerMultiplier = 1.8, Image = "rbxassetid://78021654053102" },
}

-- How many featured pets rotate each day
DailyRotationConfig.FeaturedPetCount = 4

-- How many mutations are available each day
DailyRotationConfig.MutationCount = 2

-- Featured pets get this weight multiplier in egg hatching
DailyRotationConfig.FeaturedWeightMultiplier = 2.0

-- Chance for a mutation result when fusing 3 of the same base pet
DailyRotationConfig.MutationChance = 0.10

return DailyRotationConfig
