--[[
    MonetizationConfig.luau
    Central config for the monetization layer:
      - Context-aware offers (starter, comeback, milestone, low-currency)
      - Limited shop rotation (daily / weekend)
      - VIP benefit definitions
      - Boost bundle tiers
      - Event shop skeleton
]]

local MonetizationConfig = {}

-- ═══════════════════════════════════════
-- CONTEXT-AWARE OFFERS  (surfaced by OfferService)
-- ═══════════════════════════════════════

MonetizationConfig.Offers = {
    -- Starter offer — shown once after first egg hatch (high conversion window)
    {
        Id           = "starter_offer",
        Name         = "Starter Bundle",
        Description  = "10,000 Coins + 100 Gems + 30-min Coin Boost",
        TriggerType  = "FirstHatch",  -- fires after first egg hatch
        ProductId    = "starter_pack", -- maps to DevProductConfig
        Robux        = 99,
        OneTimePer   = true,
        Priority     = 100,
        ExpiresAfterSec = 600,  -- 10-minute popup window
        Rewards      = { Coins = 10000, Gems = 100 },
        BoostReward  = { BoostType = "Coins", Duration = 1800 },
        BannerColor  = Color3.fromRGB(50, 200, 80),
        BannerText   = "BEST VALUE",
    },
    -- Comeback offer — shown when player returns after 3+ day absence
    {
        Id           = "comeback_offer",
        Name         = "Welcome Back Pack",
        Description  = "50,000 Coins + 200 Gems + 30-min Luck Boost",
        TriggerType  = "Comeback",  -- absent >= 3 days
        ProductId    = "mega_pack",
        Robux        = 199,
        OneTimePer   = true,
        Priority     = 90,
        ExpiresAfterSec = 900,
        Rewards      = { Coins = 50000, Gems = 200 },
        BoostReward  = { BoostType = "Luck", Duration = 1800 },
        BannerColor  = Color3.fromRGB(100, 150, 255),
        BannerText   = "WELCOME BACK!",
    },
    -- Milestone offer — shown at rebirth 1, 5, 10
    {
        Id           = "rebirth_boost_offer",
        Name         = "Rebirth Power Pack",
        Description  = "100,000 Coins + 500 Gems + 30-min All Boosts",
        TriggerType  = "Rebirth",
        TriggerValues = { 1, 5, 10 },
        ProductId    = "mega_pack",
        Robux        = 399,
        OneTimePer   = false, -- can trigger at each milestone
        Priority     = 80,
        ExpiresAfterSec = 300,
        Rewards      = { Coins = 100000, Gems = 500 },
        BoostReward  = { BoostType = "AllBoosts", Duration = 1800 },
        BannerColor  = Color3.fromRGB(255, 180, 30),
        BannerText   = "REBIRTH DEAL",
    },
    -- Low currency nudge — shown when player fails to hatch due to insufficient coins
    {
        Id           = "low_coins_nudge",
        Name         = "Starter Bundle",
        Description  = "10,000 Coins + 100 Gems — get back to hatching!",
        TriggerType  = "InsufficientFunds",
        TriggerCurrency = "Coins",
        ProductId    = "starter_pack",
        Robux        = 99,   -- matches DevProductConfig.starter_pack actual price
        OneTimePer   = false,
        Priority     = 60,
        ExpiresAfterSec = 120,
        Rewards      = { Coins = 10000, Gems = 100 },  -- matches actual product rewards
        Cooldown     = 300, -- don't show again for 5 min
        BannerColor  = Color3.fromRGB(255, 100, 50),
        BannerText   = "TOP UP",
    },
    -- Inventory full nudge
    {
        Id           = "storage_full_nudge",
        Name         = "+50 Pet Storage",
        Description  = "Make room for more pets!",
        TriggerType  = "StorageFull",
        ProductId    = "pet_storage_50",
        Robux        = 149,
        OneTimePer   = false,
        Priority     = 70,
        ExpiresAfterSec = 120,
        Cooldown     = 600,
        BannerColor  = Color3.fromRGB(200, 100, 255),
        BannerText   = "EXPAND",
    },
}

-- Build lookup
MonetizationConfig.OfferById = {}
for _, offer in ipairs(MonetizationConfig.Offers) do
    MonetizationConfig.OfferById[offer.Id] = offer
end

-- ═══════════════════════════════════════
-- LIMITED SHOP  (daily rotating items, server-validated stock)
-- ═══════════════════════════════════════

