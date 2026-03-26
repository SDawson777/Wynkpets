--[[
    DevProductConfig.luau
    Developer product definitions for consumable purchases
    MVP: 3 dev products
    NOTE: Replace ProductId values with real Roblox dev product IDs before publishing
]]

local DevProductConfig = {}

DevProductConfig.Products = {
    {
        Id = "luck_boost",
        Name = "Luck Boost (30 min)",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 49,
        Description = "2x luck on all egg hatches for 30 minutes!",
        Icon = "rbxassetid://0",
        Duration = 1800, -- 30 minutes in seconds
        BoostType = "Luck",
        Multiplier = 2.0,
        Category = "Boost",
    },
    {
        Id = "coin_boost",
        Name = "Coin Boost (30 min)",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 49,
        Description = "2x Coins from all sources for 30 minutes!",
        Icon = "rbxassetid://0",
        Duration = 1800,
        BoostType = "Coins",
        Multiplier = 2.0,
        Category = "Boost",
    },
    {
        Id = "starter_pack",
        Name = "Starter Pack",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 99,
        Description = "5,000 Coins + 50 Gems + 1 Exclusive Pet! (One-time bonus for first purchase)",
        Icon = "rbxassetid://0",
        Rewards = {
            Coins = 5000,
            Gems = 50,
        },
        Category = "Pack",
    },
}

-- Build lookup
DevProductConfig.ProductById = {}
DevProductConfig.ProductByProductId = {}
for _, product in ipairs(DevProductConfig.Products) do
    DevProductConfig.ProductById[product.Id] = product
    if product.ProductId > 0 then
        DevProductConfig.ProductByProductId[product.ProductId] = product
    end
end

function DevProductConfig.GetProduct(productId: string)
    return DevProductConfig.ProductById[productId]
end

return DevProductConfig
