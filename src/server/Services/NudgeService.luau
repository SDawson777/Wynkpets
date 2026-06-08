--[[
    NudgeService.luau
    Context-aware upsell nudge system.
    Fires NudgeShown to the client with a structured nudge payload.
    Rules:
      • One nudge per trigger per session (tracked in nudgesShown).
      • Minimum delay between any nudge: NUDGE_COOLDOWN seconds.
      • Priority queue — higher priority nudges preempt lower ones.
    
    Nudge triggers (called by other services):
      NudgeService.Trigger(player, triggerKey)
    
    Available triggers:
      "no_coins"         – player tried to hatch but was broke
      "no_gems"          – player tried to spend gems but was broke
      "boost_expired"    – a boost just expired mid-session
      "near_zone_unlock" – player is within 20% of unlocking next zone
      "first_hatch"      – player just hatched their first pet
      "many_eggs_hatched"– milestone hatch count (50, 100, 250…)
      "comeback"         – player returned after >3 days
      "login_streak"     – player hit day 3/7 streak
      "rare_hatch"       – player hatched a Legendary+ pet
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService

local NudgeService = {}

-- Minimum seconds between any two nudges to the same player
local NUDGE_COOLDOWN = 120

-- Per-player tracking
local nudgesShown   = {} -- [Player] = { [triggerKey] = true }
local lastNudgeTime = {} -- [Player] = os.time()

-- ── Nudge Definitions ─────────────────────────────────────────────────────────
-- Each entry maps a triggerKey to the nudge payload fired to the client.
-- ProductId = 0 means not yet provisioned; client shows "Coming Soon" CTA.
local NUDGES = {
    no_coins = {
        Priority    = 10,
        Id          = "no_coins",
        Title       = "💰 Need More Coins?",
        Body        = "Grab a Coin Pack and keep hatching!",
        CTA         = "Shop › Currency",
        Tab         = "Currency",
        ProductId   = 3566968233,   -- starter_pack (10,000 coins + 100 gems)
        OncePerSession = true,
    },
    no_gems = {
        Priority    = 10,
        Id          = "no_gems",
        Title       = "💎 Running Low on Gems?",
        Body        = "Gems unlock boosts, rare pets, and more!",
        CTA         = "Shop › Currency",
        Tab         = "Currency",
        ProductId   = 3566972698,   -- gems_small
        OncePerSession = true,
    },
    boost_expired = {
        Priority    = 8,
        Id          = "boost_expired",
        Title       = "⚡ Your Boost Expired!",
        Body        = "Reactivate or grab a refill pack to keep earning.",
        CTA         = "Shop › Boosts",
        Tab         = "Boosts",
        ProductId   = 3566963842,   -- coin_boost (30 min)
        OncePerSession = false, -- re-show each time a boost expires
    },
    near_zone_unlock = {
        Priority    = 7,
        Id          = "near_zone_unlock",
        Title       = "🗺️ Almost There!",
        Body        = "You're close to unlocking a new zone. Boost your coins!",
        CTA         = "Shop › Currency",
        Tab         = "Currency",
        ProductId   = 3566963842,   -- coin_boost (30 min)
        OncePerSession = true,
    },
    first_hatch = {
        Priority    = 6,
        Id          = "first_hatch",
        Title       = "🥚 First Pet Hatched!",
        Body        = "Want more? Grab the Starter Pack — coins, gems & a boost!",
        CTA         = "Shop › Featured",
        Tab         = "Featured",
        ProductId   = 3566968233,   -- starter_pack
        OncePerSession = true,
    },
    many_eggs_hatched = {
        Priority    = 6,
        Id          = "many_eggs_hatched",
        Title       = "🔥 On a Hatching Spree!",
        Body        = "Keep the momentum with a Mega Boost Bundle!",
        CTA         = "Shop › Boosts",
        Tab         = "Boosts",
        ProductId   = 3566966675,   -- mega_boost_bundle
        OncePerSession = true,
    },
    comeback = {
        Priority    = 9,
        Id          = "comeback",
        Title       = "👋 Welcome Back!",
        Body        = "We saved a special comeback offer just for you.",
        CTA         = "View Offer",
        Tab         = "Featured",
        ProductId   = 3566968233,   -- starter_pack
        OncePerSession = true,
    },
    login_streak = {
        Priority    = 7,
        Id          = "login_streak",
        Title       = "🔥 Login Streak Bonus!",
        Body        = "You're on a streak — celebrate with a VIP pass upgrade!",
        CTA         = "Shop › VIP",
        Tab         = "VIP",
        ProductId   = 0,   -- subscription (VIP), no dev product
        OncePerSession = true,
    },
    rare_hatch = {
        Priority    = 8,
        Id          = "rare_hatch",
        Title       = "✨ Legendary Pet!",
        Body        = "Boost your luck and hatch even more legendaries!",
        CTA         = "Shop › Boosts",
        Tab         = "Boosts",
        ProductId   = 3566963034,   -- luck_boost (30 min)
        OncePerSession = false,
    },
    near_rare = {
        Priority    = 9,
        Id          = "near_rare",
        Title       = "✨ So Close to a Rare!",
        Body        = "You almost hatched a Legendary! A Luck Boost would have done it!",
        CTA         = "Shop › Boosts",
        Tab         = "Boosts",
        ProductId   = 3566963034,   -- luck_boost (30 min)
        OncePerSession = false, -- re-triggers after NUDGE_COOLDOWN (120s)
    },
    near_cost = {
        Priority    = 8,
        Id          = "near_cost",
        Title       = "💰 Almost Enough Coins!",
        Body        = "You're so close to the next hatch — grab a quick Coin Pack!",
        CTA         = "Shop › Currency",
        Tab         = "Currency",
        ProductId   = 3566963842,   -- coin_boost (30 min)
        OncePerSession = false,
    },
    vip_upsell = {
        Priority    = 5,
        Id          = "vip_upsell",
        Title       = "⭐ Upgrade to VIP",
        Body        = "Daily gems, bonus luck, and exclusive perks — every day!",
        CTA         = "Shop › VIP",
        Tab         = "VIP",
        ProductId   = 0,   -- subscription prompt, handled by PurchaseSubscription remote
        OncePerSession = true,
    },
}

-- ── Core ──────────────────────────────────────────────────────────────────────

function NudgeService.Trigger(player: Player, triggerKey: string, extraData: {}?)
    local nudge = NUDGES[triggerKey]
    if not nudge then return end

    if not nudgesShown[player] then nudgesShown[player] = {} end
    if not lastNudgeTime[player] then lastNudgeTime[player] = 0 end

    -- Once-per-session guard
    if nudge.OncePerSession and nudgesShown[player][triggerKey] then
        return
    end

    -- Global cooldown guard
    if os.time() - lastNudgeTime[player] < NUDGE_COOLDOWN then
        return
    end

    nudgesShown[player][triggerKey] = true
    lastNudgeTime[player] = os.time()

    local payload = {
        Id        = nudge.Id,
        Title     = nudge.Title,
        Body      = nudge.Body,
        CTA       = nudge.CTA,
        Tab       = nudge.Tab,
        ProductId = nudge.ProductId,
        Extra     = extraData or {},
    }

    Network.FireClient("NudgeShown", player, payload)
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

function NudgeService.PlayerAdded(player: Player)
    nudgesShown[player]   = {}
    lastNudgeTime[player] = 0
end

function NudgeService.PlayerRemoving(player: Player)
    nudgesShown[player]   = nil
    lastNudgeTime[player] = nil
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function NudgeService.Init(dataService)
    DataService = dataService

    -- Dismiss remote: client tells server a nudge was dismissed (no action needed server-side)
    Network.OnServerEvent("DismissNudge", function(player: Player, nudgeId: string)
        -- intentionally no-op; tracking done client side for simplicity
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        NudgeService.PlayerAdded(player)
    end
end

return NudgeService
