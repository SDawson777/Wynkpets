--[[
    CurrencyController.luau (Client)
    Tracks and displays currency values on the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local NumberFormat = require(Shared:WaitForChild("Utils"):WaitForChild("NumberFormat"))

local CurrencyController = {}

local currencies = {
    Coins = 0,
    Gems = 0,
}

local updateCallbacks = {} -- list of functions to call when currency changes

-- Get current balance
function CurrencyController.Get(currency: string): number
    return currencies[currency] or 0
end

-- Register a callback for currency updates
function CurrencyController.OnUpdate(callback: (string, number) -> ())
    table.insert(updateCallbacks, callback)
end

-- Get formatted currency string
function CurrencyController.GetFormatted(currency: string): string
    return NumberFormat.Abbreviate(currencies[currency] or 0)
end

-- Initialize
function CurrencyController.Init()
    Network.OnClientEvent("CurrencyUpdated", function(currency: string, amount: number)
        currencies[currency] = amount
        for _, callback in ipairs(updateCallbacks) do
            task.spawn(callback, currency, amount)
        end
    end)

    -- Load initial values from player data
    Network.OnClientEvent("PlayerDataLoaded", function(data)
        if data.Coins then
            currencies.Coins = data.Coins
        end
        if data.Gems then
            currencies.Gems = data.Gems
        end
        for _, callback in ipairs(updateCallbacks) do
            task.spawn(callback, "Coins", currencies.Coins)
            task.spawn(callback, "Gems", currencies.Gems)
        end
    end)
end

return CurrencyController
