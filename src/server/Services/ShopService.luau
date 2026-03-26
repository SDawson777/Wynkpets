--[[
    ShopService.luau
    Handles developer product purchases (consumables / boosts / packs).
    Server-authoritative with receipt validation.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local DevProductConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DevProductConfig"))

local DataService
local CurrencyService

local ShopService = {}

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

    local product = DevProductConfig.ProductByProductId[receiptInfo.ProductId]
    if not product then
        warn("[ShopService] Unknown product ID: " .. receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Grant the product rewards
    local success = ShopService.GrantProduct(player, product)

    if success then
        -- First purchase bonus
        if not data.FirstPurchaseClaimed then
            data.FirstPurchaseClaimed = true
            CurrencyService.Add(player, "Gems", 25, false)
            Network.FireClient("ShowNotification", player,
                "First purchase bonus: +25 Gems!", "Success")
        end

        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

-- Grant a specific product to a player
function ShopService.GrantProduct(player: Player, product): boolean
    local data = DataService.GetData(player)
    if not data then return false end

    if product.Category == "Boost" then
        -- Activate a timed boost
        if not data.ActiveBoosts then
            data.ActiveBoosts = {}
        end
        local currentExpiry = data.ActiveBoosts[product.BoostType] or 0
        local now = os.time()
        if currentExpiry > now then
            -- Extend existing boost
            data.ActiveBoosts[product.BoostType] = currentExpiry + product.Duration
        else
            data.ActiveBoosts[product.BoostType] = now + product.Duration
        end

        Network.FireClient("BoostActivated", player, product.BoostType, data.ActiveBoosts[product.BoostType])
        Network.FireClient("ShowNotification", player,
            product.Name .. " activated!", "Success")
        return true

    elseif product.Category == "Pack" then
        -- Grant pack rewards
        if product.Rewards then
            if product.Rewards.Coins then
                CurrencyService.Add(player, "Coins", product.Rewards.Coins, false)
            end
            if product.Rewards.Gems then
                CurrencyService.Add(player, "Gems", product.Rewards.Gems, false)
            end
        end

        Network.FireClient("ShowNotification", player,
            product.Name .. " claimed!", "Success")
        return true
    end

    return false
end

-- Initialize
function ShopService.Init(dataService, currencyService)
    DataService = dataService
    CurrencyService = currencyService

    -- Set up receipt processing
    MarketplaceService.ProcessReceipt = processReceipt

    -- Handle purchase prompts from client
    Network.OnServerEvent("PurchaseDevProduct", function(player: Player, productId: string)
        if type(productId) ~= "string" then return end
        local product = DevProductConfig.ProductById[productId]
        if not product or product.ProductId <= 0 then return end

        MarketplaceService:PromptProductPurchase(player, product.ProductId)
    end)
end

return ShopService
