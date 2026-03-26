--[[
    ZoneConfig.luau
    Zone definitions and unlock requirements
    MVP: 3 zones
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
        CoinValue = 1,
    },
    {
        Id = "forest_grove",
        Name = "Forest Grove",
        Order = 2,
        UnlockCost = 1000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 3.0,
        Description = "An enchanted grove deep in the forest.",
        Color = Color3.fromRGB(50, 150, 50),
        SpawnPosition = Vector3.new(200, 5, 0),
        CoinSpawnRate = 1.5,
        CoinValue = 3,
    },
    {
        Id = "crystal_caves",
        Name = "Crystal Caves",
        Order = 3,
        UnlockCost = 25000,
        UnlockCurrency = "Coins",
        CoinMultiplier = 10.0,
        Description = "Sparkling caves filled with crystalline treasures.",
        Color = Color3.fromRGB(100, 50, 200),
        SpawnPosition = Vector3.new(400, 5, 0),
        CoinSpawnRate = 2.0,
        CoinValue = 10,
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
