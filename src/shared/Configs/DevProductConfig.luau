--[[
    DevProductConfig.luau
    Developer product definitions for consumable purchases
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
        Id = "xp_boost",
        Name = "XP Boost (30 min)",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 49,
        Description = "2x XP for all equipped pets for 30 minutes!",
        Icon = "rbxassetid://0",
        Duration = 1800,
        BoostType = "XP",
        Multiplier = 2.0,
        Category = "Boost",
    },
    {
        Id = "hatch_speed_boost",
        Name = "Hatch Speed (30 min)",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 49,
        Description = "2x hatch speed for 30 minutes!",
        Icon = "rbxassetid://0",
        Duration = 1800,
        BoostType = "HatchSpeed",
        Multiplier = 2.0,
        Category = "Boost",
    },
    {
        Id = "starter_pack",
        Name = "Starter Pack",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 99,
        Description = "5,000 Coins + 50 Gems!",
        Icon = "rbxassetid://0",
        Rewards = {
            Coins = 5000,
            Gems = 50,
        },
        Category = "Pack",
    },
    {
        Id = "mega_pack",
        Name = "Mega Pack",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 399,
        Description = "100,000 Coins + 500 Gems!",
        Icon = "rbxassetid://0",
        Rewards = {
            Coins = 100000,
            Gems = 500,
        },
        Category = "Pack",
    },
    {
        Id = "ultra_pack",
        Name = "Ultra Pack",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 999,
        Description = "1,000,000 Coins + 2,000 Gems!",
        Icon = "rbxassetid://0",
        Rewards = {
            Coins = 1000000,
            Gems = 2000,
        },
        Category = "Pack",
    },
    {
        Id = "pet_storage_50",
        Name = "+50 Pet Storage",
        ProductId = 0, -- REPLACE with real dev product ID
        Price = 149,
        Description = "Expand pet storage by 50 slots! (stackable)",
        Icon = "rbxassetid://0",
        StorageIncrease = 50,
        Category = "Upgrade",
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
