--[[
    ShopService.luau
    Handles developer product purchases (consumables / boosts / packs / upgrades / currency).
    Server-authoritative with receipt validation.
    Supports: boost stacking, boost bundles (3-pack, mega), all-boost bundles,
    currency packs with bonus, upgrade grants (pet storage), offer-linked purchases.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local DevProductConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DevProductConfig"))

local DataService
local CurrencyService
local AnalyticsService
local BoostService        -- injected after BoostService init
local SubscriptionService -- injected after SubscriptionService init
local StarterPackService  -- injected via SetStarterPackService
local PersonalizedOfferService -- injected via SetPersonalizedOfferService
local EvolutionService    -- injected via SetEvolutionService

local ShopService = {}

local ALL_BOOST_TYPES = { "Coins", "Luck", "XP", "HatchSpeed" }

-- Activate a single boost (stack-friendly: extends if already active)
local function activateBoost(player: Player, data, boostType: string, duration: number)
    if not data.ActiveBoosts then
        data.ActiveBoosts = {}
    end
    local now = os.time()
    local currentExpiry = data.ActiveBoosts[boostType] or 0
    if currentExpiry > now then
        data.ActiveBoosts[boostType] = currentExpiry + duration
    else
        data.ActiveBoosts[boostType] = now + duration
    end
    Network.FireClient("BoostActivated", player, boostType, data.ActiveBoosts[boostType])
end

-- Process a dev product purchase
local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local data = DataService.GetData(player)
    if not data then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Receipt deduplication: guard against double-grant on server crash/retry.
    -- Per Roblox ProcessReceipt contract, the same PurchaseId may be retried on
    -- the next server session if the server shuts down before returning PurchaseGranted.
    if not data.PurchaseHistory then data.PurchaseHistory = {} end
    if data.PurchaseHistory[receiptInfo.PurchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local product = DevProductConfig.ProductByProductId[receiptInfo.ProductId]
    if not product then
        -- Route to EvolutionService for shard packs / instant-evolve tokens
        if EvolutionService then
            local handled = EvolutionService.OnDevProductPurchased(player, receiptInfo.ProductId)
            if handled then
                data.PurchaseHistory[receiptInfo.PurchaseId] = true
                return Enum.ProductPurchaseDecision.PurchaseGranted
            end
        end
        warn("[ShopService] Unknown product ID: " .. receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local success = ShopService.GrantProduct(player, product)

    if success then
        -- Record receipt so a server-crash retry is a no-op (cap history at 50 entries)
        data.PurchaseHistory[receiptInfo.PurchaseId] = true
        local historyKeys = {}
        for k in pairs(data.PurchaseHistory) do table.insert(historyKeys, k) end
        if #historyKeys > 50 then
            table.sort(historyKeys)
            for i = 1, #historyKeys - 50 do
                data.PurchaseHistory[historyKeys[i]] = nil
            end
        end

        -- Track analytics
        if AnalyticsService then
            AnalyticsService.TrackPurchaseCompleted(player, product.Id, product.Price)
        end

        -- Starter pack confirmation
        if StarterPackService and product.Id == "starter_pack" then
            StarterPackService.OnPurchased(player)
        end

        -- Personalized offer engine: track purchase event
        if PersonalizedOfferService then
            PersonalizedOfferService.OnPurchase(player)
        end

        -- First purchase bonus
        if not data.FirstPurchaseClaimed then
            data.FirstPurchaseClaimed = true
            CurrencyService.Add(player, "Gems", 25, false)
            Network.FireClient("ShowNotification", player,
                "First purchase bonus: +25 Gems!", "Success")
        end

        -- Track total Robux spent
        if not data.TotalRobuxSpent then data.TotalRobuxSpent = 0 end
        data.TotalRobuxSpent = data.TotalRobuxSpent + (product.Price or 0)

        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

-- Grant a specific product to a player
function ShopService.GrantProduct(player: Player, product): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    if product.Rewards and product.Rewards.WheelSpins then
        data.Wheel = data.Wheel or {
            LastFreeSpinDay = "",
            FreeSpinsUsedToday = 0,
            PaidSpinsAvailable = 0,
            TotalSpins = 0,
        }
        data.Wheel.PaidSpinsAvailable = (data.Wheel.PaidSpinsAvailable or 0) + product.Rewards.WheelSpins
        Network.FireClient("DataUpdated", player, "Wheel", data.Wheel)
        Network.FireClient("ShowNotification", player,
            "+" .. tostring(product.Rewards.WheelSpins) .. " Lucky Wheel spin credit!", "Success")
        return true
    end

    if product.Category == "Boost" then
        local duration = product.Duration or 1800
        local count = product.BoostCount or 1
        local totalDuration = duration * count

        if BoostService then
            if product.AllBoosts then
                BoostService.ActivateAll(player, totalDuration)
            else
                BoostService.Activate(player, product.BoostType, totalDuration)
            end
        else
            -- Fallback: direct data write (BoostService not yet available)
            if product.AllBoosts then
                local ALL_BOOST_TYPES = { "Coins", "Luck", "XP", "HatchSpeed" }
                for _, boostType in ipairs(ALL_BOOST_TYPES) do
                    activateBoost(player, data, boostType, totalDuration)
                end
            else
                activateBoost(player, data, product.BoostType, totalDuration)
            end
        end

        Network.FireClient("ShowNotification", player,
            product.Name .. " activated!", "Success")
        return true

    elseif product.Category == "Pack" or product.Category == "Currency" then
        -- Grant currency rewards
        if product.Rewards then
            if product.Rewards.Coins then
                CurrencyService.Add(player, "Coins", product.Rewards.Coins, false)
            end
            if product.Rewards.Gems then
                CurrencyService.Add(player, "Gems", product.Rewards.Gems, false)
            end
        end

        -- Grant bonus boost if included
        if product.BonusBoost then
            local boostDuration = product.BonusBoost.Duration or 1800
            if product.BonusBoost.BoostType == "AllBoosts" then
                for _, boostType in ipairs(ALL_BOOST_TYPES) do
                    activateBoost(player, data, boostType, boostDuration)
                end
            else
                activateBoost(player, data, product.BonusBoost.BoostType, boostDuration)
            end
        end

        Network.FireClient("ShowNotification", player,
            product.Name .. " claimed!", "Success")
        return true

    elseif product.Category == "Upgrade" then
        -- Pet storage upgrade
        if product.StorageIncrease then
            data.MaxPetStorage = (data.MaxPetStorage or 200) + product.StorageIncrease
            Network.FireClient("ShowNotification", player,
                "+" .. product.StorageIncrease .. " pet storage! (Now: " .. data.MaxPetStorage .. ")", "Success")
            Network.FireClient("DataUpdated", player, "MaxPetStorage", data.MaxPetStorage)
        end
        return true

    elseif product.Category == "BoostRefill" then
        -- Stored charges (activate on demand via BoostService.UseCharge)
        -- OR direct activation if product.DirectActivate = true
        local charges = product.ChargeCount or 1
        local duration = product.RefillDuration or product.Duration or 1800

        if product.DirectActivate and BoostService then
            -- Immediately activate all/single boost (used by "Refill All Boosts" bundle)
            if product.AllBoosts then
                BoostService.ActivateAll(player, duration)
            elseif product.BoostType then
                BoostService.Activate(player, product.BoostType, duration)
            end
        elseif product.AllBoosts and BoostService then
            local ALL_BOOST_TYPES = { "Coins", "Luck", "XP", "HatchSpeed" }
            for _, boostType in ipairs(ALL_BOOST_TYPES) do
                BoostService.AddCharges(player, boostType, charges)
            end
        elseif product.BoostType and BoostService then
            BoostService.AddCharges(player, product.BoostType, charges)
        end
        Network.FireClient("ShowNotification", player,
            product.Name .. " added to your inventory!", "Success")
        return true

    elseif product.Category == "Ultra" then
        -- High-ticket Ultra bundle: massive currency + boosts + storage + exclusive rewards
        if product.Rewards then
            if product.Rewards.Coins then
                CurrencyService.Add(player, "Coins", product.Rewards.Coins, false)
            end
            if product.Rewards.Gems then
                CurrencyService.Add(player, "Gems", product.Rewards.Gems, false)
            end
        end

        if product.BonusBoost and BoostService then
            local boostDuration = product.BonusBoost.Duration or 1800
            if product.BonusBoost.BoostType == "AllBoosts" then
                BoostService.ActivateAll(player, boostDuration)
            else
                BoostService.Activate(player, product.BonusBoost.BoostType, boostDuration)
            end
        end

        if product.BonusStorageSlots then
            data.MaxPetStorage = (data.MaxPetStorage or 200) + product.BonusStorageSlots
            Network.FireClient("DataUpdated", player, "MaxPetStorage", data.MaxPetStorage)
        end

        if product.ExclusiveTitle then
            if not data.Titles then data.Titles = {} end
            table.insert(data.Titles, product.ExclusiveTitle)
            Network.FireClient("DataUpdated", player, "Titles", data.Titles)
        end

        -- ExclusiveAnimatedPet: TODO — provision via PetService when pet asset is ready
        if product.ExclusiveAnimatedPet then
            if not data.ExclusiveAnimatedPets then data.ExclusiveAnimatedPets = {} end
            data.ExclusiveAnimatedPets[product.ExclusiveAnimatedPet] = true
        end

        Network.FireClient("ShowNotification", player,
            "🌟 " .. product.Name .. " — Ultra rewards granted!", "Success")
        return true
    end

    return false
end

-- Late-bind StarterPackService (to avoid circular require)
function ShopService.SetStarterPackService(sps)
    StarterPackService = sps
end

-- Late-bind PersonalizedOfferService
function ShopService.SetPersonalizedOfferService(pos)
    PersonalizedOfferService = pos
end

-- Late-bind EvolutionService (for receipt routing)
function ShopService.SetEvolutionService(es)
    EvolutionService = es
end

-- Initialize
function ShopService.Init(dataService, currencyService, analyticsService, boostService, subscriptionService)
    DataService = dataService
    CurrencyService = currencyService
    AnalyticsService = analyticsService
    BoostService = boostService
    SubscriptionService = subscriptionService

    -- Set up receipt processing
    MarketplaceService.ProcessReceipt = processReceipt

    -- Handle purchase prompts from client
    Network.OnServerEvent("PurchaseDevProduct", function(player: Player, productId: string)
        if type(productId) ~= "string" then return end
        if #productId > 64 then return end  -- Reject unbounded-length strings (memory-intern guard)
        local product = DevProductConfig.ProductById[productId]
        if not product or product.ProductId <= 0 then return end

        if AnalyticsService then
            AnalyticsService.TrackPurchaseStarted(player, productId, product.Price)
        end

        MarketplaceService:PromptProductPurchase(player, product.ProductId)
    end)
end

return ShopService
