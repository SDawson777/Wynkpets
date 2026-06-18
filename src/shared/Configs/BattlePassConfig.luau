--[[
    BattlePassConfig.luau
    Season 1: Origins — 30-tier battle pass.

    Structure:
        Free track   — available to all players; meaningful but modest rewards.
        Premium track — $300 R$ one-time purchase per season; top-tier rewards,
                        exclusive pets, large gem payouts.

    XP sources (awarded by BattlePassService.AddXP):
        Hatch batch     +100 XP
        Daily quest     +300 XP
        Weekly quest   +1,000 XP
        Rebirth        +2,000 XP
        Login          +50 XP/day (future)

    Total XP to complete all 30 tiers: 30,000 XP
    Estimated completion for active player (1 hr/day): ~15 days out of 35-day season.

    Reward types: Coins | Gems | Pet | EvolutionMaterial | Badge
         Pet rewards use PetId strings that match PetConfig entries.
         EvolutionMaterial uses { MaterialId, Amount } sub-fields.
]]

local BattlePassConfig = {}

-- ── Season metadata ────────────────────────────────────────────────────────────
BattlePassConfig.CurrentSeason   = 1
BattlePassConfig.SeasonName      = "Season 1: Origins"

-- Season end: 2026-05-13 00:00 UTC (35-day season, Week 3 launch → Week 5 end)
BattlePassConfig.SeasonEndTime   = 1747094400

-- XP required per tier (constant)
BattlePassConfig.XPPerTier       = 1000

-- Premium track product (create in Roblox Creator Dashboard → Dev Products)
-- Price: ~300 R$ ($2.99 equivalent)
BattlePassConfig.PremiumProductId = 3572514682  -- "Battle Pass Premium"

