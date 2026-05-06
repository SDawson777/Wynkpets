--[[
    StarterPackService.luau
    Full-screen starter pack modal for new/returning players.

    Trigger logic:
      • After a player's first-ever hatch (TotalEggsHatched first reaches hatchCount).
      • At the 5-minute session milestone if never triggered yet this session.
      • On rejoin after a 30-second delay, if the 24-hour cooldown has elapsed.

    Gating:
      • Never shows if the player has already purchased the starter pack.
      • Maximum once per session per player (shownThisSession guard).
      • After dismissal: 24-hour cooldown before re-show (stored in StarterPackShownAt).

    Analytics:
      • starter_offer_shown   — when the modal fires to the client
      • starter_offer_dismissed — when player dismisses without buying
      • starter_offer_purchased — when purchase is confirmed
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local DevProductConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DevProductConfig"))

local DataService
local AnalyticsService

local StarterPackService = {}

local STARTER_PACK_ID   = "starter_pack"
local RESHOW_COOLDOWN   = 86400  -- 24 hours between re-shows after dismiss
local SHOW_DELAY        = 1.5    -- seconds to wait before firing the modal
local REJOIN_DELAY      = 30     -- seconds after join before checking rejoin re-show

-- Per-session tracking (in-memory only, resets each server session)
local shownThisSession  = {}  -- [Player] = true once shown

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function canShow(player: Player): boolean
    if shownThisSession[player] then return false end

    local data = DataService.GetData(player)
    if not data then return false end

    -- Never show if already purchased
    if data.StarterPackPurchased then return false end

    -- Respect 24-hour cooldown since last show
    local lastShown = data.StarterPackShownAt or 0
    if lastShown > 0 and os.time() - lastShown < RESHOW_COOLDOWN then return false end

    return true
end

local function buildOffer()
    local product = DevProductConfig.GetProduct(STARTER_PACK_ID)
    if not product then return nil end

    return {
        Id             = STARTER_PACK_ID,
        Name           = product.Name,
        Price          = product.Price,
        Rewards        = product.Rewards,
        Description    = product.Description,
        OriginalValue  = "Worth 300+ R$ of value",
        ExclusiveLabel = "New Player Exclusive — Limited Offer!",
        PetPreview     = "bunny",
        -- Countdown: 15-minute urgency window from when the offer is first shown.
        -- SecondsRemaining is consumed by StarterPackGui to drive a live countdown.
        SecondsRemaining = 900,
    }
end

local function doShow(player: Player, source: string)
    if not player or not player.Parent then return end
    if not canShow(player) then return end

    local offer = buildOffer()
    if not offer then return end

    -- Mark shown for this session + record timestamp in persistent data
    shownThisSession[player] = true
    local data = DataService.GetData(player)
    if data then
        data.StarterPackShownAt = os.time()
    end

    -- Fire to client with short delay so the UI is ready
    task.delay(SHOW_DELAY, function()
        if not player or not player.Parent then return end
        Network.FireClient("StarterOfferShown", player, offer)

        if AnalyticsService then
            AnalyticsService.LogEvent(player, "starter_offer_shown", { Source = source })
        end
    end)
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Called by EggService after the player's very first hatch
function StarterPackService.OnFirstHatch(player: Player)
    doShow(player, "first_hatch")
end

-- Called by PersonalizedOfferService / AnalyticsService at session milestones
function StarterPackService.OnSessionMilestone(player: Player, minutes: number)
    if minutes <= 5 then
        doShow(player, "session_5min")
    elseif minutes == 10 and not shownThisSession[player] then
        doShow(player, "session_10min")
    end
end

-- Called by ShopService.processReceipt when the starter_pack product is granted
function StarterPackService.OnPurchased(player: Player)
    local data = DataService.GetData(player)
    if data then
        data.StarterPackPurchased = true
    end

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "starter_offer_purchased", {})
    end

    -- Confirm to client (closes modal, shows success animation)
    Network.FireClient("StarterOfferPurchased", player)
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

function StarterPackService.PlayerAdded(player: Player)
    shownThisSession[player] = false

    -- Check if player qualifies for a rejoin re-show after cooldown
    task.delay(REJOIN_DELAY, function()
        if not player or not player.Parent then return end
        doShow(player, "rejoin")
    end)
end

function StarterPackService.PlayerRemoving(player: Player)
    shownThisSession[player] = nil
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function StarterPackService.Init(dataService, analyticsService)
    DataService     = dataService
    AnalyticsService = analyticsService

    -- Client dismissed the modal without purchasing
    Network.OnServerEvent("StarterOfferDismissed", function(player: Player)
        -- StarterPackShownAt was already recorded when we showed it.
        if AnalyticsService then
            AnalyticsService.LogEvent(player, "starter_offer_dismissed", {})
        end
    end)

    print("[StarterPackService] Initialized")
end

return StarterPackService
