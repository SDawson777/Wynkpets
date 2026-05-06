--[[
    SubscriptionService.luau
    Manages VIP / subscription state for players.
    Handles:
      • Gamepass-based permanent VIP (basic tier)
      • Dev Product monthly renewable VIP+ (vip tier)
      • Daily perk grants (gems, bonus spins)
      • Perk multiplier queries for CurrencyService / EggService
      • Net benefit caching per player (cleared on leave)
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local SubscriptionConfig = require(Shared:WaitForChild("Configs"):WaitForChild("SubscriptionConfig"))
local LaunchConfig = require(Shared:WaitForChild("Configs"):WaitForChild("LaunchConfig"))

local DataService
local CurrencyService
local AnalyticsService

local SubscriptionService = {}

-- Cache of active perk tier per player (recomputed on join / purchase)
local activeTier = {} -- [Player] = tier table or nil

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function resolveActiveTier(player: Player): {}?
    local data = DataService.GetData(player)
    if not data then return nil end

    local now = os.time()

    -- VIP+ subscription still valid?
    local vipTier = SubscriptionConfig.Tiers.vip
    if data.SubscriptionTier == "vip" and (data.SubscriptionExpiry or 0) > now then
        return vipTier
    end

    -- VIP (basic) subscription still valid?
    -- Both tiers are now native Roblox Subscriptions (Type = "Subscription").
    -- Expiry is stamped by GrantFromSubscription on each renewal.
    local basicTier = SubscriptionConfig.Tiers.basic
    if data.SubscriptionTier == "basic" and (data.SubscriptionExpiry or 0) > now then
        return basicTier
    end

    return nil
end

local function pushStatus(player: Player)
    local tier = activeTier[player]
    Network.FireClient("SubscriptionStatus", player, {
        Tier        = tier and tier.Id or "none",
        TierName    = tier and tier.Name or "None",
        Expiry      = tier and (tier.Type == "Subscription") and DataService.GetData(player).SubscriptionExpiry or 0,
        Perks       = tier and tier.Perks or {},
    })
end

-- ── Perk Query API ────────────────────────────────────────────────────────────

function SubscriptionService.IsSubscribed(player: Player): boolean
    return activeTier[player] ~= nil
end

function SubscriptionService.GetTier(player: Player): string
    local tier = activeTier[player]
    return tier and tier.Id or "none"
end

-- Get a perk value; returns 0/false if player has no active tier or perk not defined
function SubscriptionService.GetPerk(player: Player, perkKey: string): any
    local tier = activeTier[player]
    if tier and tier.Perks and tier.Perks[perkKey] ~= nil then
        return tier.Perks[perkKey]
    end
    return type((SubscriptionConfig.Tiers.basic.Perks)[perkKey]) == "number" and 0 or false
end

-- ── Lifecycle ─────────────────────────────────────────────────────────────────

function SubscriptionService.PlayerAdded(player: Player)
    -- Resolve outside of the hot path (network call inside)
    task.spawn(function()
        if not player.Parent then return end
        local tier = resolveActiveTier(player)
        activeTier[player] = tier

        -- Persist tier id into data for offline queries
        local data = DataService.GetData(player)
        if data and tier then
            data.SubscriptionTier = tier.Id
        end

        pushStatus(player)

        -- Daily VIP perk: grant gems on first login of the day
        if tier and tier.Perks.DailyGems and tier.Perks.DailyGems > 0 and data then
            local today = math.floor(os.time() / 86400)
            local lastPerkDay = data.LastVIPPerkDay or 0
            if lastPerkDay < today then
                data.LastVIPPerkDay = today
                CurrencyService.Add(player, "Gems", tier.Perks.DailyGems, false)
                Network.FireClient("ShowNotification", player,
                    tier.Name .. " daily bonus: +" .. tier.Perks.DailyGems .. " Gems!", "VIP")
            end
        end
    end)
end

function SubscriptionService.PlayerRemoving(player: Player)
    activeTier[player] = nil
end

-- Grant a subscription from a Gamepass purchase
function SubscriptionService.GrantFromGamepass(player: Player, gamepassId: number)
    local tier = SubscriptionConfig.TierByGamepassId[gamepassId]
    if not tier then return end

    local data = DataService.GetData(player)
    if not data then return end

    data.SubscriptionTier = tier.Id
    activeTier[player] = tier
    pushStatus(player)

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "SubscriptionGranted", {
            Tier = tier.Id,
            Source = "Gamepass",
        })
    end

    Network.FireClient("ShowNotification", player,
        tier.Name .. " activated! Enjoy your perks.", "Success")
end

-- Grant a renewable VIP+ subscription from a native Roblox Subscription purchase
function SubscriptionService.GrantFromSubscription(player: Player, subscriptionId: string)
    local tier = SubscriptionConfig.TierBySubscriptionId[subscriptionId]
    if not tier or tier.Type ~= "Subscription" then return false end

    local data = DataService.GetData(player)
    if not data then return false end

    local now = os.time()
    local currentExpiry = data.SubscriptionExpiry or 0
    local base = math.max(currentExpiry, now)
    data.SubscriptionExpiry = base + (tier.DurationDays or 30) * 86400
    data.SubscriptionTier = tier.Id
    activeTier[player] = tier
    pushStatus(player)

    if AnalyticsService then
        AnalyticsService.LogEvent(player, "SubscriptionRenewed", {
            Tier      = tier.Id,
            NewExpiry = data.SubscriptionExpiry,
        })
    end

    Network.FireClient("ShowNotification", player,
        tier.Name .. " renewed for 30 days! Enjoy.", "Success")
    return true
end

-- Called by subscription webhook / MarketplaceService callback
function SubscriptionService.HandleSubscriptionId(player: Player, subscriptionId: string): boolean
    return SubscriptionService.GrantFromSubscription(player, subscriptionId)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function SubscriptionService.Init(dataService, currencyService, analyticsService)
    DataService = dataService
    CurrencyService = currencyService
    AnalyticsService = analyticsService

    if not LaunchConfig.IsFeatureEnabled("Subscription") then
        print("[LaunchConfig] SubscriptionService disabled — skipping purchase handler")
        -- Still wire PlayerAdded to resolve basic gamepass ownership for perk queries.
        for _, player in ipairs(Players:GetPlayers()) do
            SubscriptionService.PlayerAdded(player)
        end
        return
    end

    -- Client requests to purchase a subscription
    Network.OnServerEvent("PurchaseSubscription", function(player: Player, tierId: string)
        if type(tierId) ~= "string" then return end
        local tier = SubscriptionConfig.TierById[tierId]
        if not tier then return end

        if tier.Type == "Gamepass" and tier.GamepassId and tier.GamepassId > 0 then
            MarketplaceService:PromptGamePassPurchase(player, tier.GamepassId)
        elseif tier.Type == "Subscription" and tier.SubscriptionId and tier.SubscriptionId ~= "" then
            MarketplaceService:PromptSubscriptionPurchase(player, tier.SubscriptionId)
        else
            Network.FireClient("ShowNotification", player,
                "Coming soon — IDs not yet configured!", "Info")
        end
    end)

    -- Wire existing players (hot-reload / Studio)
    for _, player in ipairs(Players:GetPlayers()) do
        SubscriptionService.PlayerAdded(player)
    end
end

return SubscriptionService
