--[[
    SecretConfig.luau
    Defines secret orb locations, respawn behavior, zone set rewards,
    secret portals (bonus rooms), and the hidden 9th zone ("Secret Garden").

    ORB SYSTEM:
    - Each zone has 3 orbs of a unique color for that zone.
    - Collecting all 3 orbs in one zone completes that zone's "Orb Set".
    - Completing an Orb Set awards an exclusive Secret-rarity pet.
    - After an orb is collected, it disappears globally for RespawnDelay seconds,
      then reappears for players who haven't yet collected it.
]]

local SecretConfig = {}

SecretConfig.TokensPerZone = 3
SecretConfig.TotalTokens = 24 -- 3 per zone x 8 zones
SecretConfig.TokenReward = 5  -- gems per token
SecretConfig.RespawnDelay = 600 -- seconds before orb reappears globally (10 min)

-- Token visual settings (defaults; zone-specific color overrides below)
SecretConfig.TokenSize = Vector3.new(2, 2, 2)
SecretConfig.TokenLightRange = 8
SecretConfig.TokenLightBrightness = 2

-- ───────────────────────────────────────────────────────────
-- ZONE ORB COLORS — each zone has a distinct hue
-- ───────────────────────────────────────────────────────────
SecretConfig.ZoneOrbColors = {
    starter_meadow   = Color3.fromRGB(120, 255, 80),   -- Lime green
    forest_grove     = Color3.fromRGB(40, 180, 60),    -- Deep forest green
    crystal_caves    = Color3.fromRGB(80, 220, 255),   -- Cyan / ice blue
    volcanic_ridge   = Color3.fromRGB(255, 90, 20),    -- Orange-red lava
    frozen_tundra    = Color3.fromRGB(160, 220, 255),  -- Pale arctic blue
    celestial_garden = Color3.fromRGB(200, 120, 255),  -- Purple-violet
    shadow_realm     = Color3.fromRGB(140, 20, 200),   -- Dark deep purple
    cosmic_void      = Color3.fromRGB(255, 60, 220),   -- Neon pink/magenta
}

-- ───────────────────────────────────────────────────────────
-- ORB SETS — collect all 3 orbs in a zone to unlock a Secret pet
-- ───────────────────────────────────────────────────────────
SecretConfig.OrbSets = {
    starter_meadow   = { RequiredCount = 3, RewardPetId = "meadow_guardian" },
    forest_grove     = { RequiredCount = 3, RewardPetId = "forest_spirit" },
    crystal_caves    = { RequiredCount = 3, RewardPetId = "crystal_keeper" },
    volcanic_ridge   = { RequiredCount = 3, RewardPetId = "magma_guardian" },
    frozen_tundra    = { RequiredCount = 3, RewardPetId = "frost_sentinel" },
    celestial_garden = { RequiredCount = 3, RewardPetId = "celestial_herald" },
    shadow_realm     = { RequiredCount = 3, RewardPetId = "void_watcher" },
    cosmic_void      = { RequiredCount = 3, RewardPetId = "cosmos_herald" },
}

-- Ordered zone list (used by SecretService to iterate sets in display order)
SecretConfig.ZoneOrder = {
    "starter_meadow", "forest_grove", "crystal_caves", "volcanic_ridge",
    "frozen_tundra", "celestial_garden", "shadow_realm", "cosmic_void",
}

-- Token positions: offsets from zone SpawnPosition
-- Hidden near decorative props (which are at radius 25-65) and border walls (81 studs)
SecretConfig.TokenLocations = {
    starter_meadow = {
        Vector3.new(58, 1, 35),   -- behind a tree near edge
        Vector3.new(-52, 1, -48), -- behind bush near corner
        Vector3.new(35, 1, -60),  -- near border wall
    },
    forest_grove = {
        Vector3.new(-60, 1, 22),  -- behind big tree
        Vector3.new(45, 1, -50),  -- behind mushroom
        Vector3.new(-32, 1, 55),  -- behind vine prop
    },
    crystal_caves = {
        Vector3.new(62, 1, -38),  -- behind crystal
        Vector3.new(-55, 1, 42),  -- behind stalagmite
        Vector3.new(18, 1, 62),   -- near border
    },
    volcanic_ridge = {
        Vector3.new(-50, 1, -50), -- behind lavarock
        Vector3.new(55, 1, 30),   -- behind ember
        Vector3.new(-35, 1, 58),  -- near vent
    },
    frozen_tundra = {
        Vector3.new(48, 1, -55),  -- behind icespike
        Vector3.new(-58, 1, 15),  -- behind snowdrift
        Vector3.new(25, 1, 60),   -- behind frostcrystal
    },
    celestial_garden = {
        Vector3.new(-55, 1, -40), -- behind starflower
        Vector3.new(60, 1, 25),   -- behind moonpillar
        Vector3.new(-20, 1, 62),  -- behind cloudpuff
    },
    shadow_realm = {
        Vector3.new(55, 1, -45),  -- behind darkthorn
        Vector3.new(-60, 1, 30),  -- behind voidcrystal
        Vector3.new(30, 1, -60),  -- behind shadowpillar
    },
    cosmic_void = {
        Vector3.new(-55, 1, -55), -- behind neonpillar
        Vector3.new(58, 1, 40),   -- behind voidorb
        Vector3.new(-40, 1, 58),  -- behind stargate
    },
}

-- Secret portals leading to bonus rooms (in zones 3, 5, 7)
SecretConfig.SecretPortals = {
    {
        SourceZone = "crystal_caves",
        Position = Vector3.new(-65, 0, 55), -- near corner, tucked away
        BonusRoomName = "Crystal Grotto",
        Duration = 30,
        CoinMultiplier = 5,
        BonusCoins = 15,
        SpecialEggId = "crystal_egg",
        RoomColor = Color3.fromRGB(150, 220, 255),
    },
    {
        SourceZone = "frozen_tundra",
        Position = Vector3.new(60, 0, -60),
        BonusRoomName = "Frozen Vault",
        Duration = 30,
        CoinMultiplier = 5,
        BonusCoins = 15,
        SpecialEggId = "frost_egg",
        RoomColor = Color3.fromRGB(200, 240, 255),
    },
    {
        SourceZone = "shadow_realm",
        Position = Vector3.new(-55, 0, -55),
        BonusRoomName = "Shadow Sanctum",
        Duration = 30,
        CoinMultiplier = 5,
        BonusCoins = 15,
        SpecialEggId = "dusk_egg",
        RoomColor = Color3.fromRGB(80, 20, 120),
    },
}

-- Hidden 9th zone — unlock threshold
SecretConfig.HiddenZoneTokenThreshold = 16 -- need 16 of 24 tokens

SecretConfig.HiddenZone = {
    Id = "secret_garden",
    Name = "Secret Garden",
    SpawnPosition = Vector3.new(0, 5, -300),
    PlatformSize = 100,
    Color = Color3.fromRGB(255, 200, 100),
    CoinValue = 50000,
    CoinCount = 40,
    Material = Enum.Material.ForceField,
}

return SecretConfig
