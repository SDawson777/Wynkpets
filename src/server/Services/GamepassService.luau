--[[
    GamepassService.luau
    Handles gamepass purchase processing and ownership verification.
    Server-authoritative.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local GamepassConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GamepassConfig"))

local DataService
local SubscriptionService   -- late-bound
local AnalyticsService      -- late-bound
local EntitlementService    -- late-bound

local GamepassService = {}

-- Check if a player owns a gamepass (cached in data)
function GamepassService.OwnsGamepass(player: Player, gamepassId: string): boolean
    local data = DataService.GetData(player)
    if not data then return false end
    return data.Gamepasses and data.Gamepasses[gamepassId] == true
end

-- Grant a gamepass to player (update data)
function GamepassService.GiveGamepass(player: Player, gamepassId: string)
    local data = DataService.GetData(player)
    if not data then return end

    if not data.Gamepasses then
        data.Gamepasses = {}
    end

    local alreadyGranted = data.Gamepasses[gamepassId] == true
    data.Gamepasses[gamepassId] = true

    -- Sync EntitlementService cache so effects apply immediately (no rejoin needed)
    if EntitlementService then
        EntitlementService.GavePass(player, gamepassId)
    end

    -- Apply one-time persistent data effects (idempotent — only on first grant)
    if not alreadyGranted then
        local gp = GamepassConfig.GetGamepass(gamepassId)
        if gp and gp.ExtraEquipSlots then
            data.MaxEquipSlots = (data.MaxEquipSlots or 3) + gp.ExtraEquipSlots
            Network.FireClient("DataUpdated", player, "MaxEquipSlots", data.MaxEquipSlots)
        end
    end

    Network.FireClient("GamepassOwned", player, gamepassId)
    Network.FireClient("ShowNotification", player,
        "Gamepass activated: " .. (GamepassConfig.GetGamepass(gamepassId) and GamepassConfig.GetGamepass(gamepassId).Name or gamepassId) .. "!",
        "Success")
end

-- Verify ownership with Roblox on join
function GamepassService.VerifyOwnership(player: Player)
    for _, gp in ipairs(GamepassConfig.Gamepasses) do
        if gp.GamepassId and gp.GamepassId > 0 then
            local success, owns = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.GamepassId)
            end)
            if success and owns then
                GamepassService.GiveGamepass(player, gp.Id)
            end
        end
    end
end

-- Initialize
function GamepassService.Init(dataService)
    DataService = dataService

    -- Handle gamepass purchase prompts from client
    Network.OnServerEvent("PurchaseGamepass", function(player: Player, gamepassId: string)
        if type(gamepassId) ~= "string" then return end
        local gp = GamepassConfig.GetGamepass(gamepassId)
        if not gp or not gp.GamepassId or gp.GamepassId <= 0 then return end

        -- Already owns it?
        if GamepassService.OwnsGamepass(player, gamepassId) then
            Network.FireClient("ShowNotification", player, "You already own this gamepass!", "Info")
            return
        end

        -- Prompt purchase through Roblox
        if AnalyticsService then
            AnalyticsService.TrackPurchaseStarted(player, gamepassId, gp.Price)
        end
        MarketplaceService:PromptGamePassPurchase(player, gp.GamepassId)
    end)

    -- Handle completed gamepass purchases
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
        if not wasPurchased then return end
        local gp = GamepassConfig.GamepassByGamepassId[gamepassId]
        if gp then
            GamepassService.GiveGamepass(player, gp.Id)
            -- Track completed purchase
            if AnalyticsService then
                AnalyticsService.TrackPurchaseCompleted(player, gp.Id, gp.Price)
            end
            -- If this pass corresponds to a subscription tier, grant it
            if SubscriptionService then
                SubscriptionService.GrantFromGamepass(player, gamepassId)
            end
        end
    end)
end

-- Late-bind SubscriptionService to avoid circular dependency
function GamepassService.SetSubscriptionService(svc)
    SubscriptionService = svc
end

-- Late-bind EntitlementService (needed for cache sync and ExtraEquipSlots)
function GamepassService.SetEntitlementService(ents)
    EntitlementService = ents
end

-- Late-bind AnalyticsService
function GamepassService.SetAnalyticsService(as)
    AnalyticsService = as
end

return GamepassService