-- ── Reward tier definitions ────────────────────────────────────────────────────
-- Each tier has FreeReward and PremiumReward.
-- Reward schema: { Type, Amount?, PetId?, MaterialId? }
-- Types: "Coins" | "Gems" | "Pet" | "EvolutionMaterial" | "Badge"
BattlePassConfig.Tiers = {

    -- Tier 1
    {
        Level         = 1,
        FreeReward    = { Type = "Coins",  Amount = 1000 },
        PremiumReward = { Type = "Gems",   Amount = 25 },
    },
    -- Tier 2
    {
        Level         = 2,
        FreeReward    = { Type = "Gems",   Amount = 10 },
        PremiumReward = { Type = "Coins",  Amount = 5000 },
    },
    -- Tier 3
    {
        Level         = 3,
        FreeReward    = { Type = "Coins",  Amount = 2500 },
        PremiumReward = { Type = "Gems",   Amount = 50 },
    },
    -- Tier 4
    {
        Level         = 4,
        FreeReward    = { Type = "Gems",   Amount = 15 },
        PremiumReward = { Type = "Coins",  Amount = 10000 },
    },
    -- Tier 5
    {
        Level         = 5,
        FreeReward    = { Type = "Coins",  Amount = 5000 },
        PremiumReward = { Type = "Gems",   Amount = 75 },
    },

    -- Tier 6
    {
        Level         = 6,
        FreeReward    = { Type = "Gems",   Amount = 25 },
        PremiumReward = { Type = "Coins",  Amount = 25000 },
    },
    -- Tier 7
    {
        Level         = 7,
        FreeReward    = { Type = "Coins",  Amount = 10000 },
        PremiumReward = { Type = "Gems",   Amount = 100 },
    },
    -- Tier 8
    {
        Level         = 8,
        FreeReward    = { Type = "Gems",   Amount = 35 },
        PremiumReward = { Type = "Coins",  Amount = 50000 },
    },
    -- Tier 9
    {
        Level         = 9,
        FreeReward    = { Type = "Coins",  Amount = 25000 },
        PremiumReward = { Type = "Gems",   Amount = 150 },
    },
    -- Tier 10 ★ MILESTONE ★
    {
        Level         = 10,
        IsMilestone   = true,
        FreeReward    = { Type = "Gems",   Amount = 50 },
        PremiumReward = { Type = "Pet",    PetId = "pixel_pup",
                          Label = "Exclusive: Pixel Pup 🐾" },
    },

    -- Tier 11
    {
        Level         = 11,
        FreeReward    = { Type = "Coins",  Amount = 50000 },
        PremiumReward = { Type = "Gems",   Amount = 200 },
    },
    -- Tier 12
    {
        Level         = 12,
        FreeReward    = { Type = "Gems",   Amount = 75 },
        PremiumReward = { Type = "Coins",  Amount = 100000 },
    },
    -- Tier 13
    {
        Level         = 13,
        FreeReward    = { Type = "Coins",  Amount = 100000 },
        PremiumReward = { Type = "Gems",   Amount = 250 },
    },
    -- Tier 14
    {
        Level         = 14,
        FreeReward    = { Type = "Gems",   Amount = 100 },
        PremiumReward = { Type = "Coins",  Amount = 200000 },
    },
    -- Tier 15 ★ MILESTONE ★
    {
        Level         = 15,
        IsMilestone   = true,
        FreeReward    = { Type = "Coins",  Amount = 250000 },
        PremiumReward = { Type = "Pet",    PetId = "neon_fox",
                          Label = "Exclusive: Neon Fox 🦊" },
    },

    -- Tier 16
    {
        Level         = 16,
        FreeReward    = { Type = "Gems",   Amount = 150 },
        PremiumReward = { Type = "Coins",  Amount = 500000 },
    },
    -- Tier 17
    {
        Level         = 17,
        FreeReward    = { Type = "Coins",  Amount = 500000 },
        PremiumReward = { Type = "Gems",   Amount = 350 },
    },
    -- Tier 18
    {
        Level         = 18,
        FreeReward    = { Type = "Gems",   Amount = 200 },
        PremiumReward = { Type = "Coins",  Amount = 1000000 },
    },
    -- Tier 19
    {
        Level         = 19,
        FreeReward    = { Type = "Coins",  Amount = 1000000 },
        PremiumReward = { Type = "Gems",   Amount = 500 },
    },
    -- Tier 20 ★ MILESTONE ★
    {
        Level         = 20,
        IsMilestone   = true,
        FreeReward    = { Type = "Gems",   Amount = 300 },
        PremiumReward = { Type = "Pet",    PetId = "crystal_wolf",
                          Label = "Exclusive: Crystal Wolf 🐺" },
    },

    -- Tier 21
    {
        Level         = 21,
        FreeReward    = { Type = "Coins",  Amount = 2000000 },
        PremiumReward = { Type = "Gems",   Amount = 750 },
    },
    -- Tier 22
    {
        Level         = 22,
        FreeReward    = { Type = "Gems",   Amount = 500 },
        PremiumReward = { Type = "Coins",  Amount = 5000000 },
    },
    -- Tier 23
    {
        Level         = 23,
        FreeReward    = { Type = "Coins",  Amount = 5000000 },
        PremiumReward = { Type = "Gems",   Amount = 1000 },
    },
    -- Tier 24
    {
        Level         = 24,
        FreeReward    = { Type = "Gems",   Amount = 750 },
        PremiumReward = { Type = "Coins",  Amount = 10000000 },
    },
    -- Tier 25 ★ MILESTONE ★
    {
        Level         = 25,
        IsMilestone   = true,
        FreeReward    = { Type = "Gems",   Amount = 1000 },
        PremiumReward = { Type = "EvolutionMaterial", MaterialId = "WynkShards", Amount = 5,
                          Label = "5× Wynk Shards ✨" },
    },

    -- Tier 26
    {
        Level         = 26,
        FreeReward    = { Type = "Coins",  Amount = 10000000 },
        PremiumReward = { Type = "Gems",   Amount = 1500 },
    },
    -- Tier 27
    {
        Level         = 27,
        FreeReward    = { Type = "Gems",   Amount = 2000 },
        PremiumReward = { Type = "Coins",  Amount = 25000000 },
    },
    -- Tier 28
    {
        Level         = 28,
        FreeReward    = { Type = "Coins",  Amount = 25000000 },
        PremiumReward = { Type = "Badge",  BadgeId = "origins_champion",
                          Label = "Origins Champion Badge 🏆" },
    },
    -- Tier 29
    {
        Level         = 29,
        FreeReward    = { Type = "Gems",   Amount = 5000 },
        PremiumReward = { Type = "Coins",  Amount = 50000000 },
    },
    -- Tier 30 ★ SEASON FINALE ★
    {
        Level         = 30,
        IsMilestone   = true,
        IsFinale      = true,
        FreeReward    = { Type = "Coins",  Amount = 50000000,
                          Label = "50M Coins — Season Veteran!" },
        PremiumReward = { Type = "Pet",    PetId = "wynk_prime",
                          Label = "EXCLUSIVE LEGENDARY: Wynk Prime 👑" },
    },
}

-- ── Lookup by tier level ───────────────────────────────────────────────────────
BattlePassConfig.TierByLevel = {}
for _, tier in ipairs(BattlePassConfig.Tiers) do
    BattlePassConfig.TierByLevel[tier.Level] = tier
end

return BattlePassConfig
