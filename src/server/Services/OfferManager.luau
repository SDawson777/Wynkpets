--[[
    OfferManager.luau
    Priority-based, multi-surface offer queue.

    Replaces OfferService's one-at-a-time lock with a per-player priority queue
    that allows up to one offer per surface simultaneously.

    Surfaces:
      "popup"  — bottom-center small nudge / offer card  (existing OfferShown flow)
      "banner" — sticky side banner                       (future client surface)
      "modal"  — full-screen blocking offer               (used by high-priority deals)

    Priority rules:
      • Higher Priority number = shown first / preempts lower-priority queued entries.
      • If the same surface slot is claimed by a lower-priority queued offer when a
        higher-priority one arrives, the lower offer is evicted from the queue.
      • Default per-offer cooldown: 300 s (5 min).  Overridden by offer.Cooldown.
      • One-time offers (offer.OneTimePer) are blocked if data.OffersClaimed[offerId].

    Usage:
      OfferManager.ShowOffer(player, offerId)          -- show a specific offer
      OfferManager.TriggerByType(player, triggerType)  -- show best offer for trigger
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local MonetizationConfig = require(Shared:WaitForChild("Configs"):WaitForChild("MonetizationConfig"))

local DataService
local AnalyticsService

local OfferManager = {}

local DEFAULT_COOLDOWN = 300  -- seconds between repeat shows of the same offer

-- Per-player state tables
local activeOffers   = {}  -- [Player] = { [surface] = { offerId, priority, expiresAt } }
local offerQueue     = {}  -- [Player] = array of { offerId, surface, priority, expiresAt, payload }
local offerCooldowns = {}  -- [Player] = { [offerId] = lastShownTimestamp }

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function getSurface(offer): string
    if offer.IsModal  then return "modal"  end
    if offer.IsBanner then return "banner" end
    return "popup"
end

local function canShow(player: Player, offerId: string, offer): boolean
    if not offerCooldowns[player] then offerCooldowns[player] = {} end

    -- One-time-purchase guard
    if offer.OneTimePer then
        local data = DataService.GetData(player)
        if data and data.OffersClaimed and data.OffersClaimed[offerId] then
            return false
        end
    end

    -- Per-offer cooldown
    local lastShown = offerCooldowns[player][offerId] or 0
    local cooldown  = offer.Cooldown or DEFAULT_COOLDOWN
    if os.time() - lastShown < cooldown then return false end

    return true
end

-- Insert an offer into the player's queue with conflict resolution
local function enqueue(player: Player, offerId: string, offer, payload)
    if not offerQueue[player] then offerQueue[player] = {} end

    local surface  = getSurface(offer)
    local priority = offer.Priority or 5
    local expiresAt = os.time() + (offer.Duration or 300)

    -- Conflict resolution: if same surface has a queued entry, compare priorities
    for i = #offerQueue[player], 1, -1 do
        local queued = offerQueue[player][i]
        if queued.surface == surface then
            if queued.priority >= priority then
                return  -- existing queued offer has equal or higher priority; drop incoming
            else
                table.remove(offerQueue[player], i)  -- evict lower-priority entry
            end
        end
    end

    table.insert(offerQueue[player], {
        offerId   = offerId,
        surface   = surface,
        priority  = priority,
        expiresAt = expiresAt,
        payload   = payload,
    })

    -- Keep queue sorted by priority descending
    table.sort(offerQueue[player], function(a, b) return a.priority > b.priority end)
end

-- Flush the queue: show any offers whose surface slot is currently free
local function flushQueue(player: Player)
    if not offerQueue[player] or #offerQueue[player] == 0 then return end
    if not activeOffers[player] then activeOffers[player] = {} end

    local now      = os.time()
    local toRemove = {}

    for i, entry in ipairs(offerQueue[player]) do
        -- Expire stale queue entries
        if entry.expiresAt < now then
            table.insert(toRemove, i)
            continue
        end

        local current = activeOffers[player][entry.surface]
        if not current or current.expiresAt < now then
            -- Surface slot available → show this offer
            activeOffers[player][entry.surface] = {
                offerId   = entry.offerId,
                priority  = entry.priority,
                expiresAt = entry.expiresAt,
            }
            if not offerCooldowns[player] then offerCooldowns[player] = {} end
            offerCooldowns[player][entry.offerId] = now

            Network.FireClient("OfferShown", player, entry.payload)

            if AnalyticsService then
                AnalyticsService.TrackOfferShown(player, entry.offerId)
            end

            table.insert(toRemove, i)
        end
    end

    -- Remove shown/stale entries (reverse order preserves indices)
    for i = #toRemove, 1, -1 do
        table.remove(offerQueue[player], toRemove[i])
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Show a specific offer by ID, subject to priority + cooldown rules
function OfferManager.ShowOffer(player: Player, offerId: string)
    if not MonetizationConfig.OfferById then return end
    local offer = MonetizationConfig.OfferById[offerId]
    if not offer then return end
    if not canShow(player, offerId, offer) then return end

    local payload = {
        Id        = offerId,
        Title     = offer.Title,
        Body      = offer.Body or offer.Description,
        CTA       = offer.CTA or "Buy Now",
        Tab       = offer.Tab,
        ProductId = offer.ProductId,
        Duration  = offer.Duration,
        Priority  = offer.Priority or 5,
    }

    enqueue(player, offerId, offer, payload)
    flushQueue(player)
end

-- Find and show the best eligible offer for a given trigger type
function OfferManager.TriggerByType(player: Player, triggerType: string)
    if not MonetizationConfig.Offers then return end

    local best         = nil
    local bestPriority = -1

    for _, offer in ipairs(MonetizationConfig.Offers) do
        local matches = (offer.TriggerType == triggerType)
            or (offer.Triggers and table.find(offer.Triggers, triggerType))
        if matches and (offer.Priority or 5) > bestPriority then
            if canShow(player, offer.Id, offer) then
                best         = offer
                bestPriority = offer.Priority or 5
            end
        end
    end

    if best then
        OfferManager.ShowOffer(player, best.Id)
    end
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

function OfferManager.PlayerAdded(player: Player)
    activeOffers[player]   = {}
    offerQueue[player]     = {}
    offerCooldowns[player] = {}
end

function OfferManager.PlayerRemoving(player: Player)
    activeOffers[player]   = nil
    offerQueue[player]     = nil
    offerCooldowns[player] = nil
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function OfferManager.Init(dataService, analyticsService)
    DataService      = dataService
    AnalyticsService = analyticsService

    print("[OfferManager] Initialized")
end

return OfferManager
