--[[
    AnalyticsService.luau
    Server-side funnel telemetry and analytics tracking.
    Logs events to player data for dashboarding (MessagingService / external webhook ready).
    Tracks: shop funnel, offer conversions, purchase flow, session metrics.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))

local DataService
local CurrencyService
local PersonalizedOfferService -- set via SetPersonalizedOfferService (late-bind)

local AnalyticsService = {}

-- In-memory event buffer per player (flushed to data on save / leave)
local eventBuffer = {} -- [Player] = { {event, timestamp, data}, ... }

-- Session tracking
local sessionStart = {} -- [Player] = os.time()

-- Log an analytics event
function AnalyticsService.LogEvent(player: Player, eventName: string, eventData: { [string]: any }?)
    if not eventBuffer[player] then
        eventBuffer[player] = {}
    end

    local entry = {
        Event = eventName,
        Time = os.time(),
        Data = eventData or {},
    }

    table.insert(eventBuffer[player], entry)

    -- Keep buffer manageable (last 200 events per session)
    if #eventBuffer[player] > 200 then
        table.remove(eventBuffer[player], 1)
    end
end

-- Track shop funnel specifically
function AnalyticsService.TrackShopOpen(player: Player, tab: string?)
    AnalyticsService.LogEvent(player, "ShopOpened", { Tab = tab })
end

function AnalyticsService.TrackShopTabChange(player: Player, tab: string)
    AnalyticsService.LogEvent(player, "ShopTabChanged", { Tab = tab })
end

function AnalyticsService.TrackOfferShown(player: Player, offerId: string)
    AnalyticsService.LogEvent(player, "OfferShown", { OfferId = offerId })
end

function AnalyticsService.TrackOfferAccepted(player: Player, offerId: string)
    AnalyticsService.LogEvent(player, "OfferAccepted", { OfferId = offerId })
end

function AnalyticsService.TrackOfferDismissed(player: Player, offerId: string)
    AnalyticsService.LogEvent(player, "OfferDismissed", { OfferId = offerId })
end

function AnalyticsService.TrackPurchaseStarted(player: Player, productId: string, robux: number)
    AnalyticsService.LogEvent(player, "PurchaseStarted", { ProductId = productId, Robux = robux })
end

function AnalyticsService.TrackPurchaseCompleted(player: Player, productId: string, robux: number)
    AnalyticsService.LogEvent(player, "PurchaseCompleted", { ProductId = productId, Robux = robux })
end

function AnalyticsService.TrackCurrencySpent(player: Player, currency: string, amount: number, source: string)
    AnalyticsService.LogEvent(player, "CurrencySpent", {
        Currency = currency,
        Amount = amount,
        Source = source,
    })
end

function AnalyticsService.TrackCurrencyEarned(player: Player, currency: string, amount: number, source: string)
    AnalyticsService.LogEvent(player, "CurrencyEarned", {
        Currency = currency,
        Amount = amount,
        Source = source,
    })
end

function AnalyticsService.TrackLimitedPurchase(player: Player, itemId: string, price: number)
    AnalyticsService.LogEvent(player, "LimitedItemPurchased", { ItemId = itemId, Price = price })
end

-- ── Full-funnel event trackers ─────────────────────────────────────────────────

function AnalyticsService.TrackHatch(player: Player, eggId: string, petId: string, rarity: string)
    AnalyticsService.LogEvent(player, "EggHatched", {
        EggId = eggId, PetId = petId, Rarity = rarity
    })
end

function AnalyticsService.TrackFuse(player: Player, inputPetIds: {string}, resultPetId: string)
    AnalyticsService.LogEvent(player, "PetFused", {
        Inputs = inputPetIds, Result = resultPetId
    })
end

function AnalyticsService.TrackZoneUnlock(player: Player, zoneId: string, cost: number)
    AnalyticsService.LogEvent(player, "ZoneUnlocked", { ZoneId = zoneId, Cost = cost })
end

function AnalyticsService.TrackRebirth(player: Player, rebirthNumber: number)
    AnalyticsService.LogEvent(player, "Rebirth", { Count = rebirthNumber })
end

function AnalyticsService.TrackQuestCompleted(player: Player, questId: string, questType: string)
    AnalyticsService.LogEvent(player, "QuestCompleted", { QuestId = questId, Type = questType })
end

function AnalyticsService.TrackQuestReroll(player: Player, oldQuestId: string, newQuestId: string, gemCost: number)
    AnalyticsService.LogEvent(player, "QuestRerolled", {
        OldQuestId = oldQuestId, NewQuestId = newQuestId, GemCost = gemCost
    })
end

function AnalyticsService.TrackLoginStreak(player: Player, day: number)
    AnalyticsService.LogEvent(player, "LoginStreak", { Day = day })
end

function AnalyticsService.TrackBoostActivated(player: Player, boostType: string, duration: number, source: string)
    AnalyticsService.LogEvent(player, "BoostActivated", {
        BoostType = boostType, Duration = duration, Source = source or "purchase"
    })
end

function AnalyticsService.TrackBoostExpired(player: Player, boostType: string)
    AnalyticsService.LogEvent(player, "BoostExpired", { BoostType = boostType })
end

function AnalyticsService.TrackSubscription(player: Player, tier: string, action: string)
    -- action: "granted" | "renewed" | "expired"
    AnalyticsService.LogEvent(player, "Subscription", { Tier = tier, Action = action })
end

