--[[
    ShopController.luau (Client)
    Manages shop state and purchase requests.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local GamepassConfig = require(Shared:WaitForChild("Configs"):WaitForChild("GamepassConfig"))
local DevProductConfig = require(Shared:WaitForChild("Configs"):WaitForChild("DevProductConfig"))

local ShopController = {}

local ownedGamepasses = {}
local activeBoosts = {}
local updateCallbacks = {}

function ShopController.OwnsGamepass(gamepassId: string): boolean
    return ownedGamepasses[gamepassId] == true
end

function ShopController.GetActiveBoosts()
    return activeBoosts
end

function ShopController.OnUpdate(callback: () -> ())
    table.insert(updateCallbacks, callback)
end

local function notifyUpdate()
    for _, callback in ipairs(updateCallbacks) do
        task.spawn(callback)
    end
end

-- Purchase a gamepass
function ShopController.PurchaseGamepass(gamepassId: string)
    Network.FireServer("PurchaseGamepass", gamepassId)
end

-- Purchase a dev product
function ShopController.PurchaseDevProduct(productId: string)
    Network.FireServer("PurchaseDevProduct", productId)
end

-- Initialize
function ShopController.Init()
    Network.OnClientEvent("GamepassOwned", function(gamepassId: string)
        ownedGamepasses[gamepassId] = true
        notifyUpdate()
    end)

    Network.OnClientEvent("BoostActivated", function(boostType: string, expiry: number)
        activeBoosts[boostType] = expiry
        notifyUpdate()
    end)

    Network.OnClientEvent("BoostExpired", function(boostType: string)
        activeBoosts[boostType] = nil
        notifyUpdate()
    end)

    Network.OnClientEvent("PlayerDataLoaded", function(data)
        ownedGamepasses = data.Gamepasses or {}
        activeBoosts = data.ActiveBoosts or {}
        notifyUpdate()
    end)
end

return ShopController
