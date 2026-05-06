--[[
    ZoneConfig.luau
    Zone definitions and unlock requirements
    8 zones from starter to endgame
]]

local ZoneConfig = {}

ZoneConfig.Zones = {
    {
        Id = "starter_meadow",
        Name = "Starter Meadow",
        Order = 1,
        UnlockCost = 0,
        UnlockCurrency = "Coins",
        CoinMultiplier = 1.0,
        Description = "A peaceful meadow where your journey begins.",
        Color = Color3.fromRGB(120, 200, 80),
        SpawnPosition = Vector3.new(0, 5, 0),
        CoinSpawnRate = 1.0,
        CoinValue = 5,
    },
    {
        Id = "forest_grove",
        Name = "Forest Grove",
        Order = 2,
        UnlockCost = 750,
        UnlockCurrency = "Coins",
        CoinMultiplier = 3.0,
        Description = "An enchanted grove deep in the forest.",
        Color = Color3.fromRGB(50, 150, 50),
        SpawnPosition = Vector3.new(200, 5, 0),
        CoinSpawnRate = 1.5,
        CoinValue = 25,
    },
    {
        Id = "crystal_caves",
        Name = "Crystal Caves",
        Order = 3,
        UnlockCost = 7000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 10.0,
        Description = "Sparkling caves filled with crystalline treasures.",
        Color = Color3.fromRGB(100, 50, 200),
        SpawnPosition = Vector3.new(400, 5, 0),
        CoinSpawnRate = 2.0,
        CoinValue = 65,
    },
    {
        Id = "volcanic_ridge",
        Name = "Volcanic Ridge",
        Order = 4,
        UnlockCost = 100000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 25.0,
        Description = "A smoldering ridge where magma flows beneath the surface.",
        Color = Color3.fromRGB(220, 80, 30),
        SpawnPosition = Vector3.new(600, 5, 0),
        CoinSpawnRate = 2.5,
        CoinValue = 200,
    },
    {
        Id = "frozen_tundra",
        Name = "Frozen Tundra",
        Order = 5,
        UnlockCost = 500000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 60.0,
        Description = "An icy wasteland where only the hardiest creatures survive.",
        Color = Color3.fromRGB(150, 220, 255),
        SpawnPosition = Vector3.new(800, 5, 0),
        CoinSpawnRate = 3.0,
        CoinValue = 600,
    },
    {
        Id = "celestial_garden",
        Name = "Celestial Garden",
        Order = 6,
        UnlockCost = 2500000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 150.0,
        Description = "A garden floating among the stars, blooming with magic.",
        Color = Color3.fromRGB(200, 150, 255),
        SpawnPosition = Vector3.new(1000, 5, 0),
        CoinSpawnRate = 3.5,
        CoinValue = 2000,
    },
    {
        Id = "shadow_realm",
        Name = "Shadow Realm",
        Order = 7,
        UnlockCost = 15000000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 400.0,
        Description = "A dark dimension where shadows take physical form.",
        Color = Color3.fromRGB(60, 20, 80),
        SpawnPosition = Vector3.new(1200, 5, 0),
        CoinSpawnRate = 4.0,
        CoinValue = 7500,
    },
    {
        Id = "cosmic_void",
        Name = "Cosmic Void",
        Order = 8,
        UnlockCost = 100000000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 1000.0,
        Description = "The edge of existence where reality unravels into pure energy.",
        Color = Color3.fromRGB(20, 0, 50),
        SpawnPosition = Vector3.new(1400, 5, 0),
        CoinSpawnRate = 5.0,
        CoinValue = 25000,
    },
}

-- Build lookup
ZoneConfig.ZoneById = {}
for _, zone in ipairs(ZoneConfig.Zones) do
    ZoneConfig.ZoneById[zone.Id] = zone
end

function ZoneConfig.GetZone(zoneId: string)
    return ZoneConfig.ZoneById[zoneId]
end

function ZoneConfig.GetZoneByOrder(order: number)
    for _, zone in ipairs(ZoneConfig.Zones) do
        if zone.Order == order then
            return zone
        end
    end
    return nil
end

return ZoneConfig