function AnalyticsService.TrackEventShopPurchase(player: Player, eventId: string, itemId: string, cost: number)
    AnalyticsService.LogEvent(player, "EventShopPurchase", {
        EventId = eventId, ItemId = itemId, Cost = cost
    })
end

function AnalyticsService.TrackNudgeShown(player: Player, nudgeId: string)
    AnalyticsService.LogEvent(player, "NudgeShown", { NudgeId = nudgeId })
end

function AnalyticsService.TrackNudgeDismissed(player: Player, nudgeId: string)
    AnalyticsService.LogEvent(player, "NudgeDismissed", { NudgeId = nudgeId })
end

function AnalyticsService.TrackTrade(player: Player, action: string, partnerUserId: number?)
    AnalyticsService.LogEvent(player, "Trade", { Action = action, PartnerUserId = partnerUserId })
end

function AnalyticsService.TrackSessionMilestone(player: Player, minutes: number)
    AnalyticsService.LogEvent(player, "SessionMilestone", { Minutes = minutes })
end

function AnalyticsService.TrackSessionLength(player: Player, seconds: number)
    AnalyticsService.LogEvent(player, "SessionLength", { Seconds = seconds })
end

-- Flush session summary to player data on leave
local function flushSession(player: Player)
    local data = DataService and DataService.GetData(player)
    if not data then return end

    local start = sessionStart[player]
    if start then
        local sessionLength = os.time() - start

        -- Initialize analytics summary in data
        if not data.AnalyticsSummary then
            data.AnalyticsSummary = {
                TotalSessions = 0,
                TotalPlayTime = 0,
                TotalPurchases = 0,
                TotalRobuxSpent = 0,
                LastSessionLength = 0,
            }
        end

        data.AnalyticsSummary.TotalSessions = (data.AnalyticsSummary.TotalSessions or 0) + 1
        data.AnalyticsSummary.TotalPlayTime = (data.AnalyticsSummary.TotalPlayTime or 0) + sessionLength
        data.AnalyticsSummary.LastSessionLength = sessionLength

        -- Log session length event for analytics pipeline
        AnalyticsService.TrackSessionLength(player, sessionLength)

        -- Count purchases in this session
        local purchaseCount = 0
        local robuxSpent = 0
        for _, entry in ipairs(eventBuffer[player] or {}) do
            if entry.Event == "PurchaseCompleted" then
                purchaseCount = purchaseCount + 1
                robuxSpent = robuxSpent + (entry.Data.Robux or 0)
            end
        end
        data.AnalyticsSummary.TotalPurchases = (data.AnalyticsSummary.TotalPurchases or 0) + purchaseCount
        data.AnalyticsSummary.TotalRobuxSpent = (data.AnalyticsSummary.TotalRobuxSpent or 0) + robuxSpent
    end
end

function AnalyticsService.PlayerAdded(player: Player)
    sessionStart[player] = os.time()
    eventBuffer[player] = {}
    AnalyticsService.LogEvent(player, "SessionStart", {})

    -- Session milestone ticker: reward players for staying in-game
    task.spawn(function()
        local MILESTONES = { 5, 15, 30, 60 } -- minutes
        for _, minutes in ipairs(MILESTONES) do
            local waitSecs = minutes * 60
            task.wait(waitSecs)
            if not player.Parent then break end
            local data = DataService and DataService.GetData(player)
            if not data then break end

            if not data.SessionMilestonesClaimed then
                data.SessionMilestonesClaimed = {}
            end

            local key = tostring(minutes)
            -- Only grant once per calendar day to prevent AFK farming
            local todayKey = key .. "_" .. tostring(math.floor(os.time() / 86400))
            if not data.SessionMilestonesClaimed[todayKey] then
                data.SessionMilestonesClaimed[todayKey] = true
                local rewardGems = minutes >= 60 and 20 or (minutes >= 30 and 10 or (minutes >= 15 and 5 or 3))
                if CurrencyService then
                    CurrencyService.Add(player, "Gems", rewardGems, false)
                end
                Network.FireClient("SessionMilestone", player, { Minutes = minutes, Gems = rewardGems })
                AnalyticsService.TrackSessionMilestone(player, minutes)

                -- Notify PersonalizedOfferService for timed offer triggers
                if PersonalizedOfferService then
                    PersonalizedOfferService.OnSessionMilestone(player, minutes)
                end
            end
        end
    end)
end

function AnalyticsService.PlayerRemoving(player: Player)
    AnalyticsService.LogEvent(player, "SessionEnd", {})
    flushSession(player)
    sessionStart[player] = nil
    eventBuffer[player] = nil
end

function AnalyticsService.Init(dataService, currencyService)
    DataService = dataService
    CurrencyService = currencyService

    -- Client can report shop tab changes
    Network.OnServerEvent("AnalyticsEvent", function(player: Player, eventName: string, eventData)
        if type(eventName) ~= "string" then return end
        if #eventName > 50 then return end -- sanity limit
        -- Only allow whitelisted client events
        local allowed = {
            ShopOpened       = true,
            ShopTabChanged   = true,
            OfferDismissed   = true,
            NudgeDismissed   = true,
            NudgeShown       = true,
            BoostHUDClicked  = true,
            EventShopOpened  = true,
        }
        if allowed[eventName] then
            AnalyticsService.LogEvent(player, eventName, eventData)
        end
    end)

    print("[AnalyticsService] Initialized")
end

-- Late-bind PersonalizedOfferService (initialized after AnalyticsService)
function AnalyticsService.SetPersonalizedOfferService(pos)
    PersonalizedOfferService = pos
end

return AnalyticsService
