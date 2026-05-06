--[[
    ExpeditionConfig.luau
    Configuration for the Pet Expedition system.
    Players send unequipped pets on timed missions to earn
    Coins, Gems, and XP based on pet Power and zone difficulty.
]]

local ExpeditionConfig = {}

-- ── Slot limits ─────────────────────────────────────────────────────────────
ExpeditionConfig.BaseSlots      = 1   -- every player starts with 1 slot
ExpeditionConfig.VIPBonusSlots  = 1   -- SubscriptionTier "basic" or "vip" grants +1
ExpeditionConfig.MaxSlots       = 3   -- hard cap

-- ── Expedition tiers ────────────────────────────────────────────────────────
-- Duration in seconds.  Base reward values are for the lowest zone.
-- Actual rewards = Base × ZoneScaling.RewardScale  (see below).
ExpeditionConfig.Tiers = {
    {
        Id          = "quick",
        Name        = "Quick Scout",
        Description = "A short scouting mission — fast rewards.",
        Duration    = 900,     -- 15 min
        BaseCoins   = 75,
        BaseGems    = 0,
        BaseXP      = 50,
        SkipCost    = 5,       -- gems to instant-complete
        BasePower   = 5,       -- recommended power (× zone PowerScale)
    },
    {
        Id          = "standard",
        Name        = "Patrol",
        Description = "A standard patrol through the zone.",
        Duration    = 3600,    -- 1 hr
        BaseCoins   = 300,
        BaseGems    = 2,
        BaseXP      = 200,
        SkipCost    = 15,
        BasePower   = 12,
    },
    {
        Id          = "long",
        Name        = "Deep Exploration",
        Description = "An extended foray into unknown territory.",
        Duration    = 14400,   -- 4 hr
        BaseCoins   = 1200,
        BaseGems    = 5,
        BaseXP      = 800,
        SkipCost    = 40,
        BasePower   = 25,
    },
    {
        Id          = "epic",
        Name        = "Grand Expedition",
        Description = "A legendary journey that tests your pet's limits.",
        Duration    = 43200,   -- 12 hr
        BaseCoins   = 3500,
        BaseGems    = 12,
        BaseXP      = 2500,
        SkipCost    = 100,
        BasePower   = 50,
    },
}

-- ── Per-zone scaling ────────────────────────────────────────────────────────
-- RewardScale multiplies BaseCoins.  PowerScale multiplies BasePower.
-- GemScale multiplies BaseGems (kept tighter so endgame doesn't flood gems).
ExpeditionConfig.ZoneScaling = {
    starter_meadow   = { RewardScale = 1,    PowerScale = 1,   GemScale = 1   },
    forest_grove     = { RewardScale = 3,    PowerScale = 1.5, GemScale = 1   },
    crystal_caves    = { RewardScale = 10,   PowerScale = 2.5, GemScale = 1.2 },
    volcanic_ridge   = { RewardScale = 25,   PowerScale = 4,   GemScale = 1.5 },
    frozen_tundra    = { RewardScale = 60,   PowerScale = 7,   GemScale = 2   },
    celestial_garden = { RewardScale = 150,  PowerScale = 12,  GemScale = 2.5 },
    shadow_realm     = { RewardScale = 400,  PowerScale = 20,  GemScale = 3   },
    cosmic_void      = { RewardScale = 1000, PowerScale = 35,  GemScale = 4   },
}

-- ── Lookups ─────────────────────────────────────────────────────────────────
ExpeditionConfig.TierById = {}
for _, tier in ipairs(ExpeditionConfig.Tiers) do
    ExpeditionConfig.TierById[tier.Id] = tier
end

--- Get the recommended power for a zone + tier combination.
function ExpeditionConfig.GetRecommendedPower(zoneId: string, tierId: string): number
    local tier = ExpeditionConfig.TierById[tierId]
    local zone = ExpeditionConfig.ZoneScaling[zoneId]
    if not tier or not zone then return 9999 end
    return math.floor(tier.BasePower * zone.PowerScale)
end

--- Calculate reward multiplier based on pet effective power vs recommended.
--- Returns 0.2–1.1 reward fraction.
function ExpeditionConfig.GetPowerRewardMultiplier(petPower: number, recommendedPower: number): number
    if recommendedPower <= 0 then return 1.0 end
    local ratio = petPower / recommendedPower
    if ratio >= 1.0 then
        -- Slight bonus for overpowered pets, capped at 1.1×
        return math.min(1.0 + (ratio - 1.0) * 0.1, 1.1)
    elseif ratio >= 0.5 then
        -- Linear scale 0.4 → 1.0
        return 0.4 + 0.6 * (ratio - 0.5) / 0.5
    else
        -- Weak pet: heavily reduced
        return math.max(ratio * 0.8, 0.2)
    end
end

--- Calculate full rewards for a completed expedition.
--- Returns { Coins, Gems, XP }
function ExpeditionConfig.CalculateRewards(zoneId: string, tierId: string, petPower: number): { Coins: number, Gems: number, XP: number }
    local tier = ExpeditionConfig.TierById[tierId]
    local zone = ExpeditionConfig.ZoneScaling[zoneId]
    if not tier or not zone then
        return { Coins = 0, Gems = 0, XP = 0 }
    end

    local recommended = math.floor(tier.BasePower * zone.PowerScale)
    local powerMult = ExpeditionConfig.GetPowerRewardMultiplier(petPower, recommended)

    local coins = math.floor(tier.BaseCoins * zone.RewardScale * powerMult)
    local gems  = math.floor(tier.BaseGems * zone.GemScale * powerMult)
    local xp    = math.floor(tier.BaseXP * powerMult)

    return { Coins = coins, Gems = gems, XP = xp }
end

return ExpeditionConfig