MonetizationConfig.LimitedShop = {
    -- Pool of limited items; 3 are chosen daily via deterministic seed
    DailySlotCount = 3,
    WeekendSlotCount = 4, -- bonus slot on Sat/Sun

    Items = {
        {
            Id = "lucky_egg_ticket",
            Name = "Lucky Egg Ticket",
            Description = "One free hatch with 3x luck applied.",
            Currency = "Gems",
            Price = 50,
            Stock = 5, -- per player per day
            Category = "Consumable",
        },
        {
            Id = "golden_potion",
            Name = "Golden Potion",
            Description = "Next hatch is guaranteed Golden!",
            Currency = "Gems",
            Price = 100,
            Stock = 1,
            Category = "Consumable",
        },
        {
            Id = "rainbow_shard",
            Name = "Rainbow Shard",
            Description = "Collect 5 to guarantee a Rainbow pet.",
            Currency = "Gems",
            Price = 150,
            Stock = 1,
            Category = "Material",
        },
        {
            Id = "boost_bundle_coins",
            Name = "Coin Boost Bundle (3x)",
            Description = "Three 30-min Coin Boosts.",
            Currency = "Gems",
            Price = 80,
            Stock = 2,
            Category = "Boost",
        },
        {
            Id = "boost_bundle_luck",
            Name = "Luck Boost Bundle (3x)",
            Description = "Three 30-min Luck Boosts.",
            Currency = "Gems",
            Price = 80,
            Stock = 2,
            Category = "Boost",
        },
        {
            Id = "xp_mega_potion",
            Name = "XP Mega Potion",
            Description = "Instantly grants 5 levels to one pet.",
            Currency = "Gems",
            Price = 200,
            Stock = 1,
            Category = "Consumable",
        },
        {
            Id = "mystery_egg_token",
            Name = "Mystery Egg Token",
            Description = "Hatch from any egg in the game — free!",
            Currency = "Gems",
            Price = 300,
            Stock = 1,
            Category = "Consumable",
        },
        {
            Id = "auto_collect_30m",
            Name = "Auto-Collect (30 min)",
            Description = "Coins auto-collected in your current zone.",
            Currency = "Gems",
            Price = 60,
            Stock = 3,
            Category = "Consumable",
        },
    },
}

-- Build lookup
MonetizationConfig.LimitedItemById = {}
for _, item in ipairs(MonetizationConfig.LimitedShop.Items) do
    MonetizationConfig.LimitedItemById[item.Id] = item
end

-- ═══════════════════════════════════════
-- VIP BENEFITS  (referenced by ShopGui VIP tab)
-- ═══════════════════════════════════════

MonetizationConfig.VIPBenefits = {
    "+50% All Currency Earnings",
    "+3 Extra Equip Slots",
    "Exclusive VIP Chat Tag",
    "VIP-Only Daily Bonus (25 Gems)",
    "Priority Queue on Full Servers",
    "Exclusive VIP Egg (coming soon)",
}

MonetizationConfig.VIPDailyGems = 25

-- ═══════════════════════════════════════
-- BOOST TIERS  (Robux-purchased boost multiples)
-- ═══════════════════════════════════════

MonetizationConfig.BoostBundles = {
    { Id = "boost_1x",  Label = "1x",  Count = 1,  PriceRobux = 49,  Discount = 0 },
    { Id = "boost_3x",  Label = "3x",  Count = 3,  PriceRobux = 119, Discount = 19 }, -- ~R$40 each
    { Id = "boost_10x", Label = "10x", Count = 10, PriceRobux = 349, Discount = 141 }, -- ~R$35 each
}

-- ═══════════════════════════════════════
-- CURRENCY PACKS  (Robux → Gems, with bonus scaling)
-- ═══════════════════════════════════════

MonetizationConfig.GemPacks = {
    { Id = "gems_small",  Gems = 50,   BonusGems = 0,   PriceRobux = 49,  Label = "50 Gems" },
    { Id = "gems_medium", Gems = 150,  BonusGems = 25,  PriceRobux = 99,  Label = "175 Gems" },
    { Id = "gems_large",  Gems = 500,  BonusGems = 100, PriceRobux = 249, Label = "600 Gems" },
    { Id = "gems_mega",   Gems = 1500, BonusGems = 500, PriceRobux = 599, Label = "2,000 Gems" },
}

-- ═══════════════════════════════════════
-- EVENT SHOP  (placeholder — populated per event)
-- ═══════════════════════════════════════

MonetizationConfig.EventShop = {
    Enabled = false,
    EventName = "",
    Currency = "EventTokens",
    Items = {},
}

-- ═══════════════════════════════════════
-- COMEBACK THRESHOLD
-- ═══════════════════════════════════════

MonetizationConfig.ComebackDaysThreshold = 3

-- ═══════════════════════════════════════
-- ANALYTICS EVENT NAMES  (referenced by AnalyticsService)
-- ═══════════════════════════════════════

MonetizationConfig.AnalyticsEvents = {
    "ShopOpened",
    "ShopTabChanged",
    "OfferShown",
    "OfferDismissed",
    "OfferAccepted",
    "PurchaseStarted",
    "PurchaseCompleted",
    "PurchaseFailed",
    "LimitedItemPurchased",
    "BoostActivated",
    "CurrencySpent",
    "CurrencyEarned",
    "SessionStart",
    "SessionEnd",
    "ZoneUnlocked",
    "RebirthCompleted",
    "EggHatched",
}

return MonetizationConfig
