--[[
    GamepassConfig.luau
    Gamepass definitions for permanent purchases
    MVP: 5 gamepasses
    NOTE: Replace ProductId values with real Roblox gamepass IDs before publishing
]]

local GamepassConfig = {}

GamepassConfig.Gamepasses = {
    {
        Id = "2x_coins",
        Name = "2x Coins",
        ProductId = 0, -- REPLACE with real gamepass ID
        Price = 99,
        Description = "Permanently earn 2x Coins from all sources!",
        Icon = "rbxassetid://0",
        Multiplier = 2.0,
        Category = "Multiplier",
    },
    {
        Id = "2x_gems",
        Name = "2x Gems",
        ProductId = 0, -- REPLACE with real gamepass ID
        Price = 149,
        Description = "Permanently earn 2x Gems from all sources!",
        Icon = "rbxassetid://0",
        Multiplier = 2.0,
        Category = "Multiplier",
    },
    {
        Id = "auto_hatch",
        Name = "Auto Hatch",
        ProductId = 0, -- REPLACE with real gamepass ID
        Price = 399,
        Description = "Automatically hatch eggs when you have enough coins!",
        Icon = "rbxassetid://0",
        Category = "Automation",
    },
    {
        Id = "triple_hatch",
        Name = "Triple Hatch",
        ProductId = 0, -- REPLACE with real gamepass ID
        Price = 499,
        Description = "Hatch 3 eggs at once for 3x the pets!",
        Icon = "rbxassetid://0",
        HatchCount = 3,
        Category = "Hatching",
    },
    {
        Id = "vip",
        Name = "VIP",
        ProductId = 0, -- REPLACE with real gamepass ID
        Price = 799,
        Description = "VIP status! +50% all currencies, exclusive VIP area, VIP chat tag, and more!",
        Icon = "rbxassetid://0",
        CurrencyBonus = 1.5,
        ExtraEquipSlots = 3,
        Category = "Premium",
    },
}

-- Build lookup
GamepassConfig.GamepassById = {}
GamepassConfig.GamepassByProductId = {}
for _, gp in ipairs(GamepassConfig.Gamepasses) do
    GamepassConfig.GamepassById[gp.Id] = gp
    if gp.ProductId > 0 then
        GamepassConfig.GamepassByProductId[gp.ProductId] = gp
    end
end

function GamepassConfig.GetGamepass(gamepassId: string)
    return GamepassConfig.GamepassById[gamepassId]
end

return GamepassConfig
