--[[
    DevProductConfig.luau
    Consumable Developer Product definitions (repeatable purchases).
    All ProductId values start at 0 — replace with real Roblox Dev Product IDs
    from Creator Dashboard → Monetization → Developer Products before publishing.

    LAUNCH PRODUCTS (kept):
        Boosts      — individual 30-min boosts + 3-packs + mega bundle
        Packs       — Starter, Mega, Ultra (currency + gem mixed)
        Gem Packs   — pure gem packs at four price points
        Storage     — stackable pet-storage expansions

    POSTPONED (not in this file):
        BoostRefill charges   — needs charge-inventory system to be polished first
        Ultra bundles         — high-ticket items; add post-launch analytics
        VIP+/Subscription     — moved to SubscriptionConfig (native Subscription)
]]

local DevProductConfig = {}

DevProductConfig.Products = {
    -- ═══════════════════════════════
    -- BOOSTS (30 min)
    -- ═══════════════════════════════
    {
        Id          = "luck_boost",
        Name        = "Luck Boost (30 min)",
        ProductId   = 3566963034,
        Price       = 49,
        Description = "2x luck on all egg hatches for 30 minutes!",
        Icon = "rbxassetid://133500357416108",
        Duration    = 1800,
        BoostType   = "Luck",
        Multiplier  = 2.0,
        Category    = "Boost",
    },
    {
        Id          = "coin_boost",
        Name        = "Coin Boost (30 min)",
        ProductId   = 3566963842,
        Price       = 49,
        Description = "2x Coins from all sources for 30 minutes!",
        Icon = "rbxassetid://103237235431605",
        Duration    = 1800,
        BoostType   = "Coins",
        Multiplier  = 2.0,
        Category    = "Boost",
    },
    {
        Id          = "xp_boost",
        Name        = "XP Boost (30 min)",
        ProductId   = 3566964483,
        Price       = 49,
        Description = "2x XP for all equipped pets for 30 minutes!",
        Icon = "rbxassetid://90410772369304",
        Duration    = 1800,
        BoostType   = "XP",
        Multiplier  = 2.0,
        Category    = "Boost",
    },
    {
        Id          = "hatch_speed_boost",
        Name        = "Hatch Speed (30 min)",
        ProductId   = 3566965083,
        Price       = 49,
        Description = "2x hatch speed for 30 minutes!",
        Icon = "rbxassetid://91334727011697",
        Duration    = 1800,
        BoostType   = "HatchSpeed",
        Multiplier  = 2.0,
        Category    = "Boost",
    },
    -- Boost bundles (better value)
    {
        Id          = "coin_boost_3x",
        Name        = "Coin Boost 3-Pack",
        ProductId   = 3566965557,
        Price       = 119,
        Description = "Three 30-min Coin Boosts! Save 19 R$!",
        Icon = "rbxassetid://137915809387106",
        Duration    = 1800,
        BoostType   = "Coins",
        Multiplier  = 2.0,
        BoostCount  = 3,
        Category    = "Boost",
    },
    {
        Id          = "luck_boost_3x",
        Name        = "Luck Boost 3-Pack",
        ProductId   = 3566966192,
        Price       = 119,
        Description = "Three 30-min Luck Boosts! Save 19 R$!",
        Icon = "rbxassetid://132504663967009",
        Duration    = 1800,
        BoostType   = "Luck",
        Multiplier  = 2.0,
        BoostCount  = 3,
        Category    = "Boost",
    },
    {
        Id         = "mega_boost_bundle",
        Name       = "Mega Boost Bundle",
        ProductId  = 3566966675,
        Price      = 299,
        Description = "All 4 boost types for 30 min each! Best value!",
        Icon = "rbxassetid://74651892029264",
        Duration   = 1800,
        AllBoosts  = true,
        Multiplier = 2.0,
        Category   = "Boost",
    },

    -- ═══════════════════════════════
    -- CURRENCY PACKS (Robux → mixed)
    -- ═══════════════════════════════
    {
        Id          = "starter_pack",
        Name        = "Starter Pack",
        ProductId   = 3566968233,
        Price       = 99,
        Description = "10,000 Coins + 100 Gems — great value!",
        Icon = "rbxassetid://137279051454420",
        Rewards     = { Coins = 10000, Gems = 100 },
        Category    = "Pack",
    },
    {
        Id          = "mega_pack",
        Name        = "Mega Pack",
        ProductId   = 3566968828,
        Price       = 399,
        Description = "100,000 Coins + 500 Gems + 30-min Coin Boost!",
        Icon = "rbxassetid://91551982483025",
        Rewards     = { Coins = 100000, Gems = 500 },
        BonusBoost  = { BoostType = "Coins", Duration = 1800 },
        Category    = "Pack",
    },
    {
        Id          = "ultra_pack",
        Name        = "Ultra Pack",
        ProductId   = 3566972177,
        Price       = 999,
        Description = "1,000,000 Coins + 2,000 Gems + All Boosts!",
        Icon = "rbxassetid://122170094904983",
        Rewards     = { Coins = 1000000, Gems = 2000 },
        BonusBoost  = { BoostType = "AllBoosts", Duration = 1800 },
        Category    = "Pack",
    },

    -- ═══════════════════════════════
    -- GEM PACKS (pure Gems, scaling bonus)
    -- ═══════════════════════════════
    {
        Id          = "gems_small",
        Name        = "50 Gems",
        ProductId   = 3566972698,
        Price       = 49,
        Description = "50 Gems",
        Icon = "rbxassetid://133090017846961",
        Rewards     = { Gems = 50 },
        Category    = "Currency",
    },
    {
        Id          = "gems_medium",
        Name        = "175 Gems",
        ProductId   = 3566976794,
        Price       = 99,
        Description = "150 Gems + 25 BONUS!",
        Icon = "rbxassetid://104118877403019",
        Rewards     = { Gems = 175 },
        BonusLabel  = "+25 BONUS",
        Category    = "Currency",
    },
    {
        Id          = "gems_large",
        Name        = "600 Gems",
        ProductId   = 3566987884,
        Price       = 249,
        Description = "500 Gems + 100 BONUS!",
        Icon = "rbxassetid://115631881972184",
        Rewards     = { Gems = 600 },
        BonusLabel  = "+100 BONUS",
        Category    = "Currency",
    },
    {
        Id          = "gems_mega",
        Name        = "2,000 Gems",
        ProductId   = 3566988854,
        Price       = 599,
        Description = "1,500 Gems + 500 BONUS! Best value!",
        Icon = "rbxassetid://96948247671201",
        Rewards     = { Gems = 2000 },
        BonusLabel  = "+500 BONUS",
        Category    = "Currency",
    },

    -- ═══════════════════════════════
    -- LUCKY WHEEL
    -- ═══════════════════════════════
    -- STORAGE (stackable)
    -- ═══════════════════════════════
    {
        Id              = "pet_storage_50",
        Name            = "+50 Pet Storage",
        ProductId       = 3566989386,
        Price           = 149,
        Description     = "Expand pet storage by 50 slots! (stackable)",
        Icon = "rbxassetid://120131420266394",
        StorageIncrease = 50,
        Category        = "Upgrade",
    },
    {
        Id              = "pet_storage_200",
        Name            = "+200 Pet Storage",
        ProductId       = 3566989913,
        Price           = 449,
        Description     = "Expand pet storage by 200 slots! Save 40%!",
        Icon = "rbxassetid://72202444564382",
        StorageIncrease = 200,
        Category        = "Upgrade",
    },
}

-- ── Lookup tables ─────────────────────────────────────────────────────────────

-- By string Id  (e.g. "luck_boost")
DevProductConfig.ProductById = {}
-- By numeric Roblox ProductId
DevProductConfig.ProductByProductId = {}

for _, product in ipairs(DevProductConfig.Products) do
    DevProductConfig.ProductById[product.Id] = product
    if product.ProductId and product.ProductId > 0 then
        DevProductConfig.ProductByProductId[product.ProductId] = product
    end
end

--- Fetch a product definition by its internal string Id.
function DevProductConfig.GetProduct(id: string)
    return DevProductConfig.ProductById[id]
end

--- Returns all products in the given category.
function DevProductConfig.GetByCategory(category: string)
    local result = {}
    for _, product in ipairs(DevProductConfig.Products) do
        if product.Category == category then
            table.insert(result, product)
        end
    end
    return result
end

return DevProductConfig
