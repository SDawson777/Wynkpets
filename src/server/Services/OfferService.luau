--[[
    OfferService.luau
    Context-aware offer surfacing engine.
    Triggers: FirstHatch, Comeback, Rebirth, InsufficientFunds, StorageFull.
    Server-authoritative — the server decides what offer to show and when.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local MonetizationConfig = require(Shared:WaitForChild("Configs"):WaitForChild("MonetizationConfig"))

local DataService
local CurrencyService
local ShopService
local AnalyticsService

local OfferService = {}

-- Per-player cooldown tracking: [Player] = { [offerId] = lastShownTime }
local offerCooldowns = {}
-- Per-player active offer: [Player] = { offerId, expiresAt }
local activeOffers = {}

-- Check if an offer can be shown to a player right now
local function canShowOffer(player: Player, offer): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    -- One-time check
    if offer.OneTimePer then
        if not data.OffersClaimed then data.OffersClaimed = {} end
        if data.OffersClaimed[offer.Id] then return false end
    end

    -- Cooldown check
    local cooldowns = offerCooldowns[player]
    if cooldowns and cooldowns[offer.Id] then
        local elapsed = os.time() - cooldowns[offer.Id]
        local cooldown = offer.Cooldown or 300
        if elapsed < cooldown then return false end
    end

    -- Don't stack offers — one at a time
    if activeOffers[player] and activeOffers[player].expiresAt > os.time() then
        return false
    end

    return true
end

-- Show an offer to a player
local function showOffer(player: Player, offer)
    if not canShowOffer(player, offer) then return end

    -- Set cooldown
    if not offerCooldowns[player] then offerCooldowns[player] = {} end
    offerCooldowns[player][offer.Id] = os.time()

    -- Set active
    activeOffers[player] = {
        offerId = offer.Id,
        expiresAt = os.time() + (offer.ExpiresAfterSec or 300),
    }

    -- Track
    if AnalyticsService then
        AnalyticsService.TrackOfferShown(player, offer.Id)
    end

    -- Fire to client
    Network.FireClient("OfferShown", player, {
        Id = offer.Id,
        Name = offer.Name,
        Description = offer.Description,
        Robux = offer.Robux,
        BannerText = offer.BannerText,
        BannerColor = offer.BannerColor,
        ExpiresIn = offer.ExpiresAfterSec or 300,
    })
end

-- Find best offer for a trigger type
local function findBestOffer(triggerType: string, extra: any?): any?
    local best = nil
    for _, offer in ipairs(MonetizationConfig.Offers) do
        if offer.TriggerType == triggerType then
            -- Check trigger values if applicable
            if offer.TriggerValues and extra then
                local match = false
                for _, v in ipairs(offer.TriggerValues) do
                    if v == extra then match = true break end
                end
                if not match then continue end
            end
            -- Check trigger currency
            if offer.TriggerCurrency and extra ~= offer.TriggerCurrency then
                continue
            end
            -- Priority-based selection
            if not best or offer.Priority > best.Priority then
                best = offer
            end
        end
    end
    return best
end

-- ═══════════════════════════════
-- PUBLIC TRIGGER METHODS
-- ═══════════════════════════════

function OfferService.OnFirstHatch(player: Player)
    local offer = findBestOffer("FirstHatch")
    if offer then showOffer(player, offer) end
end

function OfferService.OnComeback(player: Player)
    local offer = findBestOffer("Comeback")
    if offer then showOffer(player, offer) end
end

function OfferService.OnRebirth(player: Player, rebirthCount: number)
    local offer = findBestOffer("Rebirth", rebirthCount)
    if offer then showOffer(player, offer) end
end

function OfferService.OnInsufficientFunds(player: Player, currency: string)
    local offer = findBestOffer("InsufficientFunds", currency)
    if offer then showOffer(player, offer) end
end

function OfferService.OnStorageFull(player: Player)
    local offer = findBestOffer("StorageFull")
    if offer then showOffer(player, offer) end
end

-- Check comeback on login
function OfferService.CheckComeback(player: Player)
    local data = DataService.GetData(player)
    if not data then return end

    local lastLogin = data.LastLogin or 0
    if lastLogin > 0 then
        local daysSince = math.floor((os.time() - lastLogin) / 86400)
        if daysSince >= MonetizationConfig.ComebackDaysThreshold then
            -- Delay so client is ready
            task.delay(5, function()
                if player.Parent then
                    OfferService.OnComeback(player)
                end
            end)
        end
    end
end

-- Handle offer acceptance from client
local function handleAcceptOffer(player: Player, offerId: string)
    if type(offerId) ~= "string" then return end

    local offer = MonetizationConfig.OfferById[offerId]
    if not offer then return end

    -- Verify this is the active offer
    local active = activeOffers[player]
    if not active or active.offerId ~= offerId then return end
    if active.expiresAt < os.time() then
        Network.FireClient("ShowNotification", player, "Offer expired!", "Warning")
        return
    end

    -- Track
    if AnalyticsService then
        AnalyticsService.TrackOfferAccepted(player, offerId)
    end

    -- Prompt Robux purchase via the linked dev product
    if offer.ProductId then
        local DevProductConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DevProductConfig"))
        local product = DevProductConfig.GetProduct(offer.ProductId)
        if product and product.ProductId > 0 then
            local MarketplaceService = game:GetService("MarketplaceService")
            MarketplaceService:PromptProductPurchase(player, product.ProductId)
        end
    end

    -- Mark one-time
    if offer.OneTimePer then
        local data = DataService.GetData(player)
        if data then
            if not data.OffersClaimed then data.OffersClaimed = {} end
            data.OffersClaimed[offerId] = true
        end
    end

    -- Clear active
    activeOffers[player] = nil
end

function OfferService.PlayerRemoving(player: Player)
    offerCooldowns[player] = nil
    activeOffers[player] = nil
end

function OfferService.Init(dataService, currencyService, shopService, analyticsService)
    DataService = dataService
    CurrencyService = currencyService
    ShopService = shopService
    AnalyticsService = analyticsService

    Network.OnServerEvent("AcceptOffer", function(player: Player, offerId: string)
        handleAcceptOffer(player, offerId)
    end)

    Network.OnServerEvent("DismissOffer", function(player: Player, offerId: string)
        if type(offerId) ~= "string" then return end
        activeOffers[player] = nil
        if AnalyticsService then
            AnalyticsService.TrackOfferDismissed(player, offerId)
        end
    end)

    print("[OfferService] Initialized")
end

return OfferService
