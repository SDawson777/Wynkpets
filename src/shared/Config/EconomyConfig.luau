-- EconomyConfig.luau
-- Central economy configuration for Crystal Pets Simulator

local EconomyConfig = {}

-- ─── Currency ────────────────────────────────────────────────────────────────
EconomyConfig.StartingCoins = 0
EconomyConfig.StartingGems  = 0

-- Soft-cap thresholds (used for UI display abbreviation)
EconomyConfig.CurrencyAbbreviations = {
    { threshold = 1e15, suffix = "Qa"  },
    { threshold = 1e12, suffix = "T"   },
    { threshold = 1e9,  suffix = "B"   },
    { threshold = 1e6,  suffix = "M"   },
    { threshold = 1e3,  suffix = "K"   },
}

-- ─── Sell Prices (coins per ore unit) ────────────────────────────────────────
EconomyConfig.OreValues = {
    Coal      = 1,
    Copper    = 3,
    Iron      = 8,
    Silver    = 20,
    Gold      = 55,
    Diamond   = 150,
    Emerald   = 400,
    Ruby      = 1000,
    Sapphire  = 2500,
    Amethyst  = 6000,
    Obsidian  = 15000,
    Crystal   = 40000,
    Starstone = 100000,
}

-- ─── Gem Economy ─────────────────────────────────────────────────────────────
-- Gem store packs (Robux → gems conversions reflect common Roblox pricing)
EconomyConfig.GemPacks = {
    { id = "gems_80",   gems = 80,    robux = 80   },
    { id = "gems_200",  gems = 200,   robux = 180  },
    { id = "gems_440",  gems = 440,   robux = 360  },
    { id = "gems_1000", gems = 1000,  robux = 800  },
    { id = "gems_2200", gems = 2200,  robux = 1600 },
}

-- ─── Rebirth Cost Curve ───────────────────────────────────────────────────────
-- rebirth_cost(n) = BaseRebirthCost * (RebirthCostScale ^ n)
EconomyConfig.BaseRebirthCost  = 1e6   -- 1 million coins for rebirth 1
EconomyConfig.RebirthCostScale = 5     -- each rebirth costs 5× more

-- ─── Multiplier Stacking ──────────────────────────────────────────────────────
-- All multipliers are additive bonuses to a 1× base.
-- Final multiplier = 1 + sum(all additive bonuses)
EconomyConfig.MaxCoinMultiplier  = 1000  -- hard cap to prevent economy breaks
EconomyConfig.MaxMineMultiplier  = 1000

return EconomyConfig
