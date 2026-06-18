--[[
    PersonalizedOfferService.luau
    Behavior-driven offer targeting.

    Tracks per-session player behavior, then fires contextually relevant nudges
    and starter-pack/offer triggers at the right behavioral moment.

    Behavior signals tracked (in-memory per session):
      eggsOpened          — total hatches this session
      failedRareAttempts  — hatches where result rarity order < 4 (no Legendary+)
      purchases           — number of product purchases this session
      nearMissCount       — genuine near-miss events this session

    Trigger rules:
      • After 20 eggs  → if no luck boost active → nudge "many_eggs_hatched"
      • After 50 eggs  → nudge "many_eggs_hatched" + OfferManager "hatch_spree" trigger
      • After 3 failed rare attempts (no Legendary+) → nudge "near_rare" (retry feel)
      • Session 5 min  → if never purchased → StarterPackService
      • Session 10 min → if no boosts active → nudge "boost_expired" (upsell)
      • Session 20 min → if < 1 purchase → OfferManager "mid_session" trigger
      • Session 30 min → if VIP not owned → nudge "vip_upsell"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService
local NudgeService
local StarterPackService
local BoostService
local OfferManager
local AnalyticsService

local PersonalizedOfferService = {}

-- Per-player in-memory behavior counters (reset on each join)
local behavior = {}
-- behavior[player] = {
--   eggsOpened          = number,
--   failedRareAttempts  = number,
--   nearMissCount       = number,
--   purchases           = number,
-- }

local sessionTimersFired = {}  -- [player] = { [minuteKey] = true }

-- ── Behavior helpers ──────────────────────────────────────────────────────────

local function getBehavior(player: Player)
    if not behavior[player] then
        behavior[player] = {
            eggsOpened         = 0,
            failedRareAttempts = 0,
            nearMissCount      = 0,
            purchases          = 0,
        }
    end
    return behavior[player]
end

local function hasAnyBoost(player: Player): boolean
    if not BoostService then return false end
    for _, boostType in ipairs({ "Coins", "Luck", "XP", "HatchSpeed" }) do
        if BoostService.IsActive(player, boostType) then return true end
    end
    return false
end

local function hasVIP(player: Player): boolean
    local data = DataService and DataService.GetData(player)
    if not data then return false end
    return (data.SubscriptionTier or "none") ~= "none"
end

-- ── Trigger evaluation ────────────────────────────────────────────────────────

local function evaluateHatch(player: Player, b)
    -- After 20 eggs with no luck boost: upsell boosts
    if b.eggsOpened == 20 and not hasAnyBoost(player) and NudgeService then
        NudgeService.Trigger(player, "many_eggs_hatched")
    end

    -- After 50 eggs: hatch spree offer
    if b.eggsOpened == 50 then
        if NudgeService then
            NudgeService.Trigger(player, "many_eggs_hatched")
        end
        if OfferManager then
            OfferManager.TriggerByType(player, "HatchSpree")
        end
    end

    -- After 3 failed rare attempts: near_rare nudge to push luck boost
    if b.failedRareAttempts == 3 and NudgeService then
        NudgeService.Trigger(player, "near_rare")
    end

    -- After 7 failed rare attempts: escalate with offer
    if b.failedRareAttempts == 7 and OfferManager then
        OfferManager.TriggerByType(player, "NearMiss")
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Called by EggService after each hatch batch
-- resultsSummary: array of { RarityOrder: number }
function PersonalizedOfferService.OnHatch(player: Player, resultsSummary: { { RarityOrder: number } })
    local b = getBehavior(player)
    local batchSize = #resultsSummary

    b.eggsOpened = b.eggsOpened + batchSize

    local hadRare = false
    for _, r in ipairs(resultsSummary) do
        if r.RarityOrder >= 4 then
            hadRare = true
        end
    end
    if not hadRare then
        b.failedRareAttempts = b.failedRareAttempts + 1
    else
        b.failedRareAttempts = 0  -- reset on success
    end

    evaluateHatch(player, b)
end

-- Called when a near-miss was detected by EggService
function PersonalizedOfferService.OnNearMiss(player: Player)
    local b = getBehavior(player)
    b.nearMissCount = b.nearMissCount + 1
end

-- Called by ShopService.processReceipt after any purchase
function PersonalizedOfferService.OnPurchase(player: Player)
    local b = getBehavior(player)
    b.purchases = b.purchases + 1
end

-- Called by AnalyticsService session milestone ticker (minutes = 5, 15, 30, 60)
function PersonalizedOfferService.OnSessionMilestone(player: Player, minutes: number)
    if not sessionTimersFired[player] then sessionTimersFired[player] = {} end
    if sessionTimersFired[player][minutes] then return end
    sessionTimersFired[player][minutes] = true

    local b = getBehavior(player)

    if minutes == 5 then
        -- 5 min: show starter pack if never purchased
        if StarterPackService then
            StarterPackService.OnSessionMilestone(player, 5)
        end

    elseif minutes == 10 then
        -- 10 min: if no active boosts, push boost nudge
        if not hasAnyBoost(player) and NudgeService then
            NudgeService.Trigger(player, "boost_expired")
        end
        -- 10 min: starter pack fallback if not shown yet
        if StarterPackService then
            StarterPackService.OnSessionMilestone(player, 10)
        end

    elseif minutes == 20 then
        -- 20 min: no purchases yet → bundle offer
        if b.purchases < 1 and OfferManager then
            OfferManager.TriggerByType(player, "MidSession")
        end

    elseif minutes == 30 then
        -- 30 min: VIP upsell for non-subscribers
        if not hasVIP(player) and NudgeService then
            NudgeService.Trigger(player, "vip_upsell")
        end
        -- 30 min: also try a come-back bundle if no purchases
        if b.purchases == 0 and OfferManager then
            OfferManager.TriggerByType(player, "LongSession")
        end

    elseif minutes == 60 then
        -- 60 min whale: escalate to ultra shop offer
        if OfferManager then
            OfferManager.TriggerByType(player, "SessionVeteran")
        end
    end
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

function PersonalizedOfferService.PlayerAdded(player: Player)
    behavior[player]            = nil  -- lazy-init on first use
    sessionTimersFired[player]  = {}
end

function PersonalizedOfferService.PlayerRemoving(player: Player)
    behavior[player]           = nil
    sessionTimersFired[player] = nil
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function PersonalizedOfferService.Init(
    dataService,
    nudgeService,
    starterPackService,
    boostService,
    offerManager,
    analyticsService
)
    DataService         = dataService
    NudgeService        = nudgeService
    StarterPackService  = starterPackService
    BoostService        = boostService
    OfferManager        = offerManager
    AnalyticsService    = analyticsService

    print("[PersonalizedOfferService] Initialized")
end

return PersonalizedOfferService
