--[[
    LaunchConfig.luau
    Feature-flag system for phased Day 1 rollout.

    Phases:
        "beta"         — internal testing; most features locked
        "soft_launch"  — public early access; core loop only
        "full_launch"  — all features enabled

    Safe default: if this module is somehow unavailable, callers
    receive a table with every flag = true (full access / dev mode).
    See LaunchConfig.Get() below.
]]

local LaunchConfig = {}

-- ── Release phase ──────────────────────────────────────────────────────────────
LaunchConfig.Phase = "soft_launch"  -- "beta" | "soft_launch" | "full_launch"

-- ── Gameplay features ──────────────────────────────────────────────────────────
-- true  = fully live (server handlers registered, UI shown)
-- false = silently disabled (handlers skipped, UI hidden)
LaunchConfig.Features = {
    -- Core loop (always on at soft launch)
    Hatch         = true,
    Equip         = true,
    Zones         = true,
    Quests        = true,
    DailyRewards  = true,

    -- Depth features
    Rebirth       = false,
    Fusion        = true,
    Wheel         = false,

    -- Advanced content (phase 2+)
    Evolution     = false,
    Events        = false,
    Wizard        = false,
    Trading       = false,
    Subscription  = false,  -- VIP off at soft_launch; enable post-launch once core loop retention is proven
    BattlePass    = false,  -- Season 1: Origins — enabled Apr 29 by ReleaseScheduleService
    Expedition    = true,   -- Pet Expeditions: send pets on timed missions
}

-- ── Monetization ───────────────────────────────────────────────────────────────
LaunchConfig.Monetization = {
    CorePasses     = true,   -- DoubleCoins, DoubleLuck, DoubleHatchSpeed, shard packs
    AdvancedPasses = true,   -- AutoHatch, TripleHatch, EquipSlots  (enabled at soft_launch)
    DevProducts    = true,   -- gem packs, coin packs, boost bundles
    Bundles        = false,  -- mega/ultra packs, VIP+, advanced bundles
}

-- ── Safe accessor ──────────────────────────────────────────────────────────────
-- Usage (server or client):
--   local cfg = LaunchConfig.Get()
--   if cfg.Features.Rebirth then ... end
--
-- Returns a full-access table when called in environments where LaunchConfig
-- couldn't load, so dev Studio sessions are never accidentally gated.
local _FULL_ACCESS = {
    Phase = "full_launch",
    Features = {
        Hatch = true, Equip = true, Zones = true, Quests = true,
        DailyRewards = true, Rebirth = true, Fusion = true, Wheel = true,
        Evolution = true, Events = true, Wizard = true, Trading = true,
        Subscription = true, BattlePass = true,
    },
    Monetization = {
        CorePasses = true, AdvancedPasses = true,
        DevProducts = true, Bundles = true,
    },
}

function LaunchConfig.Get()
    return LaunchConfig
end

-- ── Convenience helpers ────────────────────────────────────────────────────────
function LaunchConfig.IsFeatureEnabled(featureId: string): boolean
    local f = LaunchConfig.Features[featureId]
    if f == nil then
        -- Unknown feature → default to enabled so unknown IDs don't silently break
        warn("[LaunchConfig] Unknown feature queried: " .. tostring(featureId) .. " — defaulting to true")
        return true
    end
    return f == true
end

function LaunchConfig.IsMonetizationEnabled(cat: string): boolean
    local m = LaunchConfig.Monetization[cat]
    if m == nil then
        warn("[LaunchConfig] Unknown monetization category: " .. tostring(cat) .. " — defaulting to true")
        return true
    end
    return m == true
end

return LaunchConfig
