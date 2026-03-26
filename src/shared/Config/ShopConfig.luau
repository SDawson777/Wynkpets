-- ShopConfig.luau
-- In-game shop items (consumable boosts, cosmetics, etc.)

local ShopConfig = {}

-- ─── Coin Shop ────────────────────────────────────────────────────────────────
ShopConfig.CoinItems = {
    {
        id          = "luck_potion_small",
        name        = "Small Luck Potion",
        description = "+50% hatch luck for 15 minutes.",
        coinCost    = 10000,
        duration    = 900,
        effect      = { luckMult = 0.5 },
    },
    {
        id          = "coin_potion_small",
        name        = "Small Coin Potion",
        description = "+50% coins for 15 minutes.",
        coinCost    = 10000,
        duration    = 900,
        effect      = { coinMult = 0.5 },
    },
    {
        id          = "speed_potion_small",
        name        = "Small Speed Potion",
        description = "+25% mining speed for 15 minutes.",
        coinCost    = 8000,
        duration    = 900,
        effect      = { mineSpeedBoost = 0.25 },
    },
}

-- ─── Gem Shop ─────────────────────────────────────────────────────────────────
ShopConfig.GemItems = {
    {
        id          = "luck_potion_large",
        name        = "Large Luck Potion",
        description = "+100% hatch luck for 1 hour.",
        gemCost     = 25,
        duration    = 3600,
        effect      = { luckMult = 1.0 },
    },
    {
        id          = "coin_potion_large",
        name        = "Large Coin Potion",
        description = "+100% coins for 1 hour.",
        gemCost     = 25,
        duration    = 3600,
        effect      = { coinMult = 1.0 },
    },
    {
        id          = "speed_potion_large",
        name        = "Large Speed Potion",
        description = "+50% mining speed for 1 hour.",
        gemCost     = 20,
        duration    = 3600,
        effect      = { mineSpeedBoost = 0.5 },
    },
    {
        id          = "inventory_expansion",
        name        = "Inventory Expansion",
        description = "+25 pet inventory slots (permanent).",
        gemCost     = 100,
        duration    = -1,   -- permanent
        effect      = { inventoryExpansion = 25 },
    },
}

-- ─── Daily Gift ───────────────────────────────────────────────────────────────
-- Rewards indexed by consecutive login day (cycles at MaxStreak)
ShopConfig.DailyRewards = {
    { day = 1,  coins = 500,    gems = 0  },
    { day = 2,  coins = 1000,   gems = 0  },
    { day = 3,  coins = 2500,   gems = 5  },
    { day = 4,  coins = 5000,   gems = 0  },
    { day = 5,  coins = 10000,  gems = 10 },
    { day = 6,  coins = 25000,  gems = 0  },
    { day = 7,  coins = 50000,  gems = 50, bonusPet = "gold_lion" },
}
ShopConfig.DailyRewardMaxStreak = 7  -- cycle length

return ShopConfig
