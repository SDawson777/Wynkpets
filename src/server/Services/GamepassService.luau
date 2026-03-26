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

    data.Gamepasses[gamepassId] = true
    Network.FireClient("GamepassOwned", player, gamepassId)
    Network.FireClient("ShowNotification", player,
        "Gamepass activated: " .. (GamepassConfig.GetGamepass(gamepassId) and GamepassConfig.GetGamepass(gamepassId).Name or gamepassId) .. "!",
        "Success")
end

-- Verify ownership with Roblox on join
function GamepassService.VerifyOwnership(player: Player)
    for _, gp in ipairs(GamepassConfig.Gamepasses) do
        if gp.ProductId > 0 then
            local success, owns = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.ProductId)
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
        if not gp or gp.ProductId <= 0 then return end

        -- Already owns it?
        if GamepassService.OwnsGamepass(player, gamepassId) then
            Network.FireClient("ShowNotification", player, "You already own this gamepass!", "Info")
            return
        end

        -- Prompt purchase through Roblox
        MarketplaceService:PromptGamePassPurchase(player, gp.ProductId)
    end)

    -- Handle completed gamepass purchases
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
        if not wasPurchased then return end
        local gp = GamepassConfig.GamepassByProductId[gamepassId]
        if gp then
            GamepassService.GiveGamepass(player, gp.Id)
        end
    end)
end

return GamepassService
